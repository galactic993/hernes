# bootstrap/main.tf
# Terraform state を置く GCS バケットを作るための「最小・使い捨て」構成。
#
# なぜ別構成か（chicken-and-egg 回避）:
#   infra/terraform は state を GCS backend に保存する。しかしその state 用バケット自体を
#   GCS backend を使う構成では作れない（バケットが無いと init できない）。
#   そこで bootstrap は **local backend**（state をローカル or 手動 GCS 退避）で
#   state バケットだけを先に作る。これにより本体 (infra/terraform) が
#   GCS backend で init できるようになる。
#
# 注意: この構成の state（terraform.tfstate）はローカルに残る。チームで使うなら
#   apply 後にこの state を作成したバケットへ手動アップロードして共有する（README 参照）。

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0, < 7.0.0"
    }
  }

  # local backend（デフォルト）。state バケットがまだ無いので GCS backend は使えない。
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Terraform state 用バケット。
# - versioning 有効（state の世代管理 / 復旧）
# - uniform bucket-level access（ACL を使わない）
# - public access prevention enforced
# - force_destroy = false（state バケットを誤って中身ごと消さない）
resource "google_storage_bucket" "tfstate" {
  name     = var.state_bucket_name
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  # 古い state 世代を一定数で整理（任意。state バケットなので保守的に保持）。
  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    app        = var.app_name
    purpose    = "terraform-state"
    managed-by = "terraform-bootstrap"
  }
}
