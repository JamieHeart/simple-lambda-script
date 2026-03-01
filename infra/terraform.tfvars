region      = "us-east-1"
environment = "dev"
app_name    = "simple-lambda"

<<<<<<< HEAD
executions = {
  # ── Single-shots ──────────────────────────────────────────────

  run_alice = {
    type     = "oneoff"
    name     = "Alice"
    greeting = "hello"
    language = "en"
    run_id   = "4"
  }

  run_bob_es = {
    type     = "oneoff"
    name     = "Bob"
    greeting = "buenos dias"
    language = "es"
    title    = "Dr."
    run_id   = "2"
  }

  run_diana_de = {
    type     = "oneoff"
    name     = "Diana"
    greeting = "guten tag"
    language = "de"
    title    = "Professor"
    emoji    = true
    run_id   = "1"
  }

  run_eve_minimal = {
    type     = "oneoff"
    name     = "Eve"
    greeting = "howdy"
    language = "en"
    run_id   = "1"
  }

  # ── Cron schedules ───────────────────────────────────────────

  cron_charlie_fr = {
    type     = "cron"
    name     = "Charlie"
    greeting = "bonjour"
    language = "fr"
    emoji    = true
    schedule = "rate(5 minutes)"
  }

  cron_frank_es = {
    type     = "cron"
    name     = "Frank"
    greeting = "hola"
    language = "es"
    title    = "Captain"
    schedule = "rate(5 minutes)"
  }

  cron_grace_de = {
    type     = "cron"
    name     = "Grace"
    greeting = "guten morgen"
    language = "de"
    emoji    = true
    schedule = "rate(10 minutes)"
  }

  cron_jamie_en = {
    type = "cron"
    name = "Jamie"
    greeting = "Yo yo!"
    language = "en"
    schedule = "rate(1 minute)"
  }
}
=======
executions = {}
>>>>>>> cd0bae1 (Destroy all executions (clean slate))
