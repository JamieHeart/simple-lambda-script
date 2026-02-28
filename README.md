# Simple Lambda Script

Terraform-managed AWS Lambda (container image) supporting one-off invocations and cron schedules. Each execution receives a JSON payload with a `name` field and logs `hello world, <name>` to CloudWatch.

## Architecture

- **Lambda**: Python 3.12 container image stored in ECR
- **One-off runs**: Terraform `null_resource` + `local-exec` calling `aws lambda invoke`
- **Cron schedules**: EventBridge Rules with JSON payload targets
- **State**: S3 backend with DynamoDB locking
- **CI/CD**: Two GitHub Actions workflows (infra and lambda), triggered by PRs

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions                                         │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │ infra.yml    │  │ lambda.yml   │                     │
│  │ plan on PR   │  │ build on PR  │                     │
│  │ apply on     │  │ push on      │                     │
│  │ merge        │  │ merge        │                     │
│  └──────┬───────┘  └──────┬───────┘                     │
└─────────┼─────────────────┼─────────────────────────────┘
          │                 │
          ▼                 ▼
┌─────────────────┐  ┌─────────────┐
│ Terraform State │  │ ECR Repo    │
│ (S3 + DynamoDB) │  │ (image)     │
└─────────────────┘  └──────┬──────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                  ▼
   ┌────────────┐   ┌────────────┐   ┌──────────────────┐
   │ Lambda     │◄──│ EventBridge│   │ null_resource     │
   │ Function   │   │ Rules      │   │ (one-off invoke)  │
   └─────┬──────┘   └────────────┘   └──────────────────┘
         │
         ▼
   ┌────────────┐
   │ CloudWatch │
   │ Logs       │
   └────────────┘
```

## Repo Structure

```
├── .github/workflows/
│   ├── infra.yml             # Terraform: plan on PR, apply on merge
│   └── lambda.yml            # Docker: build on PR, push on merge
├── infra/
│   ├── backend.tf            # S3 + DynamoDB remote state
│   ├── ecr.tf                # ECR repository
│   ├── executions.tf         # EventBridge rules + one-off triggers
│   ├── iam.tf                # Lambda execution role
│   ├── lambda.tf             # Lambda function + log group
│   ├── main.tf               # AWS provider
│   ├── outputs.tf            # Exported values
│   ├── terraform.tfvars      # Committed config (non-secret)
│   ├── terraform.tfvars.example
│   ├── variables.tf          # Input variables
│   └── versions.tf           # Provider version constraints
├── lambda/
│   ├── app.py                # Lambda handler
│   ├── Dockerfile            # Container image definition
│   └── requirements.txt      # Python dependencies
├── scripts/
│   ├── build-and-push.sh     # Local ECR push helper
│   └── check-no-mixed-pr.sh  # Validates PR scope
├── Makefile                  # Local dev convenience targets
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

### 2. Configure GitHub Secrets

Set these secrets on your GitHub repository:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key with permissions for Lambda, ECR, EventBridge, CloudWatch, IAM, S3, DynamoDB |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |

### 3. First Deploy (Local)

The Lambda requires an image in ECR before it can be created. Run a two-phase initial deploy:

```bash
# Initialize Terraform
make init

# Create ECR repo first
terraform -chdir=infra apply -target=aws_ecr_repository.this

# Build and push the initial image
make push

# Deploy everything
make apply
```

After this, all subsequent changes go through PRs.

## Steady-State Operations (Via PR)

| Operation | What to change | PR scope |
|---|---|---|
| Deploy new Lambda code | Edit files in `lambda/` | `lambda/` only |
| Update Lambda to new image | Change `lambda_image_uri` in `infra/terraform.tfvars` | `infra/` only |
| Add a cron schedule | Add entry to `executions` in `infra/terraform.tfvars` | `infra/` only |
| Remove a cron schedule | Delete entry from `executions` map | `infra/` only |
| Trigger a one-off run | Add/modify oneoff entry, bump `run_id` | `infra/` only |
| Re-trigger same one-off | Bump `run_id` value | `infra/` only |

**Important**: Do not mix `infra/` and `lambda/` changes in the same PR. CI will reject mixed PRs.

## Execution Configuration

All execution config lives in `infra/terraform.tfvars` in the `executions` map:

```hcl
executions = {
  # One-off: bump run_id to re-trigger
  run_alice = {
    type   = "oneoff"
    name   = "Alice"
    run_id = "1"
  }

  # Cron: fires every 5 minutes
  cron_bob = {
    type     = "cron"
    name     = "Bob"
    schedule = "rate(5 minutes)"
  }

  # Cron: fires daily at 9 AM UTC
  cron_charlie = {
    type     = "cron"
    name     = "Charlie"
    schedule = "cron(0 9 * * ? *)"
  }
}
```

### One-Off Invocations

- Executed during `terraform apply` via `null_resource` + `local-exec`
- Controlled by the `run_id` field: if `run_id` and `name` are unchanged, subsequent applies are no-ops
- To re-invoke: bump `run_id` (e.g., change `"1"` to `"2"`)
- To remove: delete the entry from the map and apply
- The Lambda response appears in the Terraform apply output

### Cron Schedules

- Creates an EventBridge Rule + Target + Lambda Permission per entry
- The `schedule` field accepts `rate(...)` or `cron(...)` expressions
- Removing an entry from the map and applying destroys all associated resources cleanly (no orphans)

## CI/CD Workflows

### `infra.yml` (Terraform)

- **On PR** (touching `infra/`): Runs `terraform plan` and posts the output as a PR comment
- **On merge to main** (touching `infra/`): Runs `terraform apply -auto-approve`
- Concurrency group prevents parallel applies

### `lambda.yml` (Docker Image)

- **On PR** (touching `lambda/`): Builds the Docker image to validate it compiles
- **On merge to main** (touching `lambda/`): Builds, tags (SHA + latest), and pushes to ECR

### Image URI Flow

1. `lambda.yml` pushes images tagged with the git SHA and `latest`
2. `infra/terraform.tfvars` references the image via `lambda_image_uri`
3. To roll the Lambda to a new image, open an infra PR updating `lambda_image_uri`

## Local Development

```bash
make build    # Build Docker image locally
make push     # Authenticate + push to ECR
make init     # terraform init
make plan     # terraform plan
make apply    # terraform apply
make destroy  # terraform destroy
make logs     # Tail CloudWatch logs
```

## Verifying

```bash
# Check CloudWatch logs
aws logs tail /aws/lambda/simple-lambda-dev --follow --region us-east-1

# Manual invocation (outside Terraform)
aws lambda invoke \
  --function-name simple-lambda-dev \
  --payload '{"name": "Test"}' \
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

## Acceptance Criteria

1. `terraform init` and `terraform plan` succeed with no errors
2. `terraform apply` creates: ECR repo, IAM role, CloudWatch log group, Lambda function, EventBridge rule(s), and fires one-off invocation(s)
3. One-off invocation returns `{"statusCode": 200, "body": "{\"message\": \"hello world, Alice\"}"}`
4. CloudWatch Logs show `{"message": "hello world, Alice", "name": "Alice"}`
5. Cron-scheduled Lambda fires on schedule with correct log output
6. Removing a cron entry and applying destroys the rule, target, and permission with no orphans
7. Re-running a one-off (bumping `run_id`) triggers a new invocation; unchanged `run_id` is a no-op
8. `terraform destroy` removes all AWS resources cleanly
9. IAM role has only `AWSLambdaBasicExecutionRole` (least privilege)
10. Lambda permissions are scoped per EventBridge rule ARN
11. PRs touching `infra/` get a `terraform plan` comment automatically
12. PRs touching `lambda/` verify the Docker build succeeds
13. PRs touching both `infra/` and `lambda/` are rejected by CI
14. Merging an infra PR runs `terraform apply`; merging a lambda PR pushes a new image to ECR
