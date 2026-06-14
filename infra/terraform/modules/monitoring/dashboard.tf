# dashboard.tf
# 概要ダッシュボード（6 タイル）。dashboard_json は jsonencode で組み立てる。
#   1) リクエストレート  2) 5xx 比率  3) レイテンシ p95  4) p99
#   5) インスタンス数    6) ERROR ログ件数
#
# 監視対象は var.services のサービス名に絞る（services が空なら project 全体の
# cloud_run_revision を表示）。

locals {
  _dash_svc_clause = local.service_name_metric_clause != "" ? " AND ${local.service_name_metric_clause}" : ""

  dash_req_filter       = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\"${local._dash_svc_clause}"
  dash_5xx_filter       = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND metric.label.\"response_code_class\"=\"5xx\"${local._dash_svc_clause}"
  dash_latency_filter   = "metric.type=\"run.googleapis.com/request_latencies\" AND resource.type=\"cloud_run_revision\"${local._dash_svc_clause}"
  dash_instances_filter = "metric.type=\"run.googleapis.com/container/instance_count\" AND resource.type=\"cloud_run_revision\"${local._dash_svc_clause}"
  dash_error_log_filter = "metric.type=\"logging.googleapis.com/log_entry_count\" AND resource.type=\"cloud_run_revision\" AND metric.label.\"severity\"=\"ERROR\"${local._dash_svc_clause}"
}

resource "google_monitoring_dashboard" "overview" {
  count = var.enable_dashboard ? 1 : 0

  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "hernes ${var.env} — overview"
    labels      = local.monitoring_user_labels
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos = 0, yPos = 0, width = 6, height = 4
          widget = {
            title = "Request rate (req/s)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.dash_req_filter
                    aggregation = {
                      alignmentPeriod    = var.alignment_period
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.\"service_name\""]
                    }
                  }
                }
              }]
              yAxis = { label = "req/s", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 6, yPos = 0, width = 6, height = 4
          widget = {
            title = "HTTP 5xx ratio"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilterRatio = {
                    numerator = {
                      filter = local.dash_5xx_filter
                      aggregation = {
                        alignmentPeriod    = var.alignment_period
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                    denominator = {
                      filter = local.dash_req_filter
                      aggregation = {
                        alignmentPeriod    = var.alignment_period
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                      }
                    }
                  }
                }
              }]
              yAxis = { label = "ratio", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 0, yPos = 4, width = 6, height = 4
          widget = {
            title = "Latency p95 (ms)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.dash_latency_filter
                    aggregation = {
                      alignmentPeriod    = var.alignment_period
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.\"service_name\""]
                    }
                  }
                }
              }]
              yAxis = { label = "ms", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 6, yPos = 4, width = 6, height = 4
          widget = {
            title = "Latency p99 (ms)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.dash_latency_filter
                    aggregation = {
                      alignmentPeriod    = var.alignment_period
                      perSeriesAligner   = "ALIGN_PERCENTILE_99"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.\"service_name\""]
                    }
                  }
                }
              }]
              yAxis = { label = "ms", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 0, yPos = 8, width = 6, height = 4
          widget = {
            title = "Container instances"
            xyChart = {
              dataSets = [{
                plotType = "STACKED_AREA"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.dash_instances_filter
                    aggregation = {
                      alignmentPeriod    = var.alignment_period
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.\"service_name\""]
                    }
                  }
                }
              }]
              yAxis = { label = "instances", scale = "LINEAR" }
            }
          }
        },
        {
          xPos = 6, yPos = 8, width = 6, height = 4
          widget = {
            title = "ERROR logs (entries/s)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.dash_error_log_filter
                    aggregation = {
                      alignmentPeriod    = var.alignment_period
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["resource.label.\"service_name\""]
                    }
                  }
                }
              }]
              yAxis = { label = "entries/s", scale = "LINEAR" }
            }
          }
        },
      ]
    }
  })

  depends_on = [google_project_service.required]
}
