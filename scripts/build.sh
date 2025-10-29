#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID=897722691159
REGION=ap-northeast-2
REPO_BASE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# 단일 아키텍처 강제 (buildx 기본이더라도 단일로)
# export DOCKER_DEFAULT_PLATFORM=linux/amd64

# ECR 로그인(1회)
aws ecr get-login-password --region "$REGION" \
| docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# 서비스: 로컬경로 => ECR 리포지토리명
declare -A SRV=(
  #[./spring-petclinic-admin-server]=admin-server
  [./spring-petclinic-customers-service]=customers-service
  [./spring-petclinic-vets-service]=vets-service
  [./spring-petclinic-visits-service]=visits-service
)

TAG="$(date +%Y%m%d-%H%M%S)"

for SERVICE_PATH in "${!SRV[@]}"; do
  NAME="${SRV[$SERVICE_PATH]}"
  REPO="$REPO_BASE/$NAME"

  # (없으면 생성해도 됨)
  aws ecr describe-repositories --repository-names "$NAME" --region "$REGION" \
  || aws ecr create-repository --repository-name "$NAME" --region "$REGION"

  echo "==> Build $NAME from $SERVICE_PATH"
  docker buildx build --platform linux/amd64 -t "$REPO:latest" -t "$REPO:$TAG" "$SERVICE_PATH"

  echo "==> Push $NAME"
  docker push "$REPO:latest"
  docker push "$REPO:$TAG"
done