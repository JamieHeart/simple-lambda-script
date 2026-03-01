region      = "us-east-1"
environment = "dev"
app_name    = "simple-lambda"

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
  cron_charlie_fr = {
    type     = "cron"
    name     = "Charlie"
    greeting = "bonjour"
    language = "fr"
    emoji    = true
    schedule = "rate(5 minutes)"
  }
}
