variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "app_name" {
  type    = string
  default = "simple-lambda"
}

variable "lambda_image_uri" {
  type        = string
  description = "Full ECR image URI including tag (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/simple-lambda-dev:latest)"
}

variable "executions" {
  type = map(object({
    type     = string
    name     = string
    schedule = optional(string)
    run_id   = optional(string)
  }))
  description = "Map of execution configurations. type is 'oneoff' or 'cron'. schedule is required for cron. run_id controls re-invocation for oneoff."
}
