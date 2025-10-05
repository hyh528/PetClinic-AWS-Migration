#!/bin/bash

# 간단한 Terraform 모듈 검증 스크립트
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 전역 변수
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
RESULTS_DIR="$PROJECT_ROOT/terraform-validation-results"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# 결과 저장
mkdir -p "$RESULTS_DIR"
REPORT_FILE="$RESULTS_DIR/simple-validation-$TIMESTAMP.txt"

# 리포트 초기화
cat > "$REPORT_FILE" << EOF
=== Terraform 모듈 간단 검증 리포트 ===
검증 시간: $(date)
프로젝트: Spring PetClinic AWS Migration

EOF

log_info "=== Terraform 모듈 간단 검증 시작 ==="

# 1. 모듈 구조 검증
log_info "1. 모듈 구조 검증 중..."
echo "1. 모듈 구조 검증 결과:" >> "$REPORT_FILE"

total_modules=0
complete_modules=0
incomplete_modules=0

for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [[ -d "$module_dir" ]]; then
        module_name=$(basename "$module_dir")
        ((total_modules++))
        
        # 필수 파일 확인
        main_tf=false
        variables_tf=false
        outputs_tf=false
        
        [[ -f "$module_dir/main.tf" ]] && main_tf=true
        [[ -f "$module_dir/variables.tf" ]] && variables_tf=true
        [[ -f "$module_dir/outputs.tf" ]] && outputs_tf=true
        
        if [[ $main_tf == true && $variables_tf == true && $outputs_tf == true ]]; then
            log_success "모듈 $module_name: 완전함"
            echo "  ✓ $module_name: 완전함 (main.tf, variables.tf, outputs.tf 모두 존재)" >> "$REPORT_FILE"
            ((complete_modules++))
        else
            log_warning "모듈 $module_name: 불완전함"
            echo "  ⚠ $module_name: 불완전함" >> "$REPORT_FILE"
            [[ $main_tf == false ]] && echo "    - main.tf 누락" >> "$REPORT_FILE"
            [[ $variables_tf == false ]] && echo "    - variables.tf 누락" >> "$REPORT_FILE"
            [[ $outputs_tf == false ]] && echo "    - outputs.tf 누락" >> "$REPORT_FILE"
            ((incomplete_modules++))
        fi
    fi
done

echo "" >> "$REPORT_FILE"
echo "모듈 요약: 총 $total_modules개, 완전 $complete_modules개, 불완전 $incomplete_modules개" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 2. 환경 설정 검증
log_info "2. 환경 설정 검증 중..."
echo "2. 환경 설정 검증 결과:" >> "$REPORT_FILE"

total_layers=0
complete_layers=0

for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
    if [[ -d "$env_layer" ]]; then
        layer_name=$(basename "$env_layer")
        ((total_layers++))
        
        # 필수 파일 확인
        main_tf=false
        variables_tf=false
        providers_tf=false
        backend_tf=false
        tfvars=false
        
        [[ -f "$env_layer/main.tf" ]] && main_tf=true
        [[ -f "$env_layer/variables.tf" ]] && variables_tf=true
        [[ -f "$env_layer/providers.tf" ]] && providers_tf=true
        [[ -f "$env_layer/backend.tf" ]] && backend_tf=true
        [[ -f "$env_layer/dev.tfvars" ]] && tfvars=true
        
        echo "  레이어: $layer_name" >> "$REPORT_FILE"
        [[ $main_tf == true ]] && echo "    ✓ main.tf" >> "$REPORT_FILE" || echo "    ✗ main.tf" >> "$REPORT_FILE"
        [[ $variables_tf == true ]] && echo "    ✓ variables.tf" >> "$REPORT_FILE" || echo "    ✗ variables.tf" >> "$REPORT_FILE"
        [[ $providers_tf == true ]] && echo "    ✓ providers.tf" >> "$REPORT_FILE" || echo "    ✗ providers.tf" >> "$REPORT_FILE"
        
        # backend.tf는 일부 레이어에서 선택사항
        if [[ "$layer_name" != "state-management" && "$layer_name" != "aws-native" && "$layer_name" != "monitoring" ]]; then
            [[ $backend_tf == true ]] && echo "    ✓ backend.tf" >> "$REPORT_FILE" || echo "    ✗ backend.tf (필수)" >> "$REPORT_FILE"
        else
            echo "    - backend.tf (선택사항)" >> "$REPORT_FILE"
        fi
        
        [[ $tfvars == true ]] && echo "    ✓ dev.tfvars" >> "$REPORT_FILE" || echo "    ✗ dev.tfvars" >> "$REPORT_FILE"
        
        if [[ $main_tf == true && $variables_tf == true && $providers_tf == true ]]; then
            log_success "레이어 $layer_name: 기본 구성 완료"
            ((complete_layers++))
        else
            log_warning "레이어 $layer_name: 기본 구성 불완전"
        fi
        
        echo "" >> "$REPORT_FILE"
    fi
done

echo "레이어 요약: 총 $total_layers개, 기본 구성 완료 $complete_layers개" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 3. 변수 및 출력값 통계
log_info "3. 변수 및 출력값 통계 생성 중..."
echo "3. 변수 및 출력값 통계:" >> "$REPORT_FILE"

for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [[ -d "$module_dir" && -f "$module_dir/variables.tf" && -f "$module_dir/outputs.tf" ]]; then
        module_name=$(basename "$module_dir")
        
        var_count=$(grep -c "^variable" "$module_dir/variables.tf" 2>/dev/null || echo "0")
        output_count=$(grep -c "^output" "$module_dir/outputs.tf" 2>/dev/null || echo "0")
        
        echo "  $module_name: 변수 ${var_count}개, 출력값 ${output_count}개" >> "$REPORT_FILE"
    fi
done

echo "" >> "$REPORT_FILE"

# 4. 태그 사용 현황
log_info "4. 태그 사용 현황 확인 중..."
echo "4. 태그 사용 현황:" >> "$REPORT_FILE"

for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
    if [[ -d "$env_layer" && -f "$env_layer/main.tf" ]]; then
        layer_name=$(basename "$env_layer")
        
        # 태그 관련 키워드 검색
        tag_usage=$(grep -c "tags\|Tag" "$env_layer/main.tf" 2>/dev/null || echo "0")
        
        if [[ $tag_usage -gt 0 ]]; then
            echo "  ✓ $layer_name: 태그 사용 중 (${tag_usage}개 참조)" >> "$REPORT_FILE"
        else
            echo "  ✗ $layer_name: 태그 사용 없음" >> "$REPORT_FILE"
        fi
    fi
done

echo "" >> "$REPORT_FILE"

# 5. 최종 요약
echo "=== 최종 요약 ===" >> "$REPORT_FILE"
echo "모듈 완성도: $complete_modules/$total_modules ($(( complete_modules * 100 / total_modules ))%)" >> "$REPORT_FILE"
echo "레이어 완성도: $complete_layers/$total_layers ($(( complete_layers * 100 / total_layers ))%)" >> "$REPORT_FILE"

if [[ $incomplete_modules -eq 0 ]]; then
    echo "상태: 모든 모듈이 완전함 ✓" >> "$REPORT_FILE"
    log_success "모든 모듈이 완전합니다!"
else
    echo "상태: $incomplete_modules개 모듈이 불완전함 ⚠" >> "$REPORT_FILE"
    log_warning "$incomplete_modules개 모듈이 불완전합니다."
fi

echo "" >> "$REPORT_FILE"
echo "상세 리포트 위치: $REPORT_FILE" >> "$REPORT_FILE"

log_success "검증 완료! 리포트: $REPORT_FILE"
log_info "=== 검증 완료 ==="

# 리포트 내용 출력
echo ""
echo "=== 검증 결과 요약 ==="
tail -n 10 "$REPORT_FILE"