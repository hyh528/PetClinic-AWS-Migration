#!/bin/bash

# Terraform 정적 분석 실행 스크립트
# 이 스크립트는 정적 분석 도구들을 쉽게 실행할 수 있도록 도와줍니다.

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

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

# 사용법 출력
show_usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -h, --help          이 도움말 표시"
    echo "  -d, --dir DIR       Terraform 디렉토리 지정 (기본값: $TERRAFORM_DIR)"
    echo "  -f, --format-only   포맷팅만 실행"
    echo "  -v, --validate-only 검증만 실행"
    echo "  -l, --lint-only     TFLint만 실행"
    echo "  -s, --security-only Checkov 보안 검사만 실행"
    echo "  --fix               자동 수정 가능한 문제들 수정"
    echo "  --skip-init         Terraform init 건너뛰기"
    echo ""
    echo "예시:"
    echo "  $0                          # 모든 검사 실행"
    echo "  $0 --format-only            # 포맷팅만 실행"
    echo "  $0 --fix                    # 자동 수정과 함께 실행"
    echo "  $0 -d /path/to/terraform    # 특정 디렉토리에서 실행"
}

# 기본값 설정
FORMAT_ONLY=false
VALIDATE_ONLY=false
LINT_ONLY=false
SECURITY_ONLY=false
AUTO_FIX=false
SKIP_INIT=false

# 명령행 인수 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d|--dir)
            TERRAFORM_DIR="$2"
            shift 2
            ;;
        -f|--format-only)
            FORMAT_ONLY=true
            shift
            ;;
        -v|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -l|--lint-only)
            LINT_ONLY=true
            shift
            ;;
        -s|--security-only)
            SECURITY_ONLY=true
            shift
            ;;
        --fix)
            AUTO_FIX=true
            shift
            ;;
        --skip-init)
            SKIP_INIT=true
            shift
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Terraform 디렉토리로 이동
cd "$TERRAFORM_DIR"

log_info "Terraform 정적 분석을 시작합니다: $(pwd)"
echo ""

# 정적 분석 스크립트 실행
if [[ "$FORMAT_ONLY" == "true" ]]; then
    log_info "포맷팅만 실행합니다..."
    if [[ "$AUTO_FIX" == "true" ]]; then
        terraform fmt -recursive
        log_success "Terraform 포맷팅 완료"
    else
        terraform fmt -check -recursive -diff
    fi
elif [[ "$VALIDATE_ONLY" == "true" ]]; then
    log_info "검증만 실행합니다..."
    if [[ "$SKIP_INIT" == "false" ]]; then
        ./scripts/static-analysis.sh
    else
        ./scripts/static-analysis.sh --skip-init
    fi
elif [[ "$LINT_ONLY" == "true" ]]; then
    log_info "TFLint만 실행합니다..."
    tflint --init
    tflint --recursive --format=compact
elif [[ "$SECURITY_ONLY" == "true" ]]; then
    log_info "보안 검사만 실행합니다..."
    checkov -d . --framework terraform --output cli --output json --output-file-path console,checkov-report.json
else
    # 전체 정적 분석 실행
    if [[ -f "./scripts/static-analysis.sh" ]]; then
        chmod +x ./scripts/static-analysis.sh
        if [[ "$SKIP_INIT" == "true" ]]; then
            ./scripts/static-analysis.sh --skip-init
        else
            ./scripts/static-analysis.sh
        fi
    else
        log_error "정적 분석 스크립트를 찾을 수 없습니다: ./scripts/static-analysis.sh"
        exit 1
    fi
fi

echo ""
log_success "정적 분석 실행 완료!"