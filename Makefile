.PHONY: build push init plan apply destroy logs

ECR_REPO_URL ?= $(shell cd infra && terraform output -raw ecr_repository_url 2>/dev/null)
REGION       ?= us-east-1
APP_NAME     ?= simple-lambda
ENVIRONMENT  ?= dev
LOG_GROUP    ?= /aws/lambda/$(APP_NAME)-$(ENVIRONMENT)

build:
	docker build -t $(APP_NAME)-$(ENVIRONMENT):latest lambda/

push:
	@if [ -z "$(ECR_REPO_URL)" ]; then \
		echo "ERROR: ECR_REPO_URL not set. Run 'make apply' first to create the ECR repo, or set ECR_REPO_URL manually."; \
		exit 1; \
	fi
	./scripts/build-and-push.sh $(ECR_REPO_URL) latest

init:
	terraform -chdir=infra init

plan:
	terraform -chdir=infra plan

apply:
	terraform -chdir=infra apply

destroy:
	terraform -chdir=infra destroy

logs:
	aws logs tail $(LOG_GROUP) --follow --region $(REGION)
