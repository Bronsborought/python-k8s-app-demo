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
