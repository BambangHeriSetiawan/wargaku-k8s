resource "civo_firewall" "main" {
  name                 = "estathub-${var.environment}"
  region               = var.region
  create_default_rules = false

  # Public web traffic
  ingress_rule {
    label      = "http"
    protocol   = "TCP"
    port_range = "80"
    cidr       = ["0.0.0.0/0", "::/0"]
    action     = "allow"
  }

  ingress_rule {
    label      = "https"
    protocol   = "TCP"
    port_range = "443"
    cidr       = ["0.0.0.0/0", "::/0"]
    action     = "allow"
  }

  # K8s API — restrict to your IP
  ingress_rule {
    label      = "k8s-api"
    protocol   = "TCP"
    port_range = "6443"
    cidr       = var.admin_cidrs
    action     = "allow"
  }

  # All outbound allowed (OS updates, image pulls, Firebase, Midtrans)
  egress_rule {
    label      = "all-outbound"
    protocol   = "TCP"
    port_range = "1-65535"
    cidr       = ["0.0.0.0/0", "::/0"]
    action     = "allow"
  }

  egress_rule {
    label      = "all-outbound-udp"
    protocol   = "UDP"
    port_range = "1-65535"
    cidr       = ["0.0.0.0/0", "::/0"]
    action     = "allow"
  }
}

resource "civo_kubernetes_cluster" "main" {
  name        = "estathub-${var.environment}"
  region      = var.region
  firewall_id = civo_firewall.main.id
  cni         = "flannel"

  # Set only when overriding the default
  kubernetes_version = var.k8s_version != "" ? var.k8s_version : null

  pools {
    label      = "default"
    size       = var.node_size
    node_count = var.node_count
  }
}

# Write kubeconfig to disk so kubectl and helm can pick it up
resource "local_sensitive_file" "kubeconfig" {
  content         = civo_kubernetes_cluster.main.kubeconfig
  filename        = "${path.module}/kubeconfig.yaml"
  file_permission = "0600"
}
