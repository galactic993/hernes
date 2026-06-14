# providers.tf
# google / google-beta プロバイダ定義。
# project / region は変数で受け取る（単一 project でも複数 project でも動く）。
# google-beta は Cloud Run / Memorystore / WIF の一部 beta フィールドを使う場合に備えて定義しておく。

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0, < 7.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0, < 7.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
