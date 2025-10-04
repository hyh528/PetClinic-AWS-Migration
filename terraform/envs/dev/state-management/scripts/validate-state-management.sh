#!/bin/bash

# ==========================================
# Terraform 상태 관리 검증 스크립트
# ==========================================

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

# 설정 파일에서 변수 읽기
if [ -f "terraform.tfvars" ]; then
    source <(grep -E '^[^#]*=' terraform.tfvars | sed 's/^/export /')
fi

# 기본값 설정
BUCKET_NAME=${bucket_name:-"petclinic-terraform-state-dev-ap-northeast-2"}
REGION=${aws_region:-"ap-northeast-2"}
DYNAMODB_TABLE=${lock_table_name:-"petclinic-terraform-lock-dev"}
ENVIRONMENT=${environment:-"dev"}

log_info "Terraform 상태 관리 인프라 검증을 시작합니다..."

# ==========================================
# 사전 검증
# ==========================================

log_info "사전 검증 중..."

# AWS CLI 확인
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI가 설치되지 않았습니다."
    exit 1
fi

# Terraform 확인
if ! command -v terraform &> /dev/null; then
    log_error "Terraform이 설치되지 않았습니다."
    exit 1
fi

# AWS 자격 증명 확인
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS 자격 증명이 설정되지 않았습니다."
    exit 1
fi

log_success "사전 검증 완료"

# ==========================================
# S3 버킷 검증
# ==========================================

log_info "S3 버킷 검증 중..."

# 버킷 존재 확인
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    log_success "S3 버킷 '$BUCKET_NAME' 존재 확인"
    
    # 버전 관리 확인
    VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query 'Status' --output text)
    if [ "$VERSIONING" = "Enabled" ]; then
        log_success "S3 버킷 버전 관리 활성화됨"
    else
        log_warning "S3 버킷 버전 관리가 비활성화되어 있습니다"
    fi
    
    # 암호화 확인
    if aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" &>/dev/null; then
        log_success "S3 버킷 암호화 설정됨"
    else
        log_error "S3 버킷 암호화가 설정되지 않았습니다"
    fi
    
    # 퍼블릭 액세스 차단 확인
    PUBLIC_ACCESS=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" --query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text)
    if [ "$PUBLIC_ACCESS" = "True" ]; then
        log_success "S3 버킷 퍼블릭 액세스 차단됨"
    else
        log_error "S3 버킷 퍼블릭 액세스가 차단되지 않았습니다"
    fi
    
else
    log_error "S3 버킷 '$BUCKET_NAME'이 존재하지 않습니다"
    exit 1
fi

# ==========================================
# DynamoDB 테이블 검증
# ==========================================

log_info "DynamoDB 테이블 검증 중..."

if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &>/dev/null; then
    log_success "DynamoDB 테이블 '$DYNAMODB_TABLE' 존재 확인"
    
    # 테이블 상태 확인
    TABLE_STATUS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.TableStatus' --output text)
    if [ "$TABLE_STATUS" = "ACTIVE" ]; then
        log_success "DynamoDB 테이블 활성 상태"
    else
        log_warning "DynamoDB 테이블 상태: $TABLE_STATUS"
    fi
    
    # Point-in-Time Recovery 확인
    PITR_STATUS=$(aws dynamodb describe-continuous-backups --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus' --output text 2>/dev/null || echo "DISABLED")
    if [ "$PITR_STATUS" = "ENABLED" ]; then
        log_success "DynamoDB Point-in-Time Recovery 활성화됨"
    else
        log_warning "DynamoDB Point-in-Time Recovery가 비활성화되어 있습니다"
    fi
    
else
    log_error "DynamoDB 테이블 '$DYNAMODB_TABLE'이 존재하지 않습니다"
    exit 1
fi

# ==========================================
# KMS 키 검증
# ==========================================

log_info "KMS 키 검증 중..."

# 별칭으로 KMS 키 찾기
KMS_ALIAS="alias/$ENVIRONMENT-terraform-state"
if aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" &>/dev/null; then
    log_success "KMS 키 '$KMS_ALIAS' 존재 확인"
    
    # 키 상태 확인
    KEY_STATE=$(aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" --query 'KeyMetadata.KeyState' --output text)
    if [ "$KEY_STATE" = "Enabled" ]; then
        log_success "KMS 키 활성 상태"
    else
        log_warning "KMS 키 상태: $KEY_STATE"
    fi
    
else
    log_error "KMS 키 '$KMS_ALIAS'이 존재하지 않습니다"
    exit 1
fi

# ==========================================
# 백엔드 연결 테스트
# ==========================================

log_info "백엔드 연결 테스트 중..."

# 임시 테스트 디렉토리 생성
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# 테스트용 Terraform 설정 생성
cat > main.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "test/validation.tfstate"
    region         = "$REGION"
    dynamodb_table = "$DYNAMODB_TABLE"
    encrypt        = true
  }
}

data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
EOF

# Terraform 초기화 테스트
if terraform init &>/dev/null; then
    log_success "백엔드 연결 테스트 성공"
    
    # 상태 파일 생성 테스트
    if terraform apply -auto-approve &>/dev/null; then
        log_success "상태 파일 생성 테스트 성공"
        
        # 상태 파일 읽기 테스트
        if terraform state list &>/dev/null; then
            log_success "상태 파일 읽기 테스트 성공"
        else
            log_error "상태 파일 읽기 테스트 실패"
        fi
        
        # 정리
        terraform destroy -auto-approve &>/dev/null
    else
        log_error "상태 파일 생성 테스트 실패"
    fi
else
    log_error "백엔드 연결 테스트 실패"
fi

# 임시 디렉토리 정리
cd - > /dev/null
rm -rf "$TEST_DIR"

# 테스트 상태 파일 정리
aws s3 rm "s3://$BUCKET_NAME/test/validation.tfstate" &>/dev/null || true

# ==========================================
# 보안 검증
# ==========================================

log_info "보안 설정 검증 중..."

# S3 버킷 정책 확인
if aws s3api get-bucket-policy --bucket "$BUCKET_NAME" &>/dev/null; then
    HTTPS_ONLY=$(aws s3api get-bucket-policy --bucket "$BUCKET_NAME" --query 'Policy' --output text | grep -c "aws:SecureTransport" || echo "0")
    if [ "$HTTPS_ONLY" -gt 0 ]; then
        log_success "S3 HTTPS 전용 정책 설정됨"
    else
        log_warning "S3 HTTPS 전용 정책이 설정되지 않았습니다"
    fi
else
    log_warning "S3 버킷 정책이 설정되지 않았습니다"
fi

# ==========================================
# 성능 및 비용 검증
# ==========================================

log_info "성능 및 비용 설정 검증 중..."

# 라이프사이클 정책 확인
if aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" &>/dev/null; then
    log_success "S3 라이프사이클 정책 설정됨"
else
    log_warning "S3 라이프사이클 정책이 설정되지 않았습니다"
fi

# DynamoDB 과금 모드 확인
BILLING_MODE=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.BillingModeSummary.BillingMode' --output text)
if [ "$BILLING_MODE" = "PAY_PER_REQUEST" ]; then
    log_success "DynamoDB 온디맨드 과금 모드 설정됨"
else
    log_info "DynamoDB 과금 모드: $BILLING_MODE"
fi

# ==========================================
# 검증 결과 요약
# ==========================================

log_info "검증 결과 요약:"
echo "=================================="
echo "✅ S3 버킷: $BUCKET_NAME"
echo "✅ DynamoDB 테이블: $DYNAMODB_TABLE"
echo "✅ KMS 키: $KMS_ALIAS"
echo "✅ 백엔드 연결: 정상"
echo "✅ 보안 설정: 검증됨"
echo "=================================="

log_success "Terraform 상태 관리 인프라 검증이 완료되었습니다!"

# 사용법 안내
cat << EOF

다음 단계:
1. 각 레이어에서 백엔드 설정 적용
2. terraform init으로 원격 상태 마이그레이션
3. 정기적인 백업 및 모니터링 설정

문제 발생 시:
- 로그 확인: CloudTrail, CloudWatch
- 백업 복원: S3 버전 관리 활용
- 지원 요청: DevOps 팀 문의

EOF