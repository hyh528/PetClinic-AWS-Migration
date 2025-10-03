#!/bin/bash

# 보안 설정 종합 검증 스크립트
# 보안 그룹, IAM 정책, VPC 엔드포인트, 암호화 설정 검증

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
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

# 검증 결과 저장
VALIDATION_RESULTS=()
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 결과 기록 함수
record_result() {
    local test_name=$1
    local status=$2
    local message=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$status" = "PASS" ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_success "$test_name: $message"
    elif [ "$status" = "WARNING" ]; then
        log_warning "$test_name: $message"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_error "$test_name: $message"
    fi
    
    VALIDATION_RESULTS+=("$test_name|$status|$message")
}

# 보안 레이어 경로
SECURITY_PATH="terraform/envs/dev/security"

# 보안 그룹 규칙 검증
validate_security_groups() {
    log_info "=== 보안 그룹 규칙 검증 ==="
    
    local security_module="terraform/modules/security/main.tf"
    local security_vars="terraform/modules/security/variables.tf"
    
    # ECS 보안 그룹 존재 확인
    if grep -q "resource \"aws_security_group\" \"ecs\"" "$security_module"; then
        record_result "ECS_SECURITY_GROUP" "PASS" "ECS 보안 그룹이 정의됨"
    else
        record_result "ECS_SECURITY_GROUP" "FAIL" "ECS 보안 그룹이 누락됨"
    fi
    
    # RDS 보안 그룹 존재 확인
    if grep -q "resource \"aws_security_group\" \"rds\"" "$security_module"; then
        record_result "RDS_SECURITY_GROUP" "PASS" "RDS 보안 그룹이 정의됨"
    else
        record_result "RDS_SECURITY_GROUP" "FAIL" "RDS 보안 그룹이 누락됨"
    fi
    
    # ALB → ECS 인바운드 규칙 확인
    if grep -q "aws_vpc_security_group_ingress_rule.*ecs_in_from_alb" "$security_module"; then
        record_result "ALB_TO_ECS_INGRESS" "PASS" "ALB에서 ECS로의 인바운드 규칙이 설정됨"
    else
        record_result "ALB_TO_ECS_INGRESS" "WARNING" "ALB에서 ECS로의 인바운드 규칙이 조건부 설정됨"
    fi
    
    # ECS → RDS 인바운드 규칙 확인
    if grep -q "aws_vpc_security_group_ingress_rule.*rds_in_from_ecs" "$security_module"; then
        record_result "ECS_TO_RDS_INGRESS" "PASS" "ECS에서 RDS로의 인바운드 규칙이 설정됨"
    else
        record_result "ECS_TO_RDS_INGRESS" "FAIL" "ECS에서 RDS로의 인바운드 규칙이 누락됨"
    fi
    
    # ECS 아웃바운드 규칙 (VPC 엔드포인트 우선) 확인
    if grep -q "aws_vpc_security_group_egress_rule.*ecs_out_to_vpce_443" "$security_module"; then
        record_result "ECS_VPCE_EGRESS" "PASS" "ECS에서 VPC 엔드포인트로의 HTTPS 아웃바운드 규칙이 설정됨"
    else
        record_result "ECS_VPCE_EGRESS" "FAIL" "ECS VPC 엔드포인트 아웃바운드 규칙이 누락됨"
    fi
    
    # 인터넷 폴백 규칙 확인
    if grep -q "aws_vpc_security_group_egress_rule.*ecs_out_to_internet_443" "$security_module"; then
        record_result "ECS_INTERNET_FALLBACK" "PASS" "ECS 인터넷 HTTPS 폴백 규칙이 설정됨"
    else
        record_result "ECS_INTERNET_FALLBACK" "WARNING" "ECS 인터넷 폴백 규칙이 누락됨"
    fi
    
    # 포트 설정 확인
    if grep -q "default.*=.*8080" "$security_vars"; then
        record_result "ECS_PORT_CONFIG" "PASS" "ECS 태스크 포트가 8080으로 설정됨"
    else
        record_result "ECS_PORT_CONFIG" "WARNING" "ECS 태스크 포트 설정 확인 필요"
    fi
    
    if grep -q "default.*=.*3306" "$security_vars"; then
        record_result "RDS_PORT_CONFIG" "PASS" "RDS 포트가 3306(MySQL)으로 설정됨"
    else
        record_result "RDS_PORT_CONFIG" "WARNING" "RDS 포트 설정 확인 필요"
    fi
    
    # 보안 그룹 태그 확인
    if grep -q "tags.*=.*merge" "$security_module"; then
        record_result "SECURITY_GROUP_TAGS" "PASS" "보안 그룹에 태그가 설정됨"
    else
        record_result "SECURITY_GROUP_TAGS" "FAIL" "보안 그룹 태그 설정이 누락됨"
    fi
}

# VPC 엔드포인트 보안 검증
validate_vpc_endpoints() {
    log_info "=== VPC 엔드포인트 보안 검증 ==="
    
    local endpoints_module="terraform/modules/endpoints/main.tf"
    local endpoints_vars="terraform/modules/endpoints/variables.tf"
    
    # VPC 엔드포인트 보안 그룹 존재 확인
    if grep -q "resource \"aws_security_group\" \"vpce\"" "$endpoints_module"; then
        record_result "VPCE_SECURITY_GROUP" "PASS" "VPC 엔드포인트 보안 그룹이 정의됨"
    else
        record_result "VPCE_SECURITY_GROUP" "FAIL" "VPC 엔드포인트 보안 그룹이 누락됨"
    fi
    
    # VPC CIDR에서 HTTPS 인바운드 규칙 확인
    if grep -q "aws_vpc_security_group_ingress_rule.*vpce_https_ipv4" "$endpoints_module"; then
        record_result "VPCE_HTTPS_INGRESS" "PASS" "VPC 엔드포인트 HTTPS 인바운드 규칙이 설정됨"
    else
        record_result "VPCE_HTTPS_INGRESS" "FAIL" "VPC 엔드포인트 HTTPS 인바운드 규칙이 누락됨"
    fi
    
    # S3 게이트웨이 엔드포인트 확인
    if grep -q "resource \"aws_vpc_endpoint\" \"s3\"" "$endpoints_module"; then
        record_result "S3_GATEWAY_ENDPOINT" "PASS" "S3 게이트웨이 엔드포인트가 설정됨"
    else
        record_result "S3_GATEWAY_ENDPOINT" "FAIL" "S3 게이트웨이 엔드포인트가 누락됨"
    fi
    
    # 인터페이스 엔드포인트 확인
    if grep -q "resource \"aws_vpc_endpoint\" \"interface\"" "$endpoints_module"; then
        record_result "INTERFACE_ENDPOINTS" "PASS" "인터페이스 엔드포인트가 설정됨"
    else
        record_result "INTERFACE_ENDPOINTS" "FAIL" "인터페이스 엔드포인트가 누락됨"
    fi
    
    # 필수 AWS 서비스 엔드포인트 확인
    local required_services=("ecr.api" "ecr.dkr" "logs" "secretsmanager" "ssm" "kms")
    for service in "${required_services[@]}"; do
        if grep -q "\"$service\"" "$endpoints_vars"; then
            record_result "ENDPOINT_$service" "PASS" "$service 엔드포인트가 포함됨"
        else
            record_result "ENDPOINT_$service" "WARNING" "$service 엔드포인트가 기본 목록에 없음"
        fi
    done
    
    # Private DNS 활성화 확인
    if grep -q "private_dns_enabled.*=.*true" "$endpoints_module"; then
        record_result "VPCE_PRIVATE_DNS" "PASS" "VPC 엔드포인트 Private DNS가 활성화됨"
    else
        record_result "VPCE_PRIVATE_DNS" "FAIL" "VPC 엔드포인트 Private DNS 설정이 누락됨"
    fi
}

# IAM 정책 검증
validate_iam_policies() {
    log_info "=== IAM 정책 검증 ==="
    
    local iam_module="terraform/modules/iam/main.tf"
    
    # IAM 모듈 존재 확인
    if [ -f "$iam_module" ]; then
        record_result "IAM_MODULE_EXISTS" "PASS" "IAM 모듈이 존재함"
        
        # 팀 멤버 기반 사용자 생성 확인
        if grep -q "aws_iam_user" "$iam_module"; then
            record_result "IAM_USERS" "PASS" "IAM 사용자가 정의됨"
        else
            record_result "IAM_USERS" "WARNING" "IAM 사용자 정의가 없음"
        fi
        
        # IAM 그룹 확인
        if grep -q "aws_iam_group" "$iam_module"; then
            record_result "IAM_GROUPS" "PASS" "IAM 그룹이 정의됨"
        else
            record_result "IAM_GROUPS" "WARNING" "IAM 그룹 정의가 없음"
        fi
        
        # 정책 연결 확인
        if grep -q "aws_iam_user_group_membership\|aws_iam_group_policy_attachment" "$iam_module"; then
            record_result "IAM_POLICY_ATTACHMENTS" "PASS" "IAM 정책 연결이 설정됨"
        else
            record_result "IAM_POLICY_ATTACHMENTS" "WARNING" "IAM 정책 연결 확인 필요"
        fi
        
    else
        record_result "IAM_MODULE_EXISTS" "FAIL" "IAM 모듈이 존재하지 않음"
    fi
    
    # ECS 태스크 역할 확인 (application 레이어에서 정의될 수 있음)
    local app_path="terraform/envs/dev/application"
    if [ -d "$app_path" ]; then
        if find "$app_path" -name "*.tf" -exec grep -l "aws_iam_role.*ecs" {} \; | head -1 > /dev/null; then
            record_result "ECS_TASK_ROLES" "PASS" "ECS 태스크 역할이 정의됨"
        else
            record_result "ECS_TASK_ROLES" "WARNING" "ECS 태스크 역할 확인 필요"
        fi
    fi
}

# 암호화 설정 검증
validate_encryption() {
    log_info "=== 암호화 설정 검증 ==="
    
    # Secrets Manager 암호화 확인
    local app_secrets="terraform/envs/dev/application/secrets.tf"
    if [ -f "$app_secrets" ]; then
        record_result "SECRETS_MANAGER_FILE" "PASS" "Secrets Manager 설정 파일이 존재함"
        
        if grep -q "kms_key_id" "$app_secrets"; then
            record_result "SECRETS_KMS_ENCRYPTION" "PASS" "Secrets Manager KMS 암호화가 설정됨"
        else
            record_result "SECRETS_KMS_ENCRYPTION" "WARNING" "Secrets Manager KMS 암호화 확인 필요"
        fi
    else
        record_result "SECRETS_MANAGER_FILE" "WARNING" "Secrets Manager 설정 파일이 없음"
    fi
    
    # Aurora 암호화 확인 (database 레이어)
    local db_main="terraform/envs/dev/database/main.tf"
    if [ -f "$db_main" ]; then
        if grep -q "storage_encrypted.*=.*true\|kms_key_id" "$db_main"; then
            record_result "AURORA_ENCRYPTION" "PASS" "Aurora 저장 시 암호화가 설정됨"
        else
            record_result "AURORA_ENCRYPTION" "WARNING" "Aurora 암호화 설정 확인 필요"
        fi
    else
        record_result "AURORA_ENCRYPTION" "WARNING" "데이터베이스 설정 파일 확인 필요"
    fi
    
    # Terraform 상태 파일 암호화 확인
    local backend_files=("$SECURITY_PATH/backend.tf" "terraform/envs/dev/network/backend.tf")
    local encrypted_backends=0
    
    for backend_file in "${backend_files[@]}"; do
        if [ -f "$backend_file" ] && grep -q "encrypt.*=.*true" "$backend_file"; then
            encrypted_backends=$((encrypted_backends + 1))
        fi
    done
    
    if [ $encrypted_backends -gt 0 ]; then
        record_result "TERRAFORM_STATE_ENCRYPTION" "PASS" "Terraform 상태 파일 암호화가 설정됨"
    else
        record_result "TERRAFORM_STATE_ENCRYPTION" "FAIL" "Terraform 상태 파일 암호화가 설정되지 않음"
    fi
}

# 네트워크 보안 검증
validate_network_security() {
    log_info "=== 네트워크 보안 검증 ==="
    
    local security_main="$SECURITY_PATH/main.tf"
    
    # VPC 엔드포인트 사용 확인
    if grep -q "module \"endpoints\"" "$security_main"; then
        record_result "VPC_ENDPOINTS_MODULE" "PASS" "VPC 엔드포인트 모듈이 사용됨"
    else
        record_result "VPC_ENDPOINTS_MODULE" "FAIL" "VPC 엔드포인트 모듈이 누락됨"
    fi
    
    # 보안 그룹 모듈 사용 확인
    if grep -q "module \"security\"" "$security_main"; then
        record_result "SECURITY_MODULE" "PASS" "보안 그룹 모듈이 사용됨"
    else
        record_result "SECURITY_MODULE" "FAIL" "보안 그룹 모듈이 누락됨"
    fi
    
    # 프라이빗 서브넷 배치 확인 (간접적)
    if grep -q "private_app_subnet_ids" "$security_main"; then
        record_result "PRIVATE_SUBNET_USAGE" "PASS" "프라이빗 서브넷 사용이 확인됨"
    else
        record_result "PRIVATE_SUBNET_USAGE" "WARNING" "프라이빗 서브넷 사용 확인 필요"
    fi
    
    # 최소 권한 원칙 확인 (보안 그룹 참조 사용)
    local security_module="terraform/modules/security/main.tf"
    local sg_references=$(grep -c "referenced_security_group_id" "$security_module" 2>/dev/null || echo "0")
    
    if [ "$sg_references" -ge 3 ]; then
        record_result "LEAST_PRIVILEGE_SG" "PASS" "보안 그룹 간 참조를 통한 최소 권한 원칙 적용됨"
    else
        record_result "LEAST_PRIVILEGE_SG" "WARNING" "보안 그룹 최소 권한 원칙 확인 필요"
    fi
}

# 컴플라이언스 검증
validate_compliance() {
    log_info "=== 컴플라이언스 검증 ==="
    
    # 태그 표준화 확인
    local tag_usage=0
    local tf_files=(
        "$SECURITY_PATH/main.tf"
        "terraform/modules/security/main.tf"
        "terraform/modules/endpoints/main.tf"
    )
    
    for tf_file in "${tf_files[@]}"; do
        if [ -f "$tf_file" ] && grep -q "tags.*=.*merge\|Environment.*=\|Project.*=" "$tf_file"; then
            tag_usage=$((tag_usage + 1))
        fi
    done
    
    if [ $tag_usage -ge 2 ]; then
        record_result "TAG_STANDARDIZATION" "PASS" "태그 표준화가 적용됨"
    else
        record_result "TAG_STANDARDIZATION" "WARNING" "태그 표준화 확인 필요"
    fi
    
    # 리소스 명명 규칙 확인
    if grep -q "name_prefix" "$SECURITY_PATH/main.tf"; then
        record_result "NAMING_CONVENTION" "PASS" "리소스 명명 규칙이 적용됨"
    else
        record_result "NAMING_CONVENTION" "FAIL" "리소스 명명 규칙이 누락됨"
    fi
    
    # 환경 분리 확인
    if grep -q "environment.*=.*\"dev\"" "$SECURITY_PATH/main.tf"; then
        record_result "ENVIRONMENT_SEPARATION" "PASS" "환경 분리가 설정됨"
    else
        record_result "ENVIRONMENT_SEPARATION" "WARNING" "환경 분리 설정 확인 필요"
    fi
    
    # 문서화 확인 (주석)
    local security_module="terraform/modules/security/main.tf"
    local comment_lines=$(grep -c "^#\|description.*=" "$security_module" 2>/dev/null || echo "0")
    
    if [ "$comment_lines" -ge 5 ]; then
        record_result "DOCUMENTATION" "PASS" "코드 문서화가 충분함"
    else
        record_result "DOCUMENTATION" "WARNING" "코드 문서화 개선 필요"
    fi
}

# 요약 리포트 생성
generate_summary() {
    echo ""
    echo "=========================================="
    echo "        보안 설정 검증 결과 요약"
    echo "=========================================="
    echo ""
    echo "📊 전체 통계:"
    echo "   총 테스트: $TOTAL_TESTS"
    echo "   성공: $PASSED_TESTS"
    echo "   실패: $FAILED_TESTS"
    if [ $TOTAL_TESTS -gt 0 ]; then
        echo "   성공률: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
    fi
    echo ""
    
    if [ $FAILED_TESTS -gt 0 ]; then
        echo "❌ 실패한 테스트:"
        for result in "${VALIDATION_RESULTS[@]}"; do
            IFS='|' read -r test_name status message <<< "$result"
            if [ "$status" = "FAIL" ]; then
                echo "   $test_name: $message"
            fi
        done
        echo ""
    fi
    
    # 경고 항목 표시
    local warning_count=0
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r test_name status message <<< "$result"
        if [ "$status" = "WARNING" ]; then
            warning_count=$((warning_count + 1))
        fi
    done
    
    if [ $warning_count -gt 0 ]; then
        echo "⚠️  경고 항목 ($warning_count개):"
        for result in "${VALIDATION_RESULTS[@]}"; do
            IFS='|' read -r test_name status message <<< "$result"
            if [ "$status" = "WARNING" ]; then
                echo "   $test_name: $message"
            fi
        done
        echo ""
    fi
    
    echo "✅ 성공한 테스트:"
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r test_name status message <<< "$result"
        if [ "$status" = "PASS" ]; then
            echo "   $test_name"
        fi
    done
    echo ""
    
    # JSON 형태로 결과 저장
    local json_file="security-validation-results-$(date +%Y%m%d-%H%M%S).json"
    echo "{" > "$json_file"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$json_file"
    echo "  \"layer\": \"security\"," >> "$json_file"
    echo "  \"summary\": {" >> "$json_file"
    echo "    \"total_tests\": $TOTAL_TESTS," >> "$json_file"
    echo "    \"passed_tests\": $PASSED_TESTS," >> "$json_file"
    echo "    \"failed_tests\": $FAILED_TESTS," >> "$json_file"
    echo "    \"warning_count\": $warning_count," >> "$json_file"
    echo "    \"success_rate\": $(( PASSED_TESTS * 100 / TOTAL_TESTS ))" >> "$json_file"
    echo "  }," >> "$json_file"
    echo "  \"results\": [" >> "$json_file"
    
    local first=true
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r test_name status message <<< "$result"
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        echo "    {" >> "$json_file"
        echo "      \"test_name\": \"$test_name\"," >> "$json_file"
        echo "      \"status\": \"$status\"," >> "$json_file"
        echo "      \"message\": \"$message\"" >> "$json_file"
        echo -n "    }" >> "$json_file"
    done
    
    echo "" >> "$json_file"
    echo "  ]" >> "$json_file"
    echo "}" >> "$json_file"
    
    log_success "보안 검증 결과가 $json_file 파일에 저장되었습니다"
    
    # 전체 결과에 따른 종료 코드
    if [ $FAILED_TESTS -gt 0 ]; then
        echo ""
        log_error "일부 보안 검증이 실패했습니다. 위의 오류를 확인하고 수정해주세요."
        exit 1
    else
        echo ""
        log_success "모든 보안 검증이 성공했습니다! 🎉"
        if [ $warning_count -gt 0 ]; then
            log_warning "경고 항목들을 검토하여 보안을 더욱 강화할 수 있습니다."
        fi
        exit 0
    fi
}

# 메인 실행
main() {
    log_info "보안 설정 종합 검증을 시작합니다..."
    echo ""
    
    # 각 검증 실행
    validate_security_groups
    echo ""
    validate_vpc_endpoints
    echo ""
    validate_iam_policies
    echo ""
    validate_encryption
    echo ""
    validate_network_security
    echo ""
    validate_compliance
    
    # 요약 리포트 생성
    generate_summary
}

# 스크립트 실행
main "$@"