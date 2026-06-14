# Kubernetes Deployment Plan — EstathHub

## Stack

| Component | Technology | Port |
|---|---|---|
| `wargaku-web` | Next.js 16 (standalone) | 3000 |
| `wargaku-go` | Go Fiber v2 | 8080 |
| Database | PostgreSQL 16 | 5432 |
| Cache | Redis 7 | 6379 |
| Monitoring | Prometheus + Grafana | 9090 / 3001 |

---

## Where to Deploy — Minimum Pricing Research

### Managed Kubernetes (easiest)

| Provider | Node Spec | Cost/month | Notes |
|---|---|---|---|
| **Civo Cloud** | 1× g4s.kube.medium (4GB, 2vCPU) | **~$10** | Free control plane, free LB, fastest setup |
| OVHcloud Managed K8s | 1× b2-7 (7GB, 2vCPU) | ~$10 | Free control plane, EU datacenter |
| Vultr VKE | 1× vc2-2c-4gb (4GB, 2vCPU) | ~$24 | Free control plane |
| DigitalOcean DOKS | 1× s-2vcpu-4gb (4GB, 2vCPU) | ~$24 | Free control plane |
| Linode LKE | 1× g6-standard-2 (4GB, 2vCPU) | ~$24 | Free control plane |

### Self-Managed K8s (cheapest, needs more setup)

| Provider | Node Spec | Cost/month | Notes |
|---|---|---|---|
| **Hetzner + k3s** | 1× CX21 (4GB, 2vCPU) | **~$6** | Cheapest possible, no managed K8s |
| Hetzner + k3s + LB | CX21 + LB11 | ~$12 | Adds proper LoadBalancer |

### Recommendation

**Go with Civo Cloud at ~$10/month** — free control plane, built-in LoadBalancer, 1-click k3s,
and you keep kubectl access. Only $4 more than raw Hetzner but saves hours of setup.

If budget is the #1 priority and you are comfortable with Linux server setup:
use **Hetzner CX21 (~$6/month) + k3s** with NodePort instead of a LoadBalancer.

---

## File Structure Created

```
ESTATHUB/
├── wargaku-web/
│   ├── Dockerfile          ← multi-stage Next.js (standalone)
│   └── next.config.ts      ← output: "standalone" added
├── wargaku-go/
│   └── Dockerfile          ← multi-stage Go binary
└── k8s/
    ├── namespace.yaml
    ├── secrets/
    │   └── app-secrets.yaml.example        ← copy → app-secrets.yaml, fill values
    ├── postgres/
    │   ├── statefulset.yaml
    │   └── service.yaml
    ├── redis/
    │   └── deployment.yaml                 ← includes Service
    ├── api/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── web/
    │   └── deployment.yaml                 ← includes Service
    ├── monitoring/                          ← moved from wargaku-go/monitoring/
    │   ├── prometheus/
    │   │   ├── configmap.yaml              ← prometheus.yml + alert rules
    │   │   └── deployment.yaml             ← includes Service + ServiceAccount
    │   ├── grafana/
    │   │   ├── configmap.yaml              ← datasources + dashboard provisioning
    │   │   ├── dashboard-configmap.yaml    ← wargaku-overview.json
    │   │   └── deployment.yaml             ← includes Service
    │   ├── alertmanager/
    │   │   ├── configmap.yaml              ← alertmanager.yml template
    │   │   ├── secret.yaml.example         ← SMTP creds template
    │   │   └── deployment.yaml             ← init container does envsubst, includes Service
    │   └── exporters/
    │       ├── postgres-exporter.yaml
    │       ├── redis-exporter.yaml
    │       ├── node-exporter.yaml          ← DaemonSet
    │       └── cadvisor.yaml               ← DaemonSet
    └── ingress/
        ├── cert-issuer.yaml                ← Let's Encrypt ClusterIssuer
        └── ingress.yaml                    ← web + api + grafana.wargaku.id
```

---

## Deployment Steps

### 1. Prerequisites

```bash
# Install tools
brew install kubectl helm

# On Civo: install the CLI
brew install civo/tap/civo
civo apikey save <your-api-key>
```

### 2. Create Cluster (Civo example)

```bash
civo kubernetes create wargaku \
  --size g4s.kube.medium \
  --nodes 1 \
  --wait

civo kubernetes config wargaku --save
kubectl get nodes  # verify
```

### 3. Install nginx ingress + cert-manager

```bash
# nginx ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# cert-manager (free TLS via Let's Encrypt)
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true
```

### 4. Build & Push Docker Images

You need a container registry. Free options:
- **GitHub Container Registry (ghcr.io)** — free for public repos
- **Docker Hub** — free tier (1 private repo)

```bash
# Go API
cd wargaku-go
docker build -t ghcr.io/<your-org>/wargaku-go:latest .
docker push ghcr.io/<your-org>/wargaku-go:latest

# Next.js Web
cd wargaku-web
docker build -t ghcr.io/<your-org>/wargaku-web:latest .
docker push ghcr.io/<your-org>/wargaku-web:latest
```

Update `image:` fields in `k8s/api/deployment.yaml` and `k8s/web/deployment.yaml`
to match your registry path.

### 5. Configure Secrets

```bash
cp k8s/secrets/app-secrets.yaml.example k8s/secrets/app-secrets.yaml

# Encode each value:
echo -n "your-db-password" | base64

# Edit k8s/secrets/app-secrets.yaml with all encoded values
# Then apply:
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets/app-secrets.yaml

# Grafana admin password
kubectl create secret generic grafana-secrets \
  --from-literal=GRAFANA_ADMIN_PASSWORD=<your-password> \
  -n wargaku

# Alertmanager SMTP (copy + fill secret.yaml.example first)
cp k8s/monitoring/alertmanager/secret.yaml.example k8s/monitoring/alertmanager/secret.yaml
# fill all base64 values, then:
kubectl apply -f k8s/monitoring/alertmanager/secret.yaml

# postgres-exporter DSN
kubectl create secret generic postgres-exporter-secret \
  --from-literal=DATA_SOURCE_NAME="postgresql://wargaku:<password>@postgres:5432/wargaku?sslmode=disable" \
  -n wargaku
```

### 6. Deploy Everything

```bash
# Apply in order (dependencies first)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets/app-secrets.yaml
kubectl apply -f k8s/postgres/
kubectl apply -f k8s/redis/
kubectl apply -f k8s/api/
kubectl apply -f k8s/web/

# Monitoring stack
kubectl apply -f k8s/monitoring/prometheus/
kubectl apply -f k8s/monitoring/alertmanager/configmap.yaml
kubectl apply -f k8s/monitoring/alertmanager/deployment.yaml
kubectl apply -f k8s/monitoring/grafana/
kubectl apply -f k8s/monitoring/exporters/

kubectl apply -f k8s/ingress/cert-issuer.yaml
kubectl apply -f k8s/ingress/ingress.yaml
```

### 7. DNS

Point your domain's A record to the LoadBalancer IP:

```bash
kubectl get svc -n ingress-nginx
# Note the EXTERNAL-IP, then set DNS:
# wargaku.id         → A → <EXTERNAL-IP>
# api.wargaku.id     → A → <EXTERNAL-IP>
# grafana.wargaku.id → A → <EXTERNAL-IP>
```

### 8. Run DB Migrations

```bash
# One-time job to run migrations
kubectl run migrate --image=ghcr.io/<your-org>/wargaku-go:latest \
  -n wargaku --restart=Never \
  --env="DB_HOST=postgres" \
  --env="DB_PORT=5432" \
  --env="DB_NAME=wargaku" \
  --env="DB_USER=wargaku" \
  --env="DB_PASSWORD=<password>" \
  -- ./wargaku-go migrate-up

kubectl logs migrate -n wargaku
kubectl delete pod migrate -n wargaku
```

---

## Verify

```bash
kubectl get pods -n wargaku          # all pods Running
kubectl get ingress -n wargaku        # check ADDRESS
kubectl describe certificate -n wargaku  # TLS issued
curl https://api.wargaku.id/health   # API health check
```

---

## Monthly Cost Summary (Civo)

| Item | Cost |
|---|---|
| Civo 1× g4s.kube.medium node | $10 |
| LoadBalancer | Free (Civo includes 1) |
| cert-manager TLS (Let's Encrypt) | Free |
| Container Registry (ghcr.io) | Free |
| **Total** | **~$10/month** |

For Hetzner + k3s: ~$6/month (no LoadBalancer) or ~$12/month (with LB11).
