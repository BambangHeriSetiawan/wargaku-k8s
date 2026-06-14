locals {
  # Resolves to whichever cluster is active (count = 1).
  active_cluster_name = try(
    civo_kubernetes_cluster.main[0].name,
    google_container_cluster.main[0].name,
    aws_eks_cluster.main[0].name,
    digitalocean_kubernetes_cluster.main[0].name,
    hcloud_server.main[0].name,
    "unknown"
  )
}

output "cloud_provider" {
  description = "Active cloud provider"
  value       = var.cloud_provider
}

output "cluster_name" {
  description = "Kubernetes cluster / server name"
  value       = local.active_cluster_name
}

output "cluster_id" {
  description = "Cluster or server ID"
  value = try(
    civo_kubernetes_cluster.main[0].id,
    digitalocean_kubernetes_cluster.main[0].id,
    tostring(hcloud_server.main[0].id),
    "n/a"
  )
}

output "api_endpoint" {
  description = "Kubernetes API server endpoint"
  value = try(
    civo_kubernetes_cluster.main[0].api_endpoint,
    "https://${google_container_cluster.main[0].endpoint}",
    aws_eks_cluster.main[0].endpoint,
    digitalocean_kubernetes_cluster.main[0].endpoint,
    "https://${hcloud_server.main[0].ipv4_address}:6443",
    "unknown"
  )
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = "${path.module}/kubeconfig.yaml"
}

output "kubeconfig" {
  description = "Raw kubeconfig YAML (Civo and DigitalOcean). GCP/AWS/Hetzner use exec-based auth — read kubeconfig.yaml directly."
  sensitive   = true
  value = try(
    civo_kubernetes_cluster.main[0].kubeconfig,
    digitalocean_kubernetes_cluster.main[0].kube_config[0].raw_config,
    "exec-based auth — see ${path.module}/kubeconfig.yaml"
  )
}

output "node_size" {
  description = "Node size / instance type in use"
  value = (
    var.cloud_provider == "civo"    ? var.node_size :
    var.cloud_provider == "gcp"     ? var.gcp_node_machine_type :
    var.cloud_provider == "aws"     ? var.aws_node_instance_type :
    var.cloud_provider == "do"      ? var.do_node_size :
    var.cloud_provider == "hetzner" ? var.hetzner_server_type :
    "unknown"
  )
}

output "next_steps" {
  description = "Commands to run after terraform apply"
  value       = <<-EOT

    ── Next steps ──────────────────────────────────────────────────────────────

    1. Export kubeconfig:
       export KUBECONFIG=${path.module}/kubeconfig.yaml

    2. Wait for the LoadBalancer IP (takes ~60–120s):
       kubectl get svc -n ingress-nginx -w

    3. Set DNS A records to the EXTERNAL-IP:
       ${var.domain}         → A → <EXTERNAL-IP>
       www.${var.domain}     → A → <EXTERNAL-IP>
       api.${var.domain}     → A → <EXTERNAL-IP>
       grafana.${var.domain} → A → <EXTERNAL-IP>

    4. Configure secrets:
       cp ../secrets/app-secrets.yaml.example ../secrets/app-secrets.yaml
       # fill values, then:
       kubectl apply -f ../secrets/app-secrets.yaml

    5. Deploy app + monitoring:
       kubectl apply -f ../

    ────────────────────────────────────────────────────────────────────────────
  EOT
}
