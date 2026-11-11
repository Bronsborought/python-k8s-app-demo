output "project_id" {
  description = "Google Cloud project ID"
  value       = var.project_id
}

output "region" {
  description = "Default Google Cloud region"
  value       = var.region
}

output "enabled_services" {
  description = "GCP APIs managed by Terraform"
  value       = sort(keys(google_project_service.required))
}

output "artifact_registry_repository" {
  description = "Artifact Registry Docker repository ID"
  value       = google_artifact_registry_repository.docker.repository_id
}

output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "ingress_static_ip_name" {
  description = "Global static IP resource name referenced by GKE Ingress"
  value       = google_compute_global_address.ingress_ip.name
}

output "ingress_static_ip_address" {
  description = "Reserved global static IPv4 address for DNS A-record (app.tarakanovds.lol)"
  value       = google_compute_global_address.ingress_ip.address
}
