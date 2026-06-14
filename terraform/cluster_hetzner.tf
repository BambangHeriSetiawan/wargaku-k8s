resource "hcloud_ssh_key" "main" {
  count      = var.cloud_provider == "hetzner" ? 1 : 0
  name       = "estathub-${var.environment}"
  public_key = file(var.hetzner_ssh_public_key_file)
}

resource "hcloud_firewall" "main" {
  count = var.cloud_provider == "hetzner" ? 1 : 0
  name  = "estathub-${var.environment}"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # K8s API + SSH — restrict to your IP via admin_cidrs
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = var.admin_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.admin_cidrs
  }
}

resource "hcloud_server" "main" {
  count        = var.cloud_provider == "hetzner" ? 1 : 0
  name         = "estathub-${var.environment}"
  server_type  = var.hetzner_server_type
  location     = var.hetzner_location
  image        = "ubuntu-24.04"
  ssh_keys     = [hcloud_ssh_key.main[0].id]
  firewall_ids = [hcloud_firewall.main[0].id]

  # k3s with traefik disabled — nginx-ingress is installed by helm.tf instead.
  # Klipper (k3s built-in LB) will assign the node's public IP to LoadBalancer services.
  user_data = <<-CLOUD_INIT
    #cloud-config
    runcmd:
      - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
      - chmod 644 /etc/rancher/k3s/k3s.yaml
  CLOUD_INIT
}

# Wait for k3s to initialise, then pull kubeconfig with server's public IP substituted.
# Re-runs only if the server is recreated (triggers on server ID change).
resource "null_resource" "kubeconfig_hetzner" {
  count = var.cloud_provider == "hetzner" ? 1 : 0

  triggers = {
    server_id = tostring(hcloud_server.main[0].id)
  }

  provisioner "local-exec" {
    command = <<-CMD
      echo "Waiting 90s for k3s to initialise on ${hcloud_server.main[0].ipv4_address}..."
      sleep 90
      ssh -o StrictHostKeyChecking=no \
          -o ConnectTimeout=30 \
          -i ${var.hetzner_ssh_private_key_file} \
          root@${hcloud_server.main[0].ipv4_address} \
          "cat /etc/rancher/k3s/k3s.yaml" \
        | sed 's|127.0.0.1|${hcloud_server.main[0].ipv4_address}|g' \
        > ${path.module}/kubeconfig.yaml
      chmod 600 ${path.module}/kubeconfig.yaml
    CMD
  }

  depends_on = [hcloud_server.main]
}
