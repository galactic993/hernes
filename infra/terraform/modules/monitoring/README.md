# modules/monitoring

hernes プラットフォームの GCP 監視一式を作る Terraform モジュール。
**ログ / バグ・不具合 / SLA・SLO / 料金** を 1 モジュールでカバーする。

> GCP observability for hernes: logs, error/defect alerts, SLA/SLO, and a cost
> budget — in one module.

## 何を作るか / What it provisions

| 領域 | リソース | 既定 |
| --- | --- | --- |
| **ログ** | ログベースメトリクス（`severity>=ERROR` カウンタ / HTTP 5xx カウンタ） | ON |
| ログ（保存） | BigQuery へのログルーター（dataset + sink + writer IAM） | OFF |
| ログ（保持） | `_Default` ログバケットの保持期間管理 | OFF |
| **バグ・不具合** | 5xx 比率アラート（サービス別） / ERROR ログレートアラート | ON |
| バグ・不具合 | コンテナ起動失敗アラート（要 専用メトリクス） | OFF |
| **SLA・SLO** | 可用性 SLO + レイテンシ SLO + バーンレートアラート | ON※ |
| **料金** | Billing budget（閾値通知。**支出は止めない**） | OFF |
| 横断 | 通知チャンネル（メール / Pub/Sub） | — |
| 横断 | 概要ダッシュボード（6 タイル） | ON |
| 横断 | 外形監視（uptime）+ 失敗アラート | OFF |
| 横断 | 必要 API の有効化（`google_project_service`） | OFF |

※ SLO は `var.services` が空、または `enable_slo=false` なら何も作られない。

## 設計の要点 / Key decisions

- **provider は `google` のみ**（google-beta は使わない）。全リソースで
  `project = var.project_id` を明示。
- **`var.services` が単一ドライバ**。SLO・5xx アラート・ダッシュボード・ログ
  フィルタはすべてこの map から導出する。**preview の `*-pr-<N>` は渡さない**
  （scale-to-zero で寿命が短く、SLO/uptime のノイズ源になるため）。
- 危険・高コストになりうるものはすべて **既定 OFF**（BigQuery export /
  `_Default` バケット / uptime / budget / slow-burn / startup-crash）。
- **予算は通知のみ**。GCP の Billing budget は閾値超過で通知するだけで、支出の
  上限強制やリソース停止は行わない。

## アプリログの現実 / Logging reality

backend は現状 **素の `console.log`（textPayload）** で出力しており、
`severity>=ERROR` のシグナルは疎。そのため:

- ERROR 系アラートの既定しきい値は保守的、かつ
  `evaluation_missing_data = EVALUATION_MISSING_DATA_INACTIVE`（データ無しで誤発報
  しない）にしてある。
- 一方 **5xx シグナル（Cloud Run リクエストログ/メトリクス）は今日から信頼できる**。
- 構造化 JSON ログ（`severity` を出す）を導入したら、`error_log_threshold` を
  締める。構造化前は `error_log_filter` を textPayload マッチに上書きしてもよい。

## 前提 / Prerequisites

- 必要 API（`enable_apis=true` で自動有効化。手動なら以下を先に有効化）:
  `monitoring.googleapis.com`, `logging.googleapis.com`,
  （BigQuery export 時）`bigquery.googleapis.com`,
  （予算時）`billingbudgets.googleapis.com`, `cloudbilling.googleapis.com`。
- **予算を使う場合**、apply する主体に請求アカウント側の権限が必要:
  `roles/billing.costManager` もしくは `billing.budgets.*`（請求アカウントに対して）。
  `billing_account` は**請求アカウント ID**（`XXXXXX-XXXXXX-XXXXXX`）であり
  project_id ではない。
- **Pub/Sub 通知**を使う場合、監視通知用 SA に対象トピックへの
  `roles/pubsub.publisher` を別途付与する
  （`service-<project_number>@gcp-sa-monitoring-notification.iam.gserviceaccount.com`）。

## 使い方 / Usage（ルートからの配線例）

ルート `infra/terraform/main.tf` は **distinct な project_id ごとに 1 インスタンス**
を `for_each` で作る（単一 project 運用で重複させない）。最小例:

```hcl
module "monitoring" {
  source     = "./modules/monitoring"
  project_id = "hernes-dev-123456"
  env        = "staging"
  region     = "asia-northeast1"
  labels     = { app = "hernes", managed-by = "terraform" }

  notification_emails = ["oncall@example.com"]

  # 監視対象は長寿命サービスのみ（preview は入れない）。
  services = {
    backend-staging  = { service_name = "backend-staging" }
    frontend-staging = { service_name = "frontend-staging" }
  }
}
```

予算を有効化する例（production）:

```hcl
  budget_enable        = true
  billing_account      = "XXXXXX-XXXXXX-XXXXXX"
  budget_amount_units  = 50000
  budget_currency_code = "JPY"
```

## 主な変数 / Key variables

`variables.tf` を参照。よく触るもの:

- `services` — 監視対象サービス（SLO の `availability_goal` / `latency_threshold_ms`
  / `latency_goal` をサービス単位で上書き可）。
- `notification_emails`, `pubsub_notification_topic` — 通知先。
- `error_ratio_threshold`(0.05), `error_log_threshold`(0.5) — アラートしきい値。
- `enable_slo`, `rolling_period_days`(28), `fast_burn_threshold`(10) — SLO。
- `budget_enable`, `billing_account`, `budget_amount_units`(50000) — 料金。
- `enable_bigquery_log_export`, `manage_default_log_bucket` — ログ保存/保持。
- `uptime_targets`, `enable_apis`, `alert_enabled`(段階導入用) — 横断。

出力は `outputs.tf` を参照（通知チャンネル ID / SLO 名 / ダッシュボード ID /
予算 ID / 有効化 API など）。
