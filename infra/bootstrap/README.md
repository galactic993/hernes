# infra/bootstrap — Terraform state バケットの初期化

`infra/terraform` 本体が使う **Terraform state 用 GCS バケット** を作るだけの最小構成。

## なぜ別にあるか（chicken-and-egg）

本体 `infra/terraform` は state を **GCS backend** に保存する。
しかし、その state を入れるバケット自体を、GCS backend を使う構成では作れない
（init 時点でバケットが存在しないと失敗するため）。

そこで bootstrap は **local backend**（state はローカルの `terraform.tfstate`）で動き、
state バケットだけを先に作る。これで本体が GCS backend で `init` できるようになる。
この鶏と卵を切るのが bootstrap の唯一の役目。

## 何を作るか

- GCS バケット 1 個:
  - versioning 有効
  - uniform bucket-level access
  - public access prevention = enforced
  - `force_destroy = false`（誤削除防止）

## 使い方

```bash
cd infra/bootstrap

terraform init   # local backend なのでバケット不要で init できる

terraform apply \
  -var="project_id=hernes-dev-123456" \
  -var="state_bucket_name=hernes-tfstate-hernes-dev-123456"
```

apply 後、出力された `state_bucket_name` を本体の init に渡す:

```bash
cd ../terraform
terraform init \
  -backend-config="bucket=hernes-tfstate-hernes-dev-123456" \
  -backend-config="prefix=terraform/state/staging"
```

## bootstrap 自身の state について

この構成の `terraform.tfstate` は **ローカルに残る**。普段は再 apply 不要なので
そのままで問題ないが、チームで共有したい場合は apply 後に作成したバケットへ
手動アップロードする（例: 作成バケット内の `bootstrap/` prefix へ）。

一度作ったら基本的に触らない。state バケットの破棄は中身（全環境の state）を
失うため、`force_destroy = false` で保護している。
