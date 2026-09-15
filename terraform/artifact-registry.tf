resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "python-k8s-app"
  description   = "Docker images for python-k8s-app-demo"
  format        = "DOCKER"

  docker_config {
    immutable_tags = true
  }

  depends_on = [
    google_project_service.required["artifactregistry.googleapis.com"]
  ]
}
