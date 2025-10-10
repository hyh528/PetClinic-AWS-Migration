#!/bin/bash

# ==========================================
# Terraform 인프라 전체 검증 스크립트
# ==========================================
# 팀원들이 안전하게 인프라를 검증할 수 있는 스크립트

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
ERRORS=0
WARNINGS=0

log_info "Terraform 인프라 검증을 시작합니다..."
log_info "작업 디렉토리: $SCRIPT_DIR"

# ==========================================
# 1. 사전 검증
# ==========================================

log_info "=== 1단계: 사전 검증 ==="

# Terraform 설치 확인
if ! command -v terraform &> /dev/null; then
    log_error "Terraform이 설치되지 않았습니다."
    log_info "설치 방법: https://www.terraform.io/downloads.html"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
log_success "Terraform 버전: $TERRAFORM_VERSION"

# AWS CLI 확인
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI가 설치되지 않았습니다."
    log_info "설치 방법: https://aws.amazon.com/cli/"
    exit 1
fi

# AWS 자격 증명 확인
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS 자격 증명이 설정되지 않았습니다."
    log_info "aws configure를 실행하여 자격 증명을 설정하세요."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || echo "ap-northeast-2")
log_success "AWS 계정: $ACCOUNT_ID, 리전: $REGION"

# ==========================================
# 2. 모듈 검증
# ==========================================

log_info "=== 2단계: 모듈 검증 ==="

cd "$SCRIPT_DIR/modules"

for module_dir in */; do
    if [ -d "$module_dir" ]; then
        module_name=${module_dir%/}
        log_info "모듈 검증 중: $module_name"
        
        cd "$module_dir"
        
        # 포맷 확인
        if terraform fmt -check -diff > /dev/null 2>&1; then
            log_success "  ✅ 포맷팅 정상"
        else
            log_warning "  ⚠️  포맷팅 필요"
            terraform fmt
            ((WARNINGS++))
        fi
        
        # 문법 검증
        if terraform validate > /dev/null 2>&1; then
            log_success "  ✅ 문법 검증 통과"
        else
            log_error "  ❌ 문법 오류 발견"
            terraform validate
            ((ERRORS++))
        fi
        
        cd ..
    fi
done

cd "$SCRIPT_DIR"

# ==========================================
# 3. 환경별 검증
# ==========================================

log_info "=== 3단계: 환경별 검증 ==="

cd "$SCRIPT_DIR/envs/dev"

# 레이어 순서 (의존성 고려)
LAYERS=(
    "network"
    "security" 
    "database"
    "application"
    "monitoring"
    "aws-native"
    "api-gateway"
    "parameter-store"
    "cloud-map"
    "lambda-genai"
    "state-management"
)

for layer in "${LAYERS[@]}"; do
    if [ -d "$layer" ]; then
        log_info "레이어 검증 중: $layer"
        
        cd "$layer"
        
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
        
        # 포맷 확인
        if terraform fmt -check -diff > /dev/null 2>&1; then
            log_success "  ✅ 포맷팅 정상"
        else
            log_warning "  ⚠️  포맷팅 필요"
            terraform fmt
            ((WARNINGS++))
        fi
        
        # 백엔드 없이 초기화 및 검증
        if terraform init -backend=false > /dev/null 2>&1; then
            log_success "  ✅ 초기화 성공"
            
            if terraform validate > /dev/null 2>&1; then
                log_success "  ✅ 문법 검증 통과"
            else
                log_error "  ❌ 문법 오류 발견"
                terraform validate
                ((ERRORS++))
            fi
        else
            log_error "  ❌ 초기화 실패"
            terraform init -backend=false
            ((ERRORS++))
        fi
        
        # 상태 파일 확인
        if [ -f "terraform.tfstate" ]; then
            STATE_RESOURCES=$(terraform state list 2>/dev/null | wc -l || echo "0")
            log_info "  📊 로컬 상태: $STATE_RESOURCES 개 리소스"
        else
            log_info "  📊 로컬 상태: 없음"
        fi
        
        cd ..
        echo
    else
        log_warning "레이어 디렉토리 없음: $layer"
        ((WARNINGS++))
    fi
done

cd "$SCRIPT_DIR"

# ==========================================
# 4. 알려진 이슈 확인
# ==========================================

log_info "=== 4단계: 알려진 이슈 확인 ==="

# Application 레이어 특별 검증
if [ -d "envs/dev/application" ]; then
    log_info "Application 레이어 특별 검증 중..."
    
    cd "envs/dev/application"
    
    # task_role_arn 이슈 확인
    if grep -q "task_role_arn" main.tf; then
        log_info "  🔍 task_role_arn 사용 확인됨"
        
        # ECS 모듈에서 해당 변수 정의 확인
        if grep -q "variable \"task_role_arn\"" ../../../modules/ecs/variables.tf; then
            log_success "  ✅ ECS 모듈에 task_role_arn 변수 정의됨"
        else
            log_error "  ❌ ECS 모듈에 task_role_arn 변수 누락"
            ((ERRORS++))
        fi
    fi
    
    cd "$SCRIPT_DIR"
fi

# ==========================================
# 5. 보안 검증
# ==========================================

log_info "=== 5단계: 보안 검증 ==="

# 민감한 정보 하드코딩 확인
log_info "민감한 정보 하드코딩 검사 중..."

SENSITIVE_PATTERNS=(
    "password.*=.*\".*\""
    "secret.*=.*\".*\""
    "key.*=.*\"[A-Za-z0-9+/]{20,}\""
    "token.*=.*\".*\""
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if grep -r -E "$pattern" envs/ modules/ --include="*.tf" > /dev/null 2>&1; then
        log_warning "  ⚠️  민감한 정보 하드코딩 의심: $pattern"
        ((WARNINGS++))
    fi
done

log_success "보안 검증 완료"

# ==========================================
# 6. 결과 요약
# ==========================================

log_info "=== 검증 결과 요약 ==="

echo "=================================="
echo "📊 검증 통계:"
echo "   - 오류: $ERRORS 개"
echo "   - 경고: $WARNINGS 개"
echo "=================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_success "🎉 모든 검증을 통과했습니다!"
    echo
    echo "다음 단계:"
    echo "1. terraform plan으로 배포 계획 확인"
    echo "2. 팀 검토 후 terraform apply 실행"
    echo "3. AWS 콘솔에서 리소스 확인"
    
elif [ $ERRORS -eq 0 ]; then
    log_warning "⚠️  경고가 있지만 배포 가능합니다."
    echo
    echo "권장 사항:"
    echo "1. 경고 사항 검토 및 수정"
    echo "2. terraform plan으로 배포 계획 확인"
    
else
    log_error "❌ 오류가 발견되었습니다. 배포 전 수정이 필요합니다."
    echo
    echo "해결 방법:"
    echo "1. 위의 오류 메시지 확인"
    echo "2. CURRENT_ISSUES.md 문서 참조"
    echo "3. 팀에 도움 요청"
    
    exit 1
fi

# ==========================================
# 7. 추가 도구 제안
# ==========================================

echo
log_info "=== 추가 도구 ==="
echo "🔧 유용한 명령어:"
echo "   terraform fmt -recursive     # 전체 포맷팅"
echo "   terraform validate          # 문법 검증"
echo "   terraform plan             # 배포 계획 확인"
echo "   terraform state list       # 현재 상태 확인"
echo
echo "📚 문서:"
echo "   VALIDATION_GUIDE.md        # 상세 검증 가이드"
echo "   CURRENT_ISSUES.md          # 알려진 이슈 및 해결방안"
echo "   README.md                  # 프로젝트 개요"

log_success "검증 스크립트 실행 완료!"