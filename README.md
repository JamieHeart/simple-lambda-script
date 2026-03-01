# Simple Lambda Script

Terraform-managed AWS Lambda (container image) supporting one-off invocations and cron schedules. Each execution receives a configurable JSON payload with greeting, language, name, and optional title/emoji fields, producing localized output like `buenos dias mundo, Dr. Bob` logged to CloudWatch.

## Architecture

- **Lambda**: Python 3.12 container image (arm64) stored in ECR
- **One-off runs**: `aws_lambda_invocation` resource -- invokes Lambda natively during `terraform apply`, result captured in state
- **Cron schedules**: EventBridge Rules with JSON payload targets
- **Image resolution**: `data.aws_ecr_image` resolves the `:latest` tag to its SHA256 digest at apply time
- **State**: S3 backend with DynamoDB locking
- **CI/CD**: Two GitHub Actions workflows (infra and lambda) with path-based separation

```
GitHub Actions
  infra.yml ──────────────────── lambda.yml
  plan on PR                     build on PR (arm64 via QEMU)
  apply on merge                 push on merge
                                 deploy: terraform apply -target=lambda
          │                              │
          ▼                              ▼
  Terraform State (S3)           ECR Repo (:latest)
                                         │
          ┌──────────────────────────────┘
          ▼
   Lambda Function  ◄── EventBridge Rules (cron)
          │
          ▼
   CloudWatch Logs
```

## Repo Structure

```
├── .github/workflows/
│   ├── infra.yml              # Terraform: plan on PR, apply on merge
│   └── lambda.yml             # Docker: build on PR, push + deploy on merge
├── infra/
│   ├── backend.tf             # S3 + DynamoDB remote state
│   ├── ecr.tf                 # ECR repository
│   ├── executions.tf          # EventBridge rules + aws_lambda_invocation
│   ├── iam.tf                 # Lambda execution role
│   ├── lambda.tf              # Lambda function + log group + ECR image lookup
│   ├── main.tf                # AWS provider
│   ├── outputs.tf             # Exported values (including oneoff_results)
│   ├── terraform.tfvars       # Committed config (non-secret)
│   ├── terraform.tfvars.example
│   ├── variables.tf           # Input variables
│   └── versions.tf            # Provider version constraints
├── lambda/
│   ├── app.py                 # Lambda handler
│   ├── Dockerfile             # Container image definition
│   └── requirements.txt       # Python dependencies (empty for MVP)
├── scripts/
│   ├── build-and-push.sh      # Local ECR push helper
│   └── execution-history.sh   # Pretty-print recent Lambda invocations
├── Makefile                   # Local dev convenience targets
└── README.md
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- Docker
- GitHub repository with Actions enabled

## Initial Bootstrap (One-Time Setup)

### 1. Create Remote State Resources

```bash
aws s3api create-bucket \
  --bucket simple-lambda-tfstate \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket simple-lambda-tfstate \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name simple-lambda-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Create CI IAM User

Create a dedicated IAM user for GitHub Actions with permissions for: ECR (including `DescribeImages`), Lambda, EventBridge, IAM (scoped to `simple-lambda-*`), CloudWatch Logs, S3 (state bucket), and DynamoDB (lock table).

### 3. Configure GitHub Secrets

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | CI IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |

### 4. First Deploy (Local)

The Lambda requires an image in ECR before it can be created:

```bash
make init
terraform -chdir=infra apply -target=aws_ecr_repository.this
make push
make apply
```

After this, all subsequent changes go through PRs.

## Execution Configuration

All execution config lives in `infra/terraform.tfvars` in the `executions` map. Each execution has 3 required fields and 2 optional fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | yes | `"oneoff"` or `"cron"` |
| `name` | string | yes | Who to greet (e.g. `"Alice"`) |
| `greeting` | string | yes | Greeting phrase (e.g. `"hello"`, `"buenos dias"`) |
| `language` | string | yes | Language code: `en`, `es`, `fr`, `de` (maps to localized "world") |
| `title` | string | no | Honorific (e.g. `"Dr."`, `"Captain"`) |
| `emoji` | bool | no | Append a party emoji to output (default: `false`) |
| `schedule` | string | cron only | EventBridge schedule expression (e.g. `"rate(5 minutes)"`) |
| `run_id` | string | oneoff only | Change to re-trigger invocation |

**Language translations**: `en` = "world", `es` = "mundo", `fr` = "monde", `de` = "welt"

### Example Configuration

```hcl
executions = {
  run_alice = {
    type     = "oneoff"
    name     = "Alice"
    greeting = "hello"
    language = "en"
    run_id   = "1"
  }

  run_bob = {
    type     = "oneoff"
    name     = "Bob"
    greeting = "buenos dias"
    language = "es"
    title    = "Dr."
    run_id   = "1"
  }

  cron_charlie = {
    type     = "cron"
    name     = "Charlie"
    greeting = "bonjour"
    language = "fr"
    emoji    = true
    schedule = "rate(5 minutes)"
  }
}
```

**Expected outputs**:
- Alice: `hello world, Alice`
- Bob: `buenos dias mundo, Dr. Bob`
- Charlie: `bonjour monde, Charlie` (with party emoji)

### One-Off Invocations

- Executed during `terraform apply` via `aws_lambda_invocation` (no shell/CLI dependency)
- Controlled by `run_id`: if `run_id` and payload are unchanged, subsequent applies are no-ops
- To re-invoke: bump `run_id` (e.g., `"1"` to `"2"`)
- To remove: delete the entry from the map and apply
- Lambda response is captured in state and available via `terraform output oneoff_results`

### Cron Schedules

- Creates an EventBridge Rule + Target + Lambda Permission per entry
- The `schedule` field accepts `rate(...)` or `cron(...)` expressions
- Note: use singular form for 1 (e.g., `rate(1 minute)` not `rate(1 minutes)`)
- Removing an entry from the map and applying destroys all associated resources cleanly

## Steady-State Operations (Via PR)

| Operation | What to change | PR scope |
|---|---|---|
| Deploy new Lambda code | Edit files in `lambda/` | `lambda/` only |
| Add a cron schedule | Add entry to `executions` in `infra/terraform.tfvars` | `infra/` only |
| Remove a cron schedule | Delete entry from `executions` map | `infra/` only |
| Trigger a one-off run | Add/modify oneoff entry, bump `run_id` | `infra/` only |
| Re-trigger same one-off | Bump `run_id` value | `infra/` only |

**Important**: Do not mix `infra/` and `lambda/` changes in the same PR. CI will reject mixed PRs.

## CI/CD Workflows

### `infra.yml` (Terraform)

- **On PR** (touching `infra/`): Runs `terraform plan` and posts the output as a PR comment
- **On merge to main** (touching `infra/`): Runs `terraform apply -auto-approve`
- Concurrency group prevents parallel applies

### `lambda.yml` (Docker Image + Deploy)

- **On PR** (touching `lambda/` or the workflow file): Builds the Docker image (arm64 via QEMU) to validate
- **On merge to main**: Builds, tags (SHA + latest), pushes to ECR, then runs a targeted `terraform apply` to update the Lambda function to the new image digest
- The deploy step uses the same `terraform-apply` concurrency group as `infra.yml`

### Image Resolution

Terraform uses `data.aws_ecr_image` to resolve the `:latest` tag to its current SHA256 digest. This means:
- No manual `lambda_image_uri` variable to manage
- Every `terraform apply` automatically picks up the current image
- The `lambda.yml` deploy step triggers this after every image push

## Local Development

```bash
make build    # Build Docker image locally (arm64)
make push     # Authenticate + push to ECR
make init     # terraform init
make plan     # terraform plan
make apply    # terraform apply
make destroy  # terraform destroy
make logs     # Tail CloudWatch logs
make history  # Pretty-print recent execution history (HOURS=24 LIMIT=50)
```

## Verifying

```bash
# Pretty-print recent executions
./scripts/execution-history.sh          # last 24h, 50 results
./scripts/execution-history.sh 4 100    # last 4h, 100 results

# Tail CloudWatch logs live
aws logs tail /aws/lambda/simple-lambda-dev --follow --region us-east-1

# Check one-off results from Terraform state
terraform -chdir=infra output oneoff_results

# Manual invocation (outside Terraform)
aws lambda invoke \
  --function-name simple-lambda-dev \
  --payload '{"name": "Test", "greeting": "hey", "language": "en"}' \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  /tmp/response.json && cat /tmp/response.json
```

## Teardown

```bash
# Destroy all AWS resources managed by Terraform
make destroy

# Optionally remove state resources
aws s3 rb s3://simple-lambda-tfstate --force
aws dynamodb delete-table --table-name simple-lambda-tflock --region us-east-1
```
