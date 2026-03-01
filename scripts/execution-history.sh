#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
LOG_GROUP="/aws/lambda/simple-lambda-dev"
HOURS="${1:-24}"
LIMIT="${2:-50}"

START_TIME=$(date -v-${HOURS}H +%s 2>/dev/null || date -d "${HOURS} hours ago" +%s)
END_TIME=$(date +%s)

QUERY='fields @timestamp, message, name, greeting, language, title, emoji
| filter ispresent(message)
| sort @timestamp desc
| limit '"${LIMIT}"

QID=$(aws logs start-query \
  --log-group-name "$LOG_GROUP" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string "$QUERY" \
  --region "$REGION" \
  --output text)

sleep 3

aws logs get-query-results --query-id "$QID" --region "$REGION" --output json | python3 -c "
import json, sys

data = json.load(sys.stdin)
status = data.get('status', 'Unknown')
results = data.get('results', [])

if not results:
    print('No executions found.')
    sys.exit(0)

print(f\"{'TIMESTAMP':<28} {'MESSAGE':<45} {'NAME':<10} {'GREETING':<15} {'LANG':<6} {'TITLE':<12} {'EMOJI'}\")
print('─' * 125)
for row in results:
    fields = {f['field']: f['value'] for f in row}
    ts = fields.get('@timestamp', '')
    msg = fields.get('message', '')
    name = fields.get('name', '')
    greeting = fields.get('greeting', '')
    lang = fields.get('language', '')
    title = fields.get('title', '')
    emoji_val = fields.get('emoji', '')
    print(f\"{ts:<28} {msg:<45} {name:<10} {greeting:<15} {lang:<6} {title:<12} {emoji_val}\")

print(f\"\n{len(results)} execution(s) found (last ${HOURS}h) — query status: {status}\")
"
