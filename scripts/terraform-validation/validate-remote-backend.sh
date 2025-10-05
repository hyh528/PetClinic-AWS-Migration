#!/bin/bash

# ==========================================
# Terraform 원격 백엔드 설정 검증 스크립트
# ==========================================
# 목적: 모든 레이어의 원격 백엔드 설정이 올바른지 검증
# 작성자: 영현
# 날짜: 2025-10-05

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 변수 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
DEV_ENV_DIR="$TERRAFORM_DIR/envs/dev"

# Bootstrap 설정
TFSTATE_BUCKET="petclinic-tfstate-team-jungsu-kopo"
DYNAMODB_TABLE="petclinic-tf-locks-jungsu-kopo"
AWS_REGION="ap-northeast-2"
AWS_PROFILE="petclinic-yeonghyeon"

# 검증 결과 저장
VALIDATION_RESULTS=()
TOTAL_LAYERS=0
VALID_LAYERS=0
INVALID_LAYERS=0

echo "=========================================="
echo "Terraform 원격 백엔드 설정 검증"
echo "=========================================="
echo "검증 시작 시간: $(date)"
echo "프로젝트 루트: $PROJECT_ROOT"
echo "대상 환경: dev"
echo ""

# 1. Bootstrap 인프라 검증
log_info "1. Bootstrap 인프라 검증 중..."

# S3 버킷 존재 확인
if aws s3 ls "s3://$TFSTATE_BUCKET" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    log_success "S3 버킷 '$TFSTATE_BUCKET' 존재 확인"
else
    log_error "S3 버킷 '$TFSTATE_BUCKET' 존재하지 않음"
    exit 1
fi

# DynamoDB 테이블 존재 확인
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    log_success "DynamoDB 테이블 '$DYNAMODB_TABLE' 존재 확인"
else
    log_error "DynamoDB 테이블 '$DYNAMODB_TABLE' 존재하지 않음"
    exit 1
fi

echo ""

# 2. 각 레이어의 backend.tf 파일 검증
log_info "2. 각 레이어의 backend.tf 파일 검증 중..."

# 레이어 목록 (디렉토리 기반으로 자동 탐지)
LAYERS=($(find "$DEV_ENV_DIR" -maxdepth 1 -type d -not -path "$DEV_ENV_DIR" -exec basename {} \; | sort))

for layer in "${LAYERS[@]}"; do
    TOTAL_LAYERS=$((TOTAL_LAYERS + 1))
    layer_dir="$DEV_ENV_DIR/$layer"
    backend_file="$layer_dir/backend.tf"
    
    log_info "검증 중: $layer 레이어"
    
    # backend.tf 파일 존재 확인
    if [[ ! -f "$backend_file" ]]; then
        log_error "  ❌ backend.tf 파일이 존재하지 않음: $backend_file"
        VALIDATION_RESULTS+=("$layer: backend.tf 파일 없음")
        INVALID_LAYERS=$((INVALID_LAYERS + 1))
        continue
    fi
    
    # backend.tf 파일 내용 검증
    if grep -q "backend \"s3\"" "$backend_file" && \
       grep -q "bucket.*=.*\"$TFSTATE_BUCKET\"" "$backend_file" && \
       grep -q "dynamodb_table.*=.*\"$DYNAMODB_TABLE\"" "$backend_file" && \
       grep -q "region.*=.*\"$AWS_REGION\"" "$backend_file" && \
       grep -q "encrypt.*=.*true" "$backend_file"; then
        
        # key 값 추출 및 검증
        key_value=$(grep -o 'key.*=.*"[^"]*"' "$backend_file" | sed 's/.*"\([^"]*\)".*/\1/')
        expected_key="dev/$layer/terraform.tfstate"
        
        # 특별한 케이스들 처리 (팀원별 디렉토리 구조)
        case "$layer" in
            "network")
                expected_key="dev/yeonghyeon/network/terraform.tfstate"
                ;;
            "security")
                expected_key="dev/hwigwon/security/terraform.tfstate"
                ;;
            "database")
                expected_key="dev/junje/database/terraform.tfstate"
                ;;
            "application")
                expected_key="dev/seokgyeom/application/terraform.tfstate"
                ;;
        esac
        
        if [[ "$key_value" == "$expected_key" ]]; then
            log_success "  ✅ backend.tf 설정이 올바름 (key: $key_value)"
            VALIDATION_RESULTS+=("$layer: 설정 올바름")
            VALID_LAYERS=$((VALID_LAYERS + 1))
        else
            log_warning "  ⚠️  key 값이 예상과 다름 (실제: $key_value, 예상: $expected_key)"
            VALIDATION_RESULTS+=("$layer: key 값 불일치")
            VALID_LAYERS=$((VALID_LAYERS + 1))  # 동작은 하지만 경고
        fi
    else
        log_error "  ❌ backend.tf 설정이 올바르지 않음"
        VALIDATION_RESULTS+=("$layer: 설정 오류")
        INVALID_LAYERS=$((INVALID_LAYERS + 1))
    fi
    
    echo ""
done

# 3. S3 버킷 내 상태 파일 확인
log_info "3. S3 버킷 내 상태 파일 확인 중..."

state_files=$(aws s3 ls "s3://$TFSTATE_BUCKET/dev/" --recursive --profile "$AWS_PROFILE" 2>/dev/null | awk '{print $4}' || true)

if [[ -n "$state_files" ]]; then
    log_success "발견된 상태 파일들:"
    echo "$state_files" | while read -r file; do
        if [[ -n "$file" ]]; then
            echo "  - $file"
        fi
    done
else
    log_warning "S3 버킷에 상태 파일이 없음 (아직 terraform apply를 실행하지 않았을 수 있음)"
fi

echo ""

# 4. 검증 결과 요약
echo "=========================================="
echo "검증 결과 요약"
echo "=========================================="
echo "총 레이어 수: $TOTAL_LAYERS"
echo "올바른 설정: $VALID_LAYERS"
echo "잘못된 설정: $INVALID_LAYERS"
echo ""

if [[ $INVALID_LAYERS -eq 0 ]]; then
    log_success "🎉 모든 레이어의 원격 백엔드 설정이 올바릅니다!"
    echo ""
    echo "다음 단계:"
    echo "1. 각 레이어에서 'terraform init' 실행하여 원격 백엔드로 마이그레이션"
    echo "2. 'terraform plan' 실행하여 설정 확인"
    echo "3. 'terraform apply' 실행하여 인프라 배포"
else
    log_error "❌ $INVALID_LAYERS개 레이어에 문제가 있습니다."
    echo ""
    echo "문제가 있는 레이어들:"
    for result in "${VALIDATION_RESULTS[@]}"; do
        if [[ "$result" == *"없음"* ]] || [[ "$result" == *"오류"* ]]; then
            echo "  - $result"
        fi
    done
fi

echo ""
echo "검증 완료 시간: $(date)"
echo "=========================================="

# 종료 코드 설정
if [[ $INVALID_LAYERS -eq 0 ]]; then
    exit 0
else
    exit 1
fi