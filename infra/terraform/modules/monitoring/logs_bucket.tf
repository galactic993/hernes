# logs_bucket.tf
# _Default ログバケットの保持期間管理（既定 OFF / 取り扱い注意）。
#
# 注意:
#   - これは既存の _Default バケットを Terraform 管理下に "adopt" する。
#     destroy しても _Default バケット自体は削除されない（GCP 管理のため）。
#   - locked=true は **不可逆**。保持期間の短縮もバケット削除も二度とできなくなる。
resource "google_logging_project_bucket_config" "default" {
  count = var.manage_default_log_bucket ? 1 : 0

  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = var.default_log_bucket_retention_days
  locked         = var.lock_default_log_bucket

  depends_on = [google_project_service.required]
}
