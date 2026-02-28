region      = "us-east-1"
environment = "dev"
app_name    = "simple-lambda"

lambda_image_uri = "637423251679.dkr.ecr.us-east-1.amazonaws.com/simple-lambda-dev:latest"

executions = {
  run_alice = {
    type   = "oneoff"
    name   = "Alice"
    run_id = "1"
  }
  cron_bob = {
    type     = "cron"
    name     = "Bob"
    schedule = "rate(5 minutes)"
  }
  cron_charlie = {
    type     = "cron"
    name     = "Charlie"
    schedule = "cron(0 9 * * ? *)"
  }
  cron_stewart = {
    type     = "cron"
    name     = "Stewart"
    schedule = "rate(10 minutes)"
  }
}
