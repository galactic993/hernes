# =============================================================================
# modules/monitoring
# -----------------------------------------------------------------------------
# hernes プラットフォーム向けの GCP 監視一式。
#   - ログ        : ログベースメトリクス + （任意で）BigQuery エクスポート / 保持
#   - バグ/不具合 : 5xx 比アラート / ERROR ログレートアラート / 起動失敗アラート
#   - SLA / SLO   : 可用性・レイテンシ SLO + バーンレートアラート（長寿命サービスのみ）
#   - 料金        : Billing budget（**通知のみ**。支出は止めない）
#   - 横断        : 通知チャンネル / 概要ダッシュボード / API 有効化 / uptime
#
# 規約（既存モジュールに合わせる）:
#   - provider は hashicorp/google のみ（google-beta は使わない）。各リソースは
#     project = var.project_id を明示。
#   - IAM は additive（google_*_iam_member）。任意リソースは count/one() か
#     for_each/toset でゲートする。
#   - 危険・高コストになりうるもの（BigQuery export / _Default バケット / uptime /
#     budget / slow-burn / startup-crash）はすべて既定 OFF（opt-in）。
#
# 重要な前提:
#   - 監視対象 Cloud Run サービスは GitHub Actions がデプロイする固定名:
#       staging:    backend-staging / frontend-staging
#       production: backend-prod    / frontend-prod
#     preview の *-pr-<N> は scale-to-zero で寿命が短いため var.services に渡さない。
#   - backend は今のところ素の console.log（textPayload）。severity>=ERROR の
#     シグナルは構造化ログ導入までは疎。よって ERROR 系アラートは保守的な既定 +
#     no-data 非発報（EVALUATION_MISSING_DATA_INACTIVE）にしてある。
# =============================================================================

locals {
  # var.services から導出する監視対象サービス名のリスト。
  service_names = [for k, s in var.services : s.service_name]

  # ----- ログ(Logging)フィルタ: log-based metric / sink で再利用 -----------
  # Logging のフィルタ言語では resource.labels.service_name（複数形・非引用）を使う。
  service_log_filter = coalesce(
    var.log_filter_override,
    length(local.service_names) > 0 ?
    "resource.type=\"cloud_run_revision\" AND (${join(" OR ", [for n in local.service_names : "resource.labels.service_name=\"${n}\""])})" :
    "resource.type=\"cloud_run_revision\""
  )

  # ----- メトリクス(Monitoring)フィルタ用のサービス名 OR 句 ----------------
  # Monitoring の時系列フィルタでは resource.label."service_name"（単数形・引用）を使う。
  service_name_metric_clause = length(local.service_names) > 0 ? "(${join(" OR ", [for n in local.service_names : "resource.label.\"service_name\"=\"${n}\""])})" : ""

  # ----- user_labels: dot 付きキー・動的値(commit-sha)を除去し env を強制 ---
  monitoring_user_labels = merge(
    { for k, v in var.labels : k => v if k != "commit-sha" && k != "commit_sha" },
    { env = var.env },
  )

  # ----- 通知チャンネル ID（全アラート・予算がここから消費） ---------------
  notification_channel_ids = concat(
    [for c in google_monitoring_notification_channel.email : c.id],
    var.pubsub_notification_topic == "" ? [] : [google_monitoring_notification_channel.pubsub[0].id],
  )

  # ログメトリクス作成側とアラート参照側で名前がズレないよう 1 箇所に固定。
  error_log_metric_name = var.error_metric_name

  # ----- 有効化する API（enable_apis のときのみ） --------------------------
  required_apis = var.enable_apis ? toset(concat(
    ["monitoring.googleapis.com", "logging.googleapis.com"],
    var.enable_bigquery_log_export ? ["bigquery.googleapis.com"] : [],
    (var.budget_enable && var.billing_account != "") ? ["billingbudgets.googleapis.com", "cloudbilling.googleapis.com"] : [],
  )) : toset([])
}
