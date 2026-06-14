# notifications.tf
# 通知チャンネルの唯一の所有者。SLO/予算/アラートは local.notification_channel_ids
# 経由でここのチャンネルを参照する（同一アドレスの重複チャンネルを避けるため）。

# メール: アドレス 1 件につき 1 チャンネル。
resource "google_monitoring_notification_channel" "email" {
  for_each = toset(var.notification_emails)

  project      = var.project_id
  display_name = "hernes ${var.env} email: ${each.value}"
  type         = "email"
  labels = {
    email_address = each.value
  }
  user_labels  = local.monitoring_user_labels
  force_delete = var.notification_channel_force_delete

  # API 有効化を待ってから作る（enable_apis=true のとき）。
  depends_on = [google_project_service.required]
}

# 任意: Pub/Sub への fan-out チャンネル。
# 注意: 監視 SA に対象トピックへの roles/pubsub.publisher 付与が別途必要
#       （projects/<p>/serviceAccounts/service-<num>@gcp-sa-monitoring-notification.iam.gserviceaccount.com）。
resource "google_monitoring_notification_channel" "pubsub" {
  count = var.pubsub_notification_topic == "" ? 0 : 1

  project      = var.project_id
  display_name = "hernes ${var.env} pubsub"
  type         = "pubsub"
  labels = {
    topic = var.pubsub_notification_topic
  }
  user_labels  = local.monitoring_user_labels
  force_delete = var.notification_channel_force_delete

  depends_on = [google_project_service.required]
}
