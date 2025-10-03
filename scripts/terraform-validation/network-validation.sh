#!/bin/bash

# 네트워크 인프라 상세 검증 스크립트
# VPC, 서브넷, 라우팅 테이블, 게이트웨이 설정 검증

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
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_error "$test_name: $message"
    fi
    
    VALIDATION_RESULTS+=("$test_name|$status|$message")
}

# 네트워크 레이어 경로
NETWORK_PATH="terraform/envs/dev/network"

# VPC 설정 검증
validate_vpc_config() {
    log_info "=== VPC 설정 검증 ==="
    
    local main_tf="$NETWORK_PATH/main.tf"
    local variables_tf="$NETWORK_PATH/variables.tf"
    local dev_tfvars="$NETWORK_PATH/dev.tfvars"
    
    # VPC CIDR 블록 확인
    if grep -q "vpc_cidr.*=.*\"10.0.0.0/16\"" "$variables_tf"; then
        record_result "VPC_CIDR" "PASS" "VPC CIDR 블록이 10.0.0.0/16으로 올바르게 설정됨"
    else
        record_result "VPC_CIDR" "FAIL" "VPC CIDR 블록 설정이 올바르지 않음"
    fi
    
    # DNS 설정 확인 (VPC 모듈에서)
    local vpc_module="terraform/modules/vpc/main.tf"
    if grep -q "enable_dns_support.*=.*true" "$vpc_module" && grep -q "enable_dns_hostnames.*=.*true" "$vpc_module"; then
        record_result "VPC_DNS" "PASS" "VPC DNS 설정이 활성화됨 (enable_dns_support, enable_dns_hostnames)"
    else
        record_result "VPC_DNS" "FAIL" "VPC DNS 설정이 올바르지 않음"
    fi
    
    # IPv6 지원 확인
    if grep -q "enable_ipv6.*=.*true" "$variables_tf"; then
        record_result "VPC_IPv6" "PASS" "IPv6 듀얼스택 지원이 활성화됨"
    else
        record_result "VPC_IPv6" "WARNING" "IPv6 지원이 비활성화됨"
    fi
    
    # 태그 설정 확인
    if grep -q "tags.*=" "$main_tf"; then
        record_result "VPC_TAGS" "PASS" "VPC 태그 설정이 구성됨"
    else
        record_result "VPC_TAGS" "FAIL" "VPC 태그 설정이 누락됨"
    fi
}

# 서브넷 설정 검증
validate_subnet_config() {
    log_info "=== 서브넷 설정 검증 ==="
    
    local variables_tf="$NETWORK_PATH/variables.tf"
    
    # 가용 영역 설정 확인
    if grep -q "ap-northeast-2a.*ap-northeast-2c" "$variables_tf"; then
        record_result "SUBNET_AZ" "PASS" "Multi-AZ 배포 설정됨 (ap-northeast-2a, ap-northeast-2c)"
    else
        record_result "SUBNET_AZ" "FAIL" "Multi-AZ 설정이 올바르지 않음"
    fi
    
    # Public 서브넷 CIDR 확인
    if grep -q "10.0.1.0/24.*10.0.2.0/24" "$variables_tf"; then
        record_result "PUBLIC_SUBNET_CIDR" "PASS" "Public 서브넷 CIDR이 올바르게 설정됨 (10.0.1.0/24, 10.0.2.0/24)"
    else
        record_result "PUBLIC_SUBNET_CIDR" "FAIL" "Public 서브넷 CIDR 설정이 올바르지 않음"
    fi
    
    # Private App 서브넷 CIDR 확인
    if grep -q "10.0.3.0/24.*10.0.4.0/24" "$variables_tf"; then
        record_result "PRIVATE_APP_SUBNET_CIDR" "PASS" "Private App 서브넷 CIDR이 올바르게 설정됨 (10.0.3.0/24, 10.0.4.0/24)"
    else
        record_result "PRIVATE_APP_SUBNET_CIDR" "FAIL" "Private App 서브넷 CIDR 설정이 올바르지 않음"
    fi
    
    # Private DB 서브넷 CIDR 확인
    if grep -q "10.0.5.0/24.*10.0.6.0/24" "$variables_tf"; then
        record_result "PRIVATE_DB_SUBNET_CIDR" "PASS" "Private DB 서브넷 CIDR이 올바르게 설정됨 (10.0.5.0/24, 10.0.6.0/24)"
    else
        record_result "PRIVATE_DB_SUBNET_CIDR" "FAIL" "Private DB 서브넷 CIDR 설정이 올바르지 않음"
    fi
    
    # 서브넷 개수 확인 (각 타입별 2개씩)
    local public_count=$(grep -o "10.0.[12].0/24" "$variables_tf" | wc -l)
    local private_app_count=$(grep -o "10.0.[34].0/24" "$variables_tf" | wc -l)
    local private_db_count=$(grep -o "10.0.[56].0/24" "$variables_tf" | wc -l)
    
    if [ "$public_count" -eq 2 ] && [ "$private_app_count" -eq 2 ] && [ "$private_db_count" -eq 2 ]; then
        record_result "SUBNET_COUNT" "PASS" "각 서브넷 타입별로 2개씩 올바르게 설정됨"
    else
        record_result "SUBNET_COUNT" "FAIL" "서브넷 개수가 올바르지 않음 (Public: $public_count, App: $private_app_count, DB: $private_db_count)"
    fi
}

# 게이트웨이 설정 검증
validate_gateway_config() {
    log_info "=== 게이트웨이 설정 검증 ==="
    
    local vpc_module="terraform/modules/vpc/main.tf"
    local variables_tf="$NETWORK_PATH/variables.tf"
    
    # Internet Gateway 설정 확인
    if grep -q "resource \"aws_internet_gateway\"" "$vpc_module"; then
        record_result "INTERNET_GATEWAY" "PASS" "Internet Gateway가 설정됨"
    else
        record_result "INTERNET_GATEWAY" "FAIL" "Internet Gateway 설정이 누락됨"
    fi
    
    # NAT Gateway 설정 확인
    if grep -q "resource \"aws_nat_gateway\"" "$vpc_module"; then
        record_result "NAT_GATEWAY" "PASS" "NAT Gateway가 설정됨"
    else
        record_result "NAT_GATEWAY" "FAIL" "NAT Gateway 설정이 누락됨"
    fi
    
    # Multi-AZ NAT Gateway 확인
    if grep -q "create_nat_per_az.*=.*true" "$variables_tf"; then
        record_result "NAT_MULTI_AZ" "PASS" "Multi-AZ NAT Gateway 설정됨 (고가용성)"
    else
        record_result "NAT_MULTI_AZ" "WARNING" "Single NAT Gateway 설정됨 (비용 절약, 가용성 낮음)"
    fi
    
    # Egress-only Internet Gateway (IPv6) 확인
    if grep -q "resource \"aws_egress_only_internet_gateway\"" "$vpc_module"; then
        record_result "EGRESS_ONLY_IGW" "PASS" "Egress-only Internet Gateway가 설정됨 (IPv6 지원)"
    else
        record_result "EGRESS_ONLY_IGW" "WARNING" "Egress-only Internet Gateway 설정이 누락됨"
    fi
    
    # Elastic IP 설정 확인
    if grep -q "resource \"aws_eip\" \"nat\"" "$vpc_module"; then
        record_result "NAT_EIP" "PASS" "NAT Gateway용 Elastic IP가 설정됨"
    else
        record_result "NAT_EIP" "FAIL" "NAT Gateway용 Elastic IP 설정이 누락됨"
    fi
}

# 라우팅 테이블 설정 검증
validate_routing_config() {
    log_info "=== 라우팅 테이블 설정 검증 ==="
    
    local vpc_module="terraform/modules/vpc/main.tf"
    
    # Public 라우팅 테이블 확인
    if grep -q "resource \"aws_route_table\" \"public\"" "$vpc_module"; then
        record_result "PUBLIC_ROUTE_TABLE" "PASS" "Public 라우팅 테이블이 설정됨"
    else
        record_result "PUBLIC_ROUTE_TABLE" "FAIL" "Public 라우팅 테이블 설정이 누락됨"
    fi
    
    # Private App 라우팅 테이블 확인
    if grep -q "resource \"aws_route_table\" \"private_app\"" "$vpc_module"; then
        record_result "PRIVATE_APP_ROUTE_TABLE" "PASS" "Private App 라우팅 테이블이 설정됨"
    else
        record_result "PRIVATE_APP_ROUTE_TABLE" "FAIL" "Private App 라우팅 테이블 설정이 누락됨"
    fi
    
    # Private DB 라우팅 테이블 확인
    if grep -q "resource \"aws_route_table\" \"private_db\"" "$vpc_module"; then
        record_result "PRIVATE_DB_ROUTE_TABLE" "PASS" "Private DB 라우팅 테이블이 설정됨"
    else
        record_result "PRIVATE_DB_ROUTE_TABLE" "FAIL" "Private DB 라우팅 테이블 설정이 누락됨"
    fi
    
    # Public 기본 경로 (IGW) 확인
    if grep -q "destination_cidr_block.*=.*\"0.0.0.0/0\"" "$vpc_module" && grep -q "gateway_id.*=.*aws_internet_gateway" "$vpc_module"; then
        record_result "PUBLIC_DEFAULT_ROUTE" "PASS" "Public 서브넷 기본 경로가 IGW로 설정됨"
    else
        record_result "PUBLIC_DEFAULT_ROUTE" "FAIL" "Public 서브넷 기본 경로 설정이 올바르지 않음"
    fi
    
    # Private App 기본 경로 (NAT) 확인
    if grep -q "nat_gateway_id.*=.*aws_nat_gateway" "$vpc_module"; then
        record_result "PRIVATE_APP_DEFAULT_ROUTE" "PASS" "Private App 서브넷 기본 경로가 NAT Gateway로 설정됨"
    else
        record_result "PRIVATE_APP_DEFAULT_ROUTE" "FAIL" "Private App 서브넷 기본 경로 설정이 올바르지 않음"
    fi
    
    # Private DB 인터넷 경로 차단 확인 (기본 경로가 없어야 함)
    local private_db_routes=$(grep -A 10 "resource \"aws_route\" \"private_db" "$vpc_module" | grep -c "destination_cidr_block.*0.0.0.0/0" || echo "0")
    if [ "$private_db_routes" -eq 0 ]; then
        record_result "PRIVATE_DB_NO_INTERNET" "PASS" "Private DB 서브넷에 인터넷 경로가 차단됨 (보안)"
    else
        record_result "PRIVATE_DB_NO_INTERNET" "FAIL" "Private DB 서브넷에 인터넷 경로가 존재함 (보안 위험)"
    fi
    
    # IPv6 라우팅 확인
    if grep -q "destination_ipv6_cidr_block.*=.*\"::/0\"" "$vpc_module"; then
        record_result "IPv6_ROUTING" "PASS" "IPv6 라우팅이 설정됨"
    else
        record_result "IPv6_ROUTING" "WARNING" "IPv6 라우팅 설정이 누락됨"
    fi
    
    # 라우팅 테이블 연결 확인
    local rt_associations=$(grep -c "resource \"aws_route_table_association\"" "$vpc_module")
    if [ "$rt_associations" -ge 3 ]; then
        record_result "ROUTE_TABLE_ASSOCIATIONS" "PASS" "라우팅 테이블 연결이 설정됨 ($rt_associations개)"
    else
        record_result "ROUTE_TABLE_ASSOCIATIONS" "FAIL" "라우팅 테이블 연결이 부족함 ($rt_associations개)"
    fi
}

# 출력값 검증
validate_outputs() {
    log_info "=== 출력값 검증 ==="
    
    local outputs_tf="$NETWORK_PATH/outputs.tf"
    local vpc_outputs="terraform/modules/vpc/outputs.tf"
    
    # 필수 출력값 확인
    local required_outputs=(
        "vpc_id"
        "vpc_cidr"
        "public_subnet_ids"
        "private_app_subnet_ids"
        "private_db_subnet_ids"
        "public_route_table_id"
        "private_app_route_table_ids"
        "private_db_route_table_ids"
        "internet_gateway_id"
        "nat_gateway_ids"
    )
    
    local missing_outputs=()
    for output in "${required_outputs[@]}"; do
        if grep -q "output \"$output\"" "$vpc_outputs"; then
            record_result "OUTPUT_$output" "PASS" "출력값 $output이 정의됨"
        else
            missing_outputs+=("$output")
            record_result "OUTPUT_$output" "FAIL" "출력값 $output이 누락됨"
        fi
    done
    
    if [ ${#missing_outputs[@]} -eq 0 ]; then
        record_result "ALL_OUTPUTS" "PASS" "모든 필수 출력값이 정의됨"
    else
        record_result "ALL_OUTPUTS" "FAIL" "누락된 출력값: ${missing_outputs[*]}"
    fi
}

# 모듈 구조 검증
validate_module_structure() {
    log_info "=== 모듈 구조 검증 ==="
    
    local vpc_module_path="terraform/modules/vpc"
    
    # VPC 모듈 파일 존재 확인
    local required_files=("main.tf" "variables.tf" "outputs.tf")
    for file in "${required_files[@]}"; do
        if [ -f "$vpc_module_path/$file" ]; then
            record_result "MODULE_FILE_$file" "PASS" "VPC 모듈 $file 파일이 존재함"
        else
            record_result "MODULE_FILE_$file" "FAIL" "VPC 모듈 $file 파일이 누락됨"
        fi
    done
    
    # 모듈 호출 확인
    if grep -q "module \"vpc\"" "$NETWORK_PATH/main.tf"; then
        record_result "MODULE_CALL" "PASS" "VPC 모듈이 올바르게 호출됨"
    else
        record_result "MODULE_CALL" "FAIL" "VPC 모듈 호출이 누락됨"
    fi
    
    # 모듈 소스 경로 확인
    if grep -q "source.*=.*\"../../../modules/vpc\"" "$NETWORK_PATH/main.tf"; then
        record_result "MODULE_SOURCE" "PASS" "VPC 모듈 소스 경로가 올바름"
    else
        record_result "MODULE_SOURCE" "FAIL" "VPC 모듈 소스 경로가 올바르지 않음"
    fi
}

# CIDR 블록 중복 검증
validate_cidr_overlap() {
    log_info "=== CIDR 블록 중복 검증 ==="
    
    local variables_tf="$NETWORK_PATH/variables.tf"
    
    # 모든 서브넷 CIDR 추출
    local all_cidrs=(
        "10.0.1.0/24"  # Public AZ-a
        "10.0.2.0/24"  # Public AZ-c
        "10.0.3.0/24"  # Private App AZ-a
        "10.0.4.0/24"  # Private App AZ-c
        "10.0.5.0/24"  # Private DB AZ-a
        "10.0.6.0/24"  # Private DB AZ-c
    )
    
    # CIDR 중복 확인 (간단한 문자열 비교)
    local unique_cidrs=($(printf '%s\n' "${all_cidrs[@]}" | sort -u))
    
    if [ ${#all_cidrs[@]} -eq ${#unique_cidrs[@]} ]; then
        record_result "CIDR_NO_OVERLAP" "PASS" "모든 서브넷 CIDR이 고유함 (중복 없음)"
    else
        record_result "CIDR_NO_OVERLAP" "FAIL" "서브넷 CIDR에 중복이 있음"
    fi
    
    # VPC CIDR 범위 내 포함 확인
    local vpc_cidr="10.0.0.0/16"
    local all_in_range=true
    
    for cidr in "${all_cidrs[@]}"; do
        if [[ ! "$cidr" =~ ^10\.0\.[0-9]+\.0/24$ ]]; then
            all_in_range=false
            break
        fi
    done
    
    if [ "$all_in_range" = true ]; then
        record_result "CIDR_IN_VPC_RANGE" "PASS" "모든 서브넷 CIDR이 VPC CIDR 범위 내에 있음"
    else
        record_result "CIDR_IN_VPC_RANGE" "FAIL" "일부 서브넷 CIDR이 VPC CIDR 범위를 벗어남"
    fi
}

# 요약 리포트 생성
generate_summary() {
    echo ""
    echo "=========================================="
    echo "       네트워크 인프라 검증 결과 요약"
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
    
    echo "✅ 성공한 테스트:"
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r test_name status message <<< "$result"
        if [ "$status" = "PASS" ]; then
            echo "   $test_name"
        fi
    done
    echo ""
    
    # JSON 형태로 결과 저장
    local json_file="network-validation-results-$(date +%Y%m%d-%H%M%S).json"
    echo "{" > "$json_file"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$json_file"
    echo "  \"layer\": \"network\"," >> "$json_file"
    echo "  \"summary\": {" >> "$json_file"
    echo "    \"total_tests\": $TOTAL_TESTS," >> "$json_file"
    echo "    \"passed_tests\": $PASSED_TESTS," >> "$json_file"
    echo "    \"failed_tests\": $FAILED_TESTS," >> "$json_file"
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
    
    log_success "네트워크 검증 결과가 $json_file 파일에 저장되었습니다"
    
    # 전체 결과에 따른 종료 코드
    if [ $FAILED_TESTS -gt 0 ]; then
        echo ""
        log_error "일부 네트워크 검증이 실패했습니다. 위의 오류를 확인하고 수정해주세요."
        exit 1
    else
        echo ""
        log_success "모든 네트워크 검증이 성공했습니다! 🎉"
        exit 0
    fi
}

# 메인 실행
main() {
    log_info "네트워크 인프라 상세 검증을 시작합니다..."
    echo ""
    
    # 각 검증 실행
    validate_vpc_config
    echo ""
    validate_subnet_config
    echo ""
    validate_gateway_config
    echo ""
    validate_routing_config
    echo ""
    validate_outputs
    echo ""
    validate_module_structure
    echo ""
    validate_cidr_overlap
    
    # 요약 리포트 생성
    generate_summary
}

# 스크립트 실행
main "$@"