#!/bin/bash

# =============================================================================
# Terraform 레이어 의존성 검증 스크립트 (AWS Well-Architected 준수)
# =============================================================================
# 목적: 레이어 간 의존성이 올바르게 설정되었는지 검증
# 작성자: AWS 네이티브 마이그레이션 팀
# 버전: 2.0.0
# 준수 기준: AWS Well-Architected Framework + Clean Code

set -euo pipefail

# =============================================================================
# 설정 변수 (Clean Code: 명확한 변수명)
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ENVIRONMENT="${1:-dev}"
readonly ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"

# 색상 정의
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# =============================================================================
# 로깅 함수 (Single Responsibility)
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
# 의존성 정의 (AWS Well-Architected: 올바른 의존성 관계)
# =============================================================================

declare -A LAYER_DEPENDENCIES=(
    ["01-network"]=""
    ["02-security"]="01-network"
    ["03-database"]="01-network,02-security"
    ["07-application"]="01-network,02-security,03-database"
    ["04-parameter-store"]="01-network,02-security,03-database,07-application"
    ["05-cloud-map"]="01-network,02-security,03-database,07-application"
    ["06-lambda-genai"]="01-network,02-security"
    ["08-api-gateway"]="04-parameter-store,05-cloud-map,06-lambda-genai,07-application"
    ["09-monitoring"]="04-parameter-store,05-cloud-map,06-lambda-genai,07-application,08-api-gateway"
)

declare -A LAYER_DESCRIPTIONS=(
    ["01-network"]="기본 네트워크 인프라 (VPC, 서브넷, 게이트웨이)"
    ["02-security"]="보안 설정 (보안 그룹, IAM, VPC 엔드포인트)"
    ["03-database"]="데이터베이스 (Aurora 클러스터)"
    ["07-application"]="애플리케이션 인프라 (ECS, ALB, ECR)"
    ["04-parameter-store"]="Parameter Store (Spring Cloud Config 대체)"
    ["05-cloud-map"]="Cloud Map (Eureka 대체)"
    ["06-lambda-genai"]="Lambda GenAI (서버리스 AI 서비스)"
    ["08-api-gateway"]="API Gateway (Spring Cloud Gateway 대체)"
    ["09-monitoring"]="모니터링 (CloudWatch 통합)"
)

# =============================================================================
# 검증 함수 (Clean Code: 단일 책임 원칙)
# =============================================================================

check_layer_exists() {
    local layer=$1
    [[ -d "$ENV_DIR/$layer" ]]
}

check_state_exists() {
    local layer=$1
    local layer_dir="$ENV_DIR/$layer"
    
    if [[ -f "$layer_dir/terraform.tfstate" ]] || [[ -f "$layer_dir/.terraform/terraform.tfstate" ]]; then
        return 0
    fi
    
    # 원격 상태 확인
    if [[ -f "$layer_dir/backend.tf" ]]; then
        cd "$layer_dir"
        terraform show > /dev/null 2>&1
    else
        return 1
    fi
}

check_layer_outputs() {
    local layer=$1
    local layer_dir="$ENV_DIR/$layer"
    
    cd "$layer_dir"
    terraform output > /dev/null 2>&1
}

validate_dependencies() {
    local layer=$1
    local dependencies="${LAYER_DEPENDENCIES[$layer]}"
    
    if [[ -z "$dependencies" ]]; then
        return 0
    fi
    
    IFS=',' read -ra DEPS <<< "$dependencies"
    for dep in "${DEPS[@]}"; do
        dep=$(echo "$dep" | xargs)
        
        if ! check_layer_exists "$dep"; then
            log_error "의존성 레이어가 존재하지 않습니다: $dep (required by $layer)"
            return 1
        fi
        
        if ! check_state_exists "$dep"; then
            log_error "의존성 레이어가 배포되지 않았습니다: $dep (required by $layer)"
            return 1
        fi
    done
    
    return 0
}

# =============================================================================
# 메인 검증 함수
# =============================================================================

validate_layer() {
    local layer=$1
    local description="${LAYER_DESCRIPTIONS[$layer]}"
    local issues=0
    
    log "레이어 검증: $layer - $description"
    
    if ! check_layer_exists "$layer"; then
        log_error "레이어 디렉터리가 존재하지 않습니다: $layer"
        return 1
    fi
    
    if ! validate_dependencies "$layer"; then
        ((issues++))
    fi
    
    # 필수 파일 확인
    local layer_dir="$ENV_DIR/$layer"
    local required_files=("main.tf" "variables.tf" "outputs.tf" "backend.tf")
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$layer_dir/$file" ]]; then
            log_warning "필수 파일이 없습니다: $layer/$file"
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log_success "레이어 검증 통과: $layer"
        return 0
    else
        log_error "레이어 검증 실패: $layer ($issues 개 문제)"
        return 1
    fi
}

validate_all_layers() {
    local total_issues=0
    local validated_layers=()
    local failed_layers=()
    
    log "전체 레이어 의존성 검증 시작 - 환경: $ENVIRONMENT"
    
    for layer in "${!LAYER_DEPENDENCIES[@]}"; do
        if validate_layer "$layer"; then
            validated_layers+=("$layer")
        else
            failed_layers+=("$layer")
            ((total_issues++))
        fi
    done
    
    # 결과 요약
    log "=========================================="
    log "의존성 검증 결과 요약"
    log "=========================================="
    log "총 레이어 수: ${#LAYER_DEPENDENCIES[@]}"
    log "검증 통과: ${#validated_layers[@]}"
    log "검증 실패: ${#failed_layers[@]}"
    
    if [[ ${#validated_layers[@]} -gt 0 ]]; then
        log_success "검증 통과 레이어:"
        for layer in "${validated_layers[@]}"; do
            log_success "  ✓ $layer"
        done
    fi
    
    if [[ ${#failed_layers[@]} -gt 0 ]]; then
        log_error "검증 실패 레이어:"
        for layer in "${failed_layers[@]}"; do
            log_error "  ✗ $layer"
        done
    fi
    
    if [[ $total_issues -eq 0 ]]; then
        log_success "모든 의존성 검증 통과!"
        return 0
    else
        log_error "의존성 검증 실패 ($total_issues 개 문제)"
        return 1
    fi
}

show_dependency_graph() {
    log "의존성 그래프:"
    log "=============="
    
    for layer in "${!LAYER_DEPENDENCIES[@]}"; do
        local dependencies="${LAYER_DEPENDENCIES[$layer]}"
        local description="${LAYER_DESCRIPTIONS[$layer]}"
        
        if [[ -n "$dependencies" ]]; then
            log "$layer ← $dependencies"
        else
            log "$layer (의존성 없음)"
        fi
        log "  └─ $description"
    done
}

show_deployment_order() {
    log "권장 배포 순서:"
    log "=============="
    
    local order=(
        "01-network"
        "02-security"
        "03-database"
        "07-application"
        "04-parameter-store"
        "05-cloud-map"
        "06-lambda-genai"
        "08-api-gateway"
        "09-monitoring"
    )
    
    for i in "${!order[@]}"; do
        local layer="${order[$i]}"
        local description="${LAYER_DESCRIPTIONS[$layer]}"
        local status="❓"
        
        if check_layer_exists "$layer"; then
            if check_state_exists "$layer"; then
                status="✅"
            else
                status="📁"
            fi
        else
            status="❌"
        fi
        
        printf "%2d. %s %s - %s\n" $((i+1)) "$status" "$layer" "$description"
    done
    
    echo
    echo "범례:"
    echo "  ✅ - 배포 완료"
    echo "  📁 - 디렉터리 존재하지만 미배포"
    echo "  ❌ - 디렉터리 없음"
    echo "  ❓ - 상태 불명"
}

# =============================================================================
# 사용법 및 메인 실행
# =============================================================================

show_usage() {
    cat << EOF
사용법: $0 [OPTIONS] [ENVIRONMENT] [LAYER]

Terraform 레이어 의존성을 검증합니다.

OPTIONS:
    -a, --all             모든 레이어 검증
    -g, --graph           의존성 그래프 표시
    -o, --order           권장 배포 순서 표시
    -h, --help            도움말 표시

ENVIRONMENT:
    dev      개발 환경 (기본값)
    staging  스테이징 환경
    prod     프로덕션 환경

LAYER:
    특정 레이어만 검증 (선택사항)

예시:
    $0 -a                 # dev 환경 모든 레이어 검증
    $0 -a staging         # staging 환경 모든 레이어 검증
    $0 dev 01-network     # dev 환경 특정 레이어 검증
    $0 -g                 # 의존성 그래프 표시
    $0 -o                 # 배포 순서 표시

EOF
}

main() {
    case "${1:-}" in
        -a|--all)
            validate_all_layers
            ;;
        -g|--graph)
            show_dependency_graph
            ;;
        -o|--order)
            show_deployment_order
            ;;
        -h|--help)
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            if [[ -n "${LAYER_DEPENDENCIES[$1]:-}" ]]; then
                validate_layer "$1"
            else
                log_error "알 수 없는 레이어: $1"
                log "사용 가능한 레이어: ${!LAYER_DEPENDENCIES[@]}"
                exit 1
            fi
            ;;
    esac
}

main "$@"