terraform {
  required_version = ">= 1.7"

  required_providers {
    civo = {
      source  = "civo/civo"
      version = "~> 1.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Uncomment to store state remotely (recommended for team use).
  # Terraform Cloud is free for single users:
  # backend "remote" {
  #   organization = "estathub"
  #   workspaces { name = "estathub-prod" }
  # }
}
