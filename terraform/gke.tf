resource "google_container_cluster" "autopilot" {
  name     = "python-k8s-app"
  location = var.region

  enable_autopilot    = true
  deletion_protection = false

  secret_manager_config {
    enabled = true
  }

  release_channel {
    channel = "REGULAR"
  }

  depends_on = [
    google_project_service.required["compute.googleapis.com"],
    google_project_service.required["container.googleapis.com"],
  ]
}
