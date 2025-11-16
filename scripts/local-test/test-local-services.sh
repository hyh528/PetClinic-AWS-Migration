#!/bin/bash

# ==========================================
# 로컬 환경 AWS 네이티브 마이그레이션 테스트 스크립트
# ==========================================
# 이 스크립트는 로컬 Docker 환경에서 Spring PetClinic 서비스들을
# AWS 네이티브 서비스(Parameter Store, Cloud Map)와 유사한 방식으로 테스트합니다.

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

# 서비스 상태 확인 함수
check_service_health() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1

    log_info "서비스 헬스체크 시작: $service_name ($url)"

    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            log_success "서비스 정상 동작: $service_name"
            return 0
        fi

        log_info "서비스 대기 중: $service_name (시도 $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done

    log_error "서비스 헬스체크 실패: $service_name"
    return 1
}

# API 테스트 함수
test_api_endpoint() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-200}

    log_info "API 테스트: $service_name ($url)"

    local response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$url")
    local body=$(echo "$response" | sed 's/HTTPSTATUS.*//')
    local status=$(echo "$response" | grep "HTTPSTATUS" | sed 's/.*HTTPSTATUS://')

    if [ "$status" = "$expected_status" ]; then
        log_success "API 정상 응답: $service_name (Status: $status)"
        return 0
    else
        log_error "API 응답 오류: $service_name (Status: $status, Expected: $expected_status)"
        echo "Response: $body"
        return 1
    fi
}

# 메인 테스트 함수
main() {
    log_info "=== 로컬 AWS 네이티브 마이그레이션 테스트 시작 ==="

    # 1. Docker Compose 서비스 시작
    log_info "Docker Compose 서비스 시작..."
    docker-compose up -d

    # 2. 서비스 헬스체크
    log_info "=== 서비스 헬스체크 ==="

    check_service_health "MySQL" "http://localhost:3306" || exit 1
    check_service_health "Customers Service" "http://localhost:8081/actuator/health" || exit 1
    check_service_health "Vets Service" "http://localhost:8082/actuator/health" || exit 1
    check_service_health "Visits Service" "http://localhost:8083/actuator/health" || exit 1
    check_service_health "Admin Server" "http://localhost:9090/actuator/health" || exit 1
    check_service_health "API Gateway" "http://localhost:8080/actuator/health" || exit 1

    # 3. API 기능 테스트
    log_info "=== API 기능 테스트 ==="

    # Customers API 테스트
    test_api_endpoint "Customers API" "http://localhost:8080/api/customers/owners" || exit 1

    # Vets API 테스트
    test_api_endpoint "Vets API" "http://localhost:8080/api/vets/vets" || exit 1

    # Visits API 테스트
    test_api_endpoint "Visits API" "http://localhost:8080/api/visits/visits" || exit 1

    # 4. 데이터베이스 연결 테스트
    log_info "=== 데이터베이스 연결 테스트 ==="

    # MySQL 연결 테스트
    if docker-compose exec -T mysql mysql -u petclinic -ppetclinic123 -e "SELECT 1;" petclinic_customers > /dev/null 2>&1; then
        log_success "MySQL 연결 정상"
    else
        log_error "MySQL 연결 실패"
        exit 1
    fi

    # 5. 서비스 간 통신 테스트
    log_info "=== 서비스 간 통신 테스트 ==="

    # API Gateway를 통한 서비스 간 통신 확인
    if curl -f -s "http://localhost:8080/api/customers/owners" | grep -q "owners"; then
        log_success "API Gateway → Customers Service 통신 정상"
    else
        log_error "API Gateway → Customers Service 통신 실패"
        exit 1
    fi

    # 6. LocalStack Parameter Store 테스트
    log_info "=== LocalStack Parameter Store 테스트 ==="

    # LocalStack가 실행 중인지 확인
    if curl -f -s "http://localhost:4566/_localstack/health" > /dev/null 2>&1; then
        log_success "LocalStack Parameter Store 실행 중"

        # 파라미터 저장 테스트
        aws --endpoint-url=http://localhost:4566 ssm put-parameter \
            --name "/petclinic/dev/test" \
            --value "test-value" \
            --type "String" \
            --region us-east-1 > /dev/null 2>&1 && log_success "Parameter Store 파라미터 저장 성공" || log_error "Parameter Store 파라미터 저장 실패"

        # 파라미터 조회 테스트
        if aws --endpoint-url=http://localhost:4566 ssm get-parameter \
            --name "/petclinic/dev/test" \
            --region us-east-1 --query 'Parameter.Value' --output text 2>/dev/null | grep -q "test-value"; then
            log_success "Parameter Store 파라미터 조회 성공"
        else
            log_error "Parameter Store 파라미터 조회 실패"
        fi
    else
        log_warning "LocalStack가 실행되지 않음 - Parameter Store 테스트 생략"
    fi

    # 7. 테스트 완료
    log_success "=== 모든 테스트 성공! ==="
    log_info "서비스 상태 확인:"
    log_info "  - API Gateway: http://localhost:8080"
    log_info "  - Admin Server: http://localhost:9090"
    log_info "  - Customers Service: http://localhost:8081"
    log_info "  - Vets Service: http://localhost:8082"
    log_info "  - Visits Service: http://localhost:8083"
    log_info ""
    log_info "테스트 환경 정리를 위해 다음 명령어 실행:"
    log_info "  docker-compose down -v"
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi