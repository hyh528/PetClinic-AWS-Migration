#!/bin/bash

# 영현님용 Admin 프로파일 설정 스크립트
# 기존 팀원별 프로파일은 그대로 두고, admin 프로파일만 추가

set -e

echo "🔧 영현님용 Admin 프로파일 설정을 시작합니다..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 현재 디렉토리 확인
if [[ ! -d "envs/dev" ]]; then
    log_error "terraform 디렉토리에서 실행하세요"
    exit 1
fi

ADMIN_PROFILE="petclinic-dev-admin"

log_info "현재 AWS 자격 증명 확인 중..."

# 현재 AWS 설정 확인
if aws sts get-caller-identity >/dev/null 2>&1; then
    CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    log_success "현재 AWS 계정: $CURRENT_ACCOUNT"
else
    log_error "AWS 자격 증명이 설정되지 않았습니다"
    exit 1
fi

# Admin 프로파일 생성
log_info "Admin 프로파일 '$ADMIN_PROFILE' 생성 중..."

if aws configure list --profile $ADMIN_PROFILE >/dev/null 2>&1; then
    log_info "프로파일 '$ADMIN_PROFILE'이 이미 존재합니다"
else
    # 기본 프로파일 설정 복사
    DEFAULT_ACCESS_KEY=$(aws configure get aws_access_key_id)
    DEFAULT_SECRET_KEY=$(aws configure get aws_secret_access_key)
    DEFAULT_REGION=$(aws configure get region || echo "ap-northeast-2")
    
    if [[ -n "$DEFAULT_ACCESS_KEY" && -n "$DEFAULT_SECRET_KEY" ]]; then
        aws configure set aws_access_key_id "$DEFAULT_ACCESS_KEY" --profile $ADMIN_PROFILE
        aws configure set aws_secret_access_key "$DEFAULT_SECRET_KEY" --profile $ADMIN_PROFILE
        aws configure set region "$DEFAULT_REGION" --profile $ADMIN_PROFILE
        
        log_success "프로파일 '$ADMIN_PROFILE' 생성 완료"
    else
        log_error "기본 프로파일에서 자격 증명을 가져올 수 없습니다"
        exit 1
    fi
fi

# 프로파일 테스트
log_info "Admin 프로파일 테스트 중..."
if aws sts get-caller-identity --profile $ADMIN_PROFILE >/dev/null 2>&1; then
    log_success "프로파일 '$ADMIN_PROFILE' 정상 작동"
else
    log_error "프로파일 '$ADMIN_PROFILE' 테스트 실패"
    exit 1
fi

# 환경 변수 설정 가이드
log_info "영현님용 환경 변수 설정 중..."

# 현재 셸 확인
SHELL_RC=""
if [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
elif [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
fi

# 환경 변수 추가 (영현님용)
ENV_VAR_LINE="export AWS_PROFILE=$ADMIN_PROFILE"

if [[ -n "$SHELL_RC" && -f "$SHELL_RC" ]]; then
    if ! grep -q "AWS_PROFILE=$ADMIN_PROFILE" "$SHELL_RC"; then
        echo "" >> "$SHELL_RC"
        echo "# PetClinic Admin 프로파일 (영현님용)" >> "$SHELL_RC"
        echo "$ENV_VAR_LINE" >> "$SHELL_RC"
        log_success "환경 변수가 $SHELL_RC에 추가되었습니다"
    else
        log_info "환경 변수가 이미 설정되어 있습니다"
    fi
fi

# 현재 세션에 환경 변수 설정
export AWS_PROFILE=$ADMIN_PROFILE
log_success "현재 세션에 AWS_PROFILE=$ADMIN_PROFILE 설정됨"

# 사용법 안내 파일 생성
cat > "ADMIN_PROFILE_USAGE.md" << EOF
# Admin 프로파일 사용법 (영현님용)

## 🎯 목적
영현님이 모든 레이어를 확인할 수 있도록 admin 프로파일을 생성했습니다.
팀원들의 기존 프로파일은 그대로 유지됩니다.

## 🔧 사용 방법

### 영현님 사용 시
\`\`\`bash
# 환경 변수 설정 (자동으로 설정됨)
export AWS_PROFILE=petclinic-dev-admin

# 모든 레이어 확인 가능
cd envs/dev/network && terraform plan
cd envs/dev/security && terraform plan
cd envs/dev/database && terraform plan
cd envs/dev/application && terraform plan
\`\`\`

### 팀원들 사용 시 (기존 방식 유지)
\`\`\`bash
# 휘권 (보안)
export AWS_PROFILE=petclinic-hwigwon
cd envs/dev/security && terraform plan

# 석겸 (애플리케이션)  
export AWS_PROFILE=petclinic-seokgyeom
cd envs/dev/application && terraform plan

# 준제 (데이터베이스)
export AWS_PROFILE=petclinic-jungsu
cd envs/dev/database && terraform plan

# 영현 (네트워크) - 기존 프로파일도 사용 가능
export AWS_PROFILE=petclinic-yeonghyeon
cd envs/dev/network && terraform plan
\`\`\`

## 📋 프로파일 목록

| 팀원 | 역할 | 프로파일 | 접근 레이어 |
|------|------|----------|-------------|
| 영현 | 인프라 총괄 | petclinic-dev-admin | 모든 레이어 |
| 영현 | 네트워크 | petclinic-yeonghyeon | network |
| 휘권 | 보안 | petclinic-hwigwon | security |
| 석겸 | 애플리케이션 | petclinic-seokgyeom | application |
| 준제 | 데이터베이스 | petclinic-jungsu | database |

## 🔄 프로파일 전환

\`\`\`bash
# Admin 모드 (영현님 전체 확인용)
export AWS_PROFILE=petclinic-dev-admin

# 개별 작업 모드 (기존 방식)
export AWS_PROFILE=petclinic-yeonghyeon

# 현재 프로파일 확인
aws sts get-caller-identity
\`\`\`

## 💡 팁

1. **전체 확인 시**: admin 프로파일 사용
2. **개별 작업 시**: 기존 개인 프로파일 사용  
3. **팀원들**: 기존 방식 그대로 사용
4. **문제 발생 시**: admin 프로파일로 디버깅

EOF

log_success "사용법 가이드가 ADMIN_PROFILE_USAGE.md에 생성되었습니다"

# 결과 요약
log_info "=== 설정 완료 요약 ==="
echo "🔧 Admin 프로파일: $ADMIN_PROFILE (영현님용)"
echo "🌍 환경 변수: AWS_PROFILE=$ADMIN_PROFILE"
echo "📋 기존 팀원 프로파일: 그대로 유지"
echo ""

# 검증
log_info "설정 검증 중..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    FINAL_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    log_success "✅ AWS 연결 정상: $FINAL_ACCOUNT"
else
    log_error "❌ AWS 연결 실패"
fi

# 다음 단계 안내
echo ""
log_info "=== 사용 방법 ==="
echo "1. 전체 확인 시 (영현님):"
echo "   export AWS_PROFILE=petclinic-dev-admin"
echo ""
echo "2. 개별 작업 시:"
echo "   export AWS_PROFILE=petclinic-yeonghyeon  # 기존 방식"
echo ""
echo "3. 팀원들:"
echo "   기존 프로파일 그대로 사용 (변경 없음)"
echo ""

log_success "🎉 Admin 프로파일 설정이 완료되었습니다!"
log_info "📖 자세한 사용법은 ADMIN_PROFILE_USAGE.md를 참고하세요"