data "google_project" "current" {
  project_id = var.project_id
}

resource "google_billing_budget" "project" {
  billing_account = var.billing_account_id
  display_name    = "python-k8s-app-demo monthly budget"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.monthly_budget_usd
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.8
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = []
    enable_project_level_recipients  = true
  }

  depends_on = [
    google_project_service.required["billingbudgets.googleapis.com"]
  ]
}
