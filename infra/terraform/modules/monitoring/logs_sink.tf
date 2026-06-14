# logs_sink.tf
# ログを BigQuery へルーティングして長期保存・SQL 分析する（既定 OFF）。
#   dataset → sink（writer identity 生成）→ dataset への dataEditor 付与
# の順で参照チェーンする。
#
# 注意: dataset_id はアンダースコアのみ。location 未指定だと US になるので必ず指定。
#       delete_contents_on_destroy=false のときは中身があると destroy が失敗する。

resource "google_bigquery_dataset" "log_export" {
  count = var.enable_bigquery_log_export ? 1 : 0

  project    = var.project_id
  dataset_id = var.log_export_dataset_id
  location   = coalesce(var.bigquery_location, var.region)

  # 日次パーティションの自動失効（保持期間）。
  default_partition_expiration_ms = var.log_export_partition_expiration_ms
  delete_contents_on_destroy      = var.log_export_delete_contents_on_destroy

  labels = local.monitoring_user_labels

  depends_on = [google_project_service.required]
}

resource "google_logging_project_sink" "bigquery" {
  count = var.enable_bigquery_log_export ? 1 : 0

  project     = var.project_id
  name        = var.log_sink_name
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.log_export[0].dataset_id}"
  filter      = coalesce(var.sink_filter, local.service_log_filter)

  # パーティション分割テーブルで書き込む（クエリ効率・保持管理のため）。
  bigquery_options {
    use_partitioned_tables = true
  }

  # 専用 writer identity を発行（共有 SA を使わない）。
  unique_writer_identity = true
}

# シンクの writer identity にデータセットへの書き込み権限を付与（additive）。
resource "google_bigquery_dataset_iam_member" "sink_writer" {
  count = var.enable_bigquery_log_export ? 1 : 0

  project    = var.project_id
  dataset_id = google_bigquery_dataset.log_export[0].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.bigquery[0].writer_identity
}
