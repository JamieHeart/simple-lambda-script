resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.app_name}-${var.environment}"
  retention_in_days = 7
}

resource "aws_lambda_function" "this" {
  function_name = "${var.app_name}-${var.environment}"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = var.lambda_image_uri
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda,
  ]
}
