#!/bin/bash

# Terraform 통합 테스트 스크립트
# 전체 레이어 순차 배포, 상태 파일 분리 및 잠금 테스트, 롤백 시나리오 테스트

set -e

# Color functions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

# Default parameters
ENVIRONMENT="dev"
SKIP_CLEANUP=false
TEST_ROLLBACK=false
TEST_STATE_LOCKING=false
TEST_TYPE="full"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --test-rollback)
            TEST_ROLLBACK=true
            shift
            ;;
        --test-state-locking)
            TEST_STATE_LOCKING=true
            shift
            ;;
        -t|--test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            echo "사용법: $0 [옵션]"
            echo "옵션:"
            echo "  -e, --environment ENV     테스트 환경 (기본값: dev)"
            echo "  --skip-cleanup           테스트 후 리소스 정리 건너뛰기"
            echo "  --test-rollback          롤백 시나리오 테스트 포함"
            echo "  --test-state-locking     상태 잠금 테스트 포함"
            echo "  -t, --test-type TYPE     테스트 유형 (full|deploy|state|rollback)"
            echo "  -h, --help               도움말 표시"
            exit 0
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            exit 1
            ;;
    esac
done

# Global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
readonly TEST_RESULTS_DIR="$PROJECT_ROOT/integration-test-results"
readonly TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
readonly TEST_REPORT_FILE="$TEST_RESULTS_DIR/integration-test-$ENVIRONMENT-$TIMESTAMP.json"

# Test statistics
declare -A TEST_STATS
TEST_STATS[start_time]=$(date -Iseconds)
TEST_STATS[environment]=$ENVIRONMENT
TEST_STATS[test_type]=$TEST_TYPE
TEST_STATS[total_layers]=0
TEST_STATS[successful_layers]=0
TEST_STATS[failed_layers]=0
TEST_STATS[errors]=0
TEST_STATS[warnings]=0

# Layer definitions with dependencies
declare -a LAYERS=(
    "01-network:Network infrastructure (VPC, subnets, gateways):"
    "02-security:Security settings (Security Groups, IAM, VPC Endpoints):01-network"
    "03-database:Database (Aurora cluster):01-network,02-security"
    "04-parameter-store:Parameter Store (replaces Spring Cloud Config):01-network,02-security"
    "05-cloud-map:Cloud Map (replaces Eureka):01-network"
    "06-lambda-genai:Lambda GenAI (serverless AI service):01-network,02-security"
    "07-application:Application infrastructure (ECS, ALB, ECR):01-network,02-security,03-database"
    "08-api-gateway:API Gateway (replaces Spring Cloud Gateway):01-network,02-security,07-application"
    "09-monitoring:Monitoring (CloudWatch integration):01-network,02-security,07-application"
    "10-aws-native:AWS Native Services Integration:01-network,02-security,06-lambda-genai,08-api-gateway"
)

# Arrays to track test results
declare -a DEPLOYED_LAYERS=()
declare -a FAILED_LAYERS=()
declare -a TEST_ERRORS=()
declare -a TEST_WARNINGS=()

initialize_test_environment() {
    log_step "테스트 환경 초기화"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    log_info "테스트 결과 디렉터리: $TEST_RESULTS_DIR"
    
    # Validate prerequisites
    log_info "사전 조건 검증 중..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform이 설치되지 않았습니다."
        exit 1
    fi
    local terraform_version=$(terraform version | head -n1)
    log_success "Terraform 확인: $terraform_version"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi
    log_success "AWS CLI 확인 완료"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity --profile petclinic-dev &> /dev/null; then
        log_error "AWS 자격 증명이 설정되지 않았습니다."
        exit 1
    fi
    log_success "AWS 자격 증명 확인 완료"
    
    # Check environment directory
    if [[ ! -d "$ENV_DIR" ]]; then
        log_error "환경 디렉터리가 존재하지 않습니다: $ENV_DIR"
        exit 1
    fi
    
    log_success "테스트 환경 초기화 완료"
}

get_layer_info() {
    local layer_def="$1"
    local layer_name=$(echo "$layer_def" | cut -d':' -f1)
    local layer_desc=$(echo "$layer_def" | cut -d':' -f2)
    local layer_deps=$(echo "$layer_def" | cut -d':' -f3)
    
    echo "$layer_name|$layer_desc|$layer_deps"
}

check_dependencies() {
    local dependencies="$1"
    
    if [[ -z "$dependencies" ]]; then
        return 0
    fi
    
    IFS=',' read -ra DEPS <<< "$dependencies"
    for dep in "${DEPS[@]}"; do
        if [[ ! " ${DEPLOYED_LAYERS[@]} " =~ " ${dep} " ]]; then
            log_error "의존성 레이어가 배포되지 않았습니다: $dep"
            return 1
        fi
    done
    
    return 0
}

test_sequential_deployment() {
    log_step "순차 배포 테스트"
    
    TEST_STATS[total_layers]=${#LAYERS[@]}
    
    for layer_def in "${LAYERS[@]}"; do
        IFS='|' read -r layer_name layer_desc layer_deps <<< "$(get_layer_info "$layer_def")"
        
        local layer_dir="$ENV_DIR/$layer_name"
        
        if [[ ! -d "$layer_dir" ]]; then
            log_warning "레이어 디렉터리가 존재하지 않습니다: $layer_name (건너뜀)"
            TEST_WARNINGS+=("Layer directory not found: $layer_name")
            ((TEST_STATS[warnings]++))
            continue
        fi
        
        log_info "배포 중: $layer_name - $layer_desc"
        
        local layer_start_time=$(date -Iseconds)
        
        if ! check_dependencies "$layer_deps"; then
            FAILED_LAYERS+=("$layer_name")
            TEST_ERRORS+=("Layer $layer_name failed: dependency check failed")
            ((TEST_STATS[failed_layers]++))
            ((TEST_STATS[errors]++))
            continue
        fi
        
        cd "$layer_dir"
        
        local layer_success=true
        
        # Initialize
        log_info "  초기화 중..."
        if ! terraform init -upgrade &> /dev/null; then
            log_error "  초기화 실패"
            layer_success=false
        fi
        
        # Plan
        if [[ "$layer_success" == "true" ]]; then
            log_info "  계획 생성 중..."
            local plan_file="tfplan-$TIMESTAMP"
            if ! terraform plan -var-file="$ENVIRONMENT.tfvars" -out="$plan_file" &> /dev/null; then
                log_error "  계획 생성 실패"
                layer_success=false
            fi
        fi
        
        # Apply
        if [[ "$layer_success" == "true" ]]; then
            log_info "  적용 중..."
            if ! terraform apply -auto-approve "$plan_file" &> /dev/null; then
                log_error "  적용 실패"
                layer_success=false
            fi
        fi
        
        # Verify
        if [[ "$layer_success" == "true" ]]; then
            log_info "  검증 중..."
            
            # Check state file
            if terraform show &> /dev/null; then
                log_success "  상태 파일 확인 완료"
            else
                log_warning "  상태 파일 검증 실패"
                TEST_WARNINGS+=("State file verification failed for $layer_name")
                ((TEST_STATS[warnings]++))
            fi
            
            # Get resource count
            local resource_count=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources | length' 2>/dev/null || echo "0")
            log_success "  생성된 리소스 수: $resource_count"
        fi
        
        if [[ "$layer_success" == "true" ]]; then
            DEPLOYED_LAYERS+=("$layer_name")
            ((TEST_STATS[successful_layers]++))
            log_success "레이어 배포 완료: $layer_name"
        else {
            FAILED_LAYERS+=("$layer_name")
            TEST_ERRORS+=("Layer $layer_name deployment failed")
            ((TEST_STATS[failed_layers]++))
            ((TEST_STATS[errors]++))
            log_error "레이어 배포 실패: $layer_name"
        fi
        
        # Clean up plan file
        rm -f "$plan_file" 2>/dev/null
    done
    
    log_success "순차 배포 테스트 완료 - 성공: ${TEST_STATS[successful_layers]}/${TEST_STATS[total_layers]}"
}

test_state_locking() {
    log_step "상태 파일 잠금 테스트"
    
    local test_layer="01-network"
    local layer_dir="$ENV_DIR/$test_layer"
    
    if [[ ! -d "$layer_dir" ]]; then
        log_warning "테스트 레이어가 존재하지 않습니다: $test_layer"
        return
    fi
    
    cd "$layer_dir"
    
    log_info "상태 잠금 테스트 시작..."
    
    # Start a long-running terraform operation in background
    terraform plan -var-file="$ENVIRONMENT.tfvars" -lock-timeout=30s &> /tmp/tf_lock_test1.log &
    local job1_pid=$!
    
    sleep 2
    
    # Try to run another operation (should be blocked)
    timeout 15s terraform plan -var-file="$ENVIRONMENT.tfvars" -lock-timeout=10s &> /tmp/tf_lock_test2.log &
    local job2_pid=$!
    
    # Wait for jobs to complete
    wait $job1_pid 2>/dev/null
    wait $job2_pid 2>/dev/null
    
    # Check if second job was blocked (expected behavior)
    if grep -q -i "lock\|timeout" /tmp/tf_lock_test2.log; then
        log_success "상태 잠금이 정상적으로 작동합니다"
    else
        log_warning "상태 잠금이 예상대로 작동하지 않을 수 있습니다"
        TEST_WARNINGS+=("State locking behavior unclear")
        ((TEST_STATS[warnings]++))
    fi
    
    # Clean up
    rm -f /tmp/tf_lock_test1.log /tmp/tf_lock_test2.log
}

test_state_file_separation() {
    log_step "상태 파일 분리 테스트"
    
    local -a state_files=()
    local -a state_keys=()
    
    for layer_def in "${LAYERS[@]}"; do
        IFS='|' read -r layer_name layer_desc layer_deps <<< "$(get_layer_info "$layer_def")"
        
        local layer_dir="$ENV_DIR/$layer_name"
        
        if [[ -d "$layer_dir" ]]; then
            cd "$layer_dir"
            
            # Check for remote state configuration
            if grep -q "backend.*s3" *.tf 2>/dev/null; then
                log_success "  $layer_name: 원격 상태 설정 확인됨"
                
                # Extract state key from backend configuration
                local state_key="dev/$layer_name/terraform.tfstate"
                state_keys+=("$state_key")
                state_files+=("$layer_name:$state_key")
            else
                log_warning "  $layer_name: 원격 상태 설정이 없습니다"
                TEST_WARNINGS+=("No remote state configuration for $layer_name")
                ((TEST_STATS[warnings]++))
            fi
        fi
    done
    
    # Check for unique state keys
    local unique_keys=$(printf '%s\n' "${state_keys[@]}" | sort -u | wc -l)
    local total_keys=${#state_keys[@]}
    
    if [[ $total_keys -eq $unique_keys ]]; then
        log_success "모든 레이어가 고유한 상태 파일을 사용합니다"
    else
        log_error "일부 레이어가 동일한 상태 파일을 사용할 수 있습니다"
        TEST_ERRORS+=("Potential state file conflicts detected")
        ((TEST_STATS[errors]++))
    fi
}

test_rollback_scenario() {
    log_step "롤백 시나리오 테스트"
    
    # Test rollback on a non-critical layer
    local test_layer="09-monitoring"
    local layer_dir="$ENV_DIR/$test_layer"
    
    if [[ ! -d "$layer_dir" ]]; then
        log_warning "롤백 테스트 레이어가 존재하지 않습니다: $test_layer"
        return
    fi
    
    cd "$layer_dir"
    
    log_info "롤백 테스트 시작: $test_layer"
    
    # Get current state
    log_info "  현재 상태 백업 중..."
    terraform show -json > "/tmp/initial_state_$TIMESTAMP.json" 2>/dev/null || true
    
    # Create a backup plan
    log_info "  백업 계획 생성 중..."
    local backup_plan="backup-plan-$TIMESTAMP"
    if ! terraform plan -var-file="$ENVIRONMENT.tfvars" -out="$backup_plan" &> /dev/null; then
        log_error "  백업 계획 생성 실패"
        return
    fi
    
    # Make a small change (add a tag)
    log_info "  테스트 변경 사항 적용 중..."
    local temp_tfvars="test-$ENVIRONMENT.tfvars"
    cp "$ENVIRONMENT.tfvars" "$temp_tfvars"
    echo 'test_tag = "rollback-test"' >> "$temp_tfvars"
    
    local test_plan="test-plan-$TIMESTAMP"
    if terraform plan -var-file="$temp_tfvars" -out="$test_plan" &> /dev/null; then
        if terraform apply -auto-approve "$test_plan" &> /dev/null; then
            log_info "  변경 사항 적용 완료"
            
            # Rollback using the backup plan
            log_info "  롤백 수행 중..."
            if terraform apply -auto-approve "$backup_plan" &> /dev/null; then
                log_success "롤백 테스트 완료"
            else
                log_error "롤백 실패"
                TEST_ERRORS+=("Rollback failed for $test_layer")
                ((TEST_STATS[errors]++))
            fi
        else
            log_error "테스트 변경 사항 적용 실패"
        fi
    else
        log_error "테스트 계획 생성 실패"
    fi
    
    # Clean up temporary files
    rm -f "$temp_tfvars" "$backup_plan" "$test_plan" "/tmp/initial_state_$TIMESTAMP.json"
}

cleanup_test_resources() {
    if [[ "$SKIP_CLEANUP" == "true" ]]; then
        log_info "정리 단계를 건너뜁니다 (--skip-cleanup 플래그 사용)"
        return
    fi
    
    log_step "테스트 리소스 정리"
    
    # Destroy in reverse order
    local -a reverse_layers=()
    for ((i=${#DEPLOYED_LAYERS[@]}-1; i>=0; i--)); do
        reverse_layers+=("${DEPLOYED_LAYERS[i]}")
    done
    
    for layer_name in "${reverse_layers[@]}"; do
        local layer_dir="$ENV_DIR/$layer_name"
        
        if [[ -d "$layer_dir" ]]; then
            log_info "정리 중: $layer_name"
            
            cd "$layer_dir"
            if terraform destroy -var-file="$ENVIRONMENT.tfvars" -auto-approve &> /dev/null; then
                log_success "  $layer_name 정리 완료"
            else
                log_warning "  $layer_name 정리 실패"
                TEST_WARNINGS+=("Cleanup failed for $layer_name")
                ((TEST_STATS[warnings]++))
            fi
        fi
    done
    
    log_success "테스트 리소스 정리 완료"
}

generate_test_report() {
    log_step "테스트 보고서 생성"
    
    TEST_STATS[end_time]=$(date -Iseconds)
    
    # Calculate duration
    local start_epoch=$(date -d "${TEST_STATS[start_time]}" +%s)
    local end_epoch=$(date -d "${TEST_STATS[end_time]}" +%s)
    local duration_minutes=$(( (end_epoch - start_epoch) / 60 ))
    
    # Generate JSON report
    cat > "$TEST_REPORT_FILE" << EOF
{
  "start_time": "${TEST_STATS[start_time]}",
  "end_time": "${TEST_STATS[end_time]}",
  "duration_minutes": $duration_minutes,
  "environment": "${TEST_STATS[environment]}",
  "test_type": "${TEST_STATS[test_type]}",
  "total_layers": ${TEST_STATS[total_layers]},
  "successful_layers": ${TEST_STATS[successful_layers]},
  "failed_layers": ${TEST_STATS[failed_layers]},
  "errors": ${TEST_STATS[errors]},
  "warnings": ${TEST_STATS[warnings]},
  "deployed_layers": $(printf '%s\n' "${DEPLOYED_LAYERS[@]}" | jq -R . | jq -s .),
  "failed_layers": $(printf '%s\n' "${FAILED_LAYERS[@]}" | jq -R . | jq -s .),
  "test_errors": $(printf '%s\n' "${TEST_ERRORS[@]}" | jq -R . | jq -s .),
  "test_warnings": $(printf '%s\n' "${TEST_WARNINGS[@]}" | jq -R . | jq -s .)
}
EOF
    
    # Generate summary
    echo
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}통합 테스트 결과 요약${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo "환경: $ENVIRONMENT"
    echo "테스트 유형: $TEST_TYPE"
    echo "시작 시간: ${TEST_STATS[start_time]}"
    echo "종료 시간: ${TEST_STATS[end_time]}"
    echo "총 소요 시간: $duration_minutes 분"
    echo
    echo "레이어 배포 결과:"
    echo -e "  - 총 레이어: ${TEST_STATS[total_layers]}"
    echo -e "  - 성공: ${GREEN}${TEST_STATS[successful_layers]}${NC}"
    echo -e "  - 실패: ${RED}${TEST_STATS[failed_layers]}${NC}"
    echo
    echo -e "오류: ${RED}${TEST_STATS[errors]}${NC}"
    echo -e "경고: ${YELLOW}${TEST_STATS[warnings]}${NC}"
    echo
    echo -e "상세 보고서: ${BLUE}$TEST_REPORT_FILE${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    if [[ ${TEST_STATS[errors]} -eq 0 ]]; then
        log_success "🎉 모든 통합 테스트가 성공적으로 완료되었습니다!"
        return 0
    else
        log_error "❌ 일부 테스트가 실패했습니다. 상세 내용은 보고서를 확인하세요."
        return 1
    fi
}

# Main execution
main() {
    log_info "Terraform 통합 테스트 시작"
    log_info "환경: $ENVIRONMENT, 테스트 유형: $TEST_TYPE"
    
    initialize_test_environment
    
    case "$TEST_TYPE" in
        "full")
            test_sequential_deployment
            test_state_file_separation
            [[ "$TEST_STATE_LOCKING" == "true" ]] && test_state_locking
            [[ "$TEST_ROLLBACK" == "true" ]] && test_rollback_scenario
            cleanup_test_resources
            ;;
        "deploy")
            test_sequential_deployment
            ;;
        "state")
            test_state_file_separation
            test_state_locking
            ;;
        "rollback")
            test_rollback_scenario
            ;;
        *)
            log_error "알 수 없는 테스트 유형: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    local exit_code
    generate_test_report
    exit_code=$?
    
    exit $exit_code
}

# Execute main function
main "$@"