resource "google_compute_security_policy" "production_waf" {
  name        = "my-app-production-waf"
  description = "Cloud Armor WAF policy for production application"

  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Block SQL injection attempts"

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v422-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1100
    description = "Block cross-site scripting attempts"

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v422-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  depends_on = [
    google_project_service.required["compute.googleapis.com"],
  ]
}
