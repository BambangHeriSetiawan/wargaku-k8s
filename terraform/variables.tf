# ── Provider selection ────────────────────────────────────────────────────────

variable "cloud_provider" {
  description = "Which cloud provider to deploy on. One of: civo, gcp, aws, do."
  type        = string
  default     = "civo"

  validation {
    condition     = contains(["civo", "gcp", "aws", "do", "hetzner"], var.cloud_provider)
    error_message = "cloud_provider must be one of: civo, gcp, aws, do, hetzner."
  }
}

# ── Shared ────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment label appended to resource names."
  type        = string
  default     = "prod"
}

variable "node_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 1
}

variable "k8s_version" {
  description = "Kubernetes version. Leave empty to use the provider's latest stable."
  type        = string
  default     = ""
}

variable "domain" {
  description = "Root domain for the app (e.g. wargaku.id)."
  type        = string
  default     = "wargaku.id"
}

variable "alert_email" {
  description = "Email for Let's Encrypt certificate notifications."
  type        = string
  default     = "setiawan.heri.bambang@gmail.com"
}

# ── Civo ──────────────────────────────────────────────────────────────────────

variable "civo_token" {
  description = "Civo API token — https://dashboard.civo.com/security"
  type        = string
  sensitive   = true
  default     = ""
}

variable "civo_region" {
  description = "Civo region. SGP1 (Singapore) is closest to Indonesia."
  type        = string
  default     = "SGP1"
}

variable "node_size" {
  description = <<-EOT
    Civo node size.
      g4s.kube.small  — 1 vCPU, 2 GB  ~$5/mo  (too small for full stack)
      g4s.kube.medium — 2 vCPU, 4 GB  ~$10/mo (minimum recommended)
      g4s.kube.large  — 4 vCPU, 8 GB  ~$20/mo (comfortable headroom)
  EOT
  type        = string
  default     = "g4s.kube.medium"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API server (port 6443). Restrict to your IP."
  type        = list(string)
  default     = ["0.0.0.0/0"] # tighten in production
}

# ── GCP / GKE ─────────────────────────────────────────────────────────────────

variable "gcp_project" {
  description = "GCP project ID."
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region or zone for the GKE cluster (e.g. asia-southeast1-a). A zone creates a cheaper zonal cluster; a region creates a regional cluster."
  type        = string
  default     = "asia-southeast1-a"
}

variable "gcp_credentials_file" {
  description = "Path to a GCP service account JSON key file. Leave empty to use Application Default Credentials (gcloud auth application-default login)."
  type        = string
  default     = ""
}

variable "gcp_node_machine_type" {
  description = "GCE machine type for GKE nodes (e2-medium = 2 vCPU, 4 GB, ~$30/mo)."
  type        = string
  default     = "e2-medium"
}

# ── AWS / EKS ─────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for EKS (ap-southeast-1 = Singapore)."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_access_key" {
  description = "AWS access key ID. Leave empty to use env vars (AWS_ACCESS_KEY_ID) or an instance profile."
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_secret_key" {
  description = "AWS secret access key. Leave empty to use env vars (AWS_SECRET_ACCESS_KEY) or an instance profile."
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_node_instance_type" {
  description = "EC2 instance type for EKS nodes (t3.medium = 2 vCPU, 4 GB, ~$30/mo)."
  type        = string
  default     = "t3.medium"
}

# ── DigitalOcean / DOKS ───────────────────────────────────────────────────────

variable "do_token" {
  description = "DigitalOcean personal access token."
  type        = string
  sensitive   = true
  default     = ""
}

variable "do_region" {
  description = "DigitalOcean region slug (sgp1 = Singapore)."
  type        = string
  default     = "sgp1"
}

variable "do_node_size" {
  description = "DigitalOcean Droplet size for DOKS nodes (s-2vcpu-4gb = 2 vCPU, 4 GB, ~$24/mo)."
  type        = string
  default     = "s-2vcpu-4gb"
}

# ── Hetzner Cloud / k3s ───────────────────────────────────────────────────────

variable "hcloud_token" {
  description = "Hetzner Cloud API token — https://console.hetzner.cloud → project → Security → API Tokens."
  type        = string
  sensitive   = true
  default     = ""
}

variable "hetzner_location" {
  description = "Hetzner datacenter location. Options: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki), ash (Ashburn), hil (Hillsboro)."
  type        = string
  default     = "nbg1"
}

variable "hetzner_server_type" {
  description = "Hetzner server type. cx21 = 2 vCPU, 4 GB RAM, ~$6/mo. cpx21 = 3 vCPU AMD, 4 GB, ~$6/mo."
  type        = string
  default     = "cx21"
}

variable "hetzner_ssh_public_key_file" {
  description = "Path to the SSH public key to install on the Hetzner server (e.g. ~/.ssh/id_ed25519.pub)."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "hetzner_ssh_private_key_file" {
  description = "Path to the SSH private key used to pull kubeconfig from the server after k3s starts."
  type        = string
  default     = "~/.ssh/id_ed25519"
}
