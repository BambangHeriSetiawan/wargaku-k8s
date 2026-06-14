# Fetch the latest available DOKS version for the given prefix (or latest stable if k8s_version is empty).
data "digitalocean_kubernetes_versions" "main" {
  count          = var.cloud_provider == "do" ? 1 : 0
  version_prefix = var.k8s_version != "" ? var.k8s_version : null
}

resource "digitalocean_kubernetes_cluster" "main" {
  count   = var.cloud_provider == "do" ? 1 : 0
  name    = "estathub-${var.environment}"
  region  = var.do_region
  version = data.digitalocean_kubernetes_versions.main[0].latest_version

  node_pool {
    name       = "default"
    size       = var.do_node_size
    node_count = var.node_count
  }
}

resource "local_sensitive_file" "kubeconfig_do" {
  count           = var.cloud_provider == "do" ? 1 : 0
  filename        = "${path.module}/kubeconfig.yaml"
  file_permission = "0600"
  content         = digitalocean_kubernetes_cluster.main[0].kube_config[0].raw_config
}
