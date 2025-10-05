#!/bin/bash

# =============================================================================
# 도쿄 리전 테스트 스크립트
# =============================================================================
# 목적: 서울 리전 대신 도쿄 리전에서 전체 인프라 테스트
# 작성자: 영현님
# 사용법: ./scripts/tokyo-region-test.sh [plan|apply|destroy]
# =============================================================================

set -euo pipefail

# 색상 정의
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 전역 변수
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKYO_TFVARS="tokyo-test.tfvars"
ACTION="${1:-plan}"

# 로깅 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 도움말 출력
show_help() {
    cat << EOF
도쿄 리전 테스트 스크립트

사용법: $0 [action]

Actions:
    plan     - Terraform plan 실행 (기본값)
    apply    - Terraform apply 실행
    destroy  - Terraform destroy 실행
    validate - Terraform validate만 실행

레이어 실행 순서:
    1. Network (VPC, 서브넷, 라우팅)
    2. Security (보안 그룹, IAM, VPC 엔드포인트)
    3. Database (Aurora 클러스터)
    4. Application (ECS, ALB, ECR)

예시:
    $0 plan      # 모든 레이어 plan
    $0 apply     # 모든 레이어 apply
    $0 destroy   # 모든 레이어 destroy
EOF
}

# Terraform 명령 실행
run_terraform() {
    local layer="$1"
    local action="$2"
    local layer_dir="${PROJECT_ROOT}/terraform/envs/dev/${layer}"
    
    log_info "=== ${layer} 레이어 ${action} 실행 ==="
    
    if [[ ! -d "${layer_dir}" ]]; then
        log_error "${layer} 레이어 디렉토리를 찾을 수 없습니다: ${layer_dir}"
        return 1
    fi
    
    if [[ ! -f "${layer_dir}/${TOKYO_TFVARS}" ]]; then
        log_error "${layer} 레이어에 ${TOKYO_TFVARS} 파일이 없습니다"
        return 1
    fi
    
    cd "${layer_dir}"
    
    # Terraform 초기화 (필요시)
    if [[ ! -d ".terraform" ]]; then
        log_info "Terraform 초기화 중..."
        terraform init
    fi
    
    # Terraform 명령 실행
    case "${action}" in
        plan)
            terraform plan -var-file="${TOKYO_TFVARS}"
            ;;
        apply)
            terraform apply -var-file="${TOKYO_TFVARS}" -auto-approve
            ;;
        destroy)
            terraform destroy -var-file="${TOKYO_TFVARS}" -auto-approve
            ;;
        validate)
            terraform validate
            ;;
        *)
            log_error "알 수 없는 액션: ${action}"
            return 1
            ;;
    esac
    
    log_success "${layer} 레이어 ${action} 완료"
}

# 메인 실행 함수
main() {
    case "${ACTION}" in
        -h|--help)
            show_help
            exit 0
            ;;
        plan|apply|destroy|validate)
            ;;
        *)
            log_error "알 수 없는 액션: ${ACTION}"
            show_help
            exit 1
            ;;
    esac
    
    log_info "도쿄 리전 테스트 시작 (액션: ${ACTION})"
    log_warning "주의: 이 스크립트는 ap-northeast-1 (도쿄) 리전에 리소스를 생성합니다"
    
    # 레이어 실행 순서
    local layers=("network" "security" "database" "application")
    
    if [[ "${ACTION}" == "destroy" ]]; then
        # destroy는 역순으로 실행
        layers=($(printf '%s\n' "${layers[@]}" | tac))
    fi
    
    for layer in "${layers[@]}"; do
        if ! run_terraform "${layer}" "${ACTION}"; then
            log_error "${layer} 레이어에서 오류 발생"
            exit 1
        fi
        echo ""
    done
    
    log_success "모든 레이어 ${ACTION} 완료!"
    
    if [[ "${ACTION}" == "apply" ]]; then
        log_info "도쿄 리전 테스트 환경이 성공적으로 생성되었습니다"
        log_info "리소스 정리를 위해 나중에 다음 명령을 실행하세요:"
        log_info "  $0 destroy"
    fi
}

# 스크립트 실행
main "$@"