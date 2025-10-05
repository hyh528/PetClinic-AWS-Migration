#!/bin/bash

# 네트워크 연결성 테스트 스크립트
# 영현님 스타일: 클린 코드 + 클린 아키텍처 + Well-Architected Framework
# 목적: 각 서브넷에서 의도된 대상으로의 연결성 테스트

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
readonly RESULTS_FILE="$RESULTS_DIR/network-connectivity-$TIMESTAMP.json"

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

# 네트워크 연결성 테스트 정의 (클린 아키텍처: 데이터 구조로 추상화)
declare -A CONNECTIVITY_TESTS=(
    # Public Subnet 테스트
    ["public_to_internet"]="Public → Internet (양방향 통신)"
    ["public_to_private_app"]="Public → Private App (ALB → ECS)"
    ["public_to_private_db"]="Public → Private DB (차단되어야 함)"
    
    # Private App Subnet 테스트
    ["private_app_to_internet"]="Private App → Internet (아웃바운드만)"
    ["private_app_to_private_db"]="Private App → Private DB (MySQL)"
    ["private_app_to_vpc_endpoints"]="Private App → VPC Endpoints"
    
    # Private DB Subnet 테스트
    ["private_db_to_internet"]="Private DB → Internet (차단되어야 함)"
    ["private_db_to_private_app"]="Private DB → Private App (응답만)"
)

# AWS CLI 설치 확인 (Well-Architected: 운영 우수성)
check_aws_cli() {
    log_info "AWS CLI 설치 확인 중..."
    
    # 드라이런 모드 확인
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "드라이런 모드: AWS CLI 검사 건너뜀"
        add_result "prerequisites" "system" "aws_cli" "INFO" "Dry run mode - AWS CLI check skipped" ""
        return 0
    fi
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI가 설치되지 않았습니다."
        log_info "드라이런 모드로 실행하려면: DRY_RUN=true ./validate-network-connectivity.sh"
        add_result "prerequisites" "system" "aws_cli" "FAIL" "AWS CLI not installed" ""
        return 1
    fi
    
    # AWS 자격 증명 확인
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 자격 증명이 설정되지 않았습니다."
        add_result "prerequisites" "system" "aws_credentials" "FAIL" "AWS credentials not configured" ""
        return 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    log_success "AWS CLI 설정 완료 (Account: $account_id)"
    add_result "prerequisites" "system" "aws_cli" "PASS" "AWS CLI configured" "Account: $account_id"
    return 0
}

# VPC 정보 수집 (클린 아키텍처: 의존성 역전)
get_vpc_info() {
    log_info "VPC 정보 수집 중..."
    
    # 드라이런 모드 확인
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "드라이런 모드: 가상 VPC ID 사용"
        add_result "vpc_discovery" "system" "vpc_id" "INFO" "Dry run mode - using mock VPC ID" "vpc-mock123456"
        echo "vpc-mock123456"
        return 0
    fi
    
    # VPC ID 찾기 (petclinic 태그 기반)
    local vpc_id=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=petclinic" \
        --query "Vpcs[0].VpcId" \
        --output text 2>/dev/null)
    
    if [[ "$vpc_id" == "None" || -z "$vpc_id" ]]; then
        log_error "PetClinic VPC를 찾을 수 없습니다."
        add_result "vpc_discovery" "system" "vpc_id" "FAIL" "VPC not found" ""
        return 1
    fi
    
    log_success "VPC 발견: $vpc_id"
    echo "$vpc_id"
}

# 서브넷 정보 수집 (클린 코드: 명확한 함수명)
get_subnet_info() {
    local vpc_id="$1"
    log_info "서브넷 정보 수집 중..."
    
    # 서브넷 타입별 수집
    local public_subnets=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Tier,Values=public" \
        --query "Subnets[].SubnetId" \
        --output text)
    
    local private_app_subnets=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Tier,Values=private-app" \
        --query "Subnets[].SubnetId" \
        --output text)
    
    local private_db_subnets=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Tier,Values=private-db" \
        --query "Subnets[].SubnetId" \
        --output text)
    
    # 결과 검증
    if [[ -z "$public_subnets" ]]; then
        log_warning "Public 서브넷을 찾을 수 없습니다."
        add_result "subnet_discovery" "vpc" "public_subnets" "WARNING" "No public subnets found" ""
    else
        log_success "Public 서브넷: $public_subnets"
        add_result "subnet_discovery" "vpc" "public_subnets" "PASS" "Public subnets found" "$public_subnets"
    fi
    
    if [[ -z "$private_app_subnets" ]]; then
        log_warning "Private App 서브넷을 찾을 수 없습니다."
        add_result "subnet_discovery" "vpc" "private_app_subnets" "WARNING" "No private app subnets found" ""
    else
        log_success "Private App 서브넷: $private_app_subnets"
        add_result "subnet_discovery" "vpc" "private_app_subnets" "PASS" "Private app subnets found" "$private_app_subnets"
    fi
    
    if [[ -z "$private_db_subnets" ]]; then
        log_warning "Private DB 서브넷을 찾을 수 없습니다."
        add_result "subnet_discovery" "vpc" "private_db_subnets" "WARNING" "No private db subnets found" ""
    else
        log_success "Private DB 서브넷: $private_db_subnets"
        add_result "subnet_discovery" "vpc" "private_db_subnets" "PASS" "Private db subnets found" "$private_db_subnets"
    fi
    
    # 전역 변수에 저장 (클린 코드: 명확한 변수명)
    PUBLIC_SUBNETS=($public_subnets)
    PRIVATE_APP_SUBNETS=($private_app_subnets)
    PRIVATE_DB_SUBNETS=($private_db_subnets)
}

# 라우트 테이블 검증 (Well-Architected: 보안)
validate_route_tables() {
    local vpc_id="$1"
    log_info "라우트 테이블 검증 중..."
    
    # Public 라우트 테이블 확인
    local public_rt=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Tier,Values=public" \
        --query "RouteTables[0].RouteTableId" \
        --output text)
    
    if [[ "$public_rt" != "None" && -n "$public_rt" ]]; then
        # 인터넷 게이트웨이 경로 확인
        local igw_route=$(aws ec2 describe-route-tables \
            --route-table-ids "$public_rt" \
            --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
            --output text)
        
        if [[ "$igw_route" == igw-* ]]; then
            log_success "Public 라우트 테이블: 인터넷 게이트웨이 경로 확인"
            add_result "route_validation" "public_subnet" "internet_gateway" "PASS" "IGW route exists" "$igw_route"
        else
            log_error "Public 라우트 테이블: 인터넷 게이트웨이 경로 없음"
            add_result "route_validation" "public_subnet" "internet_gateway" "FAIL" "No IGW route" ""
        fi
    else
        log_error "Public 라우트 테이블을 찾을 수 없습니다."
        add_result "route_validation" "public_subnet" "route_table" "FAIL" "Public route table not found" ""
    fi
    
    # Private App 라우트 테이블 확인
    local private_app_rt=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Tier,Values=private-app" \
        --query "RouteTables[0].RouteTableId" \
        --output text)
    
    if [[ "$private_app_rt" != "None" && -n "$private_app_rt" ]]; then
        # NAT 게이트웨이 경로 확인
        local nat_route=$(aws ec2 describe-route-tables \
            --route-table-ids "$private_app_rt" \
            --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" \
            --output text)
        
        if [[ "$nat_route" == nat-* ]]; then
            log_success "Private App 라우트 테이블: NAT 게이트웨이 경로 확인"
            add_result "route_validation" "private_app_subnet" "nat_gateway" "PASS" "NAT route exists" "$nat_route"
        else
            log_warning "Private App 라우트 테이블: NAT 게이트웨이 경로 없음"
            add_result "route_validation" "private_app_subnet" "nat_gateway" "WARNING" "No NAT route" ""
        fi
    else
        log_error "Private App 라우트 테이블을 찾을 수 없습니다."
        add_result "route_validation" "private_app_subnet" "route_table" "FAIL" "Private app route table not found" ""
    fi
    
    # Private DB 라우트 테이블 확인 (인터넷 경로가 없어야 함)
    local private_db_rt=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Tier,Values=private-db" \
        --query "RouteTables[0].RouteTableId" \
        --output text)
    
    if [[ "$private_db_rt" != "None" && -n "$private_db_rt" ]]; then
        # 인터넷 경로가 없는지 확인 (보안)
        local internet_route=$(aws ec2 describe-route-tables \
            --route-table-ids "$private_db_rt" \
            --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0']" \
            --output text)
        
        if [[ -z "$internet_route" ]]; then
            log_success "Private DB 라우트 테이블: 인터넷 경로 없음 (보안 준수)"
            add_result "route_validation" "private_db_subnet" "no_internet_route" "PASS" "No internet route (secure)" ""
        else
            log_error "Private DB 라우트 테이블: 인터넷 경로 존재 (보안 위험)"
            add_result "route_validation" "private_db_subnet" "no_internet_route" "FAIL" "Internet route exists (security risk)" ""
        fi
    else
        log_error "Private DB 라우트 테이블을 찾을 수 없습니다."
        add_result "route_validation" "private_db_subnet" "route_table" "FAIL" "Private db route table not found" ""
    fi
}

# VPC 엔드포인트 확인 (Well-Architected: 보안)
validate_vpc_endpoints() {
    local vpc_id="$1"
    log_info "VPC 엔드포인트 확인 중..."
    
    # 필수 VPC 엔드포인트 목록
    local required_endpoints=(
        "com.amazonaws.ap-northeast-2.ecr.api"
        "com.amazonaws.ap-northeast-2.ecr.dkr"
        "com.amazonaws.ap-northeast-2.logs"
        "com.amazonaws.ap-northeast-2.ssm"
        "com.amazonaws.ap-northeast-2.secretsmanager"
    )
    
    for endpoint_service in "${required_endpoints[@]}"; do
        local endpoint_id=$(aws ec2 describe-vpc-endpoints \
            --filters "Name=vpc-id,Values=$vpc_id" "Name=service-name,Values=$endpoint_service" \
            --query "VpcEndpoints[0].VpcEndpointId" \
            --output text)
        
        if [[ "$endpoint_id" != "None" && -n "$endpoint_id" ]]; then
            log_success "VPC 엔드포인트 확인: $endpoint_service"
            add_result "vpc_endpoints" "private_subnet" "$endpoint_service" "PASS" "VPC endpoint exists" "$endpoint_id"
        else
            log_warning "VPC 엔드포인트 없음: $endpoint_service"
            add_result "vpc_endpoints" "private_subnet" "$endpoint_service" "WARNING" "VPC endpoint missing" ""
        fi
    done
}

# 보안 그룹 규칙 검증 (Well-Architected: 보안)
validate_security_groups() {
    local vpc_id="$1"
    log_info "보안 그룹 규칙 검증 중..."
    
    # ALB 보안 그룹 확인
    validate_alb_security_group "$vpc_id"
    
    # ECS 보안 그룹 확인
    validate_ecs_security_group "$vpc_id"
    
    # RDS 보안 그룹 확인
    validate_rds_security_group "$vpc_id"
    
    # VPC 엔드포인트 보안 그룹 확인
    validate_vpc_endpoint_security_group "$vpc_id"
}

# ALB 보안 그룹 상세 검증
validate_alb_security_group() {
    local vpc_id="$1"
    log_info "ALB 보안 그룹 검증 중..."
    
    local alb_sg=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=*alb*" \
        --query "SecurityGroups[0].GroupId" \
        --output text)
    
    if [[ "$alb_sg" == "None" || -z "$alb_sg" ]]; then
        log_warning "ALB 보안 그룹을 찾을 수 없습니다."
        add_result "security_groups" "alb" "discovery" "WARNING" "ALB security group not found" ""
        return
    fi
    
    # HTTP (80) 인바운드 규칙 확인
    local http_rule=$(aws ec2 describe-security-groups \
        --group-ids "$alb_sg" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && ToPort==\`80\`]" \
        --output json)
    
    if [[ "$http_rule" != "[]" ]]; then
        log_success "ALB 보안 그룹: HTTP(80) 인바운드 규칙 확인"
        add_result "security_groups" "alb" "http_inbound" "PASS" "HTTP inbound rule exists" "$alb_sg"
    else
        log_error "ALB 보안 그룹: HTTP(80) 인바운드 규칙 누락"
        add_result "security_groups" "alb" "http_inbound" "FAIL" "Missing HTTP inbound rule" "$alb_sg"
    fi
    
    # HTTPS (443) 인바운드 규칙 확인
    local https_rule=$(aws ec2 describe-security-groups \
        --group-ids "$alb_sg" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`443\` && ToPort==\`443\`]" \
        --output json)
    
    if [[ "$https_rule" != "[]" ]]; then
        log_success "ALB 보안 그룹: HTTPS(443) 인바운드 규칙 확인"
        add_result "security_groups" "alb" "https_inbound" "PASS" "HTTPS inbound rule exists" "$alb_sg"
    else
        log_error "ALB 보안 그룹: HTTPS(443) 인바운드 규칙 누락"
        add_result "security_groups" "alb" "https_inbound" "FAIL" "Missing HTTPS inbound rule" "$alb_sg"
    fi
    
    # ECS로의 아웃바운드 규칙 확인 (8080 포트)
    local ecs_outbound=$(aws ec2 describe-security-groups \
        --group-ids "$alb_sg" \
        --query "SecurityGroups[0].IpPermissionsEgress[?FromPort==\`8080\` && ToPort==\`8080\`]" \
        --output json)
    
    if [[ "$ecs_outbound" != "[]" ]]; then
        log_success "ALB 보안 그룹: ECS(8080) 아웃바운드 규칙 확인"
        add_result "security_groups" "alb" "ecs_outbound" "PASS" "ECS outbound rule exists" "$alb_sg"
    else
        log_warning "ALB 보안 그룹: ECS(8080) 아웃바운드 규칙 확인 필요"
        add_result "security_groups" "alb" "ecs_outbound" "WARNING" "ECS outbound rule may be missing" "$alb_sg"
    fi
}

# ECS 보안 그룹 검증
validate_ecs_security_group() {
    local vpc_id="$1"
    log_info "ECS 보안 그룹 검증 중..."
    
    local ecs_sg=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=*ecs*" \
        --query "SecurityGroups[0].GroupId" \
        --output text)
    
    if [[ "$ecs_sg" == "None" || -z "$ecs_sg" ]]; then
        log_warning "ECS 보안 그룹을 찾을 수 없습니다."
        add_result "security_groups" "ecs" "discovery" "WARNING" "ECS security group not found" ""
        return
    fi
    
    # ALB로부터의 인바운드 규칙 확인 (8080 포트)
    local alb_inbound=$(aws ec2 describe-security-groups \
        --group-ids "$ecs_sg" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`8080\` && ToPort==\`8080\`]" \
        --output json)
    
    if [[ "$alb_inbound" != "[]" ]]; then
        log_success "ECS 보안 그룹: ALB로부터 8080 인바운드 규칙 확인"
        add_result "security_groups" "ecs" "alb_inbound" "PASS" "ALB inbound rule exists" "$ecs_sg"
    else
        log_error "ECS 보안 그룹: ALB로부터 8080 인바운드 규칙 누락"
        add_result "security_groups" "ecs" "alb_inbound" "FAIL" "Missing ALB inbound rule" "$ecs_sg"
    fi
    
    # RDS로의 아웃바운드 규칙 확인 (3306 포트)
    local rds_outbound=$(aws ec2 describe-security-groups \
        --group-ids "$ecs_sg" \
        --query "SecurityGroups[0].IpPermissionsEgress[?FromPort==\`3306\` && ToPort==\`3306\`]" \
        --output json)
    
    if [[ "$rds_outbound" != "[]" ]]; then
        log_success "ECS 보안 그룹: RDS(3306) 아웃바운드 규칙 확인"
        add_result "security_groups" "ecs" "rds_outbound" "PASS" "RDS outbound rule exists" "$ecs_sg"
    else
        log_warning "ECS 보안 그룹: RDS(3306) 아웃바운드 규칙 확인 필요"
        add_result "security_groups" "ecs" "rds_outbound" "WARNING" "RDS outbound rule may be missing" "$ecs_sg"
    fi
}

# RDS 보안 그룹 검증
validate_rds_security_group() {
    local vpc_id="$1"
    log_info "RDS 보안 그룹 검증 중..."
    
    local rds_sg=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=*rds*,*aurora*,*db*" \
        --query "SecurityGroups[0].GroupId" \
        --output text)
    
    if [[ "$rds_sg" == "None" || -z "$rds_sg" ]]; then
        log_warning "RDS 보안 그룹을 찾을 수 없습니다."
        add_result "security_groups" "rds" "discovery" "WARNING" "RDS security group not found" ""
        return
    fi
    
    # ECS로부터의 인바운드 규칙 확인 (3306 포트)
    local ecs_inbound=$(aws ec2 describe-security-groups \
        --group-ids "$rds_sg" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`3306\` && ToPort==\`3306\`]" \
        --output json)
    
    if [[ "$ecs_inbound" != "[]" ]]; then
        log_success "RDS 보안 그룹: ECS로부터 3306 인바운드 규칙 확인"
        add_result "security_groups" "rds" "ecs_inbound" "PASS" "ECS inbound rule exists" "$rds_sg"
    else
        log_error "RDS 보안 그룹: ECS로부터 3306 인바운드 규칙 누락"
        add_result "security_groups" "rds" "ecs_inbound" "FAIL" "Missing ECS inbound rule" "$rds_sg"
    fi
    
    # 불필요한 아웃바운드 규칙 확인 (보안)
    local outbound_rules=$(aws ec2 describe-security-groups \
        --group-ids "$rds_sg" \
        --query "SecurityGroups[0].IpPermissionsEgress" \
        --output json)
    
    if [[ "$outbound_rules" == "[]" ]]; then
        log_success "RDS 보안 그룹: 아웃바운드 규칙 없음 (보안 준수)"
        add_result "security_groups" "rds" "no_outbound" "PASS" "No outbound rules (secure)" "$rds_sg"
    else
        log_warning "RDS 보안 그룹: 아웃바운드 규칙 존재 (검토 필요)"
        add_result "security_groups" "rds" "outbound_review" "WARNING" "Outbound rules exist (review needed)" "$rds_sg"
    fi
}

# VPC 엔드포인트 보안 그룹 검증
validate_vpc_endpoint_security_group() {
    local vpc_id="$1"
    log_info "VPC 엔드포인트 보안 그룹 검증 중..."
    
    local vpce_sg=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=*vpce*,*endpoint*" \
        --query "SecurityGroups[0].GroupId" \
        --output text)
    
    if [[ "$vpce_sg" == "None" || -z "$vpce_sg" ]]; then
        log_warning "VPC 엔드포인트 보안 그룹을 찾을 수 없습니다."
        add_result "security_groups" "vpc_endpoint" "discovery" "WARNING" "VPC endpoint security group not found" ""
        return
    fi
    
    # HTTPS (443) 인바운드 규칙 확인
    local https_inbound=$(aws ec2 describe-security-groups \
        --group-ids "$vpce_sg" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`443\` && ToPort==\`443\`]" \
        --output json)
    
    if [[ "$https_inbound" != "[]" ]]; then
        log_success "VPC 엔드포인트 보안 그룹: HTTPS(443) 인바운드 규칙 확인"
        add_result "security_groups" "vpc_endpoint" "https_inbound" "PASS" "HTTPS inbound rule exists" "$vpce_sg"
    else
        log_error "VPC 엔드포인트 보안 그룹: HTTPS(443) 인바운드 규칙 누락"
        add_result "security_groups" "vpc_endpoint" "https_inbound" "FAIL" "Missing HTTPS inbound rule" "$vpce_sg"
    fi
}

# 네트워크 ACL 검증 (추가 보안 계층)
validate_network_acls() {
    local vpc_id="$1"
    log_info "네트워크 ACL 검증 중..."
    
    # 기본 네트워크 ACL 확인
    local default_nacl=$(aws ec2 describe-network-acls \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=default,Values=true" \
        --query "NetworkAcls[0].NetworkAclId" \
        --output text)
    
    if [[ "$default_nacl" != "None" && -n "$default_nacl" ]]; then
        log_info "기본 네트워크 ACL 확인: $default_nacl"
        
        # 기본 ACL이 모든 트래픽을 허용하는지 확인
        local allow_all_inbound=$(aws ec2 describe-network-acls \
            --network-acl-ids "$default_nacl" \
            --query "NetworkAcls[0].Entries[?RuleAction=='allow' && CidrBlock=='0.0.0.0/0' && !Egress]" \
            --output json)
        
        if [[ "$allow_all_inbound" != "[]" ]]; then
            log_warning "기본 네트워크 ACL: 모든 인바운드 트래픽 허용 (보안 검토 필요)"
            add_result "network_acl" "default" "inbound_permissive" "WARNING" "Default NACL allows all inbound traffic" "$default_nacl"
        else
            log_success "기본 네트워크 ACL: 제한적 인바운드 규칙"
            add_result "network_acl" "default" "inbound_restrictive" "PASS" "Default NACL has restrictive inbound rules" "$default_nacl"
        fi
    fi
    
    # 커스텀 네트워크 ACL 확인
    validate_custom_network_acls "$vpc_id"
}

# 커스텀 네트워크 ACL 검증
validate_custom_network_acls() {
    local vpc_id="$1"
    
    # Public 서브넷 ACL 확인
    if [[ ${#PUBLIC_SUBNETS[@]} -gt 0 ]]; then
        local public_subnet="${PUBLIC_SUBNETS[0]}"
        local public_nacl=$(aws ec2 describe-network-acls \
            --filters "Name=association.subnet-id,Values=$public_subnet" \
            --query "NetworkAcls[0].NetworkAclId" \
            --output text)
        
        if [[ "$public_nacl" != "None" && -n "$public_nacl" ]]; then
            validate_public_nacl_rules "$public_nacl"
        fi
    fi
    
    # Private App 서브넷 ACL 확인
    if [[ ${#PRIVATE_APP_SUBNETS[@]} -gt 0 ]]; then
        local private_app_subnet="${PRIVATE_APP_SUBNETS[0]}"
        local private_app_nacl=$(aws ec2 describe-network-acls \
            --filters "Name=association.subnet-id,Values=$private_app_subnet" \
            --query "NetworkAcls[0].NetworkAclId" \
            --output text)
        
        if [[ "$private_app_nacl" != "None" && -n "$private_app_nacl" ]]; then
            validate_private_app_nacl_rules "$private_app_nacl"
        fi
    fi
    
    # Private DB 서브넷 ACL 확인
    if [[ ${#PRIVATE_DB_SUBNETS[@]} -gt 0 ]]; then
        local private_db_subnet="${PRIVATE_DB_SUBNETS[0]}"
        local private_db_nacl=$(aws ec2 describe-network-acls \
            --filters "Name=association.subnet-id,Values=$private_db_subnet" \
            --query "NetworkAcls[0].NetworkAclId" \
            --output text)
        
        if [[ "$private_db_nacl" != "None" && -n "$private_db_nacl" ]]; then
            validate_private_db_nacl_rules "$private_db_nacl"
        fi
    fi
}

# Public 서브넷 NACL 규칙 검증
validate_public_nacl_rules() {
    local nacl_id="$1"
    log_info "Public 서브넷 NACL 규칙 검증: $nacl_id"
    
    # HTTP/HTTPS 인바운드 허용 확인
    local web_inbound=$(aws ec2 describe-network-acls \
        --network-acl-ids "$nacl_id" \
        --query "NetworkAcls[0].Entries[?RuleAction=='allow' && !Egress && (PortRange.From==\`80\` || PortRange.From==\`443\`)]" \
        --output json)
    
    if [[ "$web_inbound" != "[]" ]]; then
        log_success "Public NACL: HTTP/HTTPS 인바운드 허용"
        add_result "network_acl" "public_subnet" "web_inbound" "PASS" "HTTP/HTTPS inbound allowed" "$nacl_id"
    else
        log_warning "Public NACL: HTTP/HTTPS 인바운드 규칙 확인 필요"
        add_result "network_acl" "public_subnet" "web_inbound" "WARNING" "HTTP/HTTPS inbound rules may be missing" "$nacl_id"
    fi
    
    # 에페메랄 포트 아웃바운드 허용 확인 (1024-65535)
    local ephemeral_outbound=$(aws ec2 describe-network-acls \
        --network-acl-ids "$nacl_id" \
        --query "NetworkAcls[0].Entries[?RuleAction=='allow' && Egress && PortRange.From>=\`1024\`]" \
        --output json)
    
    if [[ "$ephemeral_outbound" != "[]" ]]; then
        log_success "Public NACL: 에페메랄 포트 아웃바운드 허용"
        add_result "network_acl" "public_subnet" "ephemeral_outbound" "PASS" "Ephemeral ports outbound allowed" "$nacl_id"
    else
        log_warning "Public NACL: 에페메랄 포트 아웃바운드 규칙 확인 필요"
        add_result "network_acl" "public_subnet" "ephemeral_outbound" "WARNING" "Ephemeral ports outbound may be restricted" "$nacl_id"
    fi
}

# Private App 서브넷 NACL 규칙 검증
validate_private_app_nacl_rules() {
    local nacl_id="$1"
    log_info "Private App 서브넷 NACL 규칙 검증: $nacl_id"
    
    # ALB로부터 8080 포트 인바운드 허용 확인
    local alb_inbound=$(aws ec2 describe-network-acls \
        --network-acl-ids "$nacl_id" \
        --query "NetworkAcls[0].Entries[?RuleAction=='allow' && !Egress && PortRange.From==\`8080\`]" \
        --output json)
    
    if [[ "$alb_inbound" != "[]" ]]; then
        log_success "Private App NACL: ALB 8080 포트 인바운드 허용"
        add_result "network_acl" "private_app_subnet" "alb_inbound" "PASS" "ALB 8080 inbound allowed" "$nacl_id"
    else
        log_warning "Private App NACL: ALB 8080 포트 인바운드 규칙 확인 필요"
        add_result "network_acl" "private_app_subnet" "alb_inbound" "WARNING" "ALB 8080 inbound may be missing" "$nacl_id"
    fi
    
    # VPC 엔드포인트 통신 허용 확인 (443 포트)
    local vpce_outbound=$(aws ec2 describe-network-acls \
        --network-acl-ids "$nacl_id" \
        --query "NetworkAcls[0].Entries[?RuleAction=='allow' && Egress && PortRange.From==\`443\`]" \
        --output json)
    
    if [[ "$vpce_outbound" != "[]" ]]; then
        log_success "Private App NACL: VPC 엔드포인트 443 포트 아웃바운드 허용"
        add_result "network_acl" "private_app_subnet" "vpce_outbound" "PASS" "VPC endpoint 443 outbound allowed" "$nacl_id"
    else
        log_warning "Private App NACL: VPC 엔드포인트 443 포트 아웃바운드 규칙 확인 필요"
        add_result "network_acl" "private_app_subnet" "vpce_outbound" "WARNING" "VPC endpoint 443 outbound may be missing" "$nacl_id"
    fi
}

# Private DB 서브넷 NACL 규칙 검증
validate_private_db_nacl_rules() {
    local nacl_id="$1"
    log_info "Private DB 서브넷 NACL 규칙 검증: $nacl_id"
    
    # Private App에서 3306 포트 인바운드 허용 확인
    local app_inbound=$(aws ec2 describe-network-acls \
        --network-acl-ids "$nacl_id" \
        --query "NetworkAcls[0].Entries[?RuleAction=='allow' && !Egress && PortRange.From==\`3306\`]" \
        --output json)
    
    if [[ "$app_inbound" != "[]" ]]; then
        log_success "Private DB NACL: Private App 3306 포트 인바운드 허용"
        add_result "network_acl" "private_db_subnet" "app_inbound" "PASS" "Private App 3306 inbound allowed" "$nacl_id"
    else
        log_warning "Private DB NACL: Private App 3306 포트 인바운드 규칙 확인 필요"
        add_result "network_acl" "private_db_subnet" "app_inbound" "WARNING" "Private App 3306 inbound may be missing" "$nacl_id"
    fi
    
    # 인터넷 아웃바운드 차단 확인 (보안)
    local internet_outbound=$(aws ec2 describe-network-acls \
        --network-acl-ids "$nacl_id" \
        --query "NetworkAcls[0].Entries[?RuleAction=='allow' && Egress && CidrBlock=='0.0.0.0/0']" \
        --output json)
    
    if [[ "$internet_outbound" == "[]" ]]; then
        log_success "Private DB NACL: 인터넷 아웃바운드 차단 (보안 준수)"
        add_result "network_acl" "private_db_subnet" "no_internet_outbound" "PASS" "No internet outbound (secure)" "$nacl_id"
    else
        log_error "Private DB NACL: 인터넷 아웃바운드 허용 (보안 위험)"
        add_result "network_acl" "private_db_subnet" "internet_outbound_risk" "FAIL" "Internet outbound allowed (security risk)" "$nacl_id"
    fi
}

# 실제 네트워크 연결성 테스트 (요구사항 2.5 구현)
test_network_connectivity() {
    log_info "실제 네트워크 연결성 테스트 중..."
    
    # 1. Public Subnet → Internet 테스트
    test_public_to_internet
    
    # 2. Private App Subnet → Internet (아웃바운드만) 테스트
    test_private_app_to_internet
    
    # 3. Private DB Subnet 격리 테스트
    test_private_db_isolation
    
    # 4. VPC 내부 통신 테스트
    test_internal_communication
    
    # 5. VPC 엔드포인트 연결성 테스트
    test_vpc_endpoint_connectivity
}

# Public Subnet에서 인터넷 연결성 테스트
test_public_to_internet() {
    log_info "Public Subnet → Internet 연결성 테스트"
    
    if [[ ${#PUBLIC_SUBNETS[@]} -eq 0 ]]; then
        add_result "connectivity_test" "public_subnet" "internet" "FAIL" "No public subnets found" ""
        return
    fi
    
    local public_subnet="${PUBLIC_SUBNETS[0]}"
    
    # 라우트 테이블에서 IGW 경로 확인
    local route_table=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$public_subnet" \
        --query "RouteTables[0].RouteTableId" \
        --output text)
    
    if [[ "$route_table" == "None" || -z "$route_table" ]]; then
        add_result "connectivity_test" "public_subnet" "internet" "FAIL" "No route table associated" "$public_subnet"
        return
    fi
    
    # 0.0.0.0/0 → IGW 경로 확인
    local igw_route=$(aws ec2 describe-route-tables \
        --route-table-ids "$route_table" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0' && GatewayId!=null].GatewayId" \
        --output text)
    
    if [[ "$igw_route" == igw-* ]]; then
        log_success "Public Subnet: 인터넷 게이트웨이 경로 확인됨"
        add_result "connectivity_test" "public_subnet" "internet" "PASS" "IGW route exists for internet access" "Route: $igw_route"
        
        # 추가: 인터넷 게이트웨이 상태 확인
        local igw_state=$(aws ec2 describe-internet-gateways \
            --internet-gateway-ids "$igw_route" \
            --query "InternetGateways[0].State" \
            --output text 2>/dev/null)
        
        if [[ "$igw_state" == "available" ]]; then
            add_result "connectivity_test" "public_subnet" "igw_status" "PASS" "Internet Gateway is available" "$igw_route"
        else
            add_result "connectivity_test" "public_subnet" "igw_status" "WARNING" "Internet Gateway state: $igw_state" "$igw_route"
        fi
    else
        log_error "Public Subnet: 인터넷 게이트웨이 경로 없음"
        add_result "connectivity_test" "public_subnet" "internet" "FAIL" "No IGW route for internet access" "Route table: $route_table"
    fi
}

# Private App Subnet에서 인터넷 아웃바운드 테스트
test_private_app_to_internet() {
    log_info "Private App Subnet → Internet (아웃바운드) 테스트"
    
    if [[ ${#PRIVATE_APP_SUBNETS[@]} -eq 0 ]]; then
        add_result "connectivity_test" "private_app_subnet" "internet" "FAIL" "No private app subnets found" ""
        return
    fi
    
    local private_app_subnet="${PRIVATE_APP_SUBNETS[0]}"
    
    # 라우트 테이블에서 NAT Gateway 경로 확인
    local route_table=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$private_app_subnet" \
        --query "RouteTables[0].RouteTableId" \
        --output text)
    
    if [[ "$route_table" == "None" || -z "$route_table" ]]; then
        add_result "connectivity_test" "private_app_subnet" "internet" "FAIL" "No route table associated" "$private_app_subnet"
        return
    fi
    
    # 0.0.0.0/0 → NAT Gateway 경로 확인
    local nat_route=$(aws ec2 describe-route-tables \
        --route-table-ids "$route_table" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0' && NatGatewayId!=null].NatGatewayId" \
        --output text)
    
    if [[ "$nat_route" == nat-* ]]; then
        log_success "Private App Subnet: NAT Gateway 경로 확인됨"
        add_result "connectivity_test" "private_app_subnet" "internet" "PASS" "NAT Gateway route exists for outbound internet" "Route: $nat_route"
        
        # NAT Gateway 상태 확인
        local nat_state=$(aws ec2 describe-nat-gateways \
            --nat-gateway-ids "$nat_route" \
            --query "NatGateways[0].State" \
            --output text 2>/dev/null)
        
        if [[ "$nat_state" == "available" ]]; then
            add_result "connectivity_test" "private_app_subnet" "nat_status" "PASS" "NAT Gateway is available" "$nat_route"
        else
            add_result "connectivity_test" "private_app_subnet" "nat_status" "WARNING" "NAT Gateway state: $nat_state" "$nat_route"
        fi
    else
        log_error "Private App Subnet: NAT Gateway 경로 없음"
        add_result "connectivity_test" "private_app_subnet" "internet" "FAIL" "No NAT Gateway route for outbound internet" "Route table: $route_table"
    fi
}

# Private DB Subnet 격리 테스트 (인터넷 접근 차단 확인)
test_private_db_isolation() {
    log_info "Private DB Subnet 격리 테스트 (보안 검증)"
    
    if [[ ${#PRIVATE_DB_SUBNETS[@]} -eq 0 ]]; then
        add_result "connectivity_test" "private_db_subnet" "isolation" "FAIL" "No private db subnets found" ""
        return
    fi
    
    local private_db_subnet="${PRIVATE_DB_SUBNETS[0]}"
    
    # 라우트 테이블 확인
    local route_table=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$private_db_subnet" \
        --query "RouteTables[0].RouteTableId" \
        --output text)
    
    if [[ "$route_table" == "None" || -z "$route_table" ]]; then
        add_result "connectivity_test" "private_db_subnet" "isolation" "FAIL" "No route table associated" "$private_db_subnet"
        return
    fi
    
    # 인터넷 경로가 없는지 확인 (보안 요구사항)
    local internet_routes=$(aws ec2 describe-route-tables \
        --route-table-ids "$route_table" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0']" \
        --output text)
    
    if [[ -z "$internet_routes" ]]; then
        log_success "Private DB Subnet: 인터넷 경로 없음 (보안 준수)"
        add_result "connectivity_test" "private_db_subnet" "isolation" "PASS" "No internet routes (secure isolation)" "Route table: $route_table"
    else
        log_error "Private DB Subnet: 인터넷 경로 존재 (보안 위험)"
        add_result "connectivity_test" "private_db_subnet" "isolation" "FAIL" "Internet routes exist (security risk)" "Routes: $internet_routes"
    fi
    
    # VPC 내부 통신만 허용되는지 확인
    local local_routes=$(aws ec2 describe-route-tables \
        --route-table-ids "$route_table" \
        --query "RouteTables[0].Routes[?GatewayId=='local']" \
        --output text)
    
    if [[ -n "$local_routes" ]]; then
        log_success "Private DB Subnet: VPC 내부 통신 경로 확인됨"
        add_result "connectivity_test" "private_db_subnet" "internal_communication" "PASS" "VPC local routes exist" "Local routes available"
    else
        log_error "Private DB Subnet: VPC 내부 통신 경로 없음"
        add_result "connectivity_test" "private_db_subnet" "internal_communication" "FAIL" "No VPC local routes" "Route table: $route_table"
    fi
}

# VPC 내부 통신 테스트
test_internal_communication() {
    log_info "VPC 내부 통신 테스트"
    
    # Private App → Private DB 통신 가능성 확인
    if [[ ${#PRIVATE_APP_SUBNETS[@]} -gt 0 && ${#PRIVATE_DB_SUBNETS[@]} -gt 0 ]]; then
        local app_subnet="${PRIVATE_APP_SUBNETS[0]}"
        local db_subnet="${PRIVATE_DB_SUBNETS[0]}"
        
        # 같은 VPC 내부인지 확인
        local app_vpc=$(aws ec2 describe-subnets \
            --subnet-ids "$app_subnet" \
            --query "Subnets[0].VpcId" \
            --output text)
        
        local db_vpc=$(aws ec2 describe-subnets \
            --subnet-ids "$db_subnet" \
            --query "Subnets[0].VpcId" \
            --output text)
        
        if [[ "$app_vpc" == "$db_vpc" ]]; then
            log_success "Private App ↔ Private DB: 같은 VPC 내부 통신 가능"
            add_result "connectivity_test" "private_app_subnet" "private_db_subnet" "PASS" "Same VPC allows internal communication" "VPC: $app_vpc"
        else
            log_error "Private App ↔ Private DB: 다른 VPC (통신 불가)"
            add_result "connectivity_test" "private_app_subnet" "private_db_subnet" "FAIL" "Different VPCs prevent communication" "App VPC: $app_vpc, DB VPC: $db_vpc"
        fi
    else
        add_result "connectivity_test" "internal_communication" "subnets" "WARNING" "Insufficient subnets for internal communication test" ""
    fi
}

# VPC 엔드포인트 연결성 테스트
test_vpc_endpoint_connectivity() {
    log_info "VPC 엔드포인트 연결성 테스트"
    
    local vpc_id=$(get_vpc_info)
    if [[ -z "$vpc_id" ]]; then
        add_result "connectivity_test" "vpc_endpoints" "discovery" "FAIL" "Cannot determine VPC ID" ""
        return
    fi
    
    # 필수 VPC 엔드포인트와 Private App Subnet 연결성 확인
    local required_endpoints=(
        "com.amazonaws.ap-northeast-2.ecr.api"
        "com.amazonaws.ap-northeast-2.ecr.dkr"
        "com.amazonaws.ap-northeast-2.logs"
        "com.amazonaws.ap-northeast-2.ssm"
        "com.amazonaws.ap-northeast-2.secretsmanager"
    )
    
    for endpoint_service in "${required_endpoints[@]}"; do
        local endpoint_info=$(aws ec2 describe-vpc-endpoints \
            --filters "Name=vpc-id,Values=$vpc_id" "Name=service-name,Values=$endpoint_service" \
            --query "VpcEndpoints[0].[VpcEndpointId,State,SubnetIds]" \
            --output text)
        
        if [[ "$endpoint_info" != "None" && -n "$endpoint_info" ]]; then
            local endpoint_id=$(echo "$endpoint_info" | cut -f1)
            local endpoint_state=$(echo "$endpoint_info" | cut -f2)
            local endpoint_subnets=$(echo "$endpoint_info" | cut -f3-)
            
            if [[ "$endpoint_state" == "available" ]]; then
                log_success "VPC 엔드포인트 연결 가능: $endpoint_service"
                add_result "connectivity_test" "private_app_subnet" "$endpoint_service" "PASS" "VPC endpoint available" "ID: $endpoint_id, Subnets: $endpoint_subnets"
                
                # Private App Subnet과의 연결성 확인
                for private_subnet in "${PRIVATE_APP_SUBNETS[@]}"; do
                    if [[ "$endpoint_subnets" == *"$private_subnet"* ]]; then
                        add_result "connectivity_test" "private_app_subnet" "${endpoint_service}_subnet_match" "PASS" "Endpoint in same subnet as private app" "Subnet: $private_subnet"
                        break
                    fi
                done
            else
                log_warning "VPC 엔드포인트 상태 이상: $endpoint_service ($endpoint_state)"
                add_result "connectivity_test" "private_app_subnet" "$endpoint_service" "WARNING" "VPC endpoint not available" "State: $endpoint_state"
            fi
        else
            log_warning "VPC 엔드포인트 없음: $endpoint_service"
            add_result "connectivity_test" "private_app_subnet" "$endpoint_service" "WARNING" "VPC endpoint missing" "Service: $endpoint_service"
        fi
    done
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
    cat > "$RESULTS_DIR/network-connectivity-summary-$TIMESTAMP.txt" << EOF
=== 네트워크 연결성 검증 요약 ===
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
        echo "" >> "$RESULTS_DIR/network-connectivity-summary-$TIMESTAMP.txt"
        echo "실패한 테스트:" >> "$RESULTS_DIR/network-connectivity-summary-$TIMESTAMP.txt"
        for result in "${VALIDATION_RESULTS[@]}"; do
            if [[ "$result" == *'"status": "FAIL"'* ]]; then
                local source=$(echo "$result" | grep -o '"source": "[^"]*"' | cut -d'"' -f4)
                local destination=$(echo "$result" | grep -o '"destination": "[^"]*"' | cut -d'"' -f4)
                local message=$(echo "$result" | grep -o '"message": "[^"]*"' | cut -d'"' -f4)
                echo "- $source → $destination: $message" >> "$RESULTS_DIR/network-connectivity-summary-$TIMESTAMP.txt"
            fi
        done
    fi
    
    log_success "검증 결과가 저장되었습니다: $RESULTS_FILE"
    log_info "요약 리포트: $RESULTS_DIR/network-connectivity-summary-$TIMESTAMP.txt"
}

# 메인 실행 함수 (클린 아키텍처: 의존성 주입)
main() {
    log_info "=== 네트워크 연결성 검증 시작 ==="
    log_info "프로젝트 루트: $PROJECT_ROOT"
    log_info "결과 저장 위치: $RESULTS_DIR"
    
    # AWS CLI 확인
    if ! check_aws_cli; then
        log_error "AWS CLI 설정이 필요합니다."
        save_results
        exit 1
    fi
    
    # VPC 정보 수집
    local vpc_id
    if ! vpc_id=$(get_vpc_info); then
        log_error "VPC 정보를 가져올 수 없습니다."
        save_results
        exit 1
    fi
    
    # 서브넷 정보 수집
    get_subnet_info "$vpc_id"
    
    # 라우트 테이블 검증
    validate_route_tables "$vpc_id"
    
    # VPC 엔드포인트 확인
    validate_vpc_endpoints "$vpc_id"
    
    # 보안 그룹 검증
    validate_security_groups "$vpc_id"
    
    # 네트워크 ACL 검증
    validate_network_acls "$vpc_id"
    
    # 실제 네트워크 연결성 테스트
    test_network_connectivity
    
    # 결과 저장
    save_results
    
    log_success "=== 네트워크 연결성 검증 완료 ==="
    
    # 실패한 테스트가 있으면 종료 코드 1 반환
    if [[ $failed_tests -gt 0 ]]; then
        log_error "$failed_tests개의 테스트가 실패했습니다."
        exit 1
    fi
}

# 스크립트 실행
main "$@"