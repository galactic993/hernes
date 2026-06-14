# outputs.tf
# 監視リソースの ID 群。ルートからの集約出力・運用参照に使う。

output "notification_channel_ids" {
  description = "全通知チャンネル ID（メール + 任意の Pub/Sub）。"
  value       = local.notification_channel_ids
}

output "email_channel_ids" {
  description = "メールアドレス => 通知チャンネル ID。"
  value       = { for email, c in google_monitoring_notification_channel.email : email => c.id }
}

output "pubsub_channel_id" {
  description = "Pub/Sub 通知チャンネル ID（未設定なら null）。"
  value       = one(google_monitoring_notification_channel.pubsub[*].id)
}

output "error_log_metric_name" {
  description = "ERROR ログベースメトリクス名（無効なら null）。"
  value       = var.enable_error_log_metric ? var.error_metric_name : null
}

output "http_5xx_log_metric_name" {
  description = "HTTP 5xx ログベースメトリクス名（無効なら null）。"
  value       = var.enable_http_5xx_log_metric ? var.http_5xx_metric_name : null
}

output "log_export_dataset_id" {
  description = "BigQuery ログエクスポート先データセット ID（無効なら null）。"
  value       = one(google_bigquery_dataset.log_export[*].dataset_id)
}

output "log_export_sink_name" {
  description = "ログルーターシンク名（無効なら null）。"
  value       = one(google_logging_project_sink.bigquery[*].name)
}

output "log_export_sink_writer_identity" {
  description = "シンクの writer identity（BigQuery 権限付与先。無効なら null）。"
  value       = one(google_logging_project_sink.bigquery[*].writer_identity)
}

output "monitoring_service_ids" {
  description = "SLO 用 monitoring service の service_id 群。"
  value       = { for k, s in google_monitoring_service.slo_target : k => s.service_id }
}

output "availability_slo_names" {
  description = "可用性 SLO のフルネーム群。"
  value       = { for k, s in google_monitoring_slo.availability : k => s.name }
}

output "latency_slo_names" {
  description = "レイテンシ SLO のフルネーム群。"
  value       = { for k, s in google_monitoring_slo.latency : k => s.name }
}

output "http_5xx_ratio_policy_ids" {
  description = "5xx 比率アラートポリシー ID 群。"
  value       = { for k, p in google_monitoring_alert_policy.http_5xx_ratio : k => p.id }
}

output "error_log_rate_policy_id" {
  description = "ERROR ログレートアラートポリシー ID（無効なら null）。"
  value       = one(google_monitoring_alert_policy.error_log_rate[*].id)
}

output "container_startup_crash_policy_id" {
  description = "起動失敗アラートポリシー ID（無効なら null）。"
  value       = one(google_monitoring_alert_policy.container_startup_crash[*].id)
}

output "dashboard_id" {
  description = "概要ダッシュボード ID（無効なら null）。"
  value       = one(google_monitoring_dashboard.overview[*].id)
}

output "uptime_check_ids" {
  description = "uptime チェック ID 群。"
  value       = { for k, u in google_monitoring_uptime_check_config.http : k => u.uptime_check_id }
}

output "budget_id" {
  description = "Billing budget リソース ID（無効なら null）。"
  value       = one(google_billing_budget.this[*].id)
}

output "enabled_api_ids" {
  description = "有効化した API のリソース ID 群（enable_apis=false なら空）。"
  value       = { for k, a in google_project_service.required : k => a.id }
}
