# slo.tf
# SLA / SLO（長寿命サービスのみ。preview は対象外）。
#
# 方針: Cloud Run の basic_service は組み合わせが不安定なので **カスタム
# monitoring service + request-based SLI** を使う（最も移植性が高い）。
#   - 可用性 SLO : good_total_ratio（good = 非 5xx リクエスト / total = 全リクエスト）
#   - レイテンシ SLO : distribution_cut（request_latencies が範囲 [0, max] に入る割合）
# さらに各 SLO にバーンレートアラート（高速 = CRITICAL。低速 = 任意/WARNING）。
#
# var.services が空、または enable_slo=false なら何も作られない。

locals {
  slo_services = var.enable_slo ? var.services : {}
}

# 監視サービス（SLO のコンテナ）。
resource "google_monitoring_service" "slo_target" {
  for_each = local.slo_services

  project      = var.project_id
  service_id   = "slo-${each.value.service_name}"
  display_name = "hernes ${each.value.service_name} (SLO)"
  user_labels  = local.monitoring_user_labels

  depends_on = [google_project_service.required]
}

# 可用性 SLO: 非 5xx の比率。
resource "google_monitoring_slo" "availability" {
  for_each = local.slo_services

  project             = var.project_id
  service             = google_monitoring_service.slo_target[each.key].service_id
  slo_id              = "availability"
  display_name        = "Availability — ${each.value.service_name}"
  goal                = each.value.availability_goal
  rolling_period_days = var.rolling_period_days

  request_based_sli {
    good_total_ratio {
      good_service_filter  = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${each.value.service_name}\" metric.label.\"response_code_class\"!=\"5xx\""
      total_service_filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${each.value.service_name}\""
    }
  }
}

# レイテンシ SLO: request_latencies(ms) が [0, threshold] に入る割合。
resource "google_monitoring_slo" "latency" {
  for_each = local.slo_services

  project             = var.project_id
  service             = google_monitoring_service.slo_target[each.key].service_id
  slo_id              = "latency"
  display_name        = "Latency < ${each.value.latency_threshold_ms}ms — ${each.value.service_name}"
  goal                = each.value.latency_goal
  rolling_period_days = var.rolling_period_days

  request_based_sli {
    distribution_cut {
      distribution_filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${each.value.service_name}\""
      range {
        # request_latencies は ms。max のみ指定（min は既定 0）。
        max = each.value.latency_threshold_ms
      }
    }
  }
}

# 高速バーンアラート（可用性）: エラーバジェットを急速に消費したら CRITICAL。
resource "google_monitoring_alert_policy" "availability_burn" {
  for_each = local.slo_services

  project      = var.project_id
  display_name = "Fast burn — availability — ${each.value.service_name}"
  combiner     = "OR"
  severity     = "CRITICAL"
  enabled      = var.alert_enabled

  conditions {
    display_name = "Availability error budget fast burn"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability[each.key].name}\", \"${var.fast_burn_lookback}\")"
      comparison      = "COMPARISON_GT"
      threshold_value = var.fast_burn_threshold
      duration        = "0s"
      aggregations {
        alignment_period   = var.burn_alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channel_ids

  alert_strategy {
    auto_close = var.auto_close_duration
  }

  user_labels = local.monitoring_user_labels
}

# 低速バーンアラート（レイテンシ）: 任意。長ウィンドウで緩やかな劣化を WARNING。
resource "google_monitoring_alert_policy" "latency_burn" {
  for_each = var.enable_slo && var.enable_slow_burn ? var.services : {}

  project      = var.project_id
  display_name = "Slow burn — latency — ${each.value.service_name}"
  combiner     = "OR"
  severity     = "WARNING"
  enabled      = var.alert_enabled

  conditions {
    display_name = "Latency error budget slow burn"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency[each.key].name}\", \"${var.slow_burn_lookback}\")"
      comparison      = "COMPARISON_GT"
      threshold_value = var.slow_burn_threshold
      duration        = "0s"
      aggregations {
        alignment_period   = var.burn_alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channel_ids

  alert_strategy {
    auto_close = var.auto_close_duration
  }

  user_labels = local.monitoring_user_labels
}
