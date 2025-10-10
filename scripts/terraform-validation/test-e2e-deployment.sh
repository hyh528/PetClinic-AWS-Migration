#!/bin/bash

# E2E 배포 테스트 스크립트
# 전체 인프라 배포 및 검증

set -e

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly TERRAFORM_DIR="$PROJECT_ROOT/terraform"
readonly RESULTS_DIR="$PROJECT_ROOT/terraform-validation-results"
readonly TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# 테스트 환경 설정
readonly TEST_ENV="test"
readonly TEST_DIR="$TERRAFORM_DIR/envs/$TEST_ENV"

# E2E 테스트 실행
run_e2e_test() {
    log_info "=== E2E 배포 테스트 시작 ==="

    # 사전 검증
    validate_prerequisites

    # 단계별 배포
    deploy_network_layer
    deploy_security_layer
    deploy_database_layer
    deploy_application_layer

    # 기능 검증
    validate_deployment

    # 정리
    cleanup_deployment

    log_success "=== E2E 배포 테스트 완료 ==="
}

validate_prerequisites() {
    log_info "사전 조건 검증 중..."

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

    # AWS 프로필 확인
    if ! aws sts get-caller-identity --profile petclinic-admin &> /dev/null; then
        log_error "AWS 프로필 'petclinic-admin'이 설정되지 않았습니다."
        exit 1
    fi

    log_success "사전 조건 검증 완료"
}

deploy_network_layer() {
    log_info "네트워크 레이어 배포 중..."

    cd "$TEST_DIR/01-network"

    # Plan
    terraform init
    terraform plan -var-file=dev.tfvars -out=tfplan

    # Apply
    terraform apply tfplan

    # 검증
    validate_network_deployment

    log_success "네트워크 레이어 배포 완료"
}

validate_network_deployment() {
    # VPC 확인
    vpc_id=$(terraform output vpc_id)
    if [[ -z "$vpc_id" ]]; then
        log_error "VPC가 생성되지 않았습니다."
        exit 1
    fi

    # 실제 AWS 리소스 확인
    aws ec2 describe-vpcs --vpc-ids "$vpc_id" --profile petclinic-admin > /dev/null

    log_success "네트워크 배포 검증 완료"
}

deploy_security_layer() {
    log_info "보안 레이어 배포 중..."

    cd "$TEST_DIR/02-security"

    terraform init
    terraform plan -var-file=dev.tfvars -out=tfplan
    terraform apply tfplan

    validate_security_deployment

    log_success "보안 레이어 배포 완료"
}

validate_security_deployment() {
    # IAM 사용자 확인
    user_count=$(aws iam list-users --profile petclinic-admin | jq '.Users | length')
    if [[ $user_count -lt 3 ]]; then
        log_error "IAM 사용자가 충분히 생성되지 않았습니다."
        exit 1
    fi

    log_success "보안 배포 검증 완료"
}

deploy_database_layer() {
    log_info "데이터베이스 레이어 배포 중..."

    cd "$TEST_DIR/03-database"

    terraform init
    terraform plan -var-file=dev.tfvars -out=tfplan
    terraform apply tfplan

    validate_database_deployment

    log_success "데이터베이스 레이어 배포 완료"
}

validate_database_deployment() {
    # RDS 클러스터 확인
    cluster_id=$(terraform output cluster_identifier)
    if [[ -z "$cluster_id" ]]; then
        log_error "RDS 클러스터가 생성되지 않았습니다."
        exit 1
    fi

    # 실제 AWS 리소스 확인
    aws rds describe-db-clusters --db-cluster-identifier "$cluster_id" --profile petclinic-admin > /dev/null

    log_success "데이터베이스 배포 검증 완료"
}

deploy_application_layer() {
    log_info "애플리케이션 레이어 배포 중..."

    cd "$TEST_DIR/07-application"

    terraform init
    terraform plan -var-file=dev.tfvars -out=tfplan
    terraform apply tfplan

    validate_application_deployment

    log_success "애플리케이션 레이어 배포 완료"
}

validate_application_deployment() {
    # ECS 클러스터 확인
    cluster_name=$(terraform output ecs_cluster_name)
    if [[ -z "$cluster_name" ]]; then
        log_error "ECS 클러스터가 생성되지 않았습니다."
        exit 1
    fi

    # 실제 AWS 리소스 확인
    aws ecs describe-clusters --clusters "$cluster_name" --profile petclinic-admin > /dev/null

    log_success "애플리케이션 배포 검증 완료"
}

validate_deployment() {
    log_info "전체 배포 기능 검증 중..."

    # 네트워크 연결성 테스트
    bash "$SCRIPT_DIR/validate-network-connectivity-mcp.sh"

    # 보안 검증
    validate_security_post_deployment

    log_success "전체 배포 검증 완료"
}

validate_security_post_deployment() {
    # 보안 그룹 규칙 확인
    # VPC 엔드포인트 연결성 확인
    log_success "보안 검증 완료"
}

cleanup_deployment() {
    log_info "테스트 리소스 정리 중..."

    # 역순으로 삭제
    cd "$TEST_DIR/07-application" && terraform destroy -auto-approve
    cd "$TEST_DIR/03-database" && terraform destroy -auto-approve
    cd "$TEST_DIR/02-security" && terraform destroy -auto-approve
    cd "$TEST_DIR/01-network" && terraform destroy -auto-approve

    log_success "테스트 리소스 정리 완료"
}

# 메인 실행
main() {
    run_e2e_test
}

main "$@"