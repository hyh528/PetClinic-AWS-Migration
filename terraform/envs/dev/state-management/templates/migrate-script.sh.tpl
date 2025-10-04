#!/bin/bash

# ==========================================
# Terraform 원격 상태 마이그레이션 스크립트
# ==========================================
# 이 스크립트는 자동 생성되었습니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() {
    echo -e "$${BLUE}[INFO]$${NC} $1"
}

log_success() {
    echo -e "$${GREEN}[SUCCESS]$${NC} $1"
}

log_warning() {
    echo -e "$${YELLOW}[WARNING]$${NC} $1"
}

log_error() {
    echo -e "$${RED}[ERROR]$${NC} $1"
}

# 설정 변수
BUCKET_NAME="${bucket}"
REGION="${region}"
DYNAMODB_TABLE="${dynamodb_table}"
KMS_KEY_ID="${kms_key_id}"
ENVIRONMENT="${environment}"

# 레이어 목록
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
)

log_info "Terraform 원격 상태 마이그레이션을 시작합니다..."
log_info "환경: $ENVIRONMENT"
log_info "S3 버킷: $BUCKET_NAME"
log_info "DynamoDB 테이블: $DYNAMODB_TABLE"

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI가 설치되지 않았습니다."
    exit 1
fi

# Terraform 설치 확인
if ! command -v terraform &> /dev/null; then
    log_error "Terraform이 설치되지 않았습니다."
    exit 1
fi

# AWS 자격 증명 확인
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS 자격 증명이 설정되지 않았습니다."
    exit 1
fi

# S3 버킷 존재 확인
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    log_error "S3 버킷 '$BUCKET_NAME'이 존재하지 않습니다."
    log_info "먼저 state-management 레이어를 배포하세요."
    exit 1
fi

# DynamoDB 테이블 존재 확인
if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &> /dev/null; then
    log_error "DynamoDB 테이블 '$DYNAMODB_TABLE'이 존재하지 않습니다."
    exit 1
fi

log_success "사전 검증이 완료되었습니다."

# 각 레이어별 마이그레이션
for layer in "$${LAYERS[@]}"; do
    layer_path="../$layer"
    
    if [ ! -d "$layer_path" ]; then
        log_warning "레이어 '$layer' 디렉토리가 존재하지 않습니다. 건너뜁니다."
        continue
    fi
    
    log_info "레이어 '$layer' 마이그레이션 중..."
    
    cd "$layer_path"
    
    # 로컬 상태 파일 존재 확인
    if [ ! -f "terraform.tfstate" ]; then
        log_warning "레이어 '$layer'에 로컬 상태 파일이 없습니다. 건너뜁니다."
        cd - > /dev/null
        continue
    fi
    
    # 백업 생성
    cp terraform.tfstate "terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "로컬 상태 파일 백업 생성됨"
    
    # backend.tf 파일 존재 확인
    if [ ! -f "backend.tf" ]; then
        log_error "레이어 '$layer'에 backend.tf 파일이 없습니다."
        cd - > /dev/null
        continue
    fi
    
    # Terraform 초기화 (백엔드 마이그레이션)
    log_info "Terraform 백엔드 초기화 중..."
    if terraform init -migrate-state -force-copy; then
        log_success "레이어 '$layer' 마이그레이션 완료"
        
        # 원격 상태 검증
        if terraform state list > /dev/null 2>&1; then
            log_success "원격 상태 검증 완료"
            
            # 로컬 상태 파일 정리 (선택사항)
            read -p "로컬 상태 파일을 삭제하시겠습니까? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -f terraform.tfstate terraform.tfstate.backup
                log_success "로컬 상태 파일 정리 완료"
            fi
        else
            log_error "원격 상태 검증 실패"
        fi
    else
        log_error "레이어 '$layer' 마이그레이션 실패"
    fi
    
    cd - > /dev/null
    echo
done

log_success "모든 레이어의 마이그레이션이 완료되었습니다!"

# 마이그레이션 후 검증
log_info "마이그레이션 검증 중..."

for layer in "$${LAYERS[@]}"; do
    layer_path="../$layer"
    
    if [ ! -d "$layer_path" ]; then
        continue
    fi
    
    cd "$layer_path"
    
    if [ -f "backend.tf" ]; then
        if terraform state list > /dev/null 2>&1; then
            log_success "레이어 '$layer': 원격 상태 정상"
        else
            log_error "레이어 '$layer': 원격 상태 오류"
        fi
    fi
    
    cd - > /dev/null
done

log_info "마이그레이션 검증 완료"

# 사용법 안내
cat << EOF

==========================================
마이그레이션 완료 안내
==========================================

다음 단계:
1. 각 레이어에서 'terraform plan'을 실행하여 상태 일관성 확인
2. 팀원들에게 새로운 백엔드 설정 공유
3. CI/CD 파이프라인 업데이트 (필요한 경우)

주의사항:
- 이제 모든 Terraform 작업은 원격 상태를 사용합니다
- 동시 실행 시 DynamoDB 잠금이 자동으로 적용됩니다
- 상태 파일은 KMS로 암호화되어 S3에 저장됩니다

문제 발생 시:
- 백업된 로컬 상태 파일을 사용하여 복구 가능
- 각 레이어의 terraform.tfstate.backup.* 파일 참조

==========================================
EOF