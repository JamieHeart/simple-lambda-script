region      = "us-east-1"
environment = "dev"
app_name    = "simple-lambda"

lambda_image_uri = "637423251679.dkr.ecr.us-east-1.amazonaws.com/simple-lambda-dev:latest"

executions = {
  run_alice = {
    type     = "oneoff"
    name     = "Alice"
    greeting = "hello"
    language = "en"
    run_id   = "3"
  }
  run_bob_es = {
    type     = "oneoff"
    name     = "Bob"
    greeting = "buenos dias"
    language = "es"
    title    = "Dr."
    run_id   = "1"
  }
}
