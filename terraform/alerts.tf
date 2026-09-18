resource "google_monitoring_alert_policy" "production_pod_restarts" {
  display_name = "GKE production pod restarts"
  combiner     = "OR"

  conditions {
    display_name = "my-app container restarted"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_container"
        AND metric.type = "kubernetes.io/container/restart_count"
        AND resource.labels.cluster_name = "python-k8s-app"
        AND resource.labels.namespace_name = "production"
        AND resource.labels.container_name = "my-app"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_DELTA"
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  depends_on = [
    google_project_service.required["monitoring.googleapis.com"],
  ]
}


resource "google_monitoring_alert_policy" "production_probe_failures" {
  display_name = "GKE production probe failures"
  combiner     = "OR"

  conditions {
    display_name = "Readiness or liveness probe failed"

    condition_matched_log {
      filter = <<-EOT
        resource.type = "k8s_pod"
        AND resource.labels.cluster_name = "python-k8s-app"
        AND resource.labels.namespace_name = "production"
        AND log_id("events")
        AND jsonPayload.reason = "Unhealthy"
        AND (
          jsonPayload.message : "Readiness probe failed"
          OR jsonPayload.message : "Liveness probe failed"
        )
      EOT
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }

    auto_close = "1800s"
  }

  depends_on = [
    google_project_service.required["logging.googleapis.com"],
    google_project_service.required["monitoring.googleapis.com"],
  ]
}


resource "google_monitoring_uptime_check_config" "production_health" {
  display_name       = "Production application health"
  timeout            = "10s"
  period             = "60s"
  checker_type       = "STATIC_IP_CHECKERS"
  log_check_failures = true

  http_check {
    path           = "/health"
    port           = 443
    request_method = "GET"
    use_ssl        = true
    validate_ssl   = true

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"

    labels = {
      project_id = var.project_id
      host       = "app.tarakanovds.lol"
    }
  }

  content_matchers {
    content = "Healthy"
    matcher = "CONTAINS_STRING"
  }

  depends_on = [
    google_project_service.required["monitoring.googleapis.com"],
  ]
}


resource "google_monitoring_alert_policy" "production_availability" {
  display_name = "Production application unavailable"
  combiner     = "OR"

  conditions {
    display_name = "Production health check failed"

    condition_threshold {
      filter = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.production_health.uptime_check_id}\""

      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_NEXT_OLDER"
      }

      trigger {
        percent = 0.5
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  depends_on = [
    google_project_service.required["monitoring.googleapis.com"],
  ]
}
