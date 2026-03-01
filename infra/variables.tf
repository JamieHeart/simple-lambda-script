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

variable "executions" {
  type = map(object({
    type     = string
    name     = string
    greeting = string
    language = string
    title    = optional(string)
    emoji    = optional(bool, false)
    schedule = optional(string)
    run_id   = optional(string)
  }))
  description = "Map of execution configurations. type is 'oneoff' or 'cron'. greeting/language/name are required. title and emoji are optional. schedule is required for cron. run_id controls re-invocation for oneoff."
}
