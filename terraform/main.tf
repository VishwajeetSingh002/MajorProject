terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config" # Default local kubeconfig path
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = var.namespace_name
  }
}
