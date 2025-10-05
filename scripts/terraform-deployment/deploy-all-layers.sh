#!/bin/bash

# ==========================================
# Terraform 전체 레이어 순차 배포 스크립트
# ==========================================
# 목적: 의존성을 고려하여 모든 레이어를 순서대로 배포
# 작성자: 영현
# 날짜: 2025-10-05

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로그 함수들
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

log_header() {
    echo -e "${CYAN}===========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}===========================================${NC}"
}

# 변수 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASE_DIR="$PROJECT_ROOT/terraform/envs/dev"

# 레이어 실행 순서 (의존성 고려)
LAYERS=(
    "network"
    "security" 
    "database"
    "parameter-store"
    "cloud-map"
    "lambda-genai"
    "application"
    "api-gateway"
    "monitoring"
    "aws-native"
    "state-management"
)

# 레이어 설명
declare -A LAYER_DESCRIPTIONS=(
    ["network"]="기반 네트워크 인프라 (VPC, 서브넷, 게이트웨이)"
    ["security"]="보안 설정 (보안 그룹, IAM, VPC 엔드포인트)"
    ["database"]="데이터베이스 (Aurora MySQL 클러스터)"
    ["parameter-store"]="설정 관리 (Systems Manager Parameter Store)"
    ["cloud-map"]="서비스 디스커버리 (AWS Cloud Map)"
    ["lambda-genai"]="AI 서비스 (Lambda + Bedrock)"
    ["application"]="애플리케이션 (ECS, ALB, ECR)"
    ["api-gateway"]="API 게이트웨이 (AWS API Gateway)"
    ["monitoring"]="모니터링 (CloudWatch, 알람)"
    ["aws-native"]="AWS 네이티브 서비스 통합 및 오케스트레이션"
    ["state-management"]="상태 관리 유틸리티"
)

# 실행 통계
TOTAL_LAYERS=${#LAYERS[@]}
SUCCESSFUL_LAYERS=0
FAILED_LAYERS=0
SKIPPED_LAYERS=0

# 시작 시간 기록
START_TIME=$(date +%s)

log_header "Terraform 전체 레이어 배포 시작"
echo "프로젝트 루트: $PROJECT_ROOT"
echo "대상 환경: dev"
echo "총 레이어 수: $TOTAL_LAYERS"
echo "시작 시간: $(date)"
echo ""

# 사용자 확인
read -p "모든 레이어를 순차적으로 배포하시겠습니까? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "배포가 취소되었습니다."
    exit 0
fi

echo ""

# 각 레이어 순차 실행
for i in "${!LAYERS[@]}"; do
    layer="${LAYERS[$i]}"
    layer_num=$((i + 1))
    layer_dir="$BASE_DIR/$layer"
    description="${LAYER_DESCRIPTIONS[$layer]}"
    
    log_header "[$layer_num/$TOTAL_LAYERS] $layer 레이어 배포"
    echo "설명: $description"
    echo "경로: $layer_dir"
    echo ""
    
    # 레이어 디렉토리 존재 확인
    if [[ ! -d "$layer_dir" ]]; then
        log_error "레이어 디렉토리가 존재하지 않습니다: $layer_dir"
        FAILED_LAYERS=$((FAILED_LAYERS + 1))
        continue
    fi
    
    # 레이어 디렉토리로 이동
    cd "$layer_dir"
    
    # 1. terraform init
    log_info "terraform init 실행 중..."
    if terraform init; then
        log_success "terraform init 완료"
    else
        log_error "terraform init 실패"
        FAILED_LAYERS=$((FAILED_LAYERS + 1))
        cd "$PROJECT_ROOT"
        continue
    fi
    
    # 2. terraform plan
    log_info "terraform plan 실행 중..."
    if terraform plan -out="tfplan"; then
        log_success "terraform plan 완료"
    else
        log_error "terraform plan 실패"
        FAILED_LAYERS=$((FAILED_LAYERS + 1))
        cd "$PROJECT_ROOT"
        continue
    fi
    
    # 3. 사용자 확인
    echo ""
    log_warning "계획을 검토하고 계속 진행하시겠습니까?"
    read -p "$layer 레이어를 apply하시겠습니까? (y/n/s[skip]): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # terraform apply 실행
        log_info "terraform apply 실행 중..."
        layer_start_time=$(date +%s)
        
        if terraform apply "tfplan"; then
            layer_end_time=$(date +%s)
            layer_duration=$((layer_end_time - layer_start_time))
            log_success "$layer 레이어 배포 완료 (소요시간: ${layer_duration}초)"
            SUCCESSFUL_LAYERS=$((SUCCESSFUL_LAYERS + 1))
        else
            log_error "$layer 레이어 배포 실패"
            FAILED_LAYERS=$((FAILED_LAYERS + 1))
        fi
    elif [[ $REPLY =~ ^[Ss]$ ]]; then
        log_warning "$layer 레이어 건너뜀"
        SKIPPED_LAYERS=$((SKIPPED_LAYERS + 1))
    else
        log_warning "$layer 레이어 배포 취소됨"
        SKIPPED_LAYERS=$((SKIPPED_LAYERS + 1))
    fi
    
    # 계획 파일 정리
    rm -f tfplan
    
    # 프로젝트 루트로 돌아가기
    cd "$PROJECT_ROOT"
    
    echo ""
    
    # 실패 시 계속 진행할지 확인
    if [[ $FAILED_LAYERS -gt 0 ]]; then
        read -p "실패한 레이어가 있습니다. 계속 진행하시겠습니까? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "배포가 중단되었습니다."
            break
        fi
    fi
done

# 종료 시간 및 통계
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

log_header "배포 완료 요약"
echo "총 레이어 수: $TOTAL_LAYERS"
echo "성공한 레이어: $SUCCESSFUL_LAYERS"
echo "실패한 레이어: $FAILED_LAYERS"
echo "건너뛴 레이어: $SKIPPED_LAYERS"
echo "총 소요시간: ${TOTAL_MINUTES}분 ${TOTAL_SECONDS}초"
echo "완료 시간: $(date)"
echo ""

if [[ $FAILED_LAYERS -eq 0 ]]; then
    log_success "🎉 모든 레이어가 성공적으로 배포되었습니다!"
    echo ""
    echo "다음 단계:"
    echo "1. AWS 콘솔에서 리소스 확인"
    echo "2. 애플리케이션 배포 및 테스트"
    echo "3. 모니터링 대시보드 확인"
else
    log_error "❌ $FAILED_LAYERS개 레이어에서 오류가 발생했습니다."
    echo ""
    echo "문제 해결 방법:"
    echo "1. 실패한 레이어의 로그 확인"
    echo "2. AWS 콘솔에서 리소스 상태 확인"
    echo "3. 의존성 리소스가 올바르게 생성되었는지 확인"
    echo "4. 개별 레이어에서 terraform plan/apply 재실행"
fi

echo ""
log_header "배포 스크립트 종료"

# 종료 코드 설정
if [[ $FAILED_LAYERS -eq 0 ]]; then
    exit 0
else
    exit 1
fi