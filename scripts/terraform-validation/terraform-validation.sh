#!/bin/bash

# Terraform 인프라 검증 스크립트
# Spring PetClinic 프로젝트 - 전체 레이어 검증

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
    local layer=$1
    local test_name=$2
    local status=$3
    local message=$4
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$status" = "PASS" ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_success "[$layer] $test_name: $message"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_error "[$layer] $test_name: $message"
    fi
    
    VALIDATION_RESULTS+=("$layer|$test_name|$status|$message")
}

# Terraform 레이어 정의 (실행 순서)
declare -A LAYERS=(
    ["network"]="terraform/envs/dev/network"
    ["security"]="terraform/envs/dev/security" 
    ["database"]="terraform/envs/dev/database"
    ["application"]="terraform/envs/dev/application"
)

declare -A LAYER_PROFILES=(
    ["network"]="petclinic-yeonghyeon"
    ["security"]="petclinic-hwigwon"
    ["database"]="petclinic-junje"
    ["application"]="petclinic-seokgyeom"
)

# 실행 순서 정의
LAYER_ORDER=("network" "security" "database" "application")

# 사용법 출력
usage() {
    echo "사용법: $0 [옵션] [레이어]"
    echo ""
    echo "옵션:"
    echo "  -h, --help          이 도움말 표시"
    echo "  -f, --format        코드 포맷팅만 실행"
    echo "  -v, --validate      구문 검증만 실행"
    echo "  -p, --plan          계획 검증만 실행"
    echo "  -a, --all           모든 검증 실행 (기본값)"
    echo "  -s, --summary       요약 리포트만 표시"
    echo ""
    echo "레이어:"
    echo "  network             네트워크 레이어만 검증"
    echo "  security            보안 레이어만 검증"
    echo "  database            데이터베이스 레이어만 검증"
    echo "  application         애플리케이션 레이어만 검증"
    echo "  (생략 시 모든 레이어 검증)"
    echo ""
    echo "예시:"
    echo "  $0                  # 모든 레이어 전체 검증"
    echo "  $0 network          # 네트워크 레이어만 검증"
    echo "  $0 -f               # 모든 레이어 포맷팅만"
    echo "  $0 -v security      # 보안 레이어 구문 검증만"
}

# Terraform 포맷팅 검증
validate_formatting() {
    local layer=$1
    local layer_path=$2
    
    log_info "[$layer] 코드 포맷팅 검증 중..."
    
    cd "$layer_path"
    
    # terraform fmt -check 실행
    if terraform fmt -check -diff > /dev/null 2>&1; then
        record_result "$layer" "포맷팅" "PASS" "코드 포맷팅이 표준을 준수합니다"
    else
        # 포맷팅 문제가 있는 파일 확인
        local fmt_output=$(terraform fmt -check -diff 2>&1)
        record_result "$layer" "포맷팅" "FAIL" "코드 포맷팅 문제 발견: $fmt_output"
    fi
    
    cd - > /dev/null
}

# Terraform 구문 검증
validate_syntax() {
    local layer=$1
    local layer_path=$2
    
    log_info "[$layer] 구문 검증 중..."
    
    cd "$layer_path"
    
    # terraform init (필요한 경우)
    if [ ! -d ".terraform" ]; then
        log_info "[$layer] Terraform 초기화 중..."
        if ! terraform init > /dev/null 2>&1; then
            record_result "$layer" "초기화" "FAIL" "Terraform 초기화 실패"
            cd - > /dev/null
            return 1
        fi
    fi
    
    # terraform validate 실행
    if terraform validate > /dev/null 2>&1; then
        record_result "$layer" "구문검증" "PASS" "구문이 올바릅니다"
    else
        local validate_output=$(terraform validate 2>&1)
        record_result "$layer" "구문검증" "FAIL" "구문 오류: $validate_output"
    fi
    
    cd - > /dev/null
}

# Terraform 계획 검증
validate_plan() {
    local layer=$1
    local layer_path=$2
    local profile=${LAYER_PROFILES[$layer]}
    
    log_info "[$layer] 계획 검증 중... (프로필: $profile)"
    
    cd "$layer_path"
    
    # AWS 프로필 설정
    export AWS_PROFILE=$profile
    
    # terraform plan 실행
    local plan_output
    if plan_output=$(terraform plan -var-file="dev.tfvars" -detailed-exitcode 2>&1); then
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            record_result "$layer" "계획검증" "PASS" "변경사항 없음 - 인프라가 최신 상태입니다"
        elif [ $exit_code -eq 2 ]; then
            record_result "$layer" "계획검증" "PASS" "계획된 변경사항이 있습니다 (정상)"
        fi
    else
        record_result "$layer" "계획검증" "FAIL" "계획 생성 실패: $plan_output"
    fi
    
    cd - > /dev/null
}

# 변수 및 출력값 검증
validate_variables() {
    local layer=$1
    local layer_path=$2
    
    log_info "[$layer] 변수 및 출력값 검증 중..."
    
    cd "$layer_path"
    
    # variables.tf 파일 존재 확인
    if [ -f "variables.tf" ]; then
        record_result "$layer" "변수파일" "PASS" "variables.tf 파일이 존재합니다"
    else
        record_result "$layer" "변수파일" "FAIL" "variables.tf 파일이 없습니다"
    fi
    
    # outputs.tf 파일 존재 확인
    if [ -f "outputs.tf" ]; then
        record_result "$layer" "출력파일" "PASS" "outputs.tf 파일이 존재합니다"
    else
        record_result "$layer" "출력파일" "FAIL" "outputs.tf 파일이 없습니다"
    fi
    
    # dev.tfvars 파일 존재 확인
    if [ -f "dev.tfvars" ]; then
        record_result "$layer" "환경변수" "PASS" "dev.tfvars 파일이 존재합니다"
    else
        record_result "$layer" "환경변수" "FAIL" "dev.tfvars 파일이 없습니다"
    fi
    
    cd - > /dev/null
}

# 백엔드 설정 검증
validate_backend() {
    local layer=$1
    local layer_path=$2
    
    log_info "[$layer] 백엔드 설정 검증 중..."
    
    cd "$layer_path"
    
    # backend.tf 파일 존재 확인
    if [ -f "backend.tf" ]; then
        record_result "$layer" "백엔드설정" "PASS" "backend.tf 파일이 존재합니다"
        
        # S3 백엔드 설정 확인
        if grep -q "backend \"s3\"" backend.tf; then
            record_result "$layer" "S3백엔드" "PASS" "S3 백엔드가 설정되어 있습니다"
        else
            record_result "$layer" "S3백엔드" "FAIL" "S3 백엔드 설정이 없습니다"
        fi
        
        # DynamoDB 잠금 설정 확인
        if grep -q "dynamodb_table" backend.tf; then
            record_result "$layer" "상태잠금" "PASS" "DynamoDB 상태 잠금이 설정되어 있습니다"
        else
            record_result "$layer" "상태잠금" "FAIL" "DynamoDB 상태 잠금 설정이 없습니다"
        fi
    else
        record_result "$layer" "백엔드설정" "FAIL" "backend.tf 파일이 없습니다"
    fi
    
    cd - > /dev/null
}

# 단일 레이어 검증
validate_layer() {
    local layer=$1
    local run_format=$2
    local run_validate=$3
    local run_plan=$4
    
    local layer_path=${LAYERS[$layer]}
    
    if [ ! -d "$layer_path" ]; then
        record_result "$layer" "경로확인" "FAIL" "레이어 디렉토리가 존재하지 않습니다: $layer_path"
        return 1
    fi
    
    log_info "=== [$layer] 레이어 검증 시작 ==="
    
    # 기본 파일 구조 검증
    validate_variables "$layer" "$layer_path"
    validate_backend "$layer" "$layer_path"
    
    # 선택적 검증 실행
    if [ "$run_format" = true ]; then
        validate_formatting "$layer" "$layer_path"
    fi
    
    if [ "$run_validate" = true ]; then
        validate_syntax "$layer" "$layer_path"
    fi
    
    if [ "$run_plan" = true ]; then
        validate_plan "$layer" "$layer_path"
    fi
    
    log_info "=== [$layer] 레이어 검증 완료 ==="
    echo ""
}

# 요약 리포트 생성
generate_summary() {
    echo ""
    echo "=========================================="
    echo "         Terraform 검증 결과 요약"
    echo "=========================================="
    echo ""
    echo "📊 전체 통계:"
    echo "   총 테스트: $TOTAL_TESTS"
    echo "   성공: $PASSED_TESTS"
    echo "   실패: $FAILED_TESTS"
    echo "   성공률: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
    echo ""
    
    if [ $FAILED_TESTS -gt 0 ]; then
        echo "❌ 실패한 테스트:"
        for result in "${VALIDATION_RESULTS[@]}"; do
            IFS='|' read -r layer test_name status message <<< "$result"
            if [ "$status" = "FAIL" ]; then
                echo "   [$layer] $test_name: $message"
            fi
        done
        echo ""
    fi
    
    echo "✅ 성공한 테스트:"
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r layer test_name status message <<< "$result"
        if [ "$status" = "PASS" ]; then
            echo "   [$layer] $test_name"
        fi
    done
    echo ""
    
    # JSON 형태로 결과 저장
    local json_file="terraform-validation-results-$(date +%Y%m%d-%H%M%S).json"
    echo "{" > "$json_file"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$json_file"
    echo "  \"summary\": {" >> "$json_file"
    echo "    \"total_tests\": $TOTAL_TESTS," >> "$json_file"
    echo "    \"passed_tests\": $PASSED_TESTS," >> "$json_file"
    echo "    \"failed_tests\": $FAILED_TESTS," >> "$json_file"
    echo "    \"success_rate\": $(( PASSED_TESTS * 100 / TOTAL_TESTS ))" >> "$json_file"
    echo "  }," >> "$json_file"
    echo "  \"results\": [" >> "$json_file"
    
    local first=true
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r layer test_name status message <<< "$result"
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        echo "    {" >> "$json_file"
        echo "      \"layer\": \"$layer\"," >> "$json_file"
        echo "      \"test_name\": \"$test_name\"," >> "$json_file"
        echo "      \"status\": \"$status\"," >> "$json_file"
        echo "      \"message\": \"$message\"" >> "$json_file"
        echo -n "    }" >> "$json_file"
    done
    
    echo "" >> "$json_file"
    echo "  ]" >> "$json_file"
    echo "}" >> "$json_file"
    
    log_success "검증 결과가 $json_file 파일에 저장되었습니다"
    
    # 전체 결과에 따른 종료 코드
    if [ $FAILED_TESTS -gt 0 ]; then
        echo ""
        log_error "일부 검증이 실패했습니다. 위의 오류를 확인하고 수정해주세요."
        exit 1
    else
        echo ""
        log_success "모든 검증이 성공했습니다! 🎉"
        exit 0
    fi
}

# 메인 실행 로직
main() {
    local run_format=false
    local run_validate=false
    local run_plan=false
    local run_all=true
    local show_summary_only=false
    local target_layer=""
    
    # 인자 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--format)
                run_format=true
                run_all=false
                shift
                ;;
            -v|--validate)
                run_validate=true
                run_all=false
                shift
                ;;
            -p|--plan)
                run_plan=true
                run_all=false
                shift
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            -s|--summary)
                show_summary_only=true
                shift
                ;;
            network|security|database|application)
                target_layer=$1
                shift
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # 기본값 설정
    if [ "$run_all" = true ]; then
        run_format=true
        run_validate=true
        run_plan=true
    fi
    
    # 요약만 표시하는 경우 (이전 결과 파일에서)
    if [ "$show_summary_only" = true ]; then
        local latest_result=$(ls -t terraform-validation-results-*.json 2>/dev/null | head -n1)
        if [ -n "$latest_result" ]; then
            log_info "최근 검증 결과 표시: $latest_result"
            cat "$latest_result" | jq '.' 2>/dev/null || cat "$latest_result"
        else
            log_error "이전 검증 결과 파일을 찾을 수 없습니다"
        fi
        exit 0
    fi
    
    log_info "Terraform 인프라 검증을 시작합니다..."
    echo ""
    
    # 대상 레이어 결정
    local layers_to_validate=()
    if [ -n "$target_layer" ]; then
        if [[ " ${LAYER_ORDER[@]} " =~ " $target_layer " ]]; then
            layers_to_validate=("$target_layer")
        else
            log_error "유효하지 않은 레이어: $target_layer"
            usage
            exit 1
        fi
    else
        layers_to_validate=("${LAYER_ORDER[@]}")
    fi
    
    # 각 레이어 검증 실행
    for layer in "${layers_to_validate[@]}"; do
        validate_layer "$layer" "$run_format" "$run_validate" "$run_plan"
    done
    
    # 요약 리포트 생성
    generate_summary
}

# 스크립트 실행
main "$@"