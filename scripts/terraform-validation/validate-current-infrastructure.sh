#!/bin/bash

# 현재 사용 중인 Terraform 인프라 검증 스크립트
echo "=== 현재 사용 중인 Terraform 인프라 검증 ==="
echo "검증 시간: $(date)"
echo ""

# 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# 현재 사용 중인 레이어 (README.md 기준)
ACTIVE_LAYERS=("network" "security" "database" "application" "aws-native" "monitoring")

# 현재 사용 중인 모듈들 (실제 레이어에서 참조되는 것들)
ACTIVE_MODULES=("vpc" "security" "database" "alb" "ecs" "ecr" "iam" "endpoints" "cloudwatch" "cloudtrail" "api-gateway" "parameter-store" "cloud-map" "lambda-genai")

echo "현재 사용 중인 레이어: ${ACTIVE_LAYERS[*]}"
echo "현재 사용 중인 모듈: ${ACTIVE_MODULES[*]}"
echo ""

# 1. 현재 사용 중인 레이어 검증
echo "1. 현재 사용 중인 레이어 검증"
echo "=============================="

total_layers=0
complete_layers=0
issues_found=0

for layer in "${ACTIVE_LAYERS[@]}"; do
    layer_path="$TERRAFORM_DIR/envs/dev/$layer"
    
    if [ -d "$layer_path" ]; then
        total_layers=$((total_layers + 1))
        echo "레이어: $layer"
        
        # 필수 파일 확인
        main_tf=false
        variables_tf=false
        providers_tf=false
        
        [ -f "$layer_path/main.tf" ] && main_tf=true
        [ -f "$layer_path/variables.tf" ] && variables_tf=true
        [ -f "$layer_path/providers.tf" ] && providers_tf=true
        
        # 파일 상태 출력
        [ $main_tf == true ] && echo "  ✓ main.tf" || { echo "  ✗ main.tf"; issues_found=$((issues_found + 1)); }
        [ $variables_tf == true ] && echo "  ✓ variables.tf" || { echo "  ✗ variables.tf"; issues_found=$((issues_found + 1)); }
        [ $providers_tf == true ] && echo "  ✓ providers.tf" || { echo "  ✗ providers.tf"; issues_found=$((issues_found + 1)); }
        
        # backend.tf 확인 (state-management, aws-native, monitoring은 선택사항)
        if [ "$layer" != "aws-native" ] && [ "$layer" != "monitoring" ]; then
            if [ -f "$layer_path/backend.tf" ]; then
                echo "  ✓ backend.tf"
            else
                echo "  ✗ backend.tf (필수)"
                issues_found=$((issues_found + 1))
            fi
        else
            echo "  - backend.tf (선택사항)"
        fi
        
        # tfvars 확인
        if [ -f "$layer_path/dev.tfvars" ]; then
            echo "  ✓ dev.tfvars"
        else
            echo "  ✗ dev.tfvars"
            issues_found=$((issues_found + 1))
        fi
        
        # 기본 구성 완료 여부
        if [ $main_tf == true ] && [ $variables_tf == true ] && [ $providers_tf == true ]; then
            complete_layers=$((complete_layers + 1))
            echo "  상태: ✓ 기본 구성 완료"
        else
            echo "  상태: ✗ 기본 구성 불완전"
        fi
        
        echo ""
    else
        echo "레이어 $layer: ✗ 디렉토리 없음"
        issues_found=$((issues_found + 1))
        echo ""
    fi
done

echo "레이어 요약: 총 $total_layers개 중 $complete_layers개 완료"
echo ""

# 2. 현재 사용 중인 모듈 검증
echo "2. 현재 사용 중인 모듈 검증"
echo "=========================="

total_modules=0
complete_modules=0

for module in "${ACTIVE_MODULES[@]}"; do
    module_path="$TERRAFORM_DIR/modules/$module"
    
    if [ -d "$module_path" ]; then
        total_modules=$((total_modules + 1))
        echo -n "모듈 $module: "
        
        # 필수 파일 확인
        if [ -f "$module_path/main.tf" ] && [ -f "$module_path/variables.tf" ] && [ -f "$module_path/outputs.tf" ]; then
            echo "✓ 완전함"
            complete_modules=$((complete_modules + 1))
        else
            echo "✗ 불완전함"
            [ ! -f "$module_path/main.tf" ] && echo "  - main.tf 누락"
            [ ! -f "$module_path/variables.tf" ] && echo "  - variables.tf 누락"
            [ ! -f "$module_path/outputs.tf" ] && echo "  - outputs.tf 누락"
            issues_found=$((issues_found + 1))
        fi
    else
        echo "모듈 $module: ✗ 디렉토리 없음"
        issues_found=$((issues_found + 1))
    fi
done

echo ""
echo "모듈 요약: 총 $total_modules개 중 $complete_modules개 완전함"
echo ""

# 3. 레이어 간 의존성 검증
echo "3. 레이어 간 의존성 검증"
echo "======================"

# 각 레이어의 main.tf에서 data 소스 참조 확인
for layer in "${ACTIVE_LAYERS[@]}"; do
    layer_path="$TERRAFORM_DIR/envs/dev/$layer"
    
    if [ -f "$layer_path/main.tf" ]; then
        echo "레이어 $layer 의존성:"
        
        # data 소스 참조 확인
        data_refs=$(grep -c "data\.terraform_remote_state\." "$layer_path/main.tf" 2>/dev/null || echo "0")
        module_refs=$(grep -c "module\." "$layer_path/main.tf" 2>/dev/null || echo "0")
        
        echo "  - 원격 상태 참조: ${data_refs}개"
        echo "  - 모듈 참조: ${module_refs}개"
        
        # 특정 의존성 패턴 확인
        if grep -q "terraform_remote_state.*network" "$layer_path/main.tf" 2>/dev/null; then
            echo "  ✓ network 레이어 의존성"
        fi
        
        if grep -q "terraform_remote_state.*security" "$layer_path/main.tf" 2>/dev/null; then
            echo "  ✓ security 레이어 의존성"
        fi
        
        echo ""
    fi
done

# 4. 변수 및 출력값 통계
echo "4. 변수 및 출력값 통계 (현재 사용 모듈)"
echo "=================================="

for module in "${ACTIVE_MODULES[@]}"; do
    module_path="$TERRAFORM_DIR/modules/$module"
    
    if [ -d "$module_path" ] && [ -f "$module_path/variables.tf" ] && [ -f "$module_path/outputs.tf" ]; then
        var_count=$(grep -c "^variable" "$module_path/variables.tf" 2>/dev/null || echo "0")
        output_count=$(grep -c "^output" "$module_path/outputs.tf" 2>/dev/null || echo "0")
        
        echo "$module: 변수 ${var_count}개, 출력값 ${output_count}개"
    fi
done

echo ""

# 5. 레거시 코드 정리 권장사항
echo "5. 레거시 코드 정리 권장사항"
echo "========================"

echo "사용하지 않는 레이어들:"
for layer_dir in "$TERRAFORM_DIR/envs/dev"/*; do
    if [ -d "$layer_dir" ]; then
        layer_name=$(basename "$layer_dir")
        
        # 현재 사용 중인 레이어가 아닌 경우
        is_active=false
        for active_layer in "${ACTIVE_LAYERS[@]}"; do
            if [ "$layer_name" == "$active_layer" ]; then
                is_active=true
                break
            fi
        done
        
        if [ $is_active == false ]; then
            echo "  ⚠ $layer_name (정리 권장)"
        fi
    fi
done

echo ""
echo "사용하지 않는 모듈들:"
for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        
        # 현재 사용 중인 모듈이 아닌 경우
        is_active=false
        for active_module in "${ACTIVE_MODULES[@]}"; do
            if [ "$module_name" == "$active_module" ]; then
                is_active=true
                break
            fi
        done
        
        if [ $is_active == false ]; then
            echo "  ⚠ $module_name (정리 권장)"
        fi
    fi
done

echo ""

# 6. 최종 평가
echo "6. 최종 평가"
echo "==========="

layer_completion=$((complete_layers * 100 / total_layers))
module_completion=$((complete_modules * 100 / total_modules))

echo "현재 사용 레이어 완성도: $complete_layers/$total_layers ($layer_completion%)"
echo "현재 사용 모듈 완성도: $complete_modules/$total_modules ($module_completion%)"
echo "발견된 문제: $issues_found개"

if [ $issues_found -eq 0 ]; then
    echo "상태: 우수 ✓"
    echo "현재 사용 중인 모든 인프라가 올바르게 구성되어 있습니다."
elif [ $issues_found -le 3 ]; then
    echo "상태: 양호 ⚠"
    echo "몇 가지 사소한 문제가 있지만 전반적으로 양호합니다."
else
    echo "상태: 개선 필요 ✗"
    echo "여러 문제가 발견되었습니다. 수정이 필요합니다."
fi

echo ""
echo "=== 검증 완료 ==="

# 문제가 있으면 종료 코드 1 반환
if [ $issues_found -gt 0 ]; then
    exit 1
fi