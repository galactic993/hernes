# uptime.tf
# 外形監視（uptime check）+ 失敗アラート。既定 OFF（var.uptime_targets が空）。
#
# Cloud Run の *.run.app URL は revision ごとに安定しないため、**安定したカスタム
# ドメイン**がある場合のみ host を渡す。HTTPS / GET / /healthz を既定にする。

resource "google_monitoring_uptime_check_config" "http" {
  for_each = var.uptime_targets

  project      = var.project_id
  display_name = "hernes ${var.env} uptime: ${each.key}"
  timeout      = "10s"
  period       = var.uptime_period

  http_check {
    path           = each.value.path
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value.host
    }
  }
}

# uptime 失敗アラート（check_passed=false が続いたら発報）。
resource "google_monitoring_alert_policy" "uptime" {
  for_each = var.uptime_targets

  project      = var.project_id
  display_name = "Uptime failing — ${each.key} (hernes ${var.env})"
  combiner     = "OR"
  severity     = "CRITICAL"
  enabled      = var.alert_enabled

  conditions {
    display_name = "uptime check_passed is false"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\" metric.label.\"check_id\"=\"${google_monitoring_uptime_check_config.http[each.key].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.\"host\""]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = local.notification_channel_ids

  alert_strategy {
    auto_close = var.auto_close_duration
  }

  user_labels = local.monitoring_user_labels
}
