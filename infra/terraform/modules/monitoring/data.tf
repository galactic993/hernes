# data.tf
# Billing budget の budget_filter.projects は **project NUMBER** を要求するため、
# project_id から number を引く。番号はここで 1 度だけ解決する。
data "google_project" "this" {
  project_id = var.project_id
}
