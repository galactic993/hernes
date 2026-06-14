# backend.tf
# Terraform state を GCS backend に置く。
#
# bucket は環境/プロジェクトごとに異なるため partial config で渡す（ここにはハードコードしない）。
# bucket は infra/bootstrap で先に作成しておくこと（chicken-and-egg 回避）。
#
# prefix は env 別に分けて state を分離する。例:
#   - staging:    terraform/state/staging
#   - production: terraform/state/production
#
# 初期化例（staging を単一 project で運用する場合）:
#   terraform init \
#     -backend-config="bucket=hernes-tfstate-<PROJECT_ID>" \
#     -backend-config="prefix=terraform/state/staging"
#
# あるいは -backend-config=backend-staging.hcl のように hcl ファイルを使ってもよい。

terraform {
  backend "gcs" {
    # bucket = "hernes-tfstate-<PROJECT_ID>"   # partial config: -backend-config で渡す
    # prefix = "terraform/state/<env>"         # partial config: -backend-config で渡す
  }
}
