#!/bin/bash

# Terraform Drift Detection
# 인프라 상태와 Terraform state 간의 차이를 자동으로 감지

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 환경 설정 (기본값: dev)
ENVIRONMENT="${1:-dev}"

echo "🔍 Terraform Drift Detection - 환경: $ENVIRONMENT"

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
    "09-aws-native"
    "10-monitoring"
    "11-frontend"
    "12-notification"
)

# 변수 파일 경로
VAR_FILE="$PROJECT_ROOT/envs/${ENVIRONMENT}.tfvars"

if [ ! -f "$VAR_FILE" ]; then
    echo "❌ 변수 파일이 존재하지 않습니다: $VAR_FILE"
    exit 1
fi

DRIFT_FOUND=false
REPORT_FILE="$PROJECT_ROOT/drift-report-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).txt"

echo "Drift Detection Report - $ENVIRONMENT" > "$REPORT_FILE"
echo "Generated at: $(date)" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"

# 각 레이어에 대해 drift 감지
for layer in "${LAYERS[@]}"; do
    LAYER_DIR="$PROJECT_ROOT/layers/$layer"

    if [ -d "$LAYER_DIR" ]; then
        echo "🔎 Checking drift in $layer..."

        cd "$LAYER_DIR"

        # Terraform init (필요시)
        if [ ! -d ".terraform" ]; then
            echo "  🔧 Initializing Terraform..."
            terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure >/dev/null 2>&1
        fi

        echo "" >> "$REPORT_FILE"
        echo "Layer: $layer" >> "$REPORT_FILE"
        echo "Directory: $LAYER_DIR" >> "$REPORT_FILE"
        echo "------------------------" >> "$REPORT_FILE"

        # Plan 실행하여 drift 확인
        PLAN_OUTPUT=$(terraform plan -detailed-exitcode -var-file="$VAR_FILE" 2>&1)
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo "  ✅ No drift detected in $layer"
            echo "Status: No changes" >> "$REPORT_FILE"
        elif [ $EXIT_CODE -eq 1 ]; then
            echo "  ❌ Error in $layer plan"
            echo "Status: Error" >> "$REPORT_FILE"
            echo "$PLAN_OUTPUT" >> "$REPORT_FILE"
            DRIFT_FOUND=true
        else
            echo "  ⚠️  Drift detected in $layer"
            echo "Status: Drift detected" >> "$REPORT_FILE"
            echo "$PLAN_OUTPUT" >> "$REPORT_FILE"
            DRIFT_FOUND=true
        fi

        echo "" >> "$REPORT_FILE"
    fi
done

echo "" >> "$REPORT_FILE"
echo "Summary:" >> "$REPORT_FILE"
if [ "$DRIFT_FOUND" = true ]; then
    echo "❌ Drift detected in one or more layers" >> "$REPORT_FILE"
    echo "🔴 DRIFT DETECTED! Check the report: $REPORT_FILE"

    # Slack 알림 등 추가 가능
    # curl -X POST -H 'Content-type: application/json' --data '{"text":"Terraform drift detected in '"$ENVIRONMENT"' environment"}' $SLACK_WEBHOOK_URL
else
    echo "✅ No drift detected in any layer" >> "$REPORT_FILE"
    echo "🟢 No drift detected"
fi

echo "📄 Detailed report saved to: $REPORT_FILE"