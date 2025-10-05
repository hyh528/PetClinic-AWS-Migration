#!/bin/bash

# Terraform 코드 검증 스크립트
echo "=== Terraform 코드 검증 시작 ==="
echo "검증 시간: $(date)"
echo ""

# 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "프로젝트 루트: $PROJECT_ROOT"
echo "Terraform 디렉토리: $TERRAFORM_DIR"
echo ""

# 1. 모듈 구조 검증
echo "1. 모듈 구조 검증"
echo "=================="

total_modules=0
complete_modules=0

for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        total_modules=$((total_modules + 1))
        
        echo -n "모듈 $module_name: "
        
        # 필수 파일 확인
        if [ -f "$module_dir/main.tf" ] && [ -f "$module_dir/variables.tf" ] && [ -f "$module_dir/outputs.tf" ]; then
            echo "✓ 완전함"
            complete_modules=$((complete_modules + 1))
        else
            echo "✗ 불완전함"
            [ ! -f "$module_dir/main.tf" ] && echo "  - main.tf 누락"
            [ ! -f "$module_dir/variables.tf" ] && echo "  - variables.tf 누락"
            [ ! -f "$module_dir/outputs.tf" ] && echo "  - outputs.tf 누락"
        fi
    fi
done

echo ""
echo "모듈 요약: 총 $total_modules개 중 $complete_modules개 완전함"
echo ""

# 2. 환경 설정 검증
echo "2. 환경 설정 검증 (dev)"
echo "====================="

total_layers=0
complete_layers=0

for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
    if [ -d "$env_layer" ]; then
        layer_name=$(basename "$env_layer")
        total_layers=$((total_layers + 1))
        
        echo "레이어 $layer_name:"
        
        # 필수 파일 확인
        [ -f "$env_layer/main.tf" ] && echo "  ✓ main.tf" || echo "  ✗ main.tf"
        [ -f "$env_layer/variables.tf" ] && echo "  ✓ variables.tf" || echo "  ✗ variables.tf"
        [ -f "$env_layer/providers.tf" ] && echo "  ✓ providers.tf" || echo "  ✗ providers.tf"
        
        # backend.tf (일부 레이어는 선택사항)
        if [ "$layer_name" != "state-management" ] && [ "$layer_name" != "aws-native" ] && [ "$layer_name" != "monitoring" ]; then
            [ -f "$env_layer/backend.tf" ] && echo "  ✓ backend.tf" || echo "  ✗ backend.tf (필수)"
        else
            echo "  - backend.tf (선택사항)"
        fi
        
        [ -f "$env_layer/dev.tfvars" ] && echo "  ✓ dev.tfvars" || echo "  ✗ dev.tfvars"
        
        # 기본 구성 완료 여부
        if [ -f "$env_layer/main.tf" ] && [ -f "$env_layer/variables.tf" ] && [ -f "$env_layer/providers.tf" ]; then
            complete_layers=$((complete_layers + 1))
        fi
        
        echo ""
    fi
done

echo "레이어 요약: 총 $total_layers개 중 $complete_layers개 기본 구성 완료"
echo ""

# 3. 변수 및 출력값 통계
echo "3. 변수 및 출력값 통계"
echo "==================="

for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [ -d "$module_dir" ] && [ -f "$module_dir/variables.tf" ] && [ -f "$module_dir/outputs.tf" ]; then
        module_name=$(basename "$module_dir")
        
        var_count=$(grep -c "^variable" "$module_dir/variables.tf" 2>/dev/null || echo "0")
        output_count=$(grep -c "^output" "$module_dir/outputs.tf" 2>/dev/null || echo "0")
        
        echo "$module_name: 변수 ${var_count}개, 출력값 ${output_count}개"
    fi
done

echo ""

# 4. 최종 평가
echo "4. 최종 평가"
echo "==========="

module_completion=$((complete_modules * 100 / total_modules))
layer_completion=$((complete_layers * 100 / total_layers))

echo "모듈 완성도: $complete_modules/$total_modules ($module_completion%)"
echo "레이어 완성도: $complete_layers/$total_layers ($layer_completion%)"

if [ $module_completion -ge 80 ] && [ $layer_completion -ge 80 ]; then
    echo "상태: 양호 ✓"
    echo "대부분의 모듈과 레이어가 올바르게 구성되어 있습니다."
elif [ $module_completion -ge 60 ] && [ $layer_completion -ge 60 ]; then
    echo "상태: 보통 ⚠"
    echo "일부 개선이 필요합니다."
else
    echo "상태: 개선 필요 ✗"
    echo "많은 모듈과 레이어에 문제가 있습니다."
fi

echo ""
echo "=== 검증 완료 ==="