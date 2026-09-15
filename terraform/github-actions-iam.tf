resource "google_service_account" "github_actions_deploy" {
  account_id   = "github-actions-deploy"
  display_name = "GitHub Actions Deploy"
  description  = "Identity used by GitHub Actions for cloud deployments"
}

resource "google_artifact_registry_repository_iam_member" "github_actions_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.docker.repository_id
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.github_actions_deploy.member
}

resource "google_project_iam_member" "github_actions_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = google_service_account.github_actions_deploy.member
}
