#!/bin/bash

# ==========================================
# End-to-End 전체 테스트 자동화 스크립트
# ==========================================
# AWS 네이티브 마이그레이션의 완전한 E2E 테스트를 수행합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCAL_TEST_DIR="$SCRIPT_DIR/../local-test"

# 환경 변수
export AWS_REGION="${AWS_REGION:-ap-northeast-2}"
export API_GATEWAY_URL="${API_GATEWAY_URL:-http://localhost:8080}"

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

log_phase() {
    echo -e "${PURPLE}[PHASE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 테스트 결과 추적
declare -A test_results
total_tests=0
passed_tests=0

# 테스트 실행 함수
run_test() {
    local test_name="$1"
    local test_command="$2"
    local description="$3"

    ((total_tests++))
    log_step "실행: $description"

    if eval "$test_command"; then
        log_success "$test_name 통과"
        test_results["$test_name"]="PASS"
        ((passed_tests++))
        return 0
    else
        log_error "$test_name 실패"
        test_results["$test_name"]="FAIL"
        return 1
    fi
}

# Phase 1: 환경 준비 및 검증
phase_environment_setup() {
    log_phase "Phase 1: 환경 준비 및 검증"

    # 1.1 필수 도구 확인
    run_test "terraform_check" "terraform version >/dev/null 2>&1" "Terraform 설치 확인"
    run_test "aws_cli_check" "aws --version >/dev/null 2>&1" "AWS CLI 설치 확인"
    run_test "docker_check" "docker --version >/dev/null 2>&1" "Docker 설치 확인"
    run_test "docker_compose_check" "docker-compose --version >/dev/null 2>&1" "Docker Compose 설치 확인"

    # 1.2 AWS 권한 확인
    run_test "aws_credentials_check" "aws sts get-caller-identity --region $AWS_REGION >/dev/null 2>&1" "AWS 자격 증명 확인"

    # 1.3 프로젝트 구조 확인
    run_test "project_structure_check" "[ -d '$PROJECT_ROOT/terraform' ] && [ -d '$PROJECT_ROOT/spring-petclinic-api-gateway' ]" "프로젝트 구조 확인"

    log_info "환경 준비 완료"
}

# Phase 2: 로컬 환경 테스트
phase_local_testing() {
    log_phase "Phase 2: 로컬 환경 테스트"

    cd "$LOCAL_TEST_DIR"

    # 2.1 Docker Compose 서비스 시작
    run_test "docker_compose_up" "docker-compose up -d" "Docker Compose 서비스 시작"

    # 2.2 서비스 헬스체크 대기
    log_info "서비스 시작 대기 중..."
    sleep 60

    # 2.3 로컬 서비스 테스트 실행
    run_test "local_services_test" "bash test-local-services.sh" "로컬 서비스 기능 테스트"

    log_info "로컬 환경 테스트 완료"
}

# Phase 3: Terraform 검증
phase_terraform_validation() {
    log_phase "Phase 3: Terraform 구성 검증"

    cd "$PROJECT_ROOT"

    # 3.1 Terraform 코드 검증
    run_test "terraform_fmt_check" "find terraform -name '*.tf' -exec terraform fmt -check {} \\;" "Terraform 코드 포맷팅 확인"

    # 3.2 각 레이어 초기화 및 검증
    local layers=("state-management" "network" "security" "database" "application" "parameter-store" "cloud-map" "monitoring")

    for layer in "${layers[@]}"; do
        if [ -d "terraform/envs/dev/$layer" ]; then
            log_info "레이어 검증: $layer"
            run_test "terraform_init_$layer" "cd terraform/envs/dev/$layer && terraform init -backend=false" "Terraform 초기화: $layer"
            run_test "terraform_validate_$layer" "cd terraform/envs/dev/$layer && terraform validate" "Terraform 검증: $layer"
        fi
    done

    log_info "Terraform 검증 완료"
}

# Phase 4: API 통합 테스트
phase_api_integration() {
    log_phase "Phase 4: API 통합 테스트"

    cd "$SCRIPT_DIR"

    # 4.1 API 통합 테스트 실행
    run_test "api_integration_test" "bash api-integration-test.sh" "API Gateway 및 서비스 통합 테스트"

    log_info "API 통합 테스트 완료"
}

# Phase 5: Cloud Map 서비스 디스커버리 테스트
phase_service_discovery() {
    log_phase "Phase 5: Cloud Map 서비스 디스커버리 테스트"

    cd "$SCRIPT_DIR"

    # 5.1 Cloud Map 테스트 실행 (실제 AWS 환경에서만)
    if [ "$TEST_ENV" = "aws" ]; then
        run_test "cloudmap_discovery_test" "bash cloud-map-discovery-test.sh" "Cloud Map 서비스 디스커버리 테스트"
    else
        log_info "Cloud Map 테스트는 AWS 환경에서만 실행됩니다 (TEST_ENV=aws 설정 필요)"
        test_results["cloudmap_discovery_test"]="SKIP"
    fi

    log_info "서비스 디스커버리 테스트 완료"
}

# Phase 6: 성능 및 부하 테스트
phase_performance_testing() {
    log_phase "Phase 6: 성능 및 부하 테스트"

    # 6.1 기본 성능 테스트
    run_test "basic_performance_test" "curl -w '@performance-format.txt' -s -o /dev/null $API_GATEWAY_URL/api/customers/owners" "기본 API 응답 시간 테스트"

    # 6.2 동시성 테스트 (간단한 버전)
    run_test "concurrency_test" "for i in {1..10}; do curl -f -s $API_GATEWAY_URL/actuator/health >/dev/null 2>&1 & done; wait" "동시 요청 처리 테스트"

    log_info "성능 테스트 완료"
}

# Phase 7: 정리 및 보고
phase_cleanup_and_report() {
    log_phase "Phase 7: 정리 및 보고"

    # 7.1 로컬 환경 정리
    cd "$LOCAL_TEST_DIR"
    run_test "docker_compose_down" "docker-compose down -v" "Docker Compose 서비스 정리"

    # 7.2 테스트 결과 보고
    generate_test_report

    log_info "테스트 완료 및 정리 완료"
}

# 테스트 결과 보고서 생성
generate_test_report() {
    log_info "=== E2E 테스트 결과 보고서 ==="
    echo "총 테스트 수: $total_tests"
    echo "통과: $passed_tests"
    echo "실패: $((total_tests - passed_tests))"
    echo "성공률: $((passed_tests * 100 / total_tests))%"
    echo ""
    echo "상세 결과:"
    echo "----------------------------------------"

    for test_name in "${!test_results[@]}"; do
        status="${test_results[$test_name]}"
        if [ "$status" = "PASS" ]; then
            echo -e "✅ $test_name: $status"
        elif [ "$status" = "FAIL" ]; then
            echo -e "❌ $test_name: $status"
        else
            echo -e "⏭️  $test_name: $status"
        fi
    done

    echo "----------------------------------------"

    # 결과 파일 저장
    local report_file="$PROJECT_ROOT/e2e-test-report-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "E2E 테스트 결과 보고서"
        echo "실행 시간: $(date)"
        echo "환경: ${TEST_ENV:-local}"
        echo "API Gateway URL: $API_GATEWAY_URL"
        echo ""
        echo "총 테스트 수: $total_tests"
        echo "통과: $passed_tests"
        echo "실패: $((total_tests - passed_tests))"
        echo "성공률: $((passed_tests * 100 / total_tests))%"
        echo ""
        echo "상세 결과:"
        for test_name in "${!test_results[@]}"; do
            echo "$test_name: ${test_results[$test_name]}"
        done
    } > "$report_file"

    log_info "테스트 결과가 $report_file 에 저장되었습니다."
}

# 메인 함수
main() {
    log_info "🚀 AWS 네이티브 마이그레이션 E2E 테스트 시작"
    log_info "테스트 환경: ${TEST_ENV:-local}"
    log_info "API Gateway URL: $API_GATEWAY_URL"
    log_info "AWS 리전: $AWS_REGION"

    local start_time=$(date +%s)

    # 단계별 테스트 실행
    phase_environment_setup
    phase_local_testing
    phase_terraform_validation
    phase_api_integration
    phase_service_discovery
    phase_performance_testing
    phase_cleanup_and_report

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # 최종 결과
    if [ $passed_tests -eq $total_tests ]; then
        log_success "🎉 모든 E2E 테스트 성공! (소요시간: ${duration}초)"
        exit 0
    else
        log_error "❌ E2E 테스트 실패 - $((total_tests - passed_tests))개 테스트 실패 (소요시간: ${duration}초)"
        exit 1
    fi
}

# 사용법 표시
show_usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -e, --env ENV       테스트 환경 (local/aws) - 기본값: local"
    echo "  -u, --url URL       API Gateway URL - 기본값: http://localhost:8080"
    echo "  -r, --region REGION AWS 리전 - 기본값: ap-northeast-2"
    echo "  -h, --help          도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0                                    # 로컬 환경 테스트"
    echo "  $0 -e aws -u http://api.example.com  # AWS 환경 테스트"
}

# 명령줄 인수 처리
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            TEST_ENV="$2"
            shift 2
            ;;
        -u|--url)
            API_GATEWAY_URL="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi