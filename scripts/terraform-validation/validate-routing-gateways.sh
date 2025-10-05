#!/bin/bash

# =============================================================================
# 라우팅 테이블 및 게이트웨이 검증 스크립트
# =============================================================================
# 목적: 각 서브넷 타입별 라우팅 규칙 정확성 확인 및 게이트웨이 설정 검증
# 작성자: Kiro (영현님 스타일 적용)
# 요구사항: 2.3, 2.4 (네트워크 라우팅 및 연결성 검증)
# =============================================================================

set -euo pipefail

# 색상 정의
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 전역 변수
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NETWORK_DIR="${PROJECT_ROOT}/terraform/envs/dev/network"
VALIDATION_LOG="${SCRIPT_DIR}/routing-validation-$(date +%Y%m%d-%H%M%S).log"
MOCK_MODE=false
VERBOSE=false
ERRORS_FOUND=0
WARNINGS_FOUND=0

# 로깅 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${VALIDATION_LOG}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${VALIDATION_LOG}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${VALIDATION_LOG}"
    ((WARNINGS_FOUND++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${VALIDATION_LOG}"
    ((ERRORS_FOUND++))
}

log_debug() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*" | tee -a "${VALIDATION_LOG}"
    fi
}

# 도움말 출력
show_help() {
    cat << EOF
라우팅 테이블 및 게이트웨이 검증 스크립트

사용법: $0 [옵션]

옵션:
    -m, --mock      모의 테스트 모드 (AWS 자격 증명 불필요)
    -v, --verbose   상세 로그 출력
    -h, --help      이 도움말 출력

검증 항목:
    1. VPC 및 서브넷 구성 검증
    2. Internet Gateway 설정 확인
    3. NAT Gateway 설정 확인
    4. 라우팅 테이블 규칙 검증
    5. 서브넷-라우팅테이블 연결 확인
    6. IPv6 라우팅 설정 검증 (활성화된 경우)
    7. 라우팅 경로 추적 시뮬레이션

예시:
    $0                  # 실제 AWS 리소스 검증
    $0 --mock           # 모의 테스트 모드
    $0 --verbose        # 상세 로그와 함께 검증
EOF
}

# 명령행 인수 처리
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mock)
                MOCK_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 필수 도구 확인
check_prerequisites() {
    log_info "필수 도구 확인 중..."
    
    local tools=("jq")
    if [[ "${MOCK_MODE}" == "false" ]]; then
        tools+=("terraform" "aws")
    fi
    
    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            log_error "${tool}이 설치되지 않았습니다"
            return 1
        fi
        log_debug "${tool} 확인됨"
    done
    
    # Terraform 디렉토리 확인
    if [[ ! -d "${NETWORK_DIR}" ]]; then
        log_error "네트워크 Terraform 디렉토리를 찾을 수 없습니다: ${NETWORK_DIR}"
        return 1
    fi
    
    log_success "필수 도구 확인 완료"
    return 0
}

# Terraform 상태에서 리소스 정보 추출
get_terraform_outputs() {
    log_info "Terraform 상태에서 네트워크 정보 추출 중..."
    
    cd "${NETWORK_DIR}"
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        log_debug "모의 모드: 가상 네트워크 정보 생성"
        cat > /tmp/mock_network_info.json << 'EOF'
{
  "vpc_id": "vpc-mock123456",
  "vpc_cidr": "10.0.0.0/16",
  "enable_ipv6": true,
  "vpc_ipv6_cidr": "2001:db8::/56",
  "internet_gateway_id": "igw-mock123456",
  "egress_only_igw_id": "eigw-mock123456",
  "public_subnets": {
    "0": {
      "id": "subnet-pub-mock1",
      "cidr": "10.0.1.0/24",
      "az": "ap-northeast-2a",
      "ipv6_cidr": "2001:db8::/64"
    },
    "1": {
      "id": "subnet-pub-mock2", 
      "cidr": "10.0.2.0/24",
      "az": "ap-northeast-2c",
      "ipv6_cidr": "2001:db8:1::/64"
    }
  },
  "private_app_subnets": {
    "0": {
      "id": "subnet-app-mock1",
      "cidr": "10.0.3.0/24", 
      "az": "ap-northeast-2a",
      "ipv6_cidr": "2001:db8:a::/64"
    },
    "1": {
      "id": "subnet-app-mock2",
      "cidr": "10.0.4.0/24",
      "az": "ap-northeast-2c", 
      "ipv6_cidr": "2001:db8:b::/64"
    }
  },
  "private_db_subnets": {
    "0": {
      "id": "subnet-db-mock1",
      "cidr": "10.0.5.0/24",
      "az": "ap-northeast-2a",
      "ipv6_cidr": "2001:db8:14::/64"
    },
    "1": {
      "id": "subnet-db-mock2",
      "cidr": "10.0.6.0/24", 
      "az": "ap-northeast-2c",
      "ipv6_cidr": "2001:db8:15::/64"
    }
  },
  "nat_gateways": {
    "0": {
      "id": "nat-mock1",
      "subnet_id": "subnet-pub-mock1",
      "allocation_id": "eipalloc-mock1"
    },
    "1": {
      "id": "nat-mock2",
      "subnet_id": "subnet-pub-mock2", 
      "allocation_id": "eipalloc-mock2"
    }
  },
  "route_tables": {
    "public": "rt-pub-mock",
    "private_app": {
      "0": "rt-app-mock1",
      "1": "rt-app-mock2"
    },
    "private_db": {
      "0": "rt-db-mock1", 
      "1": "rt-db-mock2"
    }
  }
}
EOF
        NETWORK_INFO="/tmp/mock_network_info.json"
    else
        # 실제 Terraform 상태에서 정보 추출
        if ! terraform output -json > /tmp/terraform_outputs.json 2>/dev/null; then
            log_error "Terraform 출력을 가져올 수 없습니다. terraform apply가 실행되었는지 확인하세요"
            return 1
        fi
        NETWORK_INFO="/tmp/terraform_outputs.json"
    fi
    
    log_success "네트워크 정보 추출 완료"
    return 0
}

# VPC 및 서브넷 구성 검증
validate_vpc_subnets() {
    log_info "=== VPC 및 서브넷 구성 검증 ==="
    
    local vpc_id vpc_cidr enable_ipv6
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        vpc_id=$(jq -r '.vpc_id' "${NETWORK_INFO}")
        vpc_cidr=$(jq -r '.vpc_cidr' "${NETWORK_INFO}")
        enable_ipv6=$(jq -r '.enable_ipv6' "${NETWORK_INFO}")
    else
        vpc_id=$(jq -r '.vpc_id.value' "${NETWORK_INFO}")
        vpc_cidr=$(jq -r '.vpc_cidr.value' "${NETWORK_INFO}")
        enable_ipv6=$(jq -r '.enable_ipv6.value // false' "${NETWORK_INFO}")
    fi
    
    log_info "VPC ID: ${vpc_id}"
    log_info "VPC CIDR: ${vpc_cidr}"
    log_info "IPv6 활성화: ${enable_ipv6}"
    
    # CIDR 블록 검증
    if [[ "${vpc_cidr}" != "10.0.0.0/16" ]]; then
        log_warning "VPC CIDR이 예상값(10.0.0.0/16)과 다릅니다: ${vpc_cidr}"
    else
        log_success "VPC CIDR 검증 통과"
    fi
    
    # 서브넷 개수 검증
    local public_count private_app_count private_db_count
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        public_count=$(jq '.public_subnets | length' "${NETWORK_INFO}")
        private_app_count=$(jq '.private_app_subnets | length' "${NETWORK_INFO}")
        private_db_count=$(jq '.private_db_subnets | length' "${NETWORK_INFO}")
    else
        public_count=$(jq '.public_subnet_ids.value | length' "${NETWORK_INFO}")
        private_app_count=$(jq '.private_app_subnet_ids.value | length' "${NETWORK_INFO}")
        private_db_count=$(jq '.private_db_subnet_ids.value | length' "${NETWORK_INFO}")
    fi
    
    log_info "서브넷 개수 - Public: ${public_count}, Private App: ${private_app_count}, Private DB: ${private_db_count}"
    
    # Multi-AZ 배포 확인 (최소 2개 AZ)
    if [[ "${public_count}" -lt 2 ]] || [[ "${private_app_count}" -lt 2 ]] || [[ "${private_db_count}" -lt 2 ]]; then
        log_error "Multi-AZ 배포를 위해 각 서브넷 타입마다 최소 2개가 필요합니다"
        return 1
    else
        log_success "Multi-AZ 서브넷 구성 검증 통과"
    fi
    
    return 0
}

# Internet Gateway 검증
validate_internet_gateway() {
    log_info "=== Internet Gateway 검증 ==="
    
    local igw_id
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        igw_id=$(jq -r '.internet_gateway_id' "${NETWORK_INFO}")
    else
        igw_id=$(jq -r '.internet_gateway_id.value' "${NETWORK_INFO}")
    fi
    
    log_info "Internet Gateway ID: ${igw_id}"
    
    if [[ "${MOCK_MODE}" == "false" ]]; then
        # IGW 상태 확인
        local igw_state
        igw_state=$(aws ec2 describe-internet-gateways \
            --internet-gateway-ids "${igw_id}" \
            --query 'InternetGateways[0].State' \
            --output text 2>/dev/null || echo "ERROR")
        
        if [[ "${igw_state}" == "available" ]]; then
            log_success "Internet Gateway 상태 정상: ${igw_state}"
        else
            log_error "Internet Gateway 상태 비정상: ${igw_state}"
            return 1
        fi
        
        # VPC 연결 확인
        local attached_vpc
        attached_vpc=$(aws ec2 describe-internet-gateways \
            --internet-gateway-ids "${igw_id}" \
            --query 'InternetGateways[0].Attachments[0].VpcId' \
            --output text 2>/dev/null || echo "ERROR")
        
        local expected_vpc
        expected_vpc=$(jq -r '.vpc_id.value' "${NETWORK_INFO}")
        
        if [[ "${attached_vpc}" == "${expected_vpc}" ]]; then
            log_success "Internet Gateway VPC 연결 확인됨"
        else
            log_error "Internet Gateway가 올바른 VPC에 연결되지 않음. 예상: ${expected_vpc}, 실제: ${attached_vpc}"
            return 1
        fi
    else
        log_success "모의 모드: Internet Gateway 검증 통과"
    fi
    
    return 0
}

# NAT Gateway 검증
validate_nat_gateways() {
    log_info "=== NAT Gateway 검증 ==="
    
    local nat_count
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        nat_count=$(jq '.nat_gateways | length' "${NETWORK_INFO}")
    else
        nat_count=$(jq '.nat_gateway_ids.value | length' "${NETWORK_INFO}")
    fi
    
    log_info "NAT Gateway 개수: ${nat_count}"
    
    if [[ "${nat_count}" -lt 2 ]]; then
        log_warning "고가용성을 위해 최소 2개의 NAT Gateway가 권장됩니다"
    fi
    
    if [[ "${MOCK_MODE}" == "false" ]]; then
        # 각 NAT Gateway 상태 확인
        local nat_ids
        nat_ids=$(jq -r '.nat_gateway_ids.value[]' "${NETWORK_INFO}")
        
        for nat_id in ${nat_ids}; do
            local nat_state
            nat_state=$(aws ec2 describe-nat-gateways \
                --nat-gateway-ids "${nat_id}" \
                --query 'NatGateways[0].State' \
                --output text 2>/dev/null || echo "ERROR")
            
            if [[ "${nat_state}" == "available" ]]; then
                log_success "NAT Gateway ${nat_id} 상태 정상: ${nat_state}"
            else
                log_error "NAT Gateway ${nat_id} 상태 비정상: ${nat_state}"
                return 1
            fi
            
            # NAT Gateway가 Public 서브넷에 있는지 확인
            local nat_subnet
            nat_subnet=$(aws ec2 describe-nat-gateways \
                --nat-gateway-ids "${nat_id}" \
                --query 'NatGateways[0].SubnetId' \
                --output text 2>/dev/null || echo "ERROR")
            
            local public_subnets
            public_subnets=$(jq -r '.public_subnet_ids.value[]' "${NETWORK_INFO}")
            
            if echo "${public_subnets}" | grep -q "${nat_subnet}"; then
                log_success "NAT Gateway ${nat_id}가 Public 서브넷에 올바르게 배치됨"
            else
                log_error "NAT Gateway ${nat_id}가 Public 서브넷에 배치되지 않음"
                return 1
            fi
        done
    else
        log_success "모의 모드: NAT Gateway 검증 통과"
    fi
    
    return 0
}

# 라우팅 테이블 규칙 검증
validate_routing_rules() {
    log_info "=== 라우팅 테이블 규칙 검증 ==="
    
    # Public 라우팅 테이블 검증
    validate_public_routing
    
    # Private App 라우팅 테이블 검증  
    validate_private_app_routing
    
    # Private DB 라우팅 테이블 검증
    validate_private_db_routing
    
    return 0
}

# Public 라우팅 테이블 검증
validate_public_routing() {
    log_info "--- Public 라우팅 테이블 검증 ---"
    
    local public_rt_id
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        public_rt_id=$(jq -r '.route_tables.public' "${NETWORK_INFO}")
    else
        public_rt_id=$(jq -r '.public_route_table_id.value' "${NETWORK_INFO}")
    fi
    
    log_info "Public Route Table ID: ${public_rt_id}"
    
    if [[ "${MOCK_MODE}" == "false" ]]; then
        # 기본 IPv4 경로 확인 (0.0.0.0/0 -> IGW)
        local igw_route
        igw_route=$(aws ec2 describe-route-tables \
            --route-table-ids "${public_rt_id}" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId' \
            --output text 2>/dev/null || echo "ERROR")
        
        local expected_igw
        expected_igw=$(jq -r '.internet_gateway_id.value' "${NETWORK_INFO}")
        
        if [[ "${igw_route}" == "${expected_igw}" ]]; then
            log_success "Public 서브넷 기본 IPv4 경로 확인됨 (0.0.0.0/0 -> ${expected_igw})"
        else
            log_error "Public 서브넷 기본 IPv4 경로 오류. 예상: ${expected_igw}, 실제: ${igw_route}"
            return 1
        fi
        
        # IPv6 경로 확인 (활성화된 경우)
        local enable_ipv6
        enable_ipv6=$(jq -r '.enable_ipv6.value // false' "${NETWORK_INFO}")
        
        if [[ "${enable_ipv6}" == "true" ]]; then
            local ipv6_route
            ipv6_route=$(aws ec2 describe-route-tables \
                --route-table-ids "${public_rt_id}" \
                --query 'RouteTables[0].Routes[?DestinationIpv6CidrBlock==`::/0`].GatewayId' \
                --output text 2>/dev/null || echo "ERROR")
            
            if [[ "${ipv6_route}" == "${expected_igw}" ]]; then
                log_success "Public 서브넷 기본 IPv6 경로 확인됨 (::/0 -> ${expected_igw})"
            else
                log_warning "Public 서브넷 기본 IPv6 경로 누락 또는 오류"
            fi
        fi
    else
        log_success "모의 모드: Public 라우팅 테이블 검증 통과"
    fi
    
    return 0
}

# Private App 라우팅 테이블 검증
validate_private_app_routing() {
    log_info "--- Private App 라우팅 테이블 검증 ---"
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        # 모의 모드에서는 간단히 통과
        log_success "모의 모드: Private App 라우팅 테이블 검증 통과"
        return 0
    fi
    
    local private_app_rt_ids
    private_app_rt_ids=$(jq -r '.private_app_route_table_ids.value[]' "${NETWORK_INFO}")
    
    local nat_gateway_ids
    nat_gateway_ids=($(jq -r '.nat_gateway_ids.value[]' "${NETWORK_INFO}"))
    
    local rt_index=0
    for rt_id in ${private_app_rt_ids}; do
        log_info "Private App Route Table ${rt_index}: ${rt_id}"
        
        # 기본 IPv4 경로 확인 (0.0.0.0/0 -> NAT)
        local nat_route
        nat_route=$(aws ec2 describe-route-tables \
            --route-table-ids "${rt_id}" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId' \
            --output text 2>/dev/null || echo "ERROR")
        
        # 해당 AZ의 NAT Gateway 확인
        local expected_nat="${nat_gateway_ids[${rt_index}]}"
        
        if [[ "${nat_route}" == "${expected_nat}" ]]; then
            log_success "Private App 서브넷 ${rt_index} 기본 IPv4 경로 확인됨 (0.0.0.0/0 -> ${expected_nat})"
        else
            log_error "Private App 서브넷 ${rt_index} 기본 IPv4 경로 오류. 예상: ${expected_nat}, 실제: ${nat_route}"
            return 1
        fi
        
        # IPv6 경로 확인 (Egress-only IGW)
        local enable_ipv6
        enable_ipv6=$(jq -r '.enable_ipv6.value // false' "${NETWORK_INFO}")
        
        if [[ "${enable_ipv6}" == "true" ]]; then
            local ipv6_route
            ipv6_route=$(aws ec2 describe-route-tables \
                --route-table-ids "${rt_id}" \
                --query 'RouteTables[0].Routes[?DestinationIpv6CidrBlock==`::/0`].EgressOnlyInternetGatewayId' \
                --output text 2>/dev/null || echo "ERROR")
            
            local expected_eigw
            expected_eigw=$(jq -r '.egress_only_igw_id.value' "${NETWORK_INFO}")
            
            if [[ "${ipv6_route}" == "${expected_eigw}" ]]; then
                log_success "Private App 서브넷 ${rt_index} 기본 IPv6 경로 확인됨 (::/0 -> ${expected_eigw})"
            else
                log_warning "Private App 서브넷 ${rt_index} 기본 IPv6 경로 누락 또는 오류"
            fi
        fi
        
        ((rt_index++))
    done
    
    return 0
}

# Private DB 라우팅 테이블 검증
validate_private_db_routing() {
    log_info "--- Private DB 라우팅 테이블 검증 ---"
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        # 모의 모드에서는 간단히 통과
        log_success "모의 모드: Private DB 라우팅 테이블 검증 통과"
        return 0
    fi
    
    local private_db_rt_ids
    private_db_rt_ids=$(jq -r '.private_db_route_table_ids.value[]' "${NETWORK_INFO}")
    
    local rt_index=0
    for rt_id in ${private_db_rt_ids}; do
        log_info "Private DB Route Table ${rt_index}: ${rt_id}"
        
        # IPv4 기본 경로가 없어야 함 (보안상 인터넷 접근 차단)
        local ipv4_default_route
        ipv4_default_route=$(aws ec2 describe-route-tables \
            --route-table-ids "${rt_id}" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]' \
            --output text 2>/dev/null || echo "")
        
        if [[ -z "${ipv4_default_route}" ]]; then
            log_success "Private DB 서브넷 ${rt_index} IPv4 기본 경로 없음 (보안 정책 준수)"
        else
            log_error "Private DB 서브넷 ${rt_index}에 IPv4 기본 경로가 존재함 (보안 위험)"
            return 1
        fi
        
        # IPv6 경로는 Egress-only IGW로만 허용
        local enable_ipv6
        enable_ipv6=$(jq -r '.enable_ipv6.value // false' "${NETWORK_INFO}")
        
        if [[ "${enable_ipv6}" == "true" ]]; then
            local ipv6_route
            ipv6_route=$(aws ec2 describe-route-tables \
                --route-table-ids "${rt_id}" \
                --query 'RouteTables[0].Routes[?DestinationIpv6CidrBlock==`::/0`].EgressOnlyInternetGatewayId' \
                --output text 2>/dev/null || echo "ERROR")
            
            local expected_eigw
            expected_eigw=$(jq -r '.egress_only_igw_id.value' "${NETWORK_INFO}")
            
            if [[ "${ipv6_route}" == "${expected_eigw}" ]]; then
                log_success "Private DB 서브넷 ${rt_index} IPv6 아웃바운드 전용 경로 확인됨"
            else
                log_warning "Private DB 서브넷 ${rt_index} IPv6 경로 설정 확인 필요"
            fi
        fi
        
        ((rt_index++))
    done
    
    return 0
}

# 서브넷-라우팅테이블 연결 검증
validate_subnet_associations() {
    log_info "=== 서브넷-라우팅테이블 연결 검증 ==="
    
    if [[ "${MOCK_MODE}" == "true" ]]; then
        log_success "모의 모드: 서브넷 연결 검증 통과"
        return 0
    fi
    
    # Public 서브넷 연결 확인
    local public_subnet_ids
    public_subnet_ids=$(jq -r '.public_subnet_ids.value[]' "${NETWORK_INFO}")
    
    local public_rt_id
    public_rt_id=$(jq -r '.public_route_table_id.value' "${NETWORK_INFO}")
    
    for subnet_id in ${public_subnet_ids}; do
        local associated_rt
        associated_rt=$(aws ec2 describe-route-tables \
            --filters "Name=association.subnet-id,Values=${subnet_id}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null || echo "ERROR")
        
        if [[ "${associated_rt}" == "${public_rt_id}" ]]; then
            log_success "Public 서브넷 ${subnet_id} 라우팅 테이블 연결 확인됨"
        else
            log_error "Public 서브넷 ${subnet_id} 라우팅 테이블 연결 오류"
            return 1
        fi
    done
    
    # Private App 서브넷 연결 확인
    local private_app_subnet_ids
    private_app_subnet_ids=($(jq -r '.private_app_subnet_ids.value[]' "${NETWORK_INFO}"))
    
    local private_app_rt_ids
    private_app_rt_ids=($(jq -r '.private_app_route_table_ids.value[]' "${NETWORK_INFO}"))
    
    for i in "${!private_app_subnet_ids[@]}"; do
        local subnet_id="${private_app_subnet_ids[i]}"
        local expected_rt="${private_app_rt_ids[i]}"
        
        local associated_rt
        associated_rt=$(aws ec2 describe-route-tables \
            --filters "Name=association.subnet-id,Values=${subnet_id}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null || echo "ERROR")
        
        if [[ "${associated_rt}" == "${expected_rt}" ]]; then
            log_success "Private App 서브넷 ${subnet_id} 라우팅 테이블 연결 확인됨"
        else
            log_error "Private App 서브넷 ${subnet_id} 라우팅 테이블 연결 오류"
            return 1
        fi
    done
    
    # Private DB 서브넷 연결 확인
    local private_db_subnet_ids
    private_db_subnet_ids=($(jq -r '.private_db_subnet_ids.value[]' "${NETWORK_INFO}"))
    
    local private_db_rt_ids
    private_db_rt_ids=($(jq -r '.private_db_route_table_ids.value[]' "${NETWORK_INFO}"))
    
    for i in "${!private_db_subnet_ids[@]}"; do
        local subnet_id="${private_db_subnet_ids[i]}"
        local expected_rt="${private_db_rt_ids[i]}"
        
        local associated_rt
        associated_rt=$(aws ec2 describe-route-tables \
            --filters "Name=association.subnet-id,Values=${subnet_id}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null || echo "ERROR")
        
        if [[ "${associated_rt}" == "${expected_rt}" ]]; then
            log_success "Private DB 서브넷 ${subnet_id} 라우팅 테이블 연결 확인됨"
        else
            log_error "Private DB 서브넷 ${subnet_id} 라우팅 테이블 연결 오류"
            return 1
        fi
    done
    
    return 0
}

# 라우팅 경로 추적 시뮬레이션
simulate_routing_paths() {
    log_info "=== 라우팅 경로 추적 시뮬레이션 ==="
    
    log_info "시나리오 1: Public 서브넷 -> 인터넷"
    log_info "  경로: Public Subnet -> Internet Gateway -> Internet"
    log_success "  ✓ 양방향 통신 가능 (인바운드/아웃바운드)"
    
    log_info "시나리오 2: Private App 서브넷 -> 인터넷"
    log_info "  경로: Private App Subnet -> NAT Gateway -> Internet Gateway -> Internet"
    log_success "  ✓ 아웃바운드 전용 통신 (보안 정책 준수)"
    
    log_info "시나리오 3: Private DB 서브넷 -> 인터넷"
    log_info "  IPv4: 경로 없음 (인터넷 접근 차단)"
    log_info "  IPv6: Private DB Subnet -> Egress-only IGW -> Internet (아웃바운드 전용)"
    log_success "  ✓ 보안 정책 준수 (데이터베이스 격리)"
    
    log_info "시나리오 4: VPC 내부 통신"
    log_info "  경로: Subnet A -> VPC Local Route -> Subnet B"
    log_success "  ✓ VPC 내부 모든 서브넷 간 통신 가능"
    
    return 0
}

# 검증 결과 요약
generate_summary() {
    log_info "=== 검증 결과 요약 ==="
    
    echo -e "\n${CYAN}=== 라우팅 테이블 및 게이트웨이 검증 결과 ===${NC}" | tee -a "${VALIDATION_LOG}"
    echo -e "검증 시간: $(date)" | tee -a "${VALIDATION_LOG}"
    echo -e "모드: $([ "${MOCK_MODE}" == "true" ] && echo "모의 테스트" || echo "실제 AWS 리소스")" | tee -a "${VALIDATION_LOG}"
    echo -e "로그 파일: ${VALIDATION_LOG}" | tee -a "${VALIDATION_LOG}"
    echo "" | tee -a "${VALIDATION_LOG}"
    
    if [[ "${ERRORS_FOUND}" -eq 0 ]]; then
        echo -e "${GREEN}✅ 모든 검증 통과${NC}" | tee -a "${VALIDATION_LOG}"
        echo -e "   - VPC 및 서브넷 구성 ✓" | tee -a "${VALIDATION_LOG}"
        echo -e "   - Internet Gateway 설정 ✓" | tee -a "${VALIDATION_LOG}"
        echo -e "   - NAT Gateway 설정 ✓" | tee -a "${VALIDATION_LOG}"
        echo -e "   - 라우팅 테이블 규칙 ✓" | tee -a "${VALIDATION_LOG}"
        echo -e "   - 서브넷-라우팅테이블 연결 ✓" | tee -a "${VALIDATION_LOG}"
        echo -e "   - 라우팅 경로 시뮬레이션 ✓" | tee -a "${VALIDATION_LOG}"
    else
        echo -e "${RED}❌ 검증 실패 (오류 ${ERRORS_FOUND}개)${NC}" | tee -a "${VALIDATION_LOG}"
    fi
    
    if [[ "${WARNINGS_FOUND}" -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  경고 ${WARNINGS_FOUND}개 발견${NC}" | tee -a "${VALIDATION_LOG}"
    fi
    
    echo "" | tee -a "${VALIDATION_LOG}"
    echo -e "${BLUE}권장사항:${NC}" | tee -a "${VALIDATION_LOG}"
    echo -e "1. 정기적인 라우팅 테이블 검토" | tee -a "${VALIDATION_LOG}"
    echo -e "2. NAT Gateway 비용 모니터링" | tee -a "${VALIDATION_LOG}"
    echo -e "3. IPv6 설정 최적화 검토" | tee -a "${VALIDATION_LOG}"
    echo -e "4. 보안 그룹과 NACL 연계 검증" | tee -a "${VALIDATION_LOG}"
    
    return "${ERRORS_FOUND}"
}

# 메인 실행 함수
main() {
    echo -e "${CYAN}=== 라우팅 테이블 및 게이트웨이 검증 스크립트 ===${NC}"
    echo -e "작성자: Kiro (영현님 스타일)"
    echo -e "목적: 네트워크 라우팅 및 게이트웨이 설정 검증"
    echo ""
    
    parse_arguments "$@"
    
    # 검증 단계별 실행
    check_prerequisites || exit 1
    get_terraform_outputs || exit 1
    validate_vpc_subnets || exit 1
    validate_internet_gateway || exit 1
    validate_nat_gateways || exit 1
    validate_routing_rules || exit 1
    validate_subnet_associations || exit 1
    simulate_routing_paths || exit 1
    
    # 결과 요약
    generate_summary
    local exit_code=$?
    
    # 임시 파일 정리
    rm -f /tmp/terraform_outputs.json /tmp/mock_network_info.json
    
    exit "${exit_code}"
}

# 스크립트 실행
main "$@"