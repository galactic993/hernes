# budget.tf
# 料金 / 予算アラート（Billing budget）。
#
# ⚠️ 重要: 予算は **通知のみ**。支出を止めたり、上限を強制したり、リソースを
#          停止したりは一切しない。閾値超過時に通知が飛ぶだけ。
#
# 注意点:
#   - billing_account は **請求アカウント ID**（project_id ではない）。
#   - budget_filter.projects は project NUMBER（data.google_project.this.number）。
#   - これを apply する主体に請求アカウント側の権限が必要
#     （roles/billing.costManager もしくは billing.budgets.* on billing account）。
#   - 既定 OFF。budget_enable=true かつ billing_account != "" のときだけ作る。

locals {
  # budget の通知に使うメールチャンネル（API 上限 5 件に丸める）。
  budget_email_channel_ids = [for c in google_monitoring_notification_channel.email : c.id]
  budget_channel_ids       = slice(local.budget_email_channel_ids, 0, min(5, length(local.budget_email_channel_ids)))
}

resource "google_billing_budget" "this" {
  count = (var.budget_enable && var.billing_account != "") ? 1 : 0

  billing_account = var.billing_account
  display_name    = var.budget_display_name

  budget_filter {
    projects               = ["projects/${data.google_project.this.number}"]
    credit_types_treatment = var.budget_credit_types_treatment
    calendar_period        = var.budget_calendar_period
  }

  amount {
    # 固定額 or 前期実績の 100%（排他）。
    dynamic "specified_amount" {
      for_each = var.budget_use_last_period_amount ? [] : [1]
      content {
        currency_code = var.budget_currency_code
        units         = tostring(var.budget_amount_units)
      }
    }
    last_period_amount = var.budget_use_last_period_amount ? true : null
  }

  # CURRENT_SPEND の閾値（50/80/90/100% など）。
  dynamic "threshold_rules" {
    for_each = var.budget_current_spend_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  # FORECASTED_SPEND の閾値（着地見込みの早期警告）。
  dynamic "threshold_rules" {
    for_each = var.budget_forecasted_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "FORECASTED_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = local.budget_channel_ids
    # メール指定があるときのみデフォルト IAM 受信者を抑止可能。無いなら必ず false。
    disable_default_iam_recipients = length(var.notification_emails) > 0 ? var.budget_disable_default_iam_recipients : false
    pubsub_topic                   = var.budget_pubsub_topic != "" ? var.budget_pubsub_topic : null
    schema_version                 = "1.0"
  }

  depends_on = [google_project_service.required]
}
