#!/bin/bash

# =============================================================================
# Terraform 레이어 순차 배포 스크립트 (AWS Well-Architected 준수)
# =============================================================================
# 목적: 의존성을 고려한 올바른 순서로 Terraform 레이어들을 배포
# 작성자: AWS 네이티브 마이그레이션 팀
# 버전: 2.0.0
# 준수 기준: AWS Well-Architected Framework + Terraform Best Practices

set -euo pipefail  # 엄격한 에러 처리

# =============================================================================
# 설정 변수 (Clean Code: 명확한 변수명)
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 환경 설정 (기본값: dev)
readonly ENVIRONMENT="${1:-dev}"
readonly ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
readonly LOG_DIR="$ENV_DIR/logs"

# 색상 정의 (가독성 향상)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# 로깅 함수 (Clean Code: 단일 책임 원칙)
# =============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/deploy_${TIMESTAMP}.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_DIR/deploy_${TIMESTAMP}.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_DIR/deploy_${TIMESTAMP}.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/deploy_${TIMESTAMP}.log"
}

# =============================================================================
# 의존성 정의 (AWS Well-Architected: 올바른 배포 순서)
# =============================================================================

# 레이어 실행 순서 정의 (의존성 기반)
readonly LAYERS=(
    "01-network"        # 기본 네트워크 인프라 (VPC, 서브넷, 게이트웨이)
    "02-security"       # 보안 설정 (보안 그룹, IAM, VPC 엔드포인트)
    "03-database"       # 데이터베이스 (Aurora 클러스터)
    "07-application"    # 애플리케이션 인프라 (ECS, ALB, ECR)
    "04-parameter-store" # Parameter Store (Spring Cloud Config 대체)
    "05-cloud-map"      # Cloud Map (Eureka 대체)
    "06-lambda-genai"   # Lambda GenAI (서버리스 AI 서비스)
    "08-api-gateway"    # API Gateway (Spring Cloud Gateway 대체)
    "09-monitoring"     # 모니터링 (CloudWatch 통합)
)

# 레이어 설명 (문서화)
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
# 검증 함수 (Reliability: 사전 검증)
# =============================================================================

validate_environment() {
    log "환경 검증 시작: $ENVIRONMENT"
    
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "지원되지 않는 환경입니다: $ENVIRONMENT (dev, staging, prod만 지원)"
        return 1
    fi
    
    if [[ ! -d "$ENV_DIR" ]]; then
        log_error "환경 디렉터리가 존재하지 않습니다: $ENV_DIR"
        return 1
    fi
    
    # 로그 디렉터리 생성
    mkdir -p "$LOG_DIR"
    
    log_success "환경 검증 완료"
    return 0
}

check_prerequisites() {
    log "사전 요구사항 확인 중..."
    
    # Terraform 설치 확인
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform이 설치되지 않았습니다"
        return 1
    fi
    
    # AWS CLI 설정 확인
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI가 설정되지 않았거나 권한이 없습니다"
        return 1
    fi
    
    log_success "사전 요구사항 확인 완료"
    return 0
}

# =============================================================================
# 레이어 배포 함수 (Single Responsibility)
# =============================================================================

terraform_init() {
    local layer=$1
    local layer_dir="$ENV_DIR/$layer"
    
    log "Terraform 초기화: $layer"
    
    cd "$layer_dir"
    if terraform init -input=false -upgrade; then
        log_success "Terraform 초기화 완료: $layer"
        return 0
    else
        log_error "Terraform 초기화 실패: $layer"
        return 1
    fi
}

terraform_plan() {
    local layer=$1
    local layer_dir="$ENV_DIR/$layer"
    local plan_file="$layer_dir/terraform.tfplan"
    local tfvars_file="$layer_dir/${ENVIRONMENT}.tfvars"
    
    log "Terraform 계획 생성: $layer"
    
    cd "$layer_dir"
    
    # tfvars 파일 확인
    local tfvars_args=""
    if [[ -f "$tfvars_file" ]]; then
        tfvars_args="-var-file=${ENVIRONMENT}.tfvars"
    fi
    
    if terraform plan -input=false -out="$plan_file" $tfvars_args 2>&1 | tee "$LOG_DIR/plan_${layer}_${TIMESTAMP}.log"; then
        log_success "Terraform 계획 생성 완료: $layer"
        return 0
    else
        log_error "Terraform 계획 생성 실패: $layer"
        return 1
    fi
}

terraform_apply() {
    local layer=$1
    local layer_dir="$ENV_DIR/$layer"
    local plan_file="$layer_dir/terraform.tfplan"
    
    log "Terraform 적용: $layer"
    
    cd "$layer_dir"
    if terraform apply -input=false "$plan_file" 2>&1 | tee "$LOG_DIR/apply_${layer}_${TIMESTAMP}.log"; then
        log_success "Terraform 적용 완료: $layer"
        # 계획 파일 정리
        rm -f "$plan_file"
        return 0
    else
        log_error "Terraform 적용 실패: $layer"
        return 1
    fi
}

# =============================================================================
# 메인 배포 함수 (Clean Architecture)
# =============================================================================

deploy_layer() {
    local layer=$1
    local description="${LAYER_DESCRIPTIONS[$layer]}"
    local layer_dir="$ENV_DIR/$layer"
    
    log "=========================================="
    log "레이어 배포 시작: $layer"
    log "설명: $description"
    log "=========================================="
    
    # 레이어 디렉터리 존재 확인
    if [[ ! -d "$layer_dir" ]]; then
        log_warning "레이어 디렉터리가 존재하지 않습니다: $layer (건너뜀)"
        return 0
    fi
    
    # Terraform 초기화
    if ! terraform_init "$layer"; then
        return 1
    fi
    
    # Terraform 계획 생성
    if ! terraform_plan "$layer"; then
        return 1
    fi
    
    # Terraform 적용
    if ! terraform_apply "$layer"; then
        return 1
    fi
    
    log_success "레이어 배포 완료: $layer"
    return 0
}

deploy_all_layers() {
    local failed_layers=()
    local deployed_layers=()
    
    log "전체 레이어 배포 시작 - 환경: $ENVIRONMENT"
    log "배포할 레이어 수: ${#LAYERS[@]}"
    
    for layer in "${LAYERS[@]}"; do
        if deploy_layer "$layer"; then
            deployed_layers+=("$layer")
        else
            failed_layers+=("$layer")
            log_error "레이어 배포 실패: $layer"
            break  # 의존성 때문에 실패 시 중단
        fi
    done
    
    # 배포 결과 요약
    log "=========================================="
    log "배포 결과 요약"
    log "=========================================="
    log "성공한 레이어: ${#deployed_layers[@]}"
    for layer in "${deployed_layers[@]}"; do
        log_success "  ✓ $layer"
    done
    
    if [[ ${#failed_layers[@]} -gt 0 ]]; then
        log "실패한 레이어: ${#failed_layers[@]}"
        for layer in "${failed_layers[@]}"; do
            log_error "  ✗ $layer"
        done
        return 1
    else
        log_success "모든 레이어 배포 성공!"
        log "Drift 감지 실행: ./scripts/drift-detect.sh $ENVIRONMENT"
        return 0
    fi
}

# =============================================================================
# 사용법 및 메인 실행 (Clean Code: 명확한 인터페이스)
# =============================================================================

show_usage() {
    cat << EOF
사용법: $0 [ENVIRONMENT]

Terraform 레이어를 의존성 순서대로 배포합니다.

ENVIRONMENT:
    dev      개발 환경 (기본값)
    staging  스테이징 환경
    prod     프로덕션 환경

예시:
    $0           # dev 환경 배포
    $0 dev       # dev 환경 배포
    $0 staging   # staging 환경 배포
    $0 prod      # prod 환경 배포

배포 순서:
EOF
    
    for i in "${!LAYERS[@]}"; do
        local layer="${LAYERS[$i]}"
        local description="${LAYER_DESCRIPTIONS[$layer]}"
        printf "  %d. %s - %s\n" $((i+1)) "$layer" "$description"
    done
}

# 메인 실행 로직
main() {
    # 도움말 표시
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    log "Terraform 레이어 배포 스크립트 시작"
    log "환경: $ENVIRONMENT"
    log "타임스탬프: $TIMESTAMP"
    
    # 검증 단계
    if ! validate_environment; then
        exit 1
    fi
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    # 배포 실행
    if deploy_all_layers; then
        log_success "전체 배포 완료"
        exit 0
    else
        log_error "배포 실패"
        exit 1
    fi
}

# 스크립트 실행
main "$@"