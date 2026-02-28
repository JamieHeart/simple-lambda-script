#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/build-and-push.sh <ECR_REPO_URL> [IMAGE_TAG]
# Example: ./scripts/build-and-push.sh 123456789012.dkr.ecr.us-east-1.amazonaws.com/simple-lambda-dev latest

if [ $# -lt 1 ]; then
  echo "Usage: $0 <ECR_REPO_URL> [IMAGE_TAG]"
  echo "  ECR_REPO_URL: full ECR repository URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/simple-lambda-dev)"
  echo "  IMAGE_TAG:    image tag (default: latest)"
  exit 1
fi

ECR_REPO_URL="$1"
IMAGE_TAG="${2:-latest}"

REGISTRY=$(echo "$ECR_REPO_URL" | cut -d'/' -f1)
REGION=$(echo "$REGISTRY" | cut -d'.' -f4)

echo ">>> Authenticating Docker to ECR ($REGISTRY)..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

echo ">>> Building image..."
docker build -t "$ECR_REPO_URL:$IMAGE_TAG" lambda/

echo ">>> Pushing $ECR_REPO_URL:$IMAGE_TAG..."
docker push "$ECR_REPO_URL:$IMAGE_TAG"

if [ "$IMAGE_TAG" != "latest" ]; then
  echo ">>> Also tagging and pushing as latest..."
  docker tag "$ECR_REPO_URL:$IMAGE_TAG" "$ECR_REPO_URL:latest"
  docker push "$ECR_REPO_URL:latest"
fi

echo ">>> Done. Image pushed: $ECR_REPO_URL:$IMAGE_TAG"
