region      = "us-east-1"
environment = "dev"
app_name    = "simple-lambda"

lambda_image_uri = "637423251679.dkr.ecr.us-east-1.amazonaws.com/simple-lambda-dev:latest"

executions = {
  run_alice = {
    type   = "oneoff"
    name   = "Alice"
    run_id = "2"
  }
  run_diana = {
    type = "oneoff"
    name = "Diana"
    run_id = "1"
  }
}
