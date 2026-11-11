resource "google_compute_global_address" "ingress_ip" {
  name         = "my-app-gke-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  description  = "Global static IPv4 address for GKE production HTTPS Ingress (app.tarakanovds.lol)"

  depends_on = [
    google_project_service.required["compute.googleapis.com"],
  ]
}
