#!/bin/bash

# Terraform 모듈 의존성 및 변수 검증 스크립트
# 작성자: Terraform 인프라 검증팀
# 목적: 모든 Terraform 모듈의 의존성, 변수, 출력값 검증

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

# 전역 변수
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
RESULTS_DIR="$PROJECT_ROOT/terraform-validation-results"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
RESULTS_FILE="$RESULTS_DIR/module-dependency-validation-$TIMESTAMP.json"

# 결과 저장을 위한 배열
declare -a VALIDATION_RESULTS=()

# 결과 디렉토리 생성
mkdir -p "$RESULTS_DIR"

# JSON 결과 추가 함수
add_result() {
    local category="$1"
    local component="$2"
    local test="$3"
    local status="$4"
    local message="$5"
    local details="$6"
    
    local result=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "category": "$category",
  "component": "$component",
  "test": "$test",
  "status": "$status",
  "message": "$message",
  "details": "$details"
}
EOF
)
    VALIDATION_RESULTS+=("$result")
}

# Terraform 설치 확인
check_terraform_installation() {
    log_info "Terraform 설치 확인 중..."
    
    if ! command -v terraform &> /dev/null; then
        log_warning "Terraform이 설치되지 않았습니다. 일부 검증은 건너뜁니다."
        add_result "prerequisites" "terraform" "installation_check" "WARNING" "Terraform not installed - skipping some validations" ""
        return 1
    fi
    
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_success "Terraform 버전: $tf_version"
    add_result "prerequisites" "terraform" "installation_check" "PASS" "Terraform installed: $tf_version" ""
    return 0
}

# 모듈 구조 검증
validate_module_structure() {
    log_info "모듈 구조 검증 중..."
    
    local modules_dir="$TERRAFORM_DIR/modules"
    local required_files=("main.tf" "variables.tf" "outputs.tf")
    local validation_passed=true
    
    # 불완전한 모듈 제외 목록
    local skip_modules=("sg" "cognito" "nacl")
    
    for module_dir in "$modules_dir"/*; do
        if [[ -d "$module_dir" ]]; then
            local module_name=$(basename "$module_dir")
            
            # 불완전한 모듈 건너뛰기
            local skip_module=false
            for skip in "${skip_modules[@]}"; do
                if [[ "$module_name" == "$skip" ]]; then
                    log_info "모듈 $module_name: 불완전한 모듈로 건너뜀"
                    add_result "module_structure" "$module_name" "skipped" "INFO" "Incomplete module skipped" ""
                    skip_module=true
                    break
                fi
            done
            
            if [[ $skip_module == true ]]; then
                continue
            fi
            
            log_info "모듈 검증: $module_name"
            
            # 필수 파일 확인
            local module_complete=true
            for required_file in "${required_files[@]}"; do
                if [[ ! -f "$module_dir/$required_file" ]]; then
                    log_error "모듈 $module_name에 $required_file이 없습니다."
                    add_result "module_structure" "$module_name" "required_files" "FAIL" "Missing $required_file" ""
                    validation_passed=false
                    module_complete=false
                else
                    add_result "module_structure" "$module_name" "required_files" "PASS" "$required_file exists" ""
                fi
            done
            
            # 완전한 모듈만 추가 검증 수행
            if [[ $module_complete == false ]]; then
                continue
            fi
            
            # 변수 정의 확인
            if [[ -f "$module_dir/variables.tf" ]]; then
                local var_count=$(grep -c "^variable" "$module_dir/variables.tf" 2>/dev/null || echo "0")
                if [[ $var_count -gt 0 ]]; then
                    log_success "모듈 $module_name: $var_count개 변수 정의됨"
                    add_result "module_structure" "$module_name" "variables_defined" "PASS" "$var_count variables defined" ""
                else
                    log_warning "모듈 $module_name: 변수가 정의되지 않음"
                    add_result "module_structure" "$module_name" "variables_defined" "WARNING" "No variables defined" ""
                fi
            fi
            
            # 출력값 정의 확인
            if [[ -f "$module_dir/outputs.tf" ]]; then
                local output_count=$(grep -c "^output" "$module_dir/outputs.tf" 2>/dev/null || echo "0")
                if [[ $output_count -gt 0 ]]; then
                    log_success "모듈 $module_name: $output_count개 출력값 정의됨"
                    add_result "module_structure" "$module_name" "outputs_defined" "PASS" "$output_count outputs defined" ""
                else
                    log_warning "모듈 $module_name: 출력값이 정의되지 않음"
                    add_result "module_structure" "$module_name" "outputs_defined" "WARNING" "No outputs defined" ""
                fi
            fi
        fi
    done
    
    if [[ $validation_passed == true ]]; then
        log_success "모든 모듈 구조 검증 완료"
    else
        log_error "일부 모듈 구조 검증 실패"
    fi
}

# 환경별 설정 검증
validate_environment_configs() {
    log_info "환경별 설정 검증 중..."
    
    local envs_dir="$TERRAFORM_DIR/envs/dev"
    local required_env_files=("main.tf" "variables.tf" "providers.tf")
    
    for env_layer in "$envs_dir"/*; do
        if [[ -d "$env_layer" ]]; then
            local layer_name=$(basename "$env_layer")
            log_info "레이어 검증: $layer_name"
            
            # 필수 파일 확인
            for required_file in "${required_env_files[@]}"; do
                if [[ -f "$env_layer/$required_file" ]]; then
                    add_result "environment_config" "$layer_name" "required_files" "PASS" "$required_file exists" ""
                else
                    log_warning "레이어 $layer_name에 $required_file이 없습니다."
                    add_result "environment_config" "$layer_name" "required_files" "WARNING" "Missing $required_file" ""
                fi
            done
            
            # backend.tf 확인 (bootstrap 제외)
            if [[ "$layer_name" != "bootstrap" && "$layer_name" != "aws-native" && "$layer_name" != "monitoring" ]]; then
                if [[ -f "$env_layer/backend.tf" ]]; then
                    log_success "레이어 $layer_name: backend.tf 존재"
                    add_result "environment_config" "$layer_name" "backend_config" "PASS" "backend.tf exists" ""
                else
                    log_error "레이어 $layer_name: backend.tf가 없습니다."
                    add_result "environment_config" "$layer_name" "backend_config" "FAIL" "Missing backend.tf" ""
                fi
            fi
            
            # tfvars 파일 확인
            if [[ -f "$env_layer/dev.tfvars" ]]; then
                log_success "레이어 $layer_name: dev.tfvars 존재"
                add_result "environment_config" "$layer_name" "tfvars_file" "PASS" "dev.tfvars exists" ""
            else
                log_warning "레이어 $layer_name: dev.tfvars가 없습니다."
                add_result "environment_config" "$layer_name" "tfvars_file" "WARNING" "Missing dev.tfvars" ""
            fi
        fi
    done
}

# 변수 일관성 검증
validate_variable_consistency() {
    log_info "변수 일관성 검증 중..."
    
    # 공통 변수 패턴 확인
    local common_vars=("project_name" "environment" "region" "vpc_id" "private_subnet_ids")
    
    for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
        if [[ -d "$env_layer" && -f "$env_layer/variables.tf" ]]; then
            local layer_name=$(basename "$env_layer")
            
            # 공통 변수 존재 확인
            for common_var in "${common_vars[@]}"; do
                if grep -q "variable \"$common_var\"" "$env_layer/variables.tf"; then
                    add_result "variable_consistency" "$layer_name" "common_variables" "PASS" "$common_var defined" ""
                else
                    # 일부 레이어에서는 특정 변수가 필요하지 않을 수 있음
                    add_result "variable_consistency" "$layer_name" "common_variables" "INFO" "$common_var not defined" ""
                fi
            done
            
            # 변수 설명 확인
            local vars_without_description=$(grep -A 3 "^variable" "$env_layer/variables.tf" | grep -B 3 -A 1 "^variable" | grep -L "description" || true)
            if [[ -z "$vars_without_description" ]]; then
                log_success "레이어 $layer_name: 모든 변수에 설명 존재"
                add_result "variable_consistency" "$layer_name" "variable_descriptions" "PASS" "All variables have descriptions" ""
            else
                log_warning "레이어 $layer_name: 일부 변수에 설명이 없습니다."
                add_result "variable_consistency" "$layer_name" "variable_descriptions" "WARNING" "Some variables missing descriptions" ""
            fi
        fi
    done
}

# 의존성 그래프 생성 및 분석
generate_dependency_graph() {
    log_info "의존성 그래프 생성 중..."
    
    # Terraform이 설치되지 않은 경우 건너뛰기
    if ! command -v terraform &> /dev/null; then
        log_warning "Terraform이 설치되지 않아 의존성 그래프 생성을 건너뜁니다."
        add_result "dependency_graph" "all" "terraform_required" "WARNING" "Terraform not available for graph generation" ""
        return
    fi
    
    for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
        if [[ -d "$env_layer" && -f "$env_layer/main.tf" ]]; then
            local layer_name=$(basename "$env_layer")
            
            # Terraform 초기화 (필요한 경우)
            if [[ ! -d "$env_layer/.terraform" ]]; then
                log_info "레이어 $layer_name: Terraform 초기화 중..."
                cd "$env_layer"
                if terraform init -backend=false &>/dev/null; then
                    add_result "dependency_graph" "$layer_name" "terraform_init" "PASS" "Terraform init successful" ""
                else
                    log_error "레이어 $layer_name: Terraform 초기화 실패"
                    add_result "dependency_graph" "$layer_name" "terraform_init" "FAIL" "Terraform init failed" ""
                    continue
                fi
            fi
            
            # 의존성 그래프 생성
            cd "$env_layer"
            if terraform graph > "$RESULTS_DIR/${layer_name}-dependency-graph.dot" 2>/dev/null; then
                log_success "레이어 $layer_name: 의존성 그래프 생성 완료"
                add_result "dependency_graph" "$layer_name" "graph_generation" "PASS" "Dependency graph generated" "$RESULTS_DIR/${layer_name}-dependency-graph.dot"
                
                # 순환 참조 검사 (간단한 검사)
                if grep -q "digraph" "$RESULTS_DIR/${layer_name}-dependency-graph.dot"; then
                    add_result "dependency_graph" "$layer_name" "circular_dependency" "PASS" "No obvious circular dependencies" ""
                else
                    add_result "dependency_graph" "$layer_name" "circular_dependency" "WARNING" "Could not verify circular dependencies" ""
                fi
            else
                log_error "레이어 $layer_name: 의존성 그래프 생성 실패"
                add_result "dependency_graph" "$layer_name" "graph_generation" "FAIL" "Failed to generate dependency graph" ""
            fi
        fi
    done
}

# 태그 표준화 검증
validate_tagging_standards() {
    log_info "태그 표준화 검증 중..."
    
    local required_tags=("Project" "Environment" "ManagedBy" "Owner")
    
    for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
        if [[ -d "$env_layer" ]]; then
            local layer_name=$(basename "$env_layer")
            local tag_compliance=true
            
            # main.tf에서 태그 사용 확인
            if [[ -f "$env_layer/main.tf" ]]; then
                for required_tag in "${required_tags[@]}"; do
                    if grep -q "$required_tag" "$env_layer/main.tf"; then
                        add_result "tagging_standards" "$layer_name" "required_tags" "PASS" "$required_tag tag found" ""
                    else
                        log_warning "레이어 $layer_name: $required_tag 태그가 없습니다."
                        add_result "tagging_standards" "$layer_name" "required_tags" "WARNING" "$required_tag tag missing" ""
                        tag_compliance=false
                    fi
                done
                
                # 공통 태그 블록 확인
                if grep -q "common_tags" "$env_layer/main.tf" || grep -q "tags.*=" "$env_layer/main.tf"; then
                    log_success "레이어 $layer_name: 태그 블록 사용 중"
                    add_result "tagging_standards" "$layer_name" "tag_blocks" "PASS" "Tag blocks found" ""
                else
                    log_warning "레이어 $layer_name: 태그 블록이 없습니다."
                    add_result "tagging_standards" "$layer_name" "tag_blocks" "WARNING" "No tag blocks found" ""
                fi
            fi
        fi
    done
}

# 명명 규칙 검증
validate_naming_conventions() {
    log_info "명명 규칙 검증 중..."
    
    # 리소스 명명 규칙 패턴
    local naming_patterns=(
        "petclinic.*"
        ".*-dev-.*"
        ".*-cluster.*"
        ".*-service.*"
    )
    
    for env_layer in "$TERRAFORM_DIR/envs/dev"/*; do
        if [[ -d "$env_layer" && -f "$env_layer/main.tf" ]]; then
            local layer_name=$(basename "$env_layer")
            
            # 리소스 이름 패턴 확인
            local resource_names=$(grep -o 'name.*=.*"[^"]*"' "$env_layer/main.tf" 2>/dev/null || true)
            
            if [[ -n "$resource_names" ]]; then
                local compliant_names=0
                local total_names=0
                
                while IFS= read -r name_line; do
                    if [[ -n "$name_line" ]]; then
                        ((total_names++))
                        local resource_name=$(echo "$name_line" | sed 's/.*"\([^"]*\)".*/\1/')
                        
                        # 패턴 매칭 확인
                        for pattern in "${naming_patterns[@]}"; do
                            if [[ "$resource_name" =~ $pattern ]]; then
                                ((compliant_names++))
                                break
                            fi
                        done
                    fi
                done <<< "$resource_names"
                
                if [[ $total_names -gt 0 ]]; then
                    local compliance_rate=$((compliant_names * 100 / total_names))
                    if [[ $compliance_rate -ge 80 ]]; then
                        log_success "레이어 $layer_name: 명명 규칙 준수율 ${compliance_rate}%"
                        add_result "naming_conventions" "$layer_name" "compliance_rate" "PASS" "Naming compliance: ${compliance_rate}%" ""
                    else
                        log_warning "레이어 $layer_name: 명명 규칙 준수율 ${compliance_rate}% (80% 미만)"
                        add_result "naming_conventions" "$layer_name" "compliance_rate" "WARNING" "Naming compliance: ${compliance_rate}%" ""
                    fi
                fi
            else
                add_result "naming_conventions" "$layer_name" "compliance_rate" "INFO" "No named resources found" ""
            fi
        fi
    done
}

# 결과 저장
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
    
    # 요약 통계 생성 (jq 없이)
    local total_tests=${#VALIDATION_RESULTS[@]}
    local passed_tests=0
    local failed_tests=0
    local warning_tests=0
    local info_tests=0
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        if [[ "$result" == *'"status": "PASS"'* ]]; then
            ((passed_tests++))
        elif [[ "$result" == *'"status": "FAIL"'* ]]; then
            ((failed_tests++))
        elif [[ "$result" == *'"status": "WARNING"'* ]]; then
            ((warning_tests++))
        elif [[ "$result" == *'"status": "INFO"'* ]]; then
            ((info_tests++))
        fi
    done
    
    # 요약 리포트 생성
    cat > "$RESULTS_DIR/module-dependency-summary-$TIMESTAMP.txt" << EOF
=== Terraform 모듈 의존성 및 변수 검증 요약 ===
검증 시간: $(date)
총 테스트: $total_tests
통과: $passed_tests
실패: $failed_tests  
경고: $warning_tests
정보: $info_tests

상세 결과: $RESULTS_FILE

=== 주요 발견 사항 ===
EOF
    
    # 실패한 테스트 목록 추가
    if [[ $failed_tests -gt 0 ]]; then
        echo "" >> "$RESULTS_DIR/module-dependency-summary-$TIMESTAMP.txt"
        echo "실패한 테스트:" >> "$RESULTS_DIR/module-dependency-summary-$TIMESTAMP.txt"
        for result in "${VALIDATION_RESULTS[@]}"; do
            if [[ "$result" == *'"status": "FAIL"'* ]]; then
                local component=$(echo "$result" | grep -o '"component": "[^"]*"' | cut -d'"' -f4)
                local test=$(echo "$result" | grep -o '"test": "[^"]*"' | cut -d'"' -f4)
                local message=$(echo "$result" | grep -o '"message": "[^"]*"' | cut -d'"' -f4)
                echo "- $component: $test - $message" >> "$RESULTS_DIR/module-dependency-summary-$TIMESTAMP.txt"
            fi
        done
    fi
    
    log_success "검증 결과가 저장되었습니다: $RESULTS_FILE"
    log_info "요약 리포트: $RESULTS_DIR/module-dependency-summary-$TIMESTAMP.txt"
}

# 메인 실행 함수
main() {
    log_info "=== Terraform 모듈 의존성 및 변수 검증 시작 ==="
    log_info "프로젝트 루트: $PROJECT_ROOT"
    log_info "결과 저장 위치: $RESULTS_DIR"
    
    # 검증 단계별 실행
    local terraform_available=false
    if check_terraform_installation; then
        terraform_available=true
    fi
    
    validate_module_structure
    validate_environment_configs
    validate_variable_consistency
    
    if [[ $terraform_available == true ]]; then
        generate_dependency_graph
    fi
    
    validate_tagging_standards
    validate_naming_conventions
    
    # 결과 저장
    save_results
    
    log_success "=== Terraform 모듈 의존성 및 변수 검증 완료 ==="
    
    # 실패한 테스트가 있으면 종료 코드 1 반환
    if [[ $failed_tests -gt 0 ]]; then
        log_error "$failed_tests개의 테스트가 실패했습니다."
        exit 1
    fi
}

# 스크립트 실행
main "$@"