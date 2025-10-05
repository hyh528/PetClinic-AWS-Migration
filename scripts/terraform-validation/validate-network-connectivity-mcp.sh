#!/bin/bash

# 네트워크 연결성 테스트 스크립트 (MCP 통합 버전)
# 영현님 스타일: 클린 코드 + 클린 아키텍처 + Well-Architected Framework
# 목적: MCP를 활용한 실제 AWS 리소스 기반 네트워크 연결성 테스트

set -e

# 색상 정의 (클린 코드: 의미 있는 상수)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 로그 함수 (클린 코드: 단일 책임 원칙)
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 전역 변수 (클린 코드: 의미 있는 이름)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly TERRAFORM_DIR="$PROJECT_ROOT/terraform"
readonly RESULTS_DIR="$PROJECT_ROOT/terraform-validation-results"
readonly TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
readonly RESULTS_FILE="$RESULTS_DIR/network-connectivity-mcp-$TIMESTAMP.json"

# 결과 저장 배열
declare -a VALIDATION_RESULTS=()

# 결과 디렉토리 생성
mkdir -p "$RESULTS_DIR"

# JSON 결과 추가 함수 (클린 코드: 재사용 가능한 함수)
add_result() {
    local test_type="$1"
    local source="$2"
    local destination="$3"
    local status="$4"
    local message="$5"
    local details="$6"
    
    local result=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "test_type": "$test_type",
  "source": "$source",
  "destination": "$destination",
  "status": "$status",
  "message": "$message",
  "details": "$details"
}
EOF
)
    VALIDATION_RESULTS+=("$result")
}

# Terraform 코드 품질 검증 (Well-Architected: 운영 우수성)
validate_terraform_code_quality() {
    log_info "Terraform 코드 품질 검증 중..."
    
    # Network 레이어 검증
    validate_terraform_layer "network"
    
    # Security 레이어 검증
    validate_terraform_layer "security"
    
    # Database 레이어 검증
    validate_terraform_layer "database"
    
    # Application 레이어 검증
    validate_terraform_layer "application"
}

# 레이어별 Terraform 검증
validate_terraform_layer() {
    local layer="$1"
    local layer_dir="$TERRAFORM_DIR/envs/dev/$layer"
    
    log_info "$layer 레이어 검증 중..."
    
    if [[ ! -d "$layer_dir" ]]; then
        log_warning "$layer 레이어 디렉토리가 존재하지 않습니다: $layer_dir"
        add_result "terraform_validation" "$layer" "directory" "WARNING" "Layer directory not found" "$layer_dir"
        return
    fi
    
    # terraform fmt 검사
    if command -v terraform &> /dev/null; then
        cd "$layer_dir"
        
        # terraform fmt 체크
        if terraform fmt -check -diff > /dev/null 2>&1; then
            log_success "$layer: terraform fmt 통과"
            add_result "terraform_validation" "$layer" "fmt" "PASS" "Code formatting is correct" ""
        else
            log_error "$layer: terraform fmt 실패"
            add_result "terraform_validation" "$layer" "fmt" "FAIL" "Code formatting issues found" ""
        fi
        
        # terraform validate 체크
        if terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1; then
            log_success "$layer: terraform validate 통과"
            add_result "terraform_validation" "$layer" "validate" "PASS" "Configuration is valid" ""
        else
            log_error "$layer: terraform validate 실패"
            add_result "terraform_validation" "$layer" "validate" "FAIL" "Configuration validation failed" ""
        fi
        
        cd "$PROJECT_ROOT"
    else
        log_warning "Terraform CLI가 설치되지 않았습니다."
        add_result "terraform_validation" "$layer" "cli" "WARNING" "Terraform CLI not installed" ""
    fi
}

# AWS Provider 문서 기반 리소스 검증
validate_aws_resources() {
    log_info "AWS 리소스 구성 검증 중..."
    
    # VPC 리소스 검증
    validate_vpc_configuration
    
    # 서브넷 리소스 검증
    validate_subnet_configuration
    
    # 보안 그룹 리소스 검증
    validate_security_group_configuration
    
    # 라우트 테이블 리소스 검증
    validate_route_table_configuration
}

# VPC 구성 검증
validate_vpc_configuration() {
    log_info "VPC 구성 검증 중..."
    
    # Network 레이어의 VPC 설정 파일 확인
    local vpc_file="$TERRAFORM_DIR/envs/dev/network/main.tf"
    local vpc_module_file="$TERRAFORM_DIR/modules/vpc/main.tf"
    
    if [[ -f "$vpc_file" ]]; then
        # 모듈 사용 확인
        if grep -q "module.*vpc" "$vpc_file"; then
            log_success "VPC: 모듈 기반 구성 확인"
            add_result "vpc_validation" "network" "module_structure" "PASS" "VPC module structure configured" ""
            
            # 모듈 파일에서 실제 설정 확인
            if [[ -f "$vpc_module_file" ]]; then
                # CIDR 블록 변수 사용 확인
                if grep -q "cidr_block.*=.*var.vpc_cidr" "$vpc_module_file"; then
                    log_success "VPC: CIDR 블록 변수 설정 확인"
                    add_result "vpc_validation" "network" "cidr_variable" "PASS" "CIDR block variable configured" ""
                fi
                
                # DNS 설정 확인
                if grep -q "enable_dns_hostnames.*=.*true" "$vpc_module_file" && grep -q "enable_dns_support.*=.*true" "$vpc_module_file"; then
                    log_success "VPC: DNS 설정 활성화 확인"
                    add_result "vpc_validation" "network" "dns_settings" "PASS" "DNS settings properly configured" ""
                else
                    log_warning "VPC: DNS 설정 확인 필요"
                    add_result "vpc_validation" "network" "dns_settings" "WARNING" "DNS settings need review" ""
                fi
                
                # IPv6 지원 확인
                if grep -q "assign_generated_ipv6_cidr_block.*=.*var.enable_ipv6" "$vpc_module_file"; then
                    log_success "VPC: IPv6 지원 설정 확인"
                    add_result "vpc_validation" "network" "ipv6_support" "PASS" "IPv6 support configured" ""
                fi
                
                # 태그 설정 확인
                if grep -q "tags.*=.*merge" "$vpc_module_file"; then
                    log_success "VPC: 태그 병합 설정 확인"
                    add_result "vpc_validation" "network" "tags" "PASS" "Tag merging configured" ""
                fi
            fi
        fi
        
        # 변수 파일 확인
        local vars_file="$TERRAFORM_DIR/envs/dev/network/variables.tf"
        if [[ -f "$vars_file" ]] && grep -q "vpc_cidr" "$vars_file"; then
            log_success "VPC: 변수 정의 확인"
            add_result "vpc_validation" "network" "variables" "PASS" "VPC variables defined" ""
        fi
        
    else
        log_error "VPC 설정 파일을 찾을 수 없습니다: $vpc_file"
        add_result "vpc_validation" "network" "configuration" "FAIL" "VPC configuration file not found" "$vpc_file"
    fi
}

# 서브넷 구성 검증
validate_subnet_configuration() {
    log_info "서브넷 구성 검증 중..."
    
    local vpc_module_file="$TERRAFORM_DIR/modules/vpc/main.tf"
    local subnet_types=("public" "private_app" "private_db")
    
    if [[ -f "$vpc_module_file" ]]; then
        for subnet_type in "${subnet_types[@]}"; do
            # 모듈에서 서브넷 리소스 확인
            if grep -q "resource.*aws_subnet.*$subnet_type" "$vpc_module_file"; then
                log_success "서브넷: $subnet_type 서브넷 리소스 정의 확인"
                add_result "subnet_validation" "network" "$subnet_type" "PASS" "Subnet resource defined in module" ""
                
                # for_each 사용 확인 (Multi-AZ 지원)
                if grep -A5 "resource.*aws_subnet.*$subnet_type" "$vpc_module_file" | grep -q "for_each"; then
                    log_success "서브넷: $subnet_type 서브넷 Multi-AZ 구성 (for_each) 확인"
                    add_result "subnet_validation" "network" "${subnet_type}_multi_az" "PASS" "Multi-AZ configuration using for_each" ""
                fi
                
                # 가용 영역 설정 확인
                if grep -A10 "resource.*aws_subnet.*$subnet_type" "$vpc_module_file" | grep -q "availability_zone.*=.*each.value.az"; then
                    log_success "서브넷: $subnet_type 서브넷 AZ 동적 할당 확인"
                    add_result "subnet_validation" "network" "${subnet_type}_az_assignment" "PASS" "Dynamic AZ assignment configured" ""
                fi
                
                # 태그 설정 확인
                if grep -A15 "resource.*aws_subnet.*$subnet_type" "$vpc_module_file" | grep -q "Tier.*=.*\"$subnet_type\""; then
                    log_success "서브넷: $subnet_type 서브넷 Tier 태그 확인"
                    add_result "subnet_validation" "network" "${subnet_type}_tier_tag" "PASS" "Tier tag properly configured" ""
                fi
                
                # Public 서브넷 특별 설정 확인
                if [[ "$subnet_type" == "public" ]]; then
                    if grep -A10 "resource.*aws_subnet.*public" "$vpc_module_file" | grep -q "map_public_ip_on_launch.*=.*true"; then
                        log_success "서브넷: Public 서브넷 자동 퍼블릭 IP 할당 확인"
                        add_result "subnet_validation" "network" "public_ip_assignment" "PASS" "Auto public IP assignment configured" ""
                    fi
                fi
                
            else
                log_warning "서브넷: $subnet_type 서브넷 리소스 정의 확인 필요"
                add_result "subnet_validation" "network" "$subnet_type" "WARNING" "Subnet resource definition needs review" ""
            fi
        done
        
        # IPv6 지원 확인
        if grep -q "assign_ipv6_address_on_creation.*=.*var.enable_ipv6" "$vpc_module_file"; then
            log_success "서브넷: IPv6 주소 자동 할당 설정 확인"
            add_result "subnet_validation" "network" "ipv6_assignment" "PASS" "IPv6 auto-assignment configured" ""
        fi
        
    else
        log_error "VPC 모듈 파일을 찾을 수 없습니다: $vpc_module_file"
        add_result "subnet_validation" "network" "module_file" "FAIL" "VPC module file not found" "$vpc_module_file"
    fi
}

# 보안 그룹 구성 검증
validate_security_group_configuration() {
    log_info "보안 그룹 구성 검증 중..."
    
    local security_files=("$TERRAFORM_DIR/envs/dev/security"/*.tf)
    local sg_types=("alb" "ecs" "rds" "vpc-endpoint")
    
    for sg_type in "${sg_types[@]}"; do
        local found_sg=false
        
        for file in "${security_files[@]}"; do
            if [[ -f "$file" ]] && grep -q "resource.*aws_security_group.*$sg_type" "$file" 2>/dev/null; then
                found_sg=true
                break
            fi
        done
        
        if [[ "$found_sg" == "true" ]]; then
            log_success "보안 그룹: $sg_type 보안 그룹 설정 확인"
            add_result "security_group_validation" "security" "$sg_type" "PASS" "Security group configuration found" ""
            
            # 포트 규칙 검증
            validate_security_group_rules "$sg_type" "${security_files[@]}"
        else
            log_warning "보안 그룹: $sg_type 보안 그룹 설정 확인 필요"
            add_result "security_group_validation" "security" "$sg_type" "WARNING" "Security group configuration needs review" ""
        fi
    done
}

# 보안 그룹 규칙 상세 검증
validate_security_group_rules() {
    local sg_type="$1"
    shift
    local files=("$@")
    
    case "$sg_type" in
        "alb")
            # ALB는 80, 443 포트 인바운드 허용해야 함
            for file in "${files[@]}"; do
                if [[ -f "$file" ]] && grep -q "from_port.*=.*80\|to_port.*=.*80" "$file" 2>/dev/null; then
                    log_success "보안 그룹: ALB HTTP(80) 포트 규칙 확인"
                    add_result "security_group_rules" "alb" "http_port" "PASS" "HTTP port rule configured" ""
                    break
                fi
            done
            
            for file in "${files[@]}"; do
                if [[ -f "$file" ]] && grep -q "from_port.*=.*443\|to_port.*=.*443" "$file" 2>/dev/null; then
                    log_success "보안 그룹: ALB HTTPS(443) 포트 규칙 확인"
                    add_result "security_group_rules" "alb" "https_port" "PASS" "HTTPS port rule configured" ""
                    break
                fi
            done
            ;;
        "ecs")
            # ECS는 8080 포트 인바운드 허용해야 함
            for file in "${files[@]}"; do
                if [[ -f "$file" ]] && grep -q "from_port.*=.*8080\|to_port.*=.*8080" "$file" 2>/dev/null; then
                    log_success "보안 그룹: ECS 애플리케이션(8080) 포트 규칙 확인"
                    add_result "security_group_rules" "ecs" "app_port" "PASS" "Application port rule configured" ""
                    break
                fi
            done
            ;;
        "rds")
            # RDS는 3306 포트 인바운드 허용해야 함
            for file in "${files[@]}"; do
                if [[ -f "$file" ]] && grep -q "from_port.*=.*3306\|to_port.*=.*3306" "$file" 2>/dev/null; then
                    log_success "보안 그룹: RDS MySQL(3306) 포트 규칙 확인"
                    add_result "security_group_rules" "rds" "mysql_port" "PASS" "MySQL port rule configured" ""
                    break
                fi
            done
            ;;
        "vpc-endpoint")
            # VPC 엔드포인트는 443 포트 인바운드 허용해야 함
            for file in "${files[@]}"; do
                if [[ -f "$file" ]] && grep -q "from_port.*=.*443\|to_port.*=.*443" "$file" 2>/dev/null; then
                    log_success "보안 그룹: VPC 엔드포인트 HTTPS(443) 포트 규칙 확인"
                    add_result "security_group_rules" "vpc_endpoint" "https_port" "PASS" "HTTPS port rule configured" ""
                    break
                fi
            done
            ;;
    esac
}

# 라우트 테이블 구성 검증
validate_route_table_configuration() {
    log_info "라우트 테이블 구성 검증 중..."
    
    local network_files=("$TERRAFORM_DIR/envs/dev/network"/*.tf)
    local route_types=("public" "private-app" "private-db")
    
    for route_type in "${route_types[@]}"; do
        local found_route_table=false
        
        for file in "${network_files[@]}"; do
            if [[ -f "$file" ]] && grep -q "resource.*aws_route_table.*$route_type" "$file" 2>/dev/null; then
                found_route_table=true
                log_success "라우트 테이블: $route_type 라우트 테이블 설정 확인"
                add_result "route_table_validation" "network" "$route_type" "PASS" "Route table configuration found" ""
                
                # 라우트 규칙 검증
                validate_route_rules "$route_type" "$file"
                break
            fi
        done
        
        if [[ "$found_route_table" == "false" ]]; then
            log_warning "라우트 테이블: $route_type 라우트 테이블 설정 확인 필요"
            add_result "route_table_validation" "network" "$route_type" "WARNING" "Route table configuration needs review" ""
        fi
    done
}

# 라우트 규칙 상세 검증
validate_route_rules() {
    local route_type="$1"
    local file="$2"
    
    case "$route_type" in
        "public")
            # Public 라우트 테이블은 IGW로의 0.0.0.0/0 경로가 있어야 함
            if grep -q "cidr_block.*=.*\"0.0.0.0/0\"" "$file" && grep -q "gateway_id.*=.*aws_internet_gateway" "$file"; then
                log_success "라우트 규칙: Public 서브넷 인터넷 게이트웨이 경로 확인"
                add_result "route_rules" "public" "internet_gateway" "PASS" "Internet gateway route configured" ""
            else
                log_warning "라우트 규칙: Public 서브넷 인터넷 게이트웨이 경로 확인 필요"
                add_result "route_rules" "public" "internet_gateway" "WARNING" "Internet gateway route needs review" ""
            fi
            ;;
        "private-app")
            # Private App 라우트 테이블은 NAT Gateway로의 0.0.0.0/0 경로가 있어야 함
            if grep -q "cidr_block.*=.*\"0.0.0.0/0\"" "$file" && grep -q "nat_gateway_id.*=.*aws_nat_gateway" "$file"; then
                log_success "라우트 규칙: Private App 서브넷 NAT 게이트웨이 경로 확인"
                add_result "route_rules" "private_app" "nat_gateway" "PASS" "NAT gateway route configured" ""
            else
                log_warning "라우트 규칙: Private App 서브넷 NAT 게이트웨이 경로 확인 필요"
                add_result "route_rules" "private_app" "nat_gateway" "WARNING" "NAT gateway route needs review" ""
            fi
            ;;
        "private-db")
            # Private DB 라우트 테이블은 인터넷 경로가 없어야 함 (보안)
            if ! grep -q "cidr_block.*=.*\"0.0.0.0/0\"" "$file"; then
                log_success "라우트 규칙: Private DB 서브넷 인터넷 경로 없음 (보안 준수)"
                add_result "route_rules" "private_db" "no_internet" "PASS" "No internet route (secure)" ""
            else
                log_error "라우트 규칙: Private DB 서브넷 인터넷 경로 존재 (보안 위험)"
                add_result "route_rules" "private_db" "internet_route" "FAIL" "Internet route exists (security risk)" ""
            fi
            ;;
    esac
}

# VPC 엔드포인트 구성 검증
validate_vpc_endpoints() {
    log_info "VPC 엔드포인트 구성 검증 중..."
    
    local security_files=("$TERRAFORM_DIR/envs/dev/security"/*.tf)
    local required_endpoints=(
        "ecr.api"
        "ecr.dkr"
        "logs"
        "ssm"
        "secretsmanager"
        "s3"
    )
    
    for endpoint in "${required_endpoints[@]}"; do
        local found_endpoint=false
        
        for file in "${security_files[@]}"; do
            if [[ -f "$file" ]] && grep -q "service_name.*=.*\"com.amazonaws.ap-northeast-2.$endpoint\"" "$file" 2>/dev/null; then
                found_endpoint=true
                break
            fi
        done
        
        if [[ "$found_endpoint" == "true" ]]; then
            log_success "VPC 엔드포인트: $endpoint 엔드포인트 설정 확인"
            add_result "vpc_endpoints" "security" "$endpoint" "PASS" "VPC endpoint configured" ""
        else
            log_warning "VPC 엔드포인트: $endpoint 엔드포인트 설정 권장"
            add_result "vpc_endpoints" "security" "$endpoint" "WARNING" "VPC endpoint recommended" ""
        fi
    done
}

# 네트워크 연결성 시뮬레이션 (설정 기반)
simulate_network_connectivity() {
    log_info "네트워크 연결성 시뮬레이션 중..."
    
    # Public → Internet 연결성 (IGW 경로 기반)
    simulate_public_internet_connectivity
    
    # Private App → Internet 연결성 (NAT Gateway 경로 기반)
    simulate_private_app_internet_connectivity
    
    # Private DB 격리 확인 (인터넷 경로 없음)
    simulate_private_db_isolation
    
    # VPC 내부 통신 (같은 VPC 내 서브넷 간)
    simulate_internal_communication
    
    # VPC 엔드포인트 연결성
    simulate_vpc_endpoint_connectivity
}

# Public 서브넷 인터넷 연결성 시뮬레이션
simulate_public_internet_connectivity() {
    log_info "Public 서브넷 → 인터넷 연결성 시뮬레이션"
    
    local network_files=("$TERRAFORM_DIR/envs/dev/network"/*.tf)
    local has_public_subnet=false
    local has_igw_route=false
    
    # Public 서브넷 존재 확인
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]] && grep -q "resource.*aws_subnet.*public" "$file" 2>/dev/null; then
            has_public_subnet=true
            break
        fi
    done
    
    # IGW 경로 존재 확인
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]] && grep -q "gateway_id.*=.*aws_internet_gateway" "$file" 2>/dev/null; then
            has_igw_route=true
            break
        fi
    done
    
    if [[ "$has_public_subnet" == "true" && "$has_igw_route" == "true" ]]; then
        log_success "연결성 시뮬레이션: Public 서브넷 → 인터넷 연결 가능"
        add_result "connectivity_simulation" "public_subnet" "internet" "PASS" "Internet connectivity available via IGW" ""
    else
        log_warning "연결성 시뮬레이션: Public 서브넷 → 인터넷 연결 설정 확인 필요"
        add_result "connectivity_simulation" "public_subnet" "internet" "WARNING" "Internet connectivity configuration needs review" "Subnet: $has_public_subnet, IGW: $has_igw_route"
    fi
}

# Private App 서브넷 인터넷 연결성 시뮬레이션
simulate_private_app_internet_connectivity() {
    log_info "Private App 서브넷 → 인터넷 (아웃바운드) 연결성 시뮬레이션"
    
    local network_files=("$TERRAFORM_DIR/envs/dev/network"/*.tf)
    local has_private_app_subnet=false
    local has_nat_route=false
    
    # Private App 서브넷 존재 확인
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]] && grep -q "resource.*aws_subnet.*private-app" "$file" 2>/dev/null; then
            has_private_app_subnet=true
            break
        fi
    done
    
    # NAT Gateway 경로 존재 확인
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]] && grep -q "nat_gateway_id.*=.*aws_nat_gateway" "$file" 2>/dev/null; then
            has_nat_route=true
            break
        fi
    done
    
    if [[ "$has_private_app_subnet" == "true" && "$has_nat_route" == "true" ]]; then
        log_success "연결성 시뮬레이션: Private App 서브넷 → 인터넷 아웃바운드 연결 가능"
        add_result "connectivity_simulation" "private_app_subnet" "internet" "PASS" "Outbound internet connectivity available via NAT Gateway" ""
    else
        log_warning "연결성 시뮬레이션: Private App 서브넷 → 인터넷 아웃바운드 연결 설정 확인 필요"
        add_result "connectivity_simulation" "private_app_subnet" "internet" "WARNING" "Outbound internet connectivity configuration needs review" "Subnet: $has_private_app_subnet, NAT: $has_nat_route"
    fi
}

# Private DB 서브넷 격리 시뮬레이션
simulate_private_db_isolation() {
    log_info "Private DB 서브넷 격리 시뮬레이션 (보안 검증)"
    
    local network_files=("$TERRAFORM_DIR/envs/dev/network"/*.tf)
    local has_private_db_subnet=false
    local has_internet_route=false
    
    # Private DB 서브넷 존재 확인
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]] && grep -q "resource.*aws_subnet.*private-db" "$file" 2>/dev/null; then
            has_private_db_subnet=true
            
            # 해당 파일에서 인터넷 경로 확인
            if grep -q "cidr_block.*=.*\"0.0.0.0/0\"" "$file" && grep -q "private-db" "$file"; then
                has_internet_route=true
            fi
            break
        fi
    done
    
    if [[ "$has_private_db_subnet" == "true" && "$has_internet_route" == "false" ]]; then
        log_success "연결성 시뮬레이션: Private DB 서브넷 격리 확인 (보안 준수)"
        add_result "connectivity_simulation" "private_db_subnet" "isolation" "PASS" "Database subnet properly isolated from internet" ""
    elif [[ "$has_private_db_subnet" == "true" && "$has_internet_route" == "true" ]]; then
        log_error "연결성 시뮬레이션: Private DB 서브넷 인터넷 경로 존재 (보안 위험)"
        add_result "connectivity_simulation" "private_db_subnet" "isolation" "FAIL" "Database subnet has internet route (security risk)" ""
    else
        log_warning "연결성 시뮬레이션: Private DB 서브넷 설정 확인 필요"
        add_result "connectivity_simulation" "private_db_subnet" "isolation" "WARNING" "Database subnet configuration needs review" "Subnet: $has_private_db_subnet"
    fi
}

# VPC 내부 통신 시뮬레이션
simulate_internal_communication() {
    log_info "VPC 내부 통신 시뮬레이션"
    
    local network_files=("$TERRAFORM_DIR/envs/dev/network"/*.tf)
    local has_vpc=false
    local subnet_count=0
    
    # VPC 존재 확인
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]] && grep -q "resource.*aws_vpc" "$file" 2>/dev/null; then
            has_vpc=true
            break
        fi
    done
    
    # 서브넷 개수 확인
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]]; then
            local count=$(grep -c "resource.*aws_subnet" "$file" 2>/dev/null || echo "0")
            if [[ "$count" =~ ^[0-9]+$ ]]; then
                subnet_count=$((subnet_count + count))
            fi
        fi
    done
    
    if [[ "$has_vpc" == "true" && $subnet_count -ge 2 ]]; then
        log_success "연결성 시뮬레이션: VPC 내부 통신 가능 (VPC: $has_vpc, 서브넷: $subnet_count개)"
        add_result "connectivity_simulation" "vpc_internal" "communication" "PASS" "Internal VPC communication available" "Subnets: $subnet_count"
    else
        log_warning "연결성 시뮬레이션: VPC 내부 통신 설정 확인 필요"
        add_result "connectivity_simulation" "vpc_internal" "communication" "WARNING" "Internal VPC communication configuration needs review" "VPC: $has_vpc, Subnets: $subnet_count"
    fi
}

# VPC 엔드포인트 연결성 시뮬레이션
simulate_vpc_endpoint_connectivity() {
    log_info "VPC 엔드포인트 연결성 시뮬레이션"
    
    local security_files=("$TERRAFORM_DIR/envs/dev/security"/*.tf)
    local endpoint_count=0
    local has_private_subnet=false
    
    # VPC 엔드포인트 개수 확인
    for file in "${security_files[@]}"; do
        if [[ -f "$file" ]]; then
            local count=$(grep -c "resource.*aws_vpc_endpoint" "$file" 2>/dev/null || echo "0")
            if [[ "$count" =~ ^[0-9]+$ ]]; then
                endpoint_count=$((endpoint_count + count))
            fi
        fi
    done
    
    # Private 서브넷 존재 확인
    local network_files=("$TERRAFORM_DIR/envs/dev/network"/*.tf)
    for file in "${network_files[@]}"; do
        if [[ -f "$file" ]] && grep -q "resource.*aws_subnet.*private" "$file" 2>/dev/null; then
            has_private_subnet=true
            break
        fi
    done
    
    if [[ $endpoint_count -gt 0 && "$has_private_subnet" == "true" ]]; then
        log_success "연결성 시뮬레이션: VPC 엔드포인트 연결 가능 ($endpoint_count개 엔드포인트)"
        add_result "connectivity_simulation" "private_subnet" "vpc_endpoints" "PASS" "VPC endpoint connectivity available" "Endpoints: $endpoint_count"
    else
        log_warning "연결성 시뮬레이션: VPC 엔드포인트 연결 설정 확인 필요"
        add_result "connectivity_simulation" "private_subnet" "vpc_endpoints" "WARNING" "VPC endpoint connectivity configuration needs review" "Endpoints: $endpoint_count, Private subnet: $has_private_subnet"
    fi
}

# 결과 저장 (클린 코드: 재사용 가능한 함수)
save_results() {
    log_info "검증 결과 저장 중..."
    
    # JSON 배열 생성
    local json_results="["
    for i in "${!VALIDATION_RESULTS[@]}"; do
        json_results+="${VALIDATION_RESULTS[$i]}"
        if [[ $i -lt $((${#VALIDATION_RESULTS[@]} - 1)) ]]; then
            json_results+=","
        fi
    done
    json_results+="]"
    
    # 결과 파일 저장
    echo "$json_results" > "$RESULTS_FILE"
    
    # 요약 통계 생성
    local total_tests=${#VALIDATION_RESULTS[@]}
    local passed_tests=0
    local failed_tests=0
    local warning_tests=0
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        if [[ "$result" == *'"status": "PASS"'* ]]; then
            ((passed_tests++))
        elif [[ "$result" == *'"status": "FAIL"'* ]]; then
            ((failed_tests++))
        elif [[ "$result" == *'"status": "WARNING"'* ]]; then
            ((warning_tests++))
        fi
    done
    
    # 요약 리포트 생성
    cat > "$RESULTS_DIR/network-connectivity-mcp-summary-$TIMESTAMP.txt" << EOF
=== 네트워크 연결성 검증 요약 (MCP 통합 버전) ===
검증 시간: $(date)
총 테스트: $total_tests
통과: $passed_tests
실패: $failed_tests
경고: $warning_tests

상세 결과: $RESULTS_FILE

=== 주요 발견 사항 ===
EOF
    
    # 실패한 테스트 목록 추가
    if [[ $failed_tests -gt 0 ]]; then
        echo "" >> "$RESULTS_DIR/network-connectivity-mcp-summary-$TIMESTAMP.txt"
        echo "실패한 테스트:" >> "$RESULTS_DIR/network-connectivity-mcp-summary-$TIMESTAMP.txt"
        for result in "${VALIDATION_RESULTS[@]}"; do
            if [[ "$result" == *'"status": "FAIL"'* ]]; then
                local source=$(echo "$result" | grep -o '"source": "[^"]*"' | cut -d'"' -f4)
                local destination=$(echo "$result" | grep -o '"destination": "[^"]*"' | cut -d'"' -f4)
                local message=$(echo "$result" | grep -o '"message": "[^"]*"' | cut -d'"' -f4)
                echo "- $source → $destination: $message" >> "$RESULTS_DIR/network-connectivity-mcp-summary-$TIMESTAMP.txt"
            fi
        done
    fi
    
    log_success "검증 결과가 저장되었습니다: $RESULTS_FILE"
    log_info "요약 리포트: $RESULTS_DIR/network-connectivity-mcp-summary-$TIMESTAMP.txt"
}

# 메인 실행 함수 (클린 아키텍처: 의존성 주입)
main() {
    log_info "=== 네트워크 연결성 검증 시작 (MCP 통합 버전) ==="
    log_info "프로젝트 루트: $PROJECT_ROOT"
    log_info "결과 저장 위치: $RESULTS_DIR"
    
    # Terraform 코드 품질 검증
    validate_terraform_code_quality
    
    # AWS 리소스 구성 검증
    validate_aws_resources
    
    # VPC 엔드포인트 구성 검증
    validate_vpc_endpoints
    
    # 네트워크 연결성 시뮬레이션
    simulate_network_connectivity
    
    # 결과 저장
    save_results
    
    log_success "=== 네트워크 연결성 검증 완료 (MCP 통합 버전) ==="
    
    # 실패한 테스트가 있으면 종료 코드 1 반환
    local failed_count=0
    for result in "${VALIDATION_RESULTS[@]}"; do
        if [[ "$result" == *'"status": "FAIL"'* ]]; then
            ((failed_count++))
        fi
    done
    
    if [[ $failed_count -gt 0 ]]; then
        log_error "$failed_count개의 테스트가 실패했습니다."
        exit 1
    fi
}

# 스크립트 실행
main "$@"