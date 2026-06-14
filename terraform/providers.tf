# ── Civo ──────────────────────────────────────────────────────────────────────
provider "civo" {
  token  = var.civo_token
  region = var.civo_region
}

# ── GCP ───────────────────────────────────────────────────────────────────────
provider "google" {
  project     = var.gcp_project
  region      = var.gcp_region
  credentials = var.gcp_credentials_file != "" ? file(var.gcp_credentials_file) : null
}

# ── AWS ───────────────────────────────────────────────────────────────────────
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null
}

# ── DigitalOcean ──────────────────────────────────────────────────────────────
provider "digitalocean" {
  token = var.do_token
}

# ── Hetzner Cloud ─────────────────────────────────────────────────────────────
provider "hcloud" {
  token = var.hcloud_token
}

# ── Kubernetes & Helm ─────────────────────────────────────────────────────────
# All cluster resources write their kubeconfig to kubeconfig.yaml so a single
# file-based config works regardless of which cloud_provider is active.
provider "kubernetes" {
  config_path = "${path.module}/kubeconfig.yaml"
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}
