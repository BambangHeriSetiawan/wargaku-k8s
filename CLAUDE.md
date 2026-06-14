# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Kubernetes manifests and Terraform IaC for **EstahHub** — an Indonesian real estate platform (`estathub.id`). The application stack is:

- **wargaku-go** — Go Fiber v2 backend API on port 8080 (image: `your-registry/wargaku-go:latest`)
- **estathub-web** — Next.js 16 standalone frontend on port 3000 (image: `your-registry/estathub-web:latest`)
- **postgres:16-alpine** — StatefulSet with 5Gi PVC
- **redis:7-alpine** — Deployment with `emptyDir` (intentional: cache + rate-limit only)
- Full monitoring stack: Prometheus, Grafana, Alertmanager, and four exporters

All workloads run in the `estathub` namespace.

## Common kubectl commands

```bash
# Apply the full stack in dependency order
kubectl apply -f namespace.yaml
kubectl apply -f secrets/app-secrets.yaml
kubectl apply -f postgres/
kubectl apply -f redis/
kubectl apply -f api/
kubectl apply -f web/
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/alertmanager/configmap.yaml
kubectl apply -f monitoring/alertmanager/deployment.yaml
kubectl apply -f monitoring/grafana/
kubectl apply -f monitoring/exporters/
kubectl apply -f ingress/cert-issuer.yaml
kubectl apply -f ingress/ingress.yaml

# Verify
kubectl get pods -n estathub
kubectl get ingress -n estathub
kubectl describe certificate -n estathub

# Run DB migrations (one-off)
kubectl run migrate --image=<registry>/wargaku-go:latest \
  -n estathub --restart=Never \
  --env="DB_HOST=postgres" --env="DB_PORT=5432" \
  --env="DB_NAME=estathub" --env="DB_USER=estathub" \
  --env="DB_PASSWORD=<password>" \
  -- ./wargaku-go migrate-up
kubectl logs migrate -n estathub && kubectl delete pod migrate -n estathub
```

## Terraform (cluster provisioning)

Supports four cloud providers selected via `cloud_provider` in `terraform.tfvars`. All provision nginx-ingress and cert-manager via Helm and write `kubeconfig.yaml` to `terraform/`.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set cloud_provider + fill the matching section
terraform init
terraform plan
terraform apply
export KUBECONFIG=$(pwd)/kubeconfig.yaml       # written by terraform apply
```

**Provider options** (`cloud_provider` value → what gets created):

| Value | Provider | Cluster type | Node default | ~Cost |
|---|---|---|---|---|
| `civo` (default) | Civo Cloud SGP1 | k3s managed | `g4s.kube.medium` 2vCPU/4GB | $10/mo |
| `gcp` | GKE, `asia-southeast1-a` | Zonal GKE | `e2-medium` 2vCPU/4GB | $30/mo |
| `aws` | EKS, `ap-southeast-1` | EKS + managed node group | `t3.medium` 2vCPU/4GB | $30/mo+ |
| `do` | DigitalOcean `sgp1` | DOKS | `s-2vcpu-4gb` 2vCPU/4GB | $24/mo |
| `hetzner` | Hetzner Cloud `nbg1` | Single server + k3s | `cx21` 2vCPU/4GB | ~$6/mo |

**Per-provider prerequisites:**
- **Civo** — `civo_token` + optionally tighten `admin_cidrs`
- **GCP** — `gcp_project` + either `gcp_credentials_file` or `gcloud auth application-default login`; install `gke-gcloud-auth-plugin` (`gcloud components install gke-gcloud-auth-plugin`)
- **AWS** — `aws_access_key`/`aws_secret_key` or ambient env vars (`AWS_ACCESS_KEY_ID`, etc.); install AWS CLI (`brew install awscli`); uses the default VPC
- **DigitalOcean** — `do_token`; DOKS version is auto-resolved to latest stable
- **Hetzner** — `hcloud_token` + SSH key paths (`hetzner_ssh_public_key_file`, `hetzner_ssh_private_key_file`); k3s is installed via cloud-init on a plain Ubuntu 24.04 server; kubeconfig is extracted via SSH 90s after server creation; `admin_cidrs` also restricts SSH (port 22) — set it to your IP

**Terraform files:**

| File | Purpose |
|---|---|
| `providers.tf` | All four cloud providers + kubernetes/helm (file-based kubeconfig) |
| `versions.tf` | Provider version pins (Terraform ≥ 1.7) |
| `variables.tf` | `cloud_provider` + shared + per-provider variables |
| `cluster.tf` | Civo firewall + cluster (`count = var.cloud_provider == "civo" ? 1 : 0`) |
| `cluster_gcp.tf` | GKE cluster + node pool |
| `cluster_aws.tf` | IAM roles + EKS cluster + managed node group |
| `cluster_do.tf` | DOKS cluster with auto-resolved version |
| `cluster_hetzner.tf` | Hetzner firewall + server + k3s (via cloud-init) + kubeconfig via `null_resource` SSH |
| `helm.tf` | `kubernetes_namespace`, nginx-ingress, cert-manager, ClusterIssuer |
| `outputs.tf` | Uses `try()` to resolve active cluster across all providers |

**How multi-cloud works** — each cluster file uses `count = var.cloud_provider == "<x>" ? 1 : 0`, so only the active provider's resources are created. Each cluster file writes `kubeconfig.yaml` (named `kubeconfig_<provider>` to avoid conflicts; Hetzner uses a `null_resource` instead of `local_sensitive_file` because the kubeconfig is pulled via SSH). The kubernetes/helm providers use `config_path = "${path.module}/kubeconfig.yaml"` so they work with any provider. `helm.tf` depends on all five kubeconfig resources; inactive ones (count=0) are no-ops.

**Hetzner specifics** — this is the only provider that creates a raw server rather than a managed cluster. k3s ships with Klipper LB built in, so LoadBalancer services receive the node's public IP without needing the hcloud cloud-controller-manager. Traefik is disabled at install time (`--disable traefik`) since nginx-ingress is used instead. The kubeconfig is extracted 90s after server creation via a `local-exec` SSH command that replaces `127.0.0.1` with the server's public IP.

## Secrets setup (before first deploy)

```bash
# 1. App secrets
cp secrets/app-secrets.yaml.example secrets/app-secrets.yaml
# Encode each value: echo -n "value" | base64
# Edit secrets/app-secrets.yaml, then:
kubectl apply -f secrets/app-secrets.yaml

# 2. Grafana admin password
kubectl create secret generic grafana-secrets \
  --from-literal=GRAFANA_ADMIN_PASSWORD=<password> -n estathub

# 3. Alertmanager SMTP
cp monitoring/alertmanager/secret.yaml.example monitoring/alertmanager/secret.yaml
# Fill all base64 values (SMTP_HOST, SMTP_USER, SMTP_PASSWORD, GRAFANA_ALERT_EMAIL,
# ALERT_EMAIL, ONCALL_EMAIL, PAYMENT_TEAM_EMAIL, INFRA_TEAM_EMAIL), then:
kubectl apply -f monitoring/alertmanager/secret.yaml

# 4. Postgres exporter DSN
kubectl create secret generic postgres-exporter-secret \
  --from-literal=DATA_SOURCE_NAME="postgresql://estathub:<pw>@postgres:5432/estathub?sslmode=disable" \
  -n estathub
```

The `alertmanager/secret.yaml` and `secrets/app-secrets.yaml` are gitignored — never commit them.

## Architecture notes

**Ingress routing** — a single nginx Ingress (`ingress/ingress.yaml`) terminates TLS for all four subdomains and routes to their ClusterIP Services. All Services use port 80 externally regardless of container port.

**Alertmanager SMTP pattern** — Alertmanager does not natively expand env vars in its config file. The Alertmanager Deployment uses an Alpine init container that runs `envsubst` to render `alertmanager.yml.tmpl` (from ConfigMap) using values from `alertmanager-secrets` into `/config/alertmanager.yml` before the main container starts.

**Prometheus data loss** — Prometheus uses `emptyDir` for its TSDB. Metrics are retained for 30 days within a running pod, but a pod restart wipes history. Add a PVC if persistence is required.

**Firebase credentials** — The `firebase-credentials` Secret holds the service account JSON, mounted as a file at `/etc/firebase/firebase-service-account.json` in the API pod. The path is set via the `FIREBASE_CREDENTIALS_FILE` env var.

**Image placeholders** — `api/deployment.yaml` and `web/deployment.yaml` both reference `your-registry/...`. Update these to your actual container registry paths before deploying.

**Security note** — `admin_cidrs` defaults to `0.0.0.0/0` in `terraform/variables.tf`. Always restrict to your actual IP in `terraform.tfvars`. `DB_SSL_MODE` defaults to `disable` in the example secret; use `require` in production.
