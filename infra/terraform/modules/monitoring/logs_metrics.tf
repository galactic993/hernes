# logs_metrics.tf
# ログベースメトリクス（ログ）。
#   - app_errors : severity>=ERROR のカウンタ。ERROR ログレートアラートが参照する。
#   - http_5xx   : Cloud Run リクエストログ（httpRequest.status>=500）のカウンタ。
#
# どちらも DELTA / INT64 カウンタ。service_name ラベルを抽出して内訳を見られるようにする。
#
# 注意: backend は現状 textPayload（素の console.log）なので ERROR severity は疎。
#       構造化ログ導入までは var.error_log_filter で textPayload マッチに上書きしてよい。

resource "google_logging_metric" "app_errors" {
  count = var.enable_error_log_metric ? 1 : 0

  project = var.project_id
  name    = var.error_metric_name
  filter  = coalesce(var.error_log_filter, "${local.service_log_filter} AND severity>=ERROR")

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "service_name"
      value_type  = "STRING"
      description = "Cloud Run service name"
    }
  }

  label_extractors = {
    service_name = "EXTRACT(resource.labels.service_name)"
  }

  depends_on = [google_project_service.required]
}

resource "google_logging_metric" "http_5xx" {
  count = var.enable_http_5xx_log_metric ? 1 : 0

  project = var.project_id
  name    = var.http_5xx_metric_name
  filter  = coalesce(var.http_5xx_log_filter, "${local.service_log_filter} AND httpRequest.status>=500")

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "service_name"
      value_type  = "STRING"
      description = "Cloud Run service name"
    }
  }

  label_extractors = {
    service_name = "EXTRACT(resource.labels.service_name)"
  }

  depends_on = [google_project_service.required]
}
