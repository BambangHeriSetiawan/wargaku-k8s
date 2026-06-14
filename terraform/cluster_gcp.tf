resource "google_container_cluster" "main" {
  count    = var.cloud_provider == "gcp" ? 1 : 0
  name     = "estathub-${var.environment}"
  location = var.gcp_region

  # Create an empty cluster and manage the node pool separately so it can be
  # updated without recreating the control plane.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = "default"
  subnetwork = "default"

  min_master_version = var.k8s_version != "" ? var.k8s_version : null

  deletion_protection = false
}

resource "google_container_node_pool" "main" {
  count      = var.cloud_provider == "gcp" ? 1 : 0
  name       = "default"
  location   = var.gcp_region
  cluster    = google_container_cluster.main[0].name
  node_count = var.node_count

  node_config {
    machine_type = var.gcp_node_machine_type
    disk_size_gb = 30
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "local_sensitive_file" "kubeconfig_gcp" {
  count           = var.cloud_provider == "gcp" ? 1 : 0
  filename        = "${path.module}/kubeconfig.yaml"
  file_permission = "0600"

  # Uses gke-gcloud-auth-plugin (install: gcloud components install gke-gcloud-auth-plugin)
  content = <<-YAML
    apiVersion: v1
    kind: Config
    clusters:
      - name: ${google_container_cluster.main[0].name}
        cluster:
          server: https://${google_container_cluster.main[0].endpoint}
          certificate-authority-data: ${google_container_cluster.main[0].master_auth[0].cluster_ca_certificate}
    users:
      - name: gcp
        user:
          exec:
            apiVersion: client.authentication.k8s.io/v1beta1
            command: gke-gcloud-auth-plugin
    contexts:
      - name: ${google_container_cluster.main[0].name}
        context:
          cluster: ${google_container_cluster.main[0].name}
          user: gcp
    current-context: ${google_container_cluster.main[0].name}
  YAML

  depends_on = [google_container_node_pool.main]
}
