output "lambda_function_name" {
  value = aws_lambda_function.this.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.this.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "cron_rule_arns" {
  value = { for k, v in aws_cloudwatch_event_rule.cron : k => v.arn }
}
