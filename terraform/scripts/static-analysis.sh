#!/bin/bash

# Terraform 정적 분석 도구 통합 스크립트
# 이 스크립트는 terraform fmt, validate, tflint, checkov를 순차적으로 실행합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 도구 설치 확인 함수
check_tool() {
    local tool=$1
    local install_cmd=$2
    
    # checkov의 경우 pipx로 설치된 경로도 확인
    if [[ "$tool" == "checkov" ]]; then
        if command -v "$tool" &> /dev/null || [[ -f "$HOME/.local/bin/checkov" ]]; then
            return 0
        fi
    elif ! command -v "$tool" &> /dev/null; then
        log_warning "$tool이 설치되지 않았습니다."
        log_info "설치 명령어: $install_cmd"
        return 1
    fi
    return 0
}

# 필수 도구 확인
log_info "필수 도구 설치 상태 확인 중..."

check_tool "terraform" "https://www.terraform.io/downloads.html"
check_tool "tflint" "curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
check_tool "checkov" "pip install checkov"

# 작업 디렉토리 설정
TERRAFORM_DIR="${1:-$(pwd)}"
cd "$TERRAFORM_DIR"

log_info "Terraform 정적 분석을 시작합니다: $TERRAFORM_DIR"

# 결과 저장 변수
ERRORS=0
WARNINGS=0

# 1. Terraform Format 검사
log_info "1. Terraform Format 검사 실행 중..."
if terraform fmt -check -recursive -diff; then
    log_success "Terraform Format 검사 통과"
else
    log_error "Terraform Format 검사 실패"
    log_info "자동 수정을 위해 'terraform fmt -recursive' 실행을 권장합니다"
    ((ERRORS++))
fi

echo ""

# 2. Terraform Validate 검사
log_info "2. Terraform Validate 검사 실행 중..."

# 모든 레이어에서 validate 실행
validate_errors=0
for layer_dir in layers/*/; do
    if [ -d "$layer_dir" ]; then
        layer_name=$(basename "$layer_dir")
        log_info "  레이어 검증 중: $layer_name"
        
        cd "$layer_dir"
        
        # terraform init이 필요한지 확인
        if [ ! -d ".terraform" ] || [ ! -d ".terraform/providers" ]; then
            log_info "    Terraform 초기화 중..."
            if ! terraform init -backend=false > /dev/null 2>&1; then
                log_error "    $layer_name 초기화 실패"
                ((validate_errors++))
                cd - > /dev/null
                continue
            fi
        fi
        
        # validate 실행
        if terraform validate > /dev/null 2>&1; then
            log_success "    $layer_name 검증 통과"
        else
            log_error "    $layer_name 검증 실패"
            terraform validate
            ((validate_errors++))
        fi
        
        cd - > /dev/null
    fi
done

if [ $validate_errors -eq 0 ]; then
    log_success "Terraform Validate 검사 통과"
else
    log_error "Terraform Validate 검사 실패 ($validate_errors개 레이어)"
    ((ERRORS++))
fi

echo ""

# 3. TFLint 검사
log_info "3. TFLint 검사 실행 중..."

# .tflint.hcl 설정 파일이 있는지 확인
if [ ! -f ".tflint.hcl" ]; then
    log_warning ".tflint.hcl 설정 파일이 없습니다. 기본 설정으로 실행합니다."
fi

# TFLint 초기화
if tflint --init > /dev/null 2>&1; then
    log_info "TFLint 초기화 완료"
else
    log_warning "TFLint 초기화 실패, 기본 설정으로 계속 진행"
fi

# TFLint 실행
if tflint --recursive --format=compact; then
    log_success "TFLint 검사 통과"
else
    log_warning "TFLint에서 경고 또는 오류가 발견되었습니다"
    ((WARNINGS++))
fi

echo ""

# 4. Checkov 보안 검사
log_info "4. Checkov 보안 검사 실행 중..."

# Checkov 실행 (pipx 설치 경로도 확인)
CHECKOV_CMD="checkov"
if [[ -f "$HOME/.local/bin/checkov" ]]; then
    CHECKOV_CMD="$HOME/.local/bin/checkov"
fi

checkov_output=$(mktemp)
if $CHECKOV_CMD -d . --framework terraform --output cli --output json --output-file-path console,checkov-report.json 2>&1 | tee "$checkov_output"; then
    log_success "Checkov 보안 검사 완료"
    
    # 결과 요약 출력
    if [ -f "checkov-report.json" ]; then
        log_info "보안 검사 결과가 checkov-report.json에 저장되었습니다"
        
        # JSON에서 통계 추출 (jq가 있는 경우)
        if command -v jq &> /dev/null; then
            passed=$(jq '.summary.passed' checkov-report.json 2>/dev/null || echo "N/A")
            failed=$(jq '.summary.failed' checkov-report.json 2>/dev/null || echo "N/A")
            skipped=$(jq '.summary.skipped' checkov-report.json 2>/dev/null || echo "N/A")
            
            log_info "  통과: $passed, 실패: $failed, 건너뜀: $skipped"
            
            if [ "$failed" != "0" ] && [ "$failed" != "N/A" ]; then
                log_warning "보안 검사에서 $failed개의 문제가 발견되었습니다"
                ((WARNINGS++))
            fi
        fi
    fi
else
    log_error "Checkov 보안 검사 중 오류 발생"
    ((ERRORS++))
fi

rm -f "$checkov_output"

echo ""

# 5. 결과 요약
log_info "=== 정적 분석 결과 요약 ==="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_success "모든 정적 분석 검사가 성공적으로 완료되었습니다! ✅"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    log_warning "정적 분석이 완료되었지만 $WARNINGS개의 경고가 있습니다 ⚠️"
    exit 0
else
    log_error "정적 분석에서 $ERRORS개의 오류와 $WARNINGS개의 경고가 발견되었습니다 ❌"
    echo ""
    log_info "다음 단계를 권장합니다:"
    log_info "1. terraform fmt -recursive (포맷 수정)"
    log_info "2. terraform validate 오류 수정"
    log_info "3. TFLint 권장사항 검토"
    log_info "4. Checkov 보안 이슈 해결"
    exit 1
fi