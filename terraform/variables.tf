# ── Civo ──────────────────────────────────────────────────────────────────────

variable "civo_token" {
  description = "Civo API token — https://dashboard.civo.com/security"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Civo region. SGP1 (Singapore) is closest to Indonesia."
  type        = string
  default     = "SGP1"
}

variable "environment" {
  description = "Environment label appended to resource names."
  type        = string
  default     = "prod"
}

# ── Cluster ───────────────────────────────────────────────────────────────────

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

variable "node_count" {
  description = "Number of worker nodes. 1 is enough for a single-project setup."
  type        = number
  default     = 1
}

variable "k8s_version" {
  description = "Kubernetes version. Leave empty to use Civo's latest stable."
  type        = string
  default     = ""
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API server (port 6443). Restrict to your IP."
  type        = list(string)
  default     = ["0.0.0.0/0"] # tighten in production
}

# ── App ───────────────────────────────────────────────────────────────────────

variable "domain" {
  description = "Root domain for the app (e.g. estathub.id)."
  type        = string
  default     = "estathub.id"
}

variable "alert_email" {
  description = "Email for Let's Encrypt certificate notifications."
  type        = string
  default     = "setiawan.heri.bambang@gmail.com"
}
