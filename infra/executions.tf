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
    name = each.value.name
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

# ── One-Off Executions (null_resource + local-exec) ──────────────────────────

resource "null_resource" "oneoff" {
  for_each = local.oneoff_executions

  triggers = {
    run_id  = each.value.run_id != null ? each.value.run_id : each.key
    payload = jsonencode({ name = each.value.name })
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws lambda invoke \
        --function-name ${aws_lambda_function.this.function_name} \
        --payload '${jsonencode({ name = each.value.name })}' \
        --cli-binary-format raw-in-base64-out \
        --region ${var.region} \
        --log-type Tail \
        /tmp/lambda-response-${each.key}.json \
      && echo "=== Lambda Response ===" \
      && cat /tmp/lambda-response-${each.key}.json \
      && echo ""
    EOT
  }

  depends_on = [aws_lambda_function.this]
}
