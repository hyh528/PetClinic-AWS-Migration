#!/bin/bash

# ==========================================
# API 통합 테스트 스크립트
# ==========================================
# AWS 네이티브 마이그레이션 후 API Gateway와 서비스 간 통신을 테스트합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 설정
API_GATEWAY_URL="${API_GATEWAY_URL:-http://localhost:8080}"
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

# API 테스트 함수
test_api() {
    local test_name="$1"
    local url="$2"
    local method="${3:-GET}"
    local expected_status="${4:-200}"
    local data="$5"

    log_info "Testing: $test_name"
    log_info "URL: $url"
    log_info "Method: $method, Expected Status: $expected_status"

    local curl_cmd="curl -s -w 'HTTPSTATUS:%{http_code};TIME:%{time_total}'"
    curl_cmd="$curl_cmd -X $method"
    curl_cmd="$curl_cmd -H 'Content-Type: application/json'"
    curl_cmd="$curl_cmd -H 'Accept: application/json'"

    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi

    curl_cmd="$curl_cmd --max-time $TEST_TIMEOUT"
    curl_cmd="$curl_cmd '$url'"

    local response=$(eval $curl_cmd)
    local body=$(echo "$response" | sed 's/HTTPSTATUS.*//')
    local status=$(echo "$response" | grep -o 'HTTPSTATUS:[0-9]*' | cut -d: -f2)
    local time=$(echo "$response" | grep -o 'TIME:[0-9.]*' | cut -d: -f2)

    if [ "$status" = "$expected_status" ]; then
        log_success "$test_name - Status: $status, Time: ${time}s"
        return 0
    else
        log_error "$test_name - Status: $status (Expected: $expected_status), Time: ${time}s"
        echo "Response: $body"
        return 1
    fi
}

# 데이터 생성 및 검증 함수
create_test_data() {
    log_info "=== 테스트 데이터 생성 ==="

    # Owner 생성
    OWNER_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "firstName": "Test",
            "lastName": "User",
            "address": "123 Test St",
            "city": "Test City",
            "telephone": "1234567890"
        }' \
        "$API_GATEWAY_URL/api/customers/owners")

    OWNER_ID=$(echo $OWNER_RESPONSE | grep -o '"id":[0-9]*' | cut -d: -f2 | tr -d ',')

    if [ -n "$OWNER_ID" ]; then
        log_success "Owner 생성 성공 - ID: $OWNER_ID"
        echo $OWNER_ID
    else
        log_error "Owner 생성 실패"
        echo "Response: $OWNER_RESPONSE"
        return 1
    fi
}

# 메인 테스트 함수
main() {
    log_info "=== API 통합 테스트 시작 ==="
    log_info "API Gateway URL: $API_GATEWAY_URL"

    local test_count=0
    local success_count=0

    # 1. 헬스체크 테스트
    log_info "=== 헬스체크 테스트 ==="

    ((test_count++))
    if test_api "API Gateway Health" "$API_GATEWAY_URL/actuator/health"; then
        ((success_count++))
    fi

    # 2. 서비스별 헬스체크
    ((test_count++))
    if test_api "Customers Service Health" "$API_GATEWAY_URL/api/customers/actuator/health"; then
        ((success_count++))
    fi

    ((test_count++))
    if test_api "Vets Service Health" "$API_GATEWAY_URL/api/vets/actuator/health"; then
        ((success_count++))
    fi

    ((test_count++))
    if test_api "Visits Service Health" "$API_GATEWAY_URL/api/visits/actuator/health"; then
        ((success_count++))
    fi

    # 3. 기본 API 테스트
    log_info "=== 기본 API 기능 테스트 ==="

    # Owners API
    ((test_count++))
    if test_api "Get All Owners" "$API_GATEWAY_URL/api/customers/owners"; then
        ((success_count++))
    fi

    # Vets API
    ((test_count++))
    if test_api "Get All Vets" "$API_GATEWAY_URL/api/vets/vets"; then
        ((success_count++))
    fi

    # Visits API
    ((test_count++))
    if test_api "Get All Visits" "$API_GATEWAY_URL/api/visits/visits"; then
        ((success_count++))
    fi

    # 4. CRUD 테스트
    log_info "=== CRUD 기능 테스트 ==="

    # Owner 생성
    OWNER_ID=$(create_test_data)
    if [ $? -eq 0 ] && [ -n "$OWNER_ID" ]; then
        ((test_count++))
        ((success_count++))

        # Owner 조회
        ((test_count++))
        if test_api "Get Owner by ID" "$API_GATEWAY_URL/api/customers/owners/$OWNER_ID"; then
            ((success_count++))
        fi

        # Owner 수정
        ((test_count++))
        if test_api "Update Owner" "$API_GATEWAY_URL/api/customers/owners/$OWNER_ID" "PUT" "204" '{
            "firstName": "Updated",
            "lastName": "User",
            "address": "456 Updated St",
            "city": "Updated City",
            "telephone": "0987654321"
        }'; then
            ((success_count++))
        fi

        # Owner 삭제
        ((test_count++))
        if test_api "Delete Owner" "$API_GATEWAY_URL/api/customers/owners/$OWNER_ID" "DELETE" "204"; then
            ((success_count++))
        fi
    else
        log_error "Owner 생성 실패로 CRUD 테스트 생략"
    fi

    # 5. 서비스 간 통신 테스트
    log_info "=== 서비스 간 통신 테스트 ==="

    # 새로운 Owner 생성 후 Vet과의 관계 테스트
    OWNER_ID2=$(create_test_data)
    if [ -n "$OWNER_ID2" ]; then
        # Pet 생성 (Owner와 연결)
        PET_RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"Test Pet\",
                \"birthDate\": \"2020-01-01\",
                \"typeId\": 1,
                \"ownerId\": $OWNER_ID2
            }" \
            "$API_GATEWAY_URL/api/customers/owners/$OWNER_ID2/pets")

        PET_ID=$(echo $PET_RESPONSE | grep -o '"id":[0-9]*' | cut -d: -f2 | tr -d ',')

        if [ -n "$PET_ID" ]; then
            log_success "Pet 생성 성공 - ID: $PET_ID"

            # Visit 생성 (Pet과 연결)
            VISIT_RESPONSE=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "{
                    \"petId\": $PET_ID,
                    \"visitDate\": \"2024-01-01\",
                    \"description\": \"Test visit\"
                }" \
                "$API_GATEWAY_URL/api/visits/visits")

            VISIT_ID=$(echo $VISIT_RESPONSE | grep -o '"id":[0-9]*' | cut -d: -f2 | tr -d ',')

            if [ -n "$VISIT_ID" ]; then
                log_success "Visit 생성 성공 - ID: $VISIT_ID"
                ((test_count++))
                ((success_count++))

                # 서비스 간 데이터 일관성 확인
                ((test_count++))
                if test_api "Cross-service Data Check" "$API_GATEWAY_URL/api/customers/owners/$OWNER_ID2/pets"; then
                    ((success_count++))
                fi
            fi
        fi
    fi

    # 6. 테스트 결과 요약
    log_info "=== 테스트 결과 요약 ==="
    log_info "총 테스트 수: $test_count"
    log_info "성공: $success_count"
    log_info "실패: $((test_count - success_count))"
    log_info "성공률: $((success_count * 100 / test_count))%"

    if [ $success_count -eq $test_count ]; then
        log_success "🎉 모든 API 통합 테스트 성공!"
        return 0
    else
        log_error "❌ 일부 테스트 실패"
        return 1
    fi
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi