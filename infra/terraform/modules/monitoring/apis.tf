# apis.tf
# 監視に必要な API をまとめて有効化する（var.enable_apis のときのみ）。
#
# 既存リポジトリでは API を Terraform 管理していない（google_project_service 不在）。
# そのため既定は OFF。enable_apis=true にしたときだけこのモジュールが面倒を見る。
#
# disable_on_destroy=false: destroy 時に API を無効化して他リソースを巻き込まない。
# disable_dependent_services=false: 依存 API を勝手に無効化しない。
resource "google_project_service" "required" {
  for_each = local.required_apis

  project = var.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}
