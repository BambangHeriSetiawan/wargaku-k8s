output "cluster_name" {
  description = "Civo Kubernetes cluster name"
  value       = civo_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "Civo Kubernetes cluster ID"
  value       = civo_kubernetes_cluster.main.id
}

output "api_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = civo_kubernetes_cluster.main.api_endpoint
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = local_sensitive_file.kubeconfig.filename
}

output "kubeconfig" {
  description = "Raw kubeconfig YAML — use with: terraform output -raw kubeconfig > ~/.kube/config"
  value       = civo_kubernetes_cluster.main.kubeconfig
  sensitive   = true
}

output "node_size" {
  description = "Node size in use"
  value       = var.node_size
}

output "next_steps" {
  description = "Commands to run after terraform apply"
  value       = <<-EOT

    ── Next steps ──────────────────────────────────────────────────────────────

    1. Export kubeconfig:
       export KUBECONFIG=${path.module}/kubeconfig.yaml

    2. Wait for the LoadBalancer IP (takes ~60s):
       kubectl get svc -n ingress-nginx -w

    3. Set DNS A records to the EXTERNAL-IP:
       ${var.domain}         → A → <EXTERNAL-IP>
       www.${var.domain}     → A → <EXTERNAL-IP>
       api.${var.domain}     → A → <EXTERNAL-IP>
       grafana.${var.domain} → A → <EXTERNAL-IP>

    4. Configure secrets:
       cp ../k8s/secrets/app-secrets.yaml.example ../k8s/secrets/app-secrets.yaml
       # fill values, then:
       kubectl apply -f ../k8s/secrets/app-secrets.yaml

    5. Deploy app + monitoring:
       kubectl apply -f ../k8s/

    ────────────────────────────────────────────────────────────────────────────
  EOT
}
