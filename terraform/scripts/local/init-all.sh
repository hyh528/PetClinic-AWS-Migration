#!/bin/bash

# =============================================================================
# Terraform 모든 레이어 초기화 스크립트
# =============================================================================
# 목적: 모든 레이어를 순서대로 초기화하여 plan/apply 준비
# 작성자: AWS 네이티브 마이그레이션 팀
# 버전: 2.0.0

set -euo pipefail

# =============================================================================
# 설정 변수
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ENVIRONMENT="${1:-dev}"
readonly LAYERS_DIR="$PROJECT_ROOT/layers"

# 색상 정의
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# =============================================================================
# 로깅 함수
# =============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
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

# =============================================================================
# 레이어 실행 순서 정의
# =============================================================================

readonly LAYERS=(
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

# =============================================================================
# 사전 요구사항 검증 함수
# =============================================================================

check_prerequisites() {
    log "사전 요구사항 확인 중..."
    
    # Terraform 설치 확인
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform이 설치되지 않았거나 PATH에 없습니다"
        log_error "Terraform을 설치하고 PATH에 추가한 후 다시 시도하세요"
        log_error "설치 가이드: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        return 1
    fi
    
    # Terraform 버전 확인
    local tf_version
    tf_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | cut -d' ' -f2 | sed 's/v//')
    log "Terraform 버전: $tf_version"
    
    # AWS CLI 설치 확인 (선택적)
    if command -v aws &> /dev/null; then
        log "AWS CLI 발견: $(aws --version 2>&1 | head -1)"
    else
        log_warning "AWS CLI가 설치되지 않았습니다 (선택적)"
    fi
    
    log_success "사전 요구사항 확인 완료"
    return 0
}

# =============================================================================
# 초기화 함수
# =============================================================================

init_layer() {
    local layer=$1
    local layer_dir="$LAYERS_DIR/$layer"
    
    if [[ ! -d "$layer_dir" ]]; then
        log_warning "레이어 디렉터리가 존재하지 않습니다: $layer (건너뜀)"
        return 0
    fi
    
    log "초기화 중: $layer"
    
    cd "$layer_dir"
    
    # 기존 .terraform 디렉터리가 있으면 백업
    if [[ -d ".terraform" ]]; then
        log_warning "기존 .terraform 디렉터리 발견, 백업 중..."
        mv .terraform ".terraform.backup.$(date +%Y%m%d_%H%M%S)" || true
    fi
    
    # Terraform 초기화
    if terraform init -upgrade -input=false; then
        log_success "$layer 초기화 완료"
        return 0
    else
        log_error "$layer 초기화 실패"
        return 1
    fi
}

# =============================================================================
# 메인 실행 함수
# =============================================================================

init_all_layers() {
    local failed_layers=()
    local success_layers=()
    
    log "전체 레이어 초기화 시작 - 환경: $ENVIRONMENT"
    log "초기화할 레이어 수: ${#LAYERS[@]}"
    
    for layer in "${LAYERS[@]}"; do
        if init_layer "$layer"; then
            success_layers+=("$layer")
        else
            failed_layers+=("$layer")
        fi
    done
    
    # 결과 요약
    log "=========================================="
    log "초기화 결과 요약"
    log "=========================================="
    log "성공한 레이어: ${#success_layers[@]}"
    for layer in "${success_layers[@]}"; do
        log_success "  ✓ $layer"
    done
    
    if [[ ${#failed_layers[@]} -gt 0 ]]; then
        log "실패한 레이어: ${#failed_layers[@]}"
        for layer in "${failed_layers[@]}"; do
            log_error "  ✗ $layer"
        done
        return 1
    else
        log_success "모든 레이어 초기화 성공!"
        log "다음 단계: ./scripts/plan-all.sh $ENVIRONMENT"
        return 0
    fi
}

# =============================================================================
# 사용법 및 메인 실행
# =============================================================================

show_usage() {
    cat << EOF
사용법: $0 [ENVIRONMENT]

모든 Terraform 레이어를 순서대로 초기화합니다.

ENVIRONMENT:
    dev      개발 환경 (기본값)
    staging  스테이징 환경
    prod     프로덕션 환경

예시:
    $0           # dev 환경 초기화
    $0 dev       # dev 환경 초기화
    $0 staging   # staging 환경 초기화

초기화 순서:
EOF
    
    for i in "${!LAYERS[@]}"; do
        local layer="${LAYERS[$i]}"
        printf "  %d. %s\n" $((i+1)) "$layer"
    done
}

main() {
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    log "Terraform 레이어 초기화 스크립트 시작"
    log "환경: $ENVIRONMENT"
    
    # 사전 요구사항 확인 (실패 시 즉시 중단)
    if ! check_prerequisites; then
        log_error "사전 요구사항 확인 실패 - 스크립트 중단"
        exit 1
    fi
    
    # 레이어 디렉터리 존재 확인
    if [[ ! -d "$LAYERS_DIR" ]]; then
        log_error "레이어 디렉터리가 존재하지 않습니다: $LAYERS_DIR"
        exit 1
    fi
    
    # 초기화 실행
    if init_all_layers; then
        log_success "전체 초기화 완료"
        exit 0
    else
        log_error "초기화 실패"
        exit 1
    fi
}

main "$@"