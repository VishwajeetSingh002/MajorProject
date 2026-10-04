output "namespace" {
  description = "The created Kubernetes namespace"
  value       = kubernetes_namespace.dev.metadata[0].name
}
