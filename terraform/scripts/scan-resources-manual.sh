#!/bin/bash

# 수동 AWS 리소스 스캔 스크립트 (jq 없이)
# 목적: 각 테라폼 레이어의 상태를 확인하고 수동 생성된 리소스 식별

set -e

ENVIRONMENT=${1:-"dev"}

echo "=== AWS 리소스 상태 스캔 시작 ==="
echo "환경: $ENVIRONMENT"

# 테라폼 레이어 목록
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
)

echo ""
echo "=== 레이어별 상태 스캔 ==="

TOTAL_LAYERS=${#LAYERS[@]}
LAYERS_SCANNED=0
DRIFT_DETECTED=0

for layer in "${LAYERS[@]}"; do
    echo ""
    echo "--- $layer 레이어 스캔 중 ---"
    
    layer_path="terraform/layers/$layer"
    
    if [ -d "$layer_path" ]; then
        cd "$layer_path"
        
        if [ -d ".terraform" ]; then
            echo "  ✓ Terraform 초기화됨"
            
            # Terraform state list 실행
            if state_output=$(terraform state list 2>/dev/null); then
                resource_count=$(echo "$state_output" | wc -l)
                if [ "$resource_count" -gt 0 ]; then
                    echo "  ✓ Terraform 상태 리소스: ${resource_count}개"
                    
                    # Terraform plan 실행하여 drift 확인
                    echo "  → Drift 확인 중..."
                    
                    # Plan 실행 (출력 숨김)
                    if terraform plan -detailed-exitcode -var-file="../../envs/$ENVIRONMENT.tfvars" >/dev/null 2>&1; then
                        exit_code=$?
                        case $exit_code in
                            0)
                                echo "  ✓ 상태 일치 (drift 없음)"
                                ;;
                            1)
                                echo "  ❌ Plan 실행 오류"
                                ;;
                            2)
                                echo "  ⚠️  Drift 감지됨"
                                ((DRIFT_DETECTED++))
                                ;;
                        esac
                    else
                        exit_code=$?
                        if [ $exit_code -eq 2 ]; then
                            echo "  ⚠️  Drift 감지됨"
                            ((DRIFT_DETECTED++))
                        else
                            echo "  ❌ Plan 실행 오류 (exit code: $exit_code)"
                        fi
                    fi
                else
                    echo "  ⚠️  State에 리소스가 없음"
                fi
            else
                echo "  ❌ State 읽기 실패"
            fi
        else
            echo "  ⚠️  Terraform 미초기화"
        fi
        
        cd - > /dev/null
    else
        echo "  ❌ 디렉토리 없음"
    fi
    
    ((LAYERS_SCANNED++))
done

echo ""
echo "=== 07-application 레이어 상세 분석 ==="

# 07-application 레이어에서 수동 생성된 리소스 식별
app_layer_path="terraform/layers/07-application"
if [ -d "$app_layer_path" ]; then
    cd "$app_layer_path"
    
    echo "07-application 레이어에서 수동 생성 가능한 리소스 확인 중..."
    
    # Terraform state 확인
    if state_output=$(terraform state list 2>/dev/null); then
        echo ""
        echo "현재 Terraform으로 관리되는 리소스:"
        echo "$state_output" | while read -r resource; do
            echo "  - $resource"
        done
        
        echo ""
        echo "수동 생성 가능성이 높은 리소스 확인:"
        
        # 보안 그룹 규칙 확인
        if echo "$state_output" | grep -q "aws_security_group_rule.*aurora"; then
            echo "  ✓ Aurora 보안 그룹 규칙이 Terraform으로 관리됨"
        else
            echo "  ⚠️  Aurora 보안 그룹 규칙이 Terraform 상태에 없음 - Import 필요"
        fi
        
        if echo "$state_output" | grep -q "aws_security_group_rule.*ecs"; then
            echo "  ✓ ECS 보안 그룹 규칙이 Terraform으로 관리됨"
        else
            echo "  ⚠️  ECS 보안 그룹 규칙이 Terraform 상태에 없음 - Import 필요"
        fi
        
        # IAM 역할 확인
        if echo "$state_output" | grep -q "aws_iam_role.*ecs"; then
            echo "  ✓ ECS IAM 역할이 Terraform으로 관리됨"
        else
            echo "  ⚠️  ECS IAM 역할이 Terraform 상태에 없음 - Import 필요"
        fi
        
        # 키 페어 확인
        if echo "$state_output" | grep -q "aws_key_pair"; then
            echo "  ✓ EC2 키 페어가 Terraform으로 관리됨"
        else
            echo "  ⚠️  EC2 키 페어가 Terraform 상태에 없음 - Import 필요"
        fi
        
    else
        echo "  ❌ Terraform state를 읽을 수 없음"
    fi
    
    cd - > /dev/null
fi

echo ""
echo "=== 스캔 요약 ==="
echo "총 레이어: $TOTAL_LAYERS"
echo "스캔된 레이어: $LAYERS_SCANNED"
echo "Drift 감지된 레이어: $DRIFT_DETECTED"

if [ $DRIFT_DETECTED -gt 0 ]; then
    echo ""
    echo "⚠️  $DRIFT_DETECTED 개 레이어에서 drift가 감지되었습니다."
    echo "수동으로 생성된 리소스가 있을 가능성이 높습니다."
    echo ""
    echo "=== 권장 다음 단계 ==="
    echo "1. Drift가 감지된 레이어에서 'terraform plan' 실행하여 상세 확인"
    echo "2. 수동 생성된 리소스 식별 후 Import 계획 수립"
    echo "3. 높은 우선순위 리소스부터 Import 시작"
else
    echo ""
    echo "✓ 모든 레이어에서 drift가 감지되지 않았습니다."
fi

echo ""
echo "=== AWS 리소스 상태 스캔 완료 ==="