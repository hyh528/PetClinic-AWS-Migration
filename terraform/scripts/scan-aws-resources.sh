#!/bin/bash

# AWS 리소스 상태 스캔 스크립트
# 목적: 모든 테라폼 레이어의 상태와 실제 AWS 리소스를 비교하여 수동 생성된 리소스 식별

set -e

ENVIRONMENT=${1:-"dev"}
OUTPUT_FILE=${2:-"terraform/resource-scan-results.json"}

echo "=== AWS 리소스 상태 스캔 시작 ==="
echo "환경: $ENVIRONMENT"
echo "결과 파일: $OUTPUT_FILE"

# 결과 저장용 JSON 초기화
cat > "$OUTPUT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "environment": "$ENVIRONMENT",
  "scan_summary": {
    "total_layers": 0,
    "layers_scanned": 0,
    "drift_detected": 0,
    "manual_resources_found": 0,
    "import_needed": 0
  },
  "layer_results": [],
  "manual_resources": [],
  "recommendations": []
}
EOF

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

TOTAL_LAYERS=${#LAYERS[@]}
LAYERS_SCANNED=0
DRIFT_DETECTED=0
MANUAL_RESOURCES_FOUND=0
IMPORT_NEEDED=0

echo ""
echo "=== 레이어별 상태 스캔 ==="

# 임시 결과 파일들
LAYER_RESULTS_FILE="/tmp/layer_results.json"
echo "[]" > "$LAYER_RESULTS_FILE"

for layer in "${LAYERS[@]}"; do
    echo ""
    echo "--- $layer 레이어 스캔 중 ---"
    
    layer_path="terraform/layers/$layer"
    
    if [ -d "$layer_path" ]; then
        cd "$layer_path"
        
        # 레이어 결과 초기화
        layer_status="unknown"
        drift=false
        resource_count=0
        notes=""
        
        if [ -d ".terraform" ]; then
            echo "  ✓ Terraform 초기화됨"
            
            # Provider 플러그인 확인 및 재초기화
            if ! terraform providers > /dev/null 2>&1; then
                echo "  → Provider 플러그인 재설치 중..."
                if [ -f "backend.config" ]; then
                    terraform init -backend-config=backend.config > /dev/null 2>&1
                elif [ -f "../backend.hcl" ]; then
                    terraform init -backend-config=../backend.hcl > /dev/null 2>&1
                elif [ -f "../../backend.hcl" ]; then
                    terraform init -backend-config=../../backend.hcl > /dev/null 2>&1
                else
                    terraform init > /dev/null 2>&1
                fi
            fi
            
            # Terraform state list 실행
            if terraform state list > /dev/null 2>&1; then
                resource_count=$(terraform state list | wc -l)
                echo "  ✓ Terraform 상태 리소스: ${resource_count}개"
                
                # Terraform plan 실행하여 drift 확인
                echo "  → Drift 확인 중..."
                if terraform plan -detailed-exitcode -var-file="../../envs/$ENVIRONMENT.tfvars" > /dev/null 2>&1; then
                    case $? in
                        0)
                            layer_status="clean"
                            notes="모든 리소스가 Terraform으로 관리됨"
                            echo "  ✓ 상태 일치 (drift 없음)"
                            ;;
                        1)
                            layer_status="error"
                            notes="Terraform plan 실행 오류"
                            echo "  ❌ Plan 실행 오류"
                            ;;
                        2)
                            layer_status="drift_detected"
                            drift=true
                            notes="상태 불일치 감지됨"
                            ((DRIFT_DETECTED++))
                            echo "  ⚠️  Drift 감지됨"
                            ;;
                    esac
                else
                    layer_status="drift_detected"
                    drift=true
                    notes="상태 불일치 감지됨"
                    ((DRIFT_DETECTED++))
                    echo "  ⚠️  Drift 감지됨"
                fi
            else
                layer_status="state_error"
                notes="Terraform state 읽기 실패"
                echo "  ❌ State 읽기 실패"
            fi
        else
            echo "  → Terraform 초기화 중..."
            # 초기화 시도
            if [ -f "backend.config" ]; then
                terraform init -backend-config=backend.config > /dev/null 2>&1
            elif [ -f "../backend.hcl" ]; then
                terraform init -backend-config=../backend.hcl > /dev/null 2>&1
            elif [ -f "../../backend.hcl" ]; then
                terraform init -backend-config=../../backend.hcl > /dev/null 2>&1
            else
                terraform init > /dev/null 2>&1
            fi
            
            if [ $? -eq 0 ]; then
                echo "  ✓ Terraform 초기화 완료"
                # 초기화 후 state list 실행
                if terraform state list > /dev/null 2>&1; then
                    resource_count=$(terraform state list | wc -l)
                    echo "  ✓ Terraform 상태 리소스: ${resource_count}개"
                    layer_status="clean"
                    notes="초기화 후 상태 확인됨"
                else
                    layer_status="empty_state"
                    notes="초기화되었지만 상태가 비어있음"
                    resource_count=0
                fi
            else
                layer_status="init_failed"
                notes="Terraform 초기화 실패"
                echo "  ❌ Terraform 초기화 실패"
            fi
        fi
        
        cd - > /dev/null
    else
        layer_status="not_found"
        notes="레이어 디렉토리가 존재하지 않음"
        echo "  ❌ 디렉토리 없음"
    fi
    
    # 레이어 결과를 JSON에 추가
    layer_result=$(cat << EOF
{
  "layer": "$layer",
  "status": "$layer_status",
  "drift": $drift,
  "resource_count": $resource_count,
  "notes": "$notes",
  "scan_time": "$(date -Iseconds)"
}
EOF
)
    
    # JSON 배열에 추가
    jq ". += [$layer_result]" "$LAYER_RESULTS_FILE" > "/tmp/layer_results_temp.json"
    mv "/tmp/layer_results_temp.json" "$LAYER_RESULTS_FILE"
    
    ((LAYERS_SCANNED++))
done

echo ""
echo "=== 07-application 레이어 상세 분석 ==="

# 07-application 레이어에서 수동 생성된 리소스 식별
app_layer_path="terraform/layers/07-application"
if [ -d "$app_layer_path" ]; then
    cd "$app_layer_path"
    
    echo "07-application 레이어에서 수동 생성 가능한 리소스 확인 중..."
    
    # 예상되는 수동 리소스들 확인
    manual_resources_file="/tmp/manual_resources.json"
    echo "[]" > "$manual_resources_file"
    
    # 보안 그룹 규칙 확인
    echo "  → Aurora 보안 그룹 규칙 확인..."
    if ! terraform state list | grep -q "aws_security_group_rule.*aurora"; then
        echo "    ⚠️  Aurora 보안 그룹 규칙이 Terraform 상태에 없음"
        ((MANUAL_RESOURCES_FOUND++))
        ((IMPORT_NEEDED++))
        
        manual_resource=$(cat << EOF
{
  "layer": "07-application",
  "type": "aws_security_group_rule",
  "description": "Aurora 보안 그룹의 ECS 접근 규칙",
  "priority": "High",
  "terraform_managed": false
}
EOF
)
        jq ". += [$manual_resource]" "$manual_resources_file" > "/tmp/manual_temp.json"
        mv "/tmp/manual_temp.json" "$manual_resources_file"
    else
        echo "    ✓ Aurora 보안 그룹 규칙이 Terraform으로 관리됨"
    fi
    
    echo "  → ECS 보안 그룹 규칙 확인..."
    if ! terraform state list | grep -q "aws_security_group_rule.*ecs"; then
        echo "    ⚠️  ECS 보안 그룹 규칙이 Terraform 상태에 없음"
        ((MANUAL_RESOURCES_FOUND++))
        ((IMPORT_NEEDED++))
        
        manual_resource=$(cat << EOF
{
  "layer": "07-application",
  "type": "aws_security_group_rule",
  "description": "ECS 보안 그룹의 ALB 접근 규칙",
  "priority": "High",
  "terraform_managed": false
}
EOF
)
        jq ". += [$manual_resource]" "$manual_resources_file" > "/tmp/manual_temp.json"
        mv "/tmp/manual_temp.json" "$manual_resources_file"
    else
        echo "    ✓ ECS 보안 그룹 규칙이 Terraform으로 관리됨"
    fi
    
    echo "  → ECS IAM 역할 확인..."
    if ! terraform state list | grep -q "aws_iam_role.*ecs"; then
        echo "    ⚠️  ECS IAM 역할이 Terraform 상태에 없음"
        ((MANUAL_RESOURCES_FOUND++))
        ((IMPORT_NEEDED++))
        
        manual_resource=$(cat << EOF
{
  "layer": "07-application",
  "type": "aws_iam_role",
  "description": "ECS 태스크 실행 역할",
  "priority": "High",
  "terraform_managed": false
}
EOF
)
        jq ". += [$manual_resource]" "$manual_resources_file" > "/tmp/manual_temp.json"
        mv "/tmp/manual_temp.json" "$manual_resources_file"
    else
        echo "    ✓ ECS IAM 역할이 Terraform으로 관리됨"
    fi
    
    echo "  → EC2 키 페어 확인..."
    if ! terraform state list | grep -q "aws_key_pair"; then
        echo "    ⚠️  EC2 키 페어가 Terraform 상태에 없음"
        ((MANUAL_RESOURCES_FOUND++))
        ((IMPORT_NEEDED++))
        
        manual_resource=$(cat << EOF
{
  "layer": "07-application",
  "type": "aws_key_pair",
  "description": "디버깅용 EC2 키 페어",
  "priority": "Low",
  "terraform_managed": false
}
EOF
)
        jq ". += [$manual_resource]" "$manual_resources_file" > "/tmp/manual_temp.json"
        mv "/tmp/manual_temp.json" "$manual_resources_file"
    else
        echo "    ✓ EC2 키 페어가 Terraform으로 관리됨"
    fi
    
    cd - > /dev/null
fi

echo ""
echo "=== Import 우선순위 결정 ==="

# 우선순위별 분류
if [ -f "$manual_resources_file" ]; then
    high_priority=$(jq '[.[] | select(.priority == "High")] | length' "$manual_resources_file")
    medium_priority=$(jq '[.[] | select(.priority == "Medium")] | length' "$manual_resources_file")
    low_priority=$(jq '[.[] | select(.priority == "Low")] | length' "$manual_resources_file")
    
    echo "높은 우선순위 (보안/네트워크): ${high_priority}개"
    echo "중간 우선순위 (IAM): ${medium_priority}개"
    echo "낮은 우선순위 (기타): ${low_priority}개"
fi

echo ""
echo "=== 스캔 결과 저장 ==="

# 최종 결과 JSON 생성
final_result=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "environment": "$ENVIRONMENT",
  "scan_summary": {
    "total_layers": $TOTAL_LAYERS,
    "layers_scanned": $LAYERS_SCANNED,
    "drift_detected": $DRIFT_DETECTED,
    "manual_resources_found": $MANUAL_RESOURCES_FOUND,
    "import_needed": $IMPORT_NEEDED
  },
  "layer_results": $(cat "$LAYER_RESULTS_FILE"),
  "manual_resources": $([ -f "$manual_resources_file" ] && cat "$manual_resources_file" || echo "[]"),
  "recommendations": [
    "1. 높은 우선순위 리소스부터 Import 시작 (보안 그룹 규칙, IAM 역할)",
    "2. 07-application 레이어 집중 분석 및 Import",
    "3. 각 Import 후 terraform plan으로 상태 검증",
    "4. 디버깅 리소스는 별도 모듈로 분리 고려"
  ]
}
EOF
)

echo "$final_result" > "$OUTPUT_FILE"
echo "스캔 결과가 $OUTPUT_FILE 에 저장되었습니다."

echo ""
echo "=== 스캔 요약 ==="
echo "총 레이어: $TOTAL_LAYERS"
echo "스캔된 레이어: $LAYERS_SCANNED"
echo "Drift 감지된 레이어: $DRIFT_DETECTED"
echo "수동 생성 리소스: $MANUAL_RESOURCES_FOUND"
echo "Import 필요: $IMPORT_NEEDED"

echo ""
echo "=== 다음 단계 ==="
echo "1. $OUTPUT_FILE 파일을 검토하여 상세 결과 확인"
echo "2. 높은 우선순위 리소스부터 Import 계획 수립"
echo "3. 07-application 레이어 집중 분석 및 Import 실행"

echo ""
echo "=== AWS 리소스 상태 스캔 완료 ==="

# 임시 파일 정리
rm -f "$LAYER_RESULTS_FILE" "$manual_resources_file" "/tmp/manual_temp.json" "/tmp/layer_results_temp.json"