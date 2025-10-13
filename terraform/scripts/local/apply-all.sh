#!/bin/bash

# =============================================================================
# Terraform Apply All Layers (의존성 고려)
# =============================================================================
# 목적: 모든 레이어를 의존성 순서대로 apply 실행
# 특별 처리: 02-security 레이어의 ALB 통합 의존성 고려
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
# 레이어 실행 순서 정의 (의존성 고려)
# =============================================================================

# Phase 1: 기본 인프라 (ALB 의존성 없음)
readonly PHASE1_LAYERS=(
    "01-network"
    "03-database"
    "04-parameter-store"
    "05-cloud-map"
    "06-lambda-genai"
    "07-application"
)

# Phase 2: ALB 의존성 있는 레이어들
readonly PHASE2_LAYERS=(
    "02-security"      # ALB 통합 기능 활성화
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
    if ! /c/terraform/terraform version &> /dev/null; then
        log_error "Terraform이 설치되지 않았습니다: /c/terraform/terraform"
        log_error "Terraform을 C:\\terraform에 설치한 후 다시 시도하세요"
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
# Apply 실행 함수
# =============================================================================

apply_layer() {
    local layer=$1
    local phase=$2
    local layer_dir="$LAYERS_DIR/$layer"

    if [[ ! -d "$layer_dir" ]]; then
        log_warning "레이어 디렉터리가 존재하지 않습니다: $layer (건너뜀)"
        return 0
    fi

    log "Applying $layer ($phase)..."

    # .terraform 디렉터리 확인
    if [[ ! -d "$layer_dir/.terraform" ]]; then
        log_error "$layer가 초기화되지 않았습니다. 먼저 ./scripts/init-all.sh를 실행하세요."
        return 1
    fi

    # 02-security 레이어 특별 처리
    local additional_vars=""
    if [[ "$layer" == "02-security" && "$phase" == "Phase 2" ]]; then
        log "02-security 레이어: ALB 통합 활성화"
        additional_vars="-var enable_alb_integration=true"
    fi

    # Apply 실행 (using -chdir with common + env vars)
    local common_tfvars="$PROJECT_ROOT/shared/common.tfvars"
    local env_tfvars="$PROJECT_ROOT/envs/$ENVIRONMENT.tfvars"

    if [[ -f "$common_tfvars" && -f "$env_tfvars" ]]; then
        if /c/terraform/terraform -chdir="$layer_dir" apply \
            -var-file="$common_tfvars" \
            -var-file="$env_tfvars" \
            $additional_vars \
            -auto-approve; then
            log_success "$layer apply 완료"
            return 0
        else
            log_error "$layer apply 실패"
            return 1
        fi
    elif [[ -f "$env_tfvars" ]]; then
        log_warning "common.tfvars 파일이 없습니다: $common_tfvars (환경 변수만 사용)"
        if /c/terraform/terraform -chdir="$layer_dir" apply \
            -var-file="$env_tfvars" \
            $additional_vars \
            -auto-approve; then
            log_success "$layer apply 완료"
            return 0
        else
            log_error "$layer apply 실패"
            return 1
        fi
    else
        log_warning "tfvars 파일이 없습니다: $env_tfvars"
        if /c/terraform/terraform -chdir="$layer_dir" apply $additional_vars -auto-approve; then
            log_success "$layer apply 완료"
            return 0
        else
            log_error "$layer apply 실패"
            return 1
        fi
    fi
}

# =============================================================================
# 메인 실행 함수
# =============================================================================

apply_all_layers() {
    local failed_layers=()
    local success_layers=()

    log "전체 레이어 Apply 시작 - 환경: $ENVIRONMENT"

    # 먼저 모든 레이어가 초기화되었는지 확인
    log "초기화 상태 확인 중..."
    local uninitialized_layers=()

    for layer in "${PHASE1_LAYERS[@]}" "${PHASE2_LAYERS[@]}"; do
        if [[ -d "$LAYERS_DIR/$layer" && ! -d "$LAYERS_DIR/$layer/.terraform" ]]; then
            uninitialized_layers+=("$layer")
        fi
    done

    if [[ ${#uninitialized_layers[@]} -gt 0 ]]; then
        log_warning "초기화되지 않은 레이어 발견: ${uninitialized_layers[*]}"
        log "자동으로 초기화를 실행합니다..."

        if ! bash "$SCRIPT_DIR/init-all.sh" "$ENVIRONMENT"; then
            log_error "초기화 실패"
            return 1
        fi
    fi

    # Phase 1: 기본 인프라 (ALB 의존성 없음)
    log "=========================================="
    log "Phase 1: 기본 인프라 레이어 Apply"
    log "=========================================="

    for layer in "${PHASE1_LAYERS[@]}"; do
        if apply_layer "$layer" "Phase 1"; then
            success_layers+=("$layer")
        else
            failed_layers+=("$layer")
            log_error "Phase 1에서 실패: $layer"
            break  # Phase 1 실패 시 중단
        fi
    done

    # Phase 1이 성공한 경우에만 Phase 2 진행
    if [[ ${#failed_layers[@]} -eq 0 ]]; then
        log "=========================================="
        log "Phase 2: ALB 의존성 레이어 Apply"
        log "=========================================="

        for layer in "${PHASE2_LAYERS[@]}"; do
            if apply_layer "$layer" "Phase 2"; then
                success_layers+=("$layer")
            else
                failed_layers+=("$layer")
            fi
        done
    fi

    # 결과 요약
    log "=========================================="
    log "Apply 결과 요약"
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
        log_success "모든 레이어 Apply 성공!"
        log "다음 단계: ./scripts/validate-infrastructure.sh $ENVIRONMENT"
        return 0
    fi
}

# =============================================================================
# 사용법 및 메인 실행
# =============================================================================

show_usage() {
    cat << EOF
사용법: $0 [ENVIRONMENT]

모든 Terraform 레이어를 의존성 순서대로 apply 실행합니다.

ENVIRONMENT:
    dev      개발 환경 (기본값)
    staging  스테이징 환경
    prod     프로덕션 환경

특별 처리:
    - 02-security 레이어는 07-application 이후에 ALB 통합 활성화
    - 초기화되지 않은 레이어는 자동으로 초기화

예시:
    $0           # dev 환경 apply
    $0 dev       # dev 환경 apply
    $0 staging   # staging 환경 apply

Phase 1 (기본 인프라):
EOF

    for i in "${!PHASE1_LAYERS[@]}"; do
        local layer="${PHASE1_LAYERS[$i]}"
        printf "  %d. %s\n" $((i+1)) "$layer"
    done

    echo ""
    echo "Phase 2 (ALB 의존성):"

    for i in "${!PHASE2_LAYERS[@]}"; do
        local layer="${PHASE2_LAYERS[$i]}"
        printf "  %d. %s\n" $((i+1)) "$layer"
    done
}

main() {
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi

    log "Terraform Apply All 스크립트 시작"
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

    # Apply 실행
    if apply_all_layers; then
        log_success "전체 Apply 완료"
        exit 0
    else
        log_error "Apply 실패"
        exit 1
    fi
}

main "$@"