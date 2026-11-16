output "argocd_ui" {
  description = "How to open the Argo CD UI."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:80, then http://localhost:8080 (user admin, password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
}

output "eurag" {
  description = "How to reach EURAG."
  value       = "kubectl -n ${var.eurag_namespace} port-forward svc/eurag 8000:8000, then http://localhost:8000"
}
