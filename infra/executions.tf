locals {
  cron_executions = {
    for k, v in var.executions : k => v if v.type == "cron"
  }
  oneoff_executions = {
    for k, v in var.executions : k => v if v.type == "oneoff"
  }
}

# ── Cron Executions (EventBridge Rule + Target + Permission) ─────────────────

resource "aws_cloudwatch_event_rule" "cron" {
  for_each = local.cron_executions

  name                = "${var.app_name}-${var.environment}-${each.key}"
  schedule_expression = each.value.schedule
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "cron" {
  for_each = local.cron_executions

  rule = aws_cloudwatch_event_rule.cron[each.key].name
  arn  = aws_lambda_function.this.arn

  input = jsonencode({
    name     = each.value.name
    greeting = each.value.greeting
    language = each.value.language
    title    = each.value.title
    emoji    = each.value.emoji
  })
}

resource "aws_lambda_permission" "cron" {
  for_each = local.cron_executions

  statement_id  = "AllowEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron[each.key].arn
}

# ── One-Off Executions (aws_lambda_invocation) ──────────────────────────────

resource "aws_lambda_invocation" "oneoff" {
  for_each = local.oneoff_executions

  function_name = aws_lambda_function.this.function_name

  triggers = {
    run_id  = coalesce(each.value.run_id, each.key)
    payload = jsonencode({
      name     = each.value.name
      greeting = each.value.greeting
      language = each.value.language
      title    = each.value.title
      emoji    = each.value.emoji
    })
  }

  input = jsonencode({
    name     = each.value.name
    greeting = each.value.greeting
    language = each.value.language
    title    = each.value.title
    emoji    = each.value.emoji
  })

  depends_on = [aws_lambda_function.this]
}
