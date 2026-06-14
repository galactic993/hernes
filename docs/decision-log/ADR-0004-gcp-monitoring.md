# ADR-0004: GCP 監視は Terraform module（ログ/不具合/SLA/料金）

- Status: Accepted
- Date: 2026-06-14
- Deciders: 開発責任者

## Context

GCP 上の preview/staging/production プラットフォーム（Cloud Run + Cloud SQL +
Memorystore + GCS）に対し、運用に必要な監視が未整備だった。求める範囲は
**ログ・バグ/不具合・SLA・料金**。Cloud Run サービスは GitHub Actions が固定名
（`backend-staging` / `frontend-staging` / `backend-prod` / `frontend-prod`、
preview は `*-pr-<N>`）でデプロイし、Terraform 管理外。

## Decision

`infra/terraform/modules/monitoring` を新設し、ルートから `for_each`（distinct な
project_id ごと）で 1 インスタンスずつ作る。provider は `google` のみ。

- **ログ**: ログベースメトリクス（`severity>=ERROR` / HTTP 5xx カウンタ）。任意で
  BigQuery へのログルーター（長期保存・SQL 分析）と `_Default` バケット保持期間管理。
- **バグ/不具合**: 5xx 比率アラート（サービス別）、ERROR ログレートアラート、
  起動失敗アラート（任意）。Error Reporting は ERROR ログから自動集約されるため
  専用リソースは持たず、ログメトリクス経由でアラート化する。
- **SLA/SLO**: カスタム monitoring service + request-based SLI で可用性（非 5xx 比）と
  レイテンシ（`request_latencies` の分位）SLO を作り、バーンレートアラートを張る。
  対象は長寿命サービスのみ（preview は除外）。
- **料金**: Billing budget（CURRENT/FORECASTED 閾値通知）。production を含む
  インスタンスのみ。**通知のみで支出は止めない**。
- **横断**: 通知チャンネル（メール/Pub/Sub）、概要ダッシュボード、必要 API 有効化、
  外形監視（uptime）。

### 重要な方針

- **`var.services` を単一ドライバ**にし、SLO/アラート/ダッシュボード/ログフィルタを
  すべてここから導出。preview の `*-pr-<N>` は呼び出し側で渡さない（scale-to-zero の
  ノイズ・誤発報を構造的に排除）。
- 危険・高コストになりうるもの（BigQuery export / `_Default` バケット / uptime /
  budget / slow-burn / startup-crash）は**すべて既定 OFF（opt-in）**。
- API 有効化は既存慣習（API は TF 管理外）を尊重し既定 OFF（`enable_monitoring_apis`）。
- ERROR severity は素の `console.log` では疎なため、ERROR 系アラートは保守的な既定 +
  `EVALUATION_MISSING_DATA_INACTIVE`（無データで誤発報しない）。一方 5xx シグナルは
  今日から信頼できる。

## Consequences

- 監視対象は staging/production の固定サービス。単一 project でも複数 project でも、
  distinct project_id ごとに重複なく構成される。
- 予算は安全側（通知のみ）。請求アカウント権限が apply 主体に必要。
- 構造化 JSON ログ導入後に ERROR 系しきい値を締める前提（README に明記）。
- `terraform validate` 済み。ルート配線（インスタンス導出・uptime マージ）は単一/
  複数 project・複合 env の各モードで評価確認済み。
