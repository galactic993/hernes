# =============================================================================
# modules/monitoring — variables
# -----------------------------------------------------------------------------
# Cloud Monitoring / Logging / Billing budget をまとめて作る監視モジュールの入力。
# Inputs for the observability module (logs / error & defect alerts / SLA-SLO /
# cost budget / notifications / dashboard).
#
# 設計の要:
#   - var.services が SLO / アラート / ダッシュボード / ログフィルタの単一ドライバ。
#     preview の "*-pr-<N>" は寿命が短く scale-to-zero なので **絶対に渡さない**。
#   - 危険なもの（BigQuery エクスポート / _Default バケット管理 / uptime / budget）は
#     すべて既定 OFF（opt-in）。
#   - budget は「通知のみ」。支出を止めたり上限を強制したりはしない。
# =============================================================================

variable "project_id" {
  description = "監視リソースを作る GCP project ID（1 インスタンス = 1 project）。GCP project owning all monitoring resources."
  type        = string
}

variable "env" {
  description = "環境ラベル（staging / production / staging-production など）。リソース名と user_label に使う。label 値として安全な文字のみ（a-z0-9_-）。"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]*$", var.env))
    error_message = "env は小文字英字で始まり [a-z0-9_-] のみで構成すること（label 値制約）。"
  }
}

variable "region" {
  description = "既定リージョン（BigQuery エクスポート用データセットのロケーション既定値）。"
  type        = string
  default     = "asia-northeast1"
}

variable "labels" {
  description = "共通ラベル（app/env/managed-by 等）。user_labels には commit-sha 等の動的値・ドット付きキーは入れない（モジュール側で除去し env を強制）。"
  type        = map(string)
  default     = {}
}

variable "services" {
  description = <<-EOT
    監視対象の長寿命 Cloud Run サービス。SLO / 5xx アラート / ダッシュボード / ログフィルタの
    単一ドライバ。キーは安定 ID（例 "backend-staging"）。

    preview の "backend-pr-<N>" / "frontend-pr-<N>" は **渡さないこと**（ノイズ・スケールゼロのため）。

    例:
      services = {
        backend-staging  = { service_name = "backend-staging",  availability_goal = 0.99, latency_threshold_ms = 800, latency_goal = 0.95 }
        frontend-staging = { service_name = "frontend-staging" }
      }
  EOT
  type = map(object({
    service_name         = string
    availability_goal    = optional(number, 0.99)
    latency_threshold_ms = optional(number, 800)
    latency_goal         = optional(number, 0.95)
  }))
  default = {}
}

variable "log_filter_override" {
  description = "共通ログフィルタ（local.service_log_filter）を完全置換したい場合に指定。null なら services から自動生成。"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# API 有効化（リポジトリ慣習: API は通常 TF 管理外。既定 OFF）。
# ---------------------------------------------------------------------------

variable "enable_apis" {
  description = "必要な API（monitoring/logging/bigquery/billingbudgets/cloudbilling）を google_project_service で管理するか。disable_on_destroy=false。既定 false（API は別管理という既存慣習を尊重）。"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# 通知チャンネル
# ---------------------------------------------------------------------------

variable "notification_emails" {
  description = "アラート通知先メールアドレス（1 件につき email チャンネルを 1 つ作る）。budget には先頭から最大 5 件が渡る。"
  type        = list(string)
  default     = []
}

variable "pubsub_notification_topic" {
  description = "アラート fan-out 用 Pub/Sub トピックのフルパス（projects/<p>/topics/<t>）。\"\" で無効。トピック自体はこのモジュールでは作らない（参照のみ）。"
  type        = string
  default     = ""
}

variable "notification_channel_force_delete" {
  description = "ポリシーから参照中でも通知チャンネルの削除を許可するか（force_delete）。"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# ログベースメトリクス（ログ）
# ---------------------------------------------------------------------------

variable "enable_error_log_metric" {
  description = "severity>=ERROR のログベースカウンタを作るか。"
  type        = bool
  default     = true
}

variable "error_metric_name" {
  description = "ERROR ログメトリクスのベース名（→ logging.googleapis.com/user/<name>）。ERROR ログレートアラートから再利用される。"
  type        = string
  default     = "hernes_error_log_count"
}

variable "error_log_filter" {
  description = "ERROR メトリクスのフィルタ上書き。null なら local.service_log_filter + severity>=ERROR。構造化ログ導入前は textPayload マッチに上書き可。"
  type        = string
  default     = null
}

variable "enable_http_5xx_log_metric" {
  description = "Cloud Run リクエストログから HTTP 5xx カウンタを作るか。"
  type        = bool
  default     = true
}

variable "http_5xx_metric_name" {
  description = "5xx ログメトリクスのベース名。"
  type        = string
  default     = "hernes_http_5xx_count"
}

variable "http_5xx_log_filter" {
  description = "5xx メトリクスのフィルタ上書き。null なら local.service_log_filter + httpRequest.status>=500。"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# BigQuery へのログエクスポート（既定 OFF）
# ---------------------------------------------------------------------------

variable "enable_bigquery_log_export" {
  description = "ログを BigQuery へルーティング（dataset + sink + writer IAM）するか。長期保存・SQL 分析用。既定 OFF。"
  type        = bool
  default     = false
}

variable "log_export_dataset_id" {
  description = "ログエクスポート先 BigQuery データセット ID（アンダースコアのみ）。"
  type        = string
  default     = "hernes_logs"
}

variable "bigquery_location" {
  description = "BigQuery データセットのロケーション。null なら var.region。"
  type        = string
  default     = null
}

variable "log_export_partition_expiration_ms" {
  description = "日次パーティションの保持期間(ms)。既定 30 日。"
  type        = number
  default     = 2592000000
}

variable "log_export_delete_contents_on_destroy" {
  description = "destroy 時に中身のあるデータセットも削除してよいか。"
  type        = bool
  default     = false
}

variable "log_sink_name" {
  description = "ログルーターシンク名（ダッシュ可）。"
  type        = string
  default     = "hernes-logs-to-bq"
}

variable "sink_filter" {
  description = "シンクフィルタ上書き。null なら local.service_log_filter。"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# _Default ログバケットの保持期間（既定 OFF / 取り扱い注意）
# ---------------------------------------------------------------------------

variable "manage_default_log_bucket" {
  description = "_Default ログバケットの保持期間を TF で管理するか。既定 OFF（_Default を adopt するため取り扱い注意）。"
  type        = bool
  default     = false
}

variable "default_log_bucket_retention_days" {
  description = "_Default バケットの保持日数（管理する場合）。"
  type        = number
  default     = 30
}

variable "lock_default_log_bucket" {
  description = "_Default バケットを locked=true にするか（**不可逆**。保持期間短縮もバケット削除も不可になる）。"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# SLO / SLA
# ---------------------------------------------------------------------------

variable "enable_slo" {
  description = "監視サービス + SLO + バーンレートアラートを作るか。services が空なら自動的に何も作られない。"
  type        = bool
  default     = true
}

variable "rolling_period_days" {
  description = "SLO のローリング期間(日)。プロバイダ上限 30。"
  type        = number
  default     = 28

  validation {
    condition     = var.rolling_period_days >= 1 && var.rolling_period_days <= 30
    error_message = "rolling_period_days は 1〜30 の範囲で指定すること。"
  }
}

variable "fast_burn_threshold" {
  description = "高速バーン倍率（CRITICAL）。"
  type        = number
  default     = 10
}

variable "fast_burn_lookback" {
  description = "高速バーンの参照ウィンドウ。"
  type        = string
  default     = "3600s"
}

variable "slow_burn_threshold" {
  description = "低速バーン倍率（WARNING）。"
  type        = number
  default     = 2
}

variable "slow_burn_lookback" {
  description = "低速バーンの参照ウィンドウ。"
  type        = string
  default     = "86400s"
}

variable "enable_slow_burn" {
  description = "低速バーンアラートも作るか。"
  type        = bool
  default     = false
}

variable "burn_alignment_period" {
  description = "バーンレート条件の alignment_period。"
  type        = string
  default     = "300s"
}

# ---------------------------------------------------------------------------
# エラー / 不具合アラート
# ---------------------------------------------------------------------------

variable "enable_alerts" {
  description = "alerts_errors.tf のポリシー群を作るか（マスタゲート）。"
  type        = bool
  default     = true
}

variable "alert_enabled" {
  description = "各ポリシーの enabled フィールド値。false にすると作成だけして発報しない（段階導入用）。"
  type        = bool
  default     = true
}

variable "error_ratio_threshold" {
  description = "5xx/total 比のしきい値（0..1）。"
  type        = number
  default     = 0.05

  validation {
    condition     = var.error_ratio_threshold > 0 && var.error_ratio_threshold <= 1
    error_message = "error_ratio_threshold は 0 より大きく 1 以下で指定すること。"
  }
}

variable "error_ratio_duration" {
  description = "5xx 比アラートの継続時間。"
  type        = string
  default     = "300s"
}

variable "enable_error_log_alert" {
  description = "ERROR ログレートアラートを作るか（メトリクスが貯まるまで静か）。"
  type        = bool
  default     = true
}

variable "error_log_threshold" {
  description = "ERROR ログレート（ALIGN_RATE: entries/sec）のしきい値。"
  type        = number
  default     = 0.5
}

variable "error_log_duration" {
  description = "ERROR ログアラートの継続時間。"
  type        = string
  default     = "300s"
}

variable "enable_startup_crash_alert" {
  description = "コンテナ起動失敗/クラッシュアラートを作るか（専用メトリクスが必要なため既定 OFF）。"
  type        = bool
  default     = false
}

variable "startup_crash_metric_name" {
  description = "起動失敗ログメトリクスのベース名。"
  type        = string
  default     = "hernes_container_startup_failure_count"
}

variable "startup_crash_threshold" {
  description = "起動失敗カウントのしきい値（GT）。0 なら 1 件で発報。"
  type        = number
  default     = 0
}

variable "startup_crash_duration" {
  description = "起動失敗アラートの継続時間。"
  type        = string
  default     = "0s"
}

variable "alignment_period" {
  description = "しきい値条件の既定 alignment_period。"
  type        = string
  default     = "60s"
}

variable "auto_close_duration" {
  description = "alert_strategy.auto_close（インシデント自動クローズまで）。"
  type        = string
  default     = "1800s"
}

variable "notification_rate_limit_period" {
  description = "ERROR ログポリシーの再通知スロットル間隔。"
  type        = string
  default     = "300s"
}

# ---------------------------------------------------------------------------
# ダッシュボード
# ---------------------------------------------------------------------------

variable "enable_dashboard" {
  description = "概要ダッシュボードを作るか。"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Uptime チェック（既定 OFF: Cloud Run URL は動的なので安定ドメインがある場合のみ）
# ---------------------------------------------------------------------------

variable "uptime_targets" {
  description = "HTTP uptime チェック対象（key => {host, path}）。Cloud Run の *.run.app は動的なので、安定したカスタムドメインがある場合のみ指定。既定は空（何も作らない）。"
  type = map(object({
    host = string
    path = optional(string, "/healthz")
  }))
  default = {}
}

variable "uptime_period" {
  description = "uptime チェック間隔（60s/300s/600s/900s）。"
  type        = string
  default     = "300s"
}

# ---------------------------------------------------------------------------
# 料金 / 予算（通知のみ。支出は止めない）
# ---------------------------------------------------------------------------

variable "budget_enable" {
  description = "Billing budget を作るか（マスタゲート）。billing_account が空なら無効。"
  type        = bool
  default     = false
}

variable "billing_account" {
  description = "予算を作る **請求アカウント ID**（XXXXXX-XXXXXX-XXXXXX 形式。project_id ではない）。\"\" で予算スキップ。"
  type        = string
  default     = ""
}

variable "budget_display_name" {
  description = "予算の表示名（<=60 文字）。"
  type        = string
  default     = "hernes budget"
}

variable "budget_currency_code" {
  description = "予算通貨（ISO 4217。請求アカウントの通貨と一致させること）。"
  type        = string
  default     = "JPY"
}

variable "budget_amount_units" {
  description = "予算額（整数・通貨の主単位）。units は文字列に変換して渡す。"
  type        = number
  default     = 50000
}

variable "budget_use_last_period_amount" {
  description = "前期実績の 100% を予算とするか（true の場合 specified_amount は使わない）。"
  type        = bool
  default     = false
}

variable "budget_calendar_period" {
  description = "予算期間（MONTH/QUARTER/YEAR）。"
  type        = string
  default     = "MONTH"
}

variable "budget_credit_types_treatment" {
  description = "クレジットの扱い（INCLUDE_ALL_CREDITS / EXCLUDE_ALL_CREDITS など）。"
  type        = string
  default     = "INCLUDE_ALL_CREDITS"
}

variable "budget_current_spend_thresholds" {
  description = "CURRENT_SPEND のしきい値（1.0 基準）。例 [0.5,0.8,0.9,1.0] = 50/80/90/100%。"
  type        = list(number)
  default     = [0.5, 0.8, 0.9, 1.0]
}

variable "budget_forecasted_thresholds" {
  description = "FORECASTED_SPEND のしきい値（1.0 基準）。"
  type        = list(number)
  default     = [1.0]
}

variable "budget_disable_default_iam_recipients" {
  description = "メール指定時にデフォルト IAM 受信者（請求管理者）への通知を抑止するか。メール未指定なら強制的に false。"
  type        = bool
  default     = true
}

variable "budget_pubsub_topic" {
  description = "予算通知の fan-out 用 Pub/Sub トピック（アラート用とは別指定可）。\"\" で無効。"
  type        = string
  default     = ""
}
