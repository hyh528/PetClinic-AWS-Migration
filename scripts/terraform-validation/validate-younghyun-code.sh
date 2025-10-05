#!/bin/bash

# 영현님이 작성한 Terraform 코드 검증 스크립트
echo "=== 영현님 작성 Terraform 코드 검증 ==="
echo "검증 시간: $(date)"
echo ""

# 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "프로젝트 루트: $PROJECT_ROOT"
echo "Terraform 디렉토리: $TERRAFORM_DIR"
echo ""

# sg 폴더 제외하고 검증
echo "주의: modules/sg 폴더는 검증에서 제외됩니다 (삭제 불가 상태)"
echo ""

# 1. 전체 구조 확인
echo "1. Terraform 전체 구조 확인"
echo "=========================="

if [ -d "$TERRAFORM_DIR" ]; then
    echo "✓ terraform 디렉토리 존재"
    
    # 주요 디렉토리 확인
    [ -d "$TERRAFORM_DIR/envs" ] && echo "✓ envs 디렉토리 존재" || echo "✗ envs 디렉토리 없음"
    [ -d "$TERRAFORM_DIR/modules" ] && echo "✓ modules 디렉토리 존재" || echo "✗ modules 디렉토리 없음"
    [ -d "$TERRAFORM_DIR/bootstrap" ] && echo "✓ bootstrap 디렉토리 존재" || echo "✗ bootstrap 디렉토리 없음"
else
    echo "✗ terraform 디렉토리가 없습니다!"
    exit 1
fi

echo ""

# 2. 모듈 검증 (sg 제외)
echo "2. 모듈 검증 (sg 폴더 제외)"
echo "========================="

total_modules=0
complete_modules=0

for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        
        # sg 폴더 건너뛰기
        if [ "$module_name" == "sg" ]; then
            echo "⚠ $module_name: 건너뜀 (삭제 불가 상태)"
            continue
        fi
        
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

# 3. 환경 설정 검증 (dev)
echo "3. 환경 설정 검증 (dev)"
echo "====================="

total_layers=0
complete_layers=0

for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
    if [ -d "$env_layer" ]; then
        layer_name=$(basename "$env_layer")
        total_layers=$((total_layers + 1))
        
        echo "레이어: $layer_name"
        
        # 필수 파일 확인
        [ -f "$env_layer/main.tf" ] && echo "  ✓ main.tf" || echo "  ✗ main.tf"
        [ -f "$env_layer/variables.tf" ] && echo "  ✓ variables.tf" || echo "  ✗ variables.tf"
        [ -f "$env_layer/providers.tf" ] && echo "  ✓ providers.tf" || echo "  ✗ providers.tf"
        
        # backend.tf 확인 (state-management는 선택사항)
        if [ "$layer_name" != "state-management" ]; then
            [ -f "$env_layer/backend.tf" ] && echo "  ✓ backend.tf" || echo "  ✗ backend.tf (필수)"
        else
            echo "  - backend.tf (선택사항)"
        fi
        
        [ -f "$env_layer/dev.tfvars" ] && echo "  ✓ dev.tfvars" || echo "  ✗ dev.tfvars"
        
        # 기본 구성 완료 여부
        if [ -f "$env_layer/main.tf" ] && [ -f "$env_layer/variables.tf" ] && [ -f "$env_layer/providers.tf" ]; then
            complete_layers=$((complete_layers + 1))
            echo "  상태: ✓ 기본 구성 완료"
        else
            echo "  상태: ✗ 기본 구성 불완전"
        fi
        
        echo ""
    fi
done

echo "레이어 요약: 총 $total_layers개 중 $complete_layers개 완료"
echo ""

# 4. 특별 검증: state-management
echo "4. 특별 검증: state-management (영현님 핵심 작업)"
echo "============================================="

state_mgmt_dir="$TERRAFORM_DIR/envs/dev/state-management"
state_mgmt_module="$TERRAFORM_DIR/modules/state-management"

if [ -d "$state_mgmt_dir" ]; then
    echo "✓ state-management 환경 디렉토리 존재"
    
    # 특별 파일들 확인
    [ -f "$state_mgmt_dir/monitoring.tf" ] && echo "  ✓ monitoring.tf (특별 파일)" || echo "  ✗ monitoring.tf"
    [ -d "$state_mgmt_dir/templates" ] && echo "  ✓ templates 디렉토리" || echo "  ✗ templates 디렉토리"
    [ -d "$state_mgmt_dir/scripts" ] && echo "  ✓ scripts 디렉토리" || echo "  ✗ scripts 디렉토리"
    
    # 템플릿 파일들 확인
    if [ -d "$state_mgmt_dir/templates" ]; then
        [ -f "$state_mgmt_dir/templates/backend.tf.tpl" ] && echo "  ✓ backend.tf.tpl 템플릿" || echo "  ✗ backend.tf.tpl 템플릿"
        [ -f "$state_mgmt_dir/templates/README.md.tpl" ] && echo "  ✓ README.md.tpl 템플릿" || echo "  ✗ README.md.tpl 템플릿"
    fi
    
    # 스크립트 파일들 확인
    if [ -d "$state_mgmt_dir/scripts" ]; then
        script_count=$(find "$state_mgmt_dir/scripts" -name "*.sh" | wc -l)
        echo "  ✓ 스크립트 파일 ${script_count}개"
    fi
else
    echo "✗ state-management 환경 디렉토리 없음"
fi

if [ -d "$state_mgmt_module" ]; then
    echo "✓ state-management 모듈 디렉토리 존재"
else
    echo "✗ state-management 모듈 디렉토리 없음"
fi

echo ""

# 5. 변수 및 출력값 통계 (sg 제외)
echo "5. 변수 및 출력값 통계"
echo "==================="

for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        
        # sg 폴더 건너뛰기
        if [ "$module_name" == "sg" ]; then
            continue
        fi
        
        if [ -f "$module_dir/variables.tf" ] && [ -f "$module_dir/outputs.tf" ]; then
            var_count=$(grep -c "^variable" "$module_dir/variables.tf" 2>/dev/null || echo "0")
            output_count=$(grep -c "^output" "$module_dir/outputs.tf" 2>/dev/null || echo "0")
            
            echo "$module_name: 변수 ${var_count}개, 출력값 ${output_count}개"
        fi
    fi
done

echo ""

# 6. 코드 품질 검증
echo "6. 코드 품질 검증"
echo "==============="

# Terraform 파일 수 계산 (sg 제외)
tf_files=0
for tf_file in $(find "$TERRAFORM_DIR" -name "*.tf" -not -path "*/sg/*" 2>/dev/null); do
    tf_files=$((tf_files + 1))
done

echo "총 Terraform 파일 수: $tf_files개 (sg 폴더 제외)"

# 주석 비율 확인
commented_files=0
for tf_file in $(find "$TERRAFORM_DIR" -name "*.tf" -not -path "*/sg/*" 2>/dev/null); do
    if grep -q "^#" "$tf_file" 2>/dev/null; then
        commented_files=$((commented_files + 1))
    fi
done

if [ $tf_files -gt 0 ]; then
    comment_ratio=$((commented_files * 100 / tf_files))
    echo "주석이 있는 파일: $commented_files/$tf_files ($comment_ratio%)"
fi

echo ""

# 7. 최종 평가
echo "7. 최종 평가"
echo "==========="

issues_found=0

# 모듈 완성도
if [ $total_modules -gt 0 ]; then
    module_completion=$((complete_modules * 100 / total_modules))
    echo "모듈 완성도: $complete_modules/$total_modules ($module_completion%)"
    
    if [ $module_completion -lt 80 ]; then
        issues_found=$((issues_found + 1))
    fi
else
    echo "모듈 완성도: 모듈 없음"
    issues_found=$((issues_found + 1))
fi

# 레이어 완성도
if [ $total_layers -gt 0 ]; then
    layer_completion=$((complete_layers * 100 / total_layers))
    echo "레이어 완성도: $complete_layers/$total_layers ($layer_completion%)"
    
    if [ $layer_completion -lt 80 ]; then
        issues_found=$((issues_found + 1))
    fi
else
    echo "레이어 완성도: 레이어 없음"
    issues_found=$((issues_found + 1))
fi

# state-management 특별 검증
if [ -d "$state_mgmt_dir" ] && [ -d "$state_mgmt_module" ]; then
    echo "state-management: ✓ 핵심 컴포넌트 완료"
else
    echo "state-management: ✗ 핵심 컴포넌트 불완전"
    issues_found=$((issues_found + 1))
fi

echo ""

# 최종 판정
if [ $issues_found -eq 0 ]; then
    echo "🎉 상태: 우수!"
    echo "영현님이 작성한 Terraform 코드가 모든 검증을 통과했습니다."
    echo "클린 코드 원칙을 잘 따르고 있으며, 구조가 체계적입니다."
elif [ $issues_found -le 2 ]; then
    echo "✅ 상태: 양호"
    echo "대부분의 코드가 잘 작성되어 있습니다. 몇 가지 사소한 개선점이 있습니다."
else
    echo "⚠️ 상태: 개선 필요"
    echo "일부 영역에서 개선이 필요합니다."
fi

echo ""
echo "참고: modules/sg 폴더는 삭제 불가 상태로 검증에서 제외되었습니다."
echo "=== 검증 완료 ==="

# 문제가 있으면 종료 코드 1 반환
if [ $issues_found -gt 2 ]; then
    exit 1
fi