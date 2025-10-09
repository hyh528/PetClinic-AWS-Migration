#!/bin/bash

# ==========================================
# Cloud Map 서비스 디스커버리 검증 스크립트
# ==========================================
# AWS Cloud Map을 통한 서비스 디스커버리 기능을 테스트합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 설정
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
NAMESPACE_NAME="${NAMESPACE_NAME:-petclinic-dev}"
TEST_TIMEOUT=30

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# AWS CLI 명령어 실행 함수
aws_cmd() {
    local cmd="$1"
    local description="$2"

    log_info "실행: $description"
    log_info "명령어: $cmd"

    if eval "$cmd"; then
        log_success "$description 성공"
        return 0
    else
        log_error "$description 실패"
        return 1
    fi
}

# Cloud Map 네임스페이스 확인
check_namespace() {
    log_info "=== Cloud Map 네임스페이스 확인 ==="

    local namespace_id=$(aws servicediscovery list-namespaces \
        --region $AWS_REGION \
        --query "Namespaces[?Name=='$NAMESPACE_NAME'].Id" \
        --output text 2>/dev/null)

    if [ -n "$namespace_id" ] && [ "$namespace_id" != "None" ]; then
        log_success "네임스페이스 발견: $NAMESPACE_NAME (ID: $namespace_id)"
        echo $namespace_id
    else
        log_error "네임스페이스를 찾을 수 없음: $NAMESPACE_NAME"
        return 1
    fi
}

# 서비스 확인
check_services() {
    local namespace_id=$1
    log_info "=== Cloud Map 서비스 확인 ==="

    local services=$(aws servicediscovery list-services \
        --region $AWS_REGION \
        --query "Services[?NamespaceId=='$namespace_id'].Name" \
        --output text 2>/dev/null)

    if [ -n "$services" ]; then
        log_success "서비스 발견: $services"
        echo $services
    else
        log_error "서비스를 찾을 수 없음"
        return 1
    fi
}

# 서비스 인스턴스 확인
check_service_instances() {
    local namespace_id=$1
    local service_name=$2
    log_info "=== 서비스 인스턴스 확인: $service_name ==="

    # 서비스 ID 조회
    local service_id=$(aws servicediscovery list-services \
        --region $AWS_REGION \
        --query "Services[?Name=='$service_name' && NamespaceId=='$namespace_id'].Id" \
        --output text 2>/dev/null)

    if [ -z "$service_id" ] || [ "$service_id" = "None" ]; then
        log_error "서비스 ID를 찾을 수 없음: $service_name"
        return 1
    fi

    # 서비스 인스턴스 조회
    local instances=$(aws servicediscovery list-instances \
        --region $AWS_REGION \
        --service-id $service_id \
        --query "Instances[].Id" \
        --output text 2>/dev/null)

    if [ -n "$instances" ]; then
        log_success "서비스 인스턴스 발견: $service_name ($instances)"

        # 각 인스턴스 상세 정보 확인
        for instance_id in $instances; do
            local instance_info=$(aws servicediscovery get-instance \
                --region $AWS_REGION \
                --service-id $service_id \
                --instance-id $instance_id \
                --query "Instance" 2>/dev/null)

            if [ $? -eq 0 ]; then
                local ip=$(echo $instance_info | jq -r '.Attributes.AWS_INSTANCE_IPV4 // empty')
                local port=$(echo $instance_info | jq -r '.Attributes.AWS_INSTANCE_PORT // empty')

                if [ -n "$ip" ] && [ -n "$port" ]; then
                    log_success "인스턴스 $instance_id - IP: $ip, Port: $port"
                else
                    log_warning "인스턴스 $instance_id - 속성 정보 부족"
                fi
            fi
        done

        return 0
    else
        log_error "서비스 인스턴스를 찾을 수 없음: $service_name"
        return 1
    fi
}

# DNS 해석 테스트
test_dns_resolution() {
    local service_name=$1
    log_info "=== DNS 해석 테스트: $service_name ==="

    local dns_name="$service_name.$NAMESPACE_NAME"

    # nslookup으로 DNS 해석 시도
    if command -v nslookup >/dev/null 2>&1; then
        local dns_result=$(nslookup $dns_name 2>/dev/null)
        if echo "$dns_result" | grep -q "Address"; then
            log_success "DNS 해석 성공: $dns_name"
            echo "$dns_result" | grep "Address" | head -3
            return 0
        fi
    fi

    # dig 명령어로 테스트
    if command -v dig >/dev/null 2>&1; then
        local dns_result=$(dig +short $dns_name 2>/dev/null)
        if [ -n "$dns_result" ]; then
            log_success "DNS 해석 성공: $dns_name"
            echo "IP 주소: $dns_result"
            return 0
        fi
    fi

    # curl로 직접 연결 테스트 (포트 8080 가정)
    local test_url="http://$dns_name:8080/actuator/health"
    if curl -f -s --max-time 10 "$test_url" >/dev/null 2>&1; then
        log_success "직접 연결 성공: $dns_name:8080"
        return 0
    fi

    log_error "DNS 해석 실패: $dns_name"
    return 1
}

# 헬스체크 상태 확인
check_health_status() {
    local service_name=$1
    log_info "=== 헬스체크 상태 확인: $service_name ==="

    # Cloud Map 헬스체크는 ECS 서비스의 헬스체크와 통합되어 있으므로
    # 실제 서비스의 헬스체크 엔드포인트로 확인
    local health_url="http://$service_name.$NAMESPACE_NAME/actuator/health"

    if curl -f -s --max-time 10 "$health_url" >/dev/null 2>&1; then
        log_success "헬스체크 통과: $service_name"
        return 0
    else
        log_error "헬스체크 실패: $service_name"
        return 1
    fi
}

# 메인 테스트 함수
main() {
    log_info "=== Cloud Map 서비스 디스커버리 테스트 시작 ==="
    log_info "리전: $AWS_REGION"
    log_info "네임스페이스: $NAMESPACE_NAME"

    local test_count=0
    local success_count=0

    # 1. 네임스페이스 확인
    ((test_count++))
    NAMESPACE_ID=$(check_namespace)
    if [ $? -eq 0 ]; then
        ((success_count++))
    else
        log_error "네임스페이스 확인 실패로 테스트 중단"
        exit 1
    fi

    # 2. 서비스 목록 확인
    ((test_count++))
    SERVICES=$(check_services $NAMESPACE_ID)
    if [ $? -eq 0 ]; then
        ((success_count++))
    else
        log_error "서비스 목록 확인 실패"
    fi

    # 3. 각 서비스별 상세 테스트
    for service in $SERVICES; do
        log_info "--- 서비스 테스트: $service ---"

        # 서비스 인스턴스 확인
        ((test_count++))
        if check_service_instances $NAMESPACE_ID $service; then
            ((success_count++))
        fi

        # DNS 해석 테스트
        ((test_count++))
        if test_dns_resolution $service; then
            ((success_count++))
        fi

        # 헬스체크 상태 확인
        ((test_count++))
        if check_health_status $service; then
            ((success_count++))
        fi
    done

    # 4. 서비스 간 통신 테스트
    log_info "=== 서비스 간 통신 테스트 ==="

    # API Gateway를 통한 서비스 간 통신 확인
    ((test_count++))
    if curl -f -s --max-time 10 "http://api-gateway.$NAMESPACE_NAME/api/customers/owners" >/dev/null 2>&1; then
        log_success "API Gateway → Customers Service 통신 성공"
        ((success_count++))
    else
        log_error "API Gateway → Customers Service 통신 실패"
    fi

    # 5. 테스트 결과 요약
    log_info "=== 테스트 결과 요약 ==="
    log_info "총 테스트 수: $test_count"
    log_info "성공: $success_count"
    log_info "실패: $((test_count - success_count))"
    log_info "성공률: $((success_count * 100 / test_count))%"

    if [ $success_count -eq $test_count ]; then
        log_success "🎉 모든 Cloud Map 서비스 디스커버리 테스트 성공!"
        return 0
    else
        log_error "❌ 일부 Cloud Map 테스트 실패"
        return 1
    fi
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi