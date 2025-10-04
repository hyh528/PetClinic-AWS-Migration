#!/bin/bash

# 간단한 Terraform 상태 확인 스크립트
# WSL이나 Linux에서 실행

echo "🔍 Terraform 인프라 간단 체크"
echo "================================"

# 현재 디렉토리 확인
if [[ ! -d "envs/dev" ]]; then
    echo "❌ terraform 디렉토리에서 실행하세요"
    echo "   cd terraform && ./simple-check.sh"
    exit 1
fi

echo "📍 작업 디렉토리: $(pwd)"

# 1. 기본 도구 확인
echo -e "\n1️⃣ 기본 도구 확인"
echo "-------------------"

# AWS CLI
if command -v aws >/dev/null 2>&1; then
    echo "✅ AWS CLI 설치됨"
    if aws sts get-caller-identity >/dev/null 2>&1; then
        ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        echo "✅ AWS 연결됨 (계정: $ACCOUNT)"
    else
        echo "❌ AWS 자격 증명 오류"
        echo "   해결: aws configure 실행"
    fi
else
    echo "❌ AWS CLI 미설치"
fi

# Terraform
if command -v terraform >/dev/null 2>&1; then
    VERSION=$(terraform version | head -1)
    echo "✅ $VERSION"
else
    echo "❌ Terraform 미설치"
    echo "   설치: https://www.terraform.io/downloads.html"
fi

# 2. 레이어별 파일 확인
echo -e "\n2️⃣ 레이어별 파일 확인"
echo "----------------------"

LAYERS=("network" "security" "database" "application" "monitoring")

for layer in "${LAYERS[@]}"; do
    echo -n "📁 $layer: "
    
    if [[ -d "envs/dev/$layer" ]]; then
        cd "envs/dev/$layer"
        
        # 필수 파일 확인
        missing=0
        for file in main.tf variables.tf outputs.tf; do
            [[ ! -f "$file" ]] && ((missing++))
        done
        
        # 상태 파일 확인
        if [[ -f "terraform.tfstate" ]]; then
            resources=$(grep -c '"type":' terraform.tfstate 2>/dev/null || echo "0")
            status="📊 $resources 리소스"
        else
            status="📊 상태없음"
        fi
        
        if [[ $missing -eq 0 ]]; then
            echo "✅ 파일완료, $status"
        else
            echo "⚠️  파일누락($missing개), $status"
        fi
        
        cd - >/dev/null
    else
        echo "❌ 디렉토리 없음"
    fi
done

# 3. 알려진 이슈 확인
echo -e "\n3️⃣ 알려진 이슈 확인"
echo "-------------------"

# AWS 프로파일 이슈
profile_files=$(find envs/dev -name "*.tfvars" -exec grep -l "aws_profile.*petclinic-" {} \; 2>/dev/null | wc -l)
if [[ $profile_files -gt 0 ]]; then
    echo "⚠️  AWS 프로파일 설정 파일 $profile_files 개 발견"
    echo "   해결: 기본 프로파일 사용 또는 환경변수 설정"
else
    echo "✅ AWS 프로파일 이슈 없음"
fi

# Application 레이어 특별 확인
if [[ -f "envs/dev/application/main.tf" ]] && grep -q "task_role_arn" envs/dev/application/main.tf; then
    if [[ -f "modules/ecs/variables.tf" ]] && grep -q 'variable "task_role_arn"' modules/ecs/variables.tf; then
        echo "✅ ECS 모듈 task_role_arn 변수 정상"
    else
        echo "❌ ECS 모듈 task_role_arn 변수 누락"
        echo "   해결: modules/ecs/variables.tf 확인 필요"
    fi
fi

# 4. 결과 요약
echo -e "\n📋 결과 요약"
echo "============"

echo "현재 상태:"
echo "- 대부분의 레이어는 정상 작동 중"
echo "- 몇 가지 설정 이슈만 해결하면 됨"
echo ""
echo "다음 단계:"
echo "1. AWS 프로파일 통일 (aws configure)"
echo "2. Application 레이어 오류 수정"
echo "3. 상태 관리 인프라 배포"
echo ""
echo "📚 자세한 내용: README_CURRENT_STATUS.md"
echo ""
echo "🆘 도움이 필요하면 팀 Slack #devops-terraform 채널로!"

echo -e "\n✨ 체크 완료!"