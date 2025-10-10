#!/bin/bash

# Terraform Plan All Layers
# 환경별로 모든 레이어를 순서대로 plan 실행

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 환경 설정 (기본값: dev)
ENVIRONMENT="${1:-dev}"

echo "🔍 Terraform Plan - 환경: $ENVIRONMENT"

# 레이어 실행 순서 정의
LAYERS=(
    "01-network"
    "02-security"
    "03-database"
    "04-parameter-store"
    "05-cloud-map"
    "06-lambda-genai"
    "07-application"
    "08-api-gateway"
    "09-monitoring"
    "10-aws-native"
)

ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    echo "❌ 환경 디렉터리가 존재하지 않습니다: $ENV_DIR"
    exit 1
fi

# 각 레이어 순서대로 plan 실행
for layer in "${LAYERS[@]}"; do
    LAYER_DIR="$ENV_DIR/$layer"

    if [ -d "$LAYER_DIR" ]; then
        echo "📋 Planning $layer..."

        cd "$LAYER_DIR"

        # Terraform init (필요시)
        if [ ! -d ".terraform" ]; then
            echo "  🔧 Initializing Terraform..."
            terraform init -upgrade
        fi

        # Plan 실행
        echo "  📝 Running terraform plan..."
        terraform plan -out=tfplan

        echo "  ✅ $layer plan completed"
        echo ""
    else
        echo "⚠️  $layer 디렉터리가 존재하지 않습니다. 건너뜁니다."
    fi
done

echo "🎉 모든 레이어 plan 완료!"
echo "💡 apply를 실행하려면: ./scripts/apply-all.sh $ENVIRONMENT"