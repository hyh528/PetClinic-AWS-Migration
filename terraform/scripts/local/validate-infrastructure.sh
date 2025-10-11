#!/bin/bash

# ==========================================
# Terraform 인프라 전체 검증 스크립트
# ==========================================
# 모든 레이어를 한 번에 init, validate, plan 수행

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로깅 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 전역 변수
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-dev}"
ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
ERRORS=0
WARNINGS=0

log_info "Terraform 인프라 검증을 시작합니다..."
log_info "환경: $ENVIRONMENT"
log_info "작업 디렉토리: $ENV_DIR"

# ==========================================
# 1. 사전 검증
# ==========================================

log_info "=== 1단계: 사전 검증 ==="

# Terraform 설치 확인
if ! command -v terraform &> /dev/null; then
    log_error "Terraform이 설치되지 않았습니다."
    exit 1
fi

TERRAFORM_VERSION=$(terraform version | head -n1)
log_success "Terraform 확인: $TERRAFORM_VERSION"

# 환경 디렉터리 확인
if [ ! -d "$ENV_DIR" ]; then
    log_error "환경 디렉터리가 존재하지 않습니다: $ENV_DIR"
    exit 1
fi

log_success "환경 디렉터리 확인: $ENV_DIR"

# ==========================================
# 2. 전체 포맷팅 검사
# ==========================================

log_info "=== 2단계: 전체 포맷팅 검사 ==="

cd "$PROJECT_ROOT"

if terraform fmt -check -recursive > /dev/null 2>&1; then
    log_success "Terraform 포맷팅 정상"
else
    log_warning "Terraform 포맷팅 필요 - 자동 적용 중..."
    terraform fmt -recursive
    log_success "Terraform 포맷팅 완료"
    ((WARNINGS++))
fi

# ==========================================
# 3. 레이어별 검증
# ==========================================

log_info "=== 3단계: 레이어별 검증 ==="

# 레이어 순서 (의존성 고려)
LAYERS=(
    "01-network"
    "02-security" 
    "03-database"
    "04-parameter-store"
    "05-cloud-map"
    "06-lambda-genai"
    "07-application"
    "08-api-gateway"
    "09-monitoring"
)

declare -A LAYER_DESCRIPTIONS=(
    ["01-network"]="기본 네트워크 인프라 (VPC, 서브넷, 게이트웨이)"
    ["02-security"]="보안 설정 (보안 그룹, IAM, VPC 엔드포인트)"
    ["03-database"]="데이터베이스 (Aurora 클러스터)"
    ["04-parameter-store"]="Parameter Store (Spring Cloud Config 대체)"
    ["05-cloud-map"]="Cloud Map (Eureka 대체)"
    ["06-lambda-genai"]="Lambda GenAI (서버리스 AI 서비스)"
    ["07-application"]="애플리케이션 인프라 (ECS, ALB, ECR)"
    ["08-api-gateway"]="API Gateway (Spring Cloud Gateway 대체)"
    ["09-monitoring"]="모니터링 (CloudWatch 통합)"
)

SUCCESS_LAYERS=()
FAILED_LAYERS=()

for layer in "${LAYERS[@]}"; do
    layer_dir="$ENV_DIR/$layer"
    
    if [ ! -d "$layer_dir" ]; then
        log_warning "레이어 디렉터리 없음: $layer (건너뜀)"
        ((WARNINGS++))
        continue
    fi
    
    log_info "=========================================="
    log_info "레이어 검증: $layer"
    log_info "설명: ${LAYER_DESCRIPTIONS[$layer]}"
    log_info "=========================================="
    
    cd "$layer_dir"
    
    # 필수 파일 확인
    required_files=("main.tf" "variables.tf" "outputs.tf")
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "  ✅ $file 존재"
        else
            log_warning "  ⚠️  $file 누락"
            ((WARNINGS++))
        fi
    done
    
    # Terraform 초기화
    log_info "  🔧 Terraform 초기화 중..."
    if terraform init -input=false -upgrade > /dev/null 2>&1; then
        log_success "  ✅ 초기화 성공"
    else
        log_error "  ❌ 초기화 실패"
        terraform init -input=false -upgrade
        FAILED_LAYERS+=("$layer")
        ((ERRORS++))
        continue
    fi
    
    # Terraform 검증
    log_info "  🔍 Terraform 검증 중..."
    if terraform validate > /dev/null 2>&1; then
        log_success "  ✅ 검증 통과"
    else
        log_error "  ❌ 검증 실패"
        terraform validate
        FAILED_LAYERS+=("$layer")
        ((ERRORS++))
        continue
    fi
    
    # Terraform Plan (tfvars 파일이 있는 경우)
    tfvars_file="${ENVIRONMENT}.tfvars"
    if [ -f "$tfvars_file" ]; then
        log_info "  📋 Terraform Plan 생성 중..."
        if terraform plan -var-file="$tfvars_file" -input=false > /dev/null 2>&1; then
            log_success "  ✅ Plan 생성 성공"
        else
            log_error "  ❌ Plan 생성 실패"
            terraform plan -var-file="$tfvars_file" -input=false
            FAILED_LAYERS+=("$layer")
            ((ERRORS++))
            continue
        fi
    else
        log_warning "  ⚠️  tfvars 파일 없음: $tfvars_file"
        ((WARNINGS++))
    fi
    
    SUCCESS_LAYERS+=("$layer")
    log_success "레이어 검증 완료: $layer"
    echo
done

# ==========================================
# 4. 보안 스캔 (선택사항)
# ==========================================

log_info "=== 4단계: 보안 스캔 ==="

cd "$PROJECT_ROOT"

# checkov 스캔
if command -v checkov &> /dev/null; then
    log_info "Checkov 보안 스캔 실행 중..."
    if checkov -d . --framework terraform --quiet > /dev/null 2>&1; then
        log_success "Checkov 보안 스캔 통과"
    else
        log_warning "Checkov 보안 스캔에서 이슈 발견됨"
        ((WARNINGS++))
    fi
else
    log_warning "Checkov가 설치되지 않았습니다. 보안 스캔을 건너뜁니다."
fi

# tfsec 스캔
if command -v tfsec &> /dev/null; then
    log_info "tfsec 보안 스캔 실행 중..."
    if tfsec . > /dev/null 2>&1; then
        log_success "tfsec 보안 스캔 통과"
    else
        log_warning "tfsec 보안 스캔에서 이슈 발견됨"
        ((WARNINGS++))
    fi
else
    log_warning "tfsec가 설치되지 않았습니다. 보안 스캔을 건너뜁니다."
fi

# ==========================================
# 5. 결과 요약
# ==========================================

log_info "=== 검증 결과 요약 ==="

echo "=========================================="
echo "📊 검증 통계:"
echo "   - 총 레이어: ${#LAYERS[@]}"
echo "   - 성공: ${#SUCCESS_LAYERS[@]}"
echo "   - 실패: ${#FAILED_LAYERS[@]}"
echo "   - 오류: $ERRORS 개"
echo "   - 경고: $WARNINGS 개"
echo "=========================================="

if [ ${#SUCCESS_LAYERS[@]} -gt 0 ]; then
    log_success "검증 성공 레이어:"
    for layer in "${SUCCESS_LAYERS[@]}"; do
        log_success "  ✓ $layer - ${LAYER_DESCRIPTIONS[$layer]}"
    done
fi

if [ ${#FAILED_LAYERS[@]} -gt 0 ]; then
    log_error "검증 실패 레이어:"
    for layer in "${FAILED_LAYERS[@]}"; do
        log_error "  ✗ $layer - ${LAYER_DESCRIPTIONS[$layer]}"
    done
fi

echo

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_success "🎉 모든 검증을 통과했습니다!"
    echo
    echo "다음 단계:"
    echo "1. ./scripts/plan-all.sh $ENVIRONMENT  # 전체 배포 계획 확인"
    echo "2. ./scripts/apply-all.sh $ENVIRONMENT # 전체 배포 실행"
    
elif [ $ERRORS -eq 0 ]; then
    log_warning "⚠️  경고가 있지만 배포 가능합니다."
    echo
    echo "권장 사항:"
    echo "1. 경고 사항 검토 및 수정"
    echo "2. ./scripts/plan-all.sh $ENVIRONMENT"
    
else
    log_error "❌ 오류가 발견되었습니다. 배포 전 수정이 필요합니다."
    echo
    echo "해결 방법:"
    echo "1. 위의 오류 메시지 확인"
    echo "2. 실패한 레이어의 terraform 파일 수정"
    echo "3. 다시 검증 실행"
    
    exit 1
fi

log_success "검증 스크립트 실행 완료!"