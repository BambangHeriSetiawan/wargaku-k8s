terraform {
  required_version = ">= 1.7"

  required_providers {
    civo = {
      source  = "civo/civo"
      version = "~> 1.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }

  # Uncomment to store state remotely (recommended for team use).
  # Terraform Cloud is free for single users:
  # backend "remote" {
  #   organization = "estathub"
  #   workspaces { name = "estathub-prod" }
  # }
}
