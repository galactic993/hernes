# alerts_errors.tf
# バグ・不具合（エラー）系アラート。すべて enable_alerts でゲート。
#   1. http_5xx_ratio          : 5xx / total 比が一定を超えたら（壊れたデプロイ検知）
#   2. error_log_rate          : ERROR ログレートが一定を超えたら（要 ERROR メトリクス）
#   3. container_startup_crash : 起動失敗（要 専用ログメトリクス・既定 OFF）
#
# 共通:
#   - notification_channels は local.notification_channel_ids（notifications.tf 由来）。
#   - evaluation_missing_data=INACTIVE: 無トラフィック/データ無しで誤発報しない。
#   - Error Reporting は ERROR severity ログ・スタックトレースから自動集約される
#     （専用 TF リソースは無い）。ここではログメトリクス経由でアラート化する。

# --- 1) HTTP 5xx 比率（サービスごと） ---------------------------------------
resource "google_monitoring_alert_policy" "http_5xx_ratio" {
  for_each = var.enable_alerts ? var.services : {}

  project      = var.project_id
  display_name = "HTTP 5xx ratio — ${each.value.service_name}"
  combiner     = "OR"
  severity     = "ERROR"
  enabled      = var.alert_enabled

  conditions {
    display_name = "5xx / total > ${var.error_ratio_threshold}"
    condition_threshold {
      # 分子: 5xx のみ
      filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${each.value.service_name}\" metric.label.\"response_code_class\"=\"5xx\""
      # 分母: 全リクエスト
      denominator_filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${each.value.service_name}\""

      comparison      = "COMPARISON_GT"
      threshold_value = var.error_ratio_threshold
      duration        = var.error_ratio_duration

      aggregations {
        alignment_period     = var.alignment_period
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.\"service_name\""]
      }
      denominator_aggregations {
        alignment_period     = var.alignment_period
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.\"service_name\""]
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
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

# --- 2) ERROR ログレート ----------------------------------------------------
# ERROR ログメトリクス（logs_metrics.tf）が有効なときだけ作る（参照先がないと無意味）。
resource "google_monitoring_alert_policy" "error_log_rate" {
  count = var.enable_alerts && var.enable_error_log_alert && var.enable_error_log_metric ? 1 : 0

  project      = var.project_id
  display_name = "ERROR log rate — hernes ${var.env}"
  combiner     = "OR"
  severity     = "WARNING"
  enabled      = var.alert_enabled

  conditions {
    display_name = "ERROR logs > ${var.error_log_threshold}/s"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${local.error_log_metric_name}\" resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_log_threshold
      duration        = var.error_log_duration

      aggregations {
        alignment_period     = var.alignment_period
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
      trigger {
        count = 1
      }
    }
  }

  notification_channels = local.notification_channel_ids

  alert_strategy {
    auto_close = var.auto_close_duration
    notification_rate_limit {
      period = var.notification_rate_limit_period
    }
  }

  user_labels = local.monitoring_user_labels

  # ERROR ログメトリクスが先に存在すること。
  depends_on = [google_logging_metric.app_errors]
}

# --- 3) コンテナ起動失敗 / クラッシュ（既定 OFF） --------------------------
# 専用のログメトリクス（var.startup_crash_metric_name）が別途必要。
resource "google_monitoring_alert_policy" "container_startup_crash" {
  count = var.enable_alerts && var.enable_startup_crash_alert ? 1 : 0

  project      = var.project_id
  display_name = "Container startup/crash — hernes ${var.env}"
  combiner     = "OR"
  severity     = "CRITICAL"
  enabled      = var.alert_enabled

  conditions {
    display_name = "Startup failures > ${var.startup_crash_threshold}"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${var.startup_crash_metric_name}\" resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.startup_crash_threshold
      duration        = var.startup_crash_duration

      aggregations {
        alignment_period     = var.alignment_period
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }

      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
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
