#!/bin/bash
# ECR 연결성 심화 진단 스크립트
# 목적: ECS Fargate 태스크의 ECR 이미지 풀 문제 진단

set -e

echo "=========================================="
echo "ECR 연결성 심화 진단 시작"
echo "=========================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 진단 결과 저장
DIAGNOSIS_FILE="ecr-diagnosis-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$DIAGNOSIS_FILE")
exec 2>&1

echo "진단 결과가 $DIAGNOSIS_FILE 에 저장됩니다."
echo ""

# AWS 계정 정보 확인
echo -e "${BLUE}=== AWS 계정 정보 ===${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ERROR")
REGION=$(aws configure get region 2>/dev/null || echo "ap-southeast-2")

if [ "$ACCOUNT_ID" = "ERROR" ]; then
    echo -e "${RED}❌ AWS 자격 증명을 확인할 수 없습니다!${NC}"
    echo "aws configure 또는 AWS 자격 증명을 확인하세요."
    exit 1
fi

echo "계정 ID: $ACCOUNT_ID"
echo "리전: $REGION"
echo ""

# 1. ECS 태스크 실행 역할 존재 여부 확인
echo -e "${BLUE}=== 1. ECS 태스크 실행 역할 확인 ===${NC}"
ROLE_NAME="ecsTaskExecutionRole"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ $ROLE_NAME 역할이 존재합니다${NC}"
    
    # 역할 정책 확인
    echo "연결된 정책들:"
    aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[*].PolicyArn' --output table
    
    # 인라인 정책 확인
    INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text)
    if [ -n "$INLINE_POLICIES" ] && [ "$INLINE_POLICIES" != "None" ]; then
        echo "인라인 정책들: $INLINE_POLICIES"
    fi
else
    echo -e "${RED}❌ $ROLE_NAME 역할이 존재하지 않습니다!${NC}"
    echo "이 역할은 ECS 태스크가 ECR에서 이미지를 풀하는 데 필요합니다."
fi
echo ""

# 2. ECR 리포지토리 및 이미지 확인
echo -e "${BLUE}=== 2. ECR 리포지토리 및 이미지 확인 ===${NC}"
SERVICES=("customers" "vets" "visits" "admin")

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}=== $service 서비스 ===${NC}"
    REPO_NAME="petclinic-dev-$service"
    
    # 리포지토리 존재 확인
    if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 리포지토리 $REPO_NAME 존재${NC}"
        
        # 이미지 목록 및 SHA 확인
        echo "이미지 목록:"
        IMAGE_COUNT=$(aws ecr describe-images --repository-name "$REPO_NAME" --region "$REGION" --query 'length(imageDetails)' --output text 2>/dev/null || echo "0")
        
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            aws ecr describe-images --repository-name "$REPO_NAME" --region "$REGION" \
                --query 'imageDetails[*].[imageTags[0],imageDigest,imagePushedAt]' --output table
        else
            echo -e "${RED}❌ 리포지토리에 이미지가 없습니다!${NC}"
        fi
        
        # 리포지토리 URI 출력
        REPO_URI=$(aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" --query 'repositories[0].repositoryUri' --output text)
        echo "리포지토리 URI: $REPO_URI"
        
    else
        echo -e "${RED}❌ 리포지토리 $REPO_NAME이 존재하지 않습니다!${NC}"
    fi
    echo ""
done

# 3. VPC 및 서브넷 정보 확인
echo -e "${BLUE}=== 3. VPC 및 네트워크 정보 확인 ===${NC}"

# VPC 확인
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=petclinic-dev-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ "$VPC_ID" != "None" ]; then
    echo -e "${GREEN}✅ VPC 발견: $VPC_ID${NC}"
    
    # DNS 설정 확인
    DNS_SUPPORT=$(aws ec2 describe-vpc-attribute --vpc-id "$VPC_ID" --attribute enableDnsSupport --query 'EnableDnsSupport.Value' --output text)
    DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute --vpc-id "$VPC_ID" --attribute enableDnsHostnames --query 'EnableDnsHostnames.Value' --output text)
    
    echo "DNS Support: $DNS_SUPPORT"
    echo "DNS Hostnames: $DNS_HOSTNAMES"
    
    if [ "$DNS_SUPPORT" = "true" ] && [ "$DNS_HOSTNAMES" = "true" ]; then
        echo -e "${GREEN}✅ VPC DNS 설정이 올바릅니다${NC}"
    else
        echo -e "${RED}❌ VPC DNS 설정에 문제가 있습니다${NC}"
    fi
else
    echo -e "${RED}❌ petclinic-dev-vpc를 찾을 수 없습니다!${NC}"
fi
echo ""

# 4. VPC 엔드포인트 확인
echo -e "${BLUE}=== 4. VPC 엔드포인트 확인 ===${NC}"
REQUIRED_ENDPOINTS=("ecr.api" "ecr.dkr" "logs")

for endpoint_service in "${REQUIRED_ENDPOINTS[@]}"; do
    SERVICE_NAME="com.amazonaws.$REGION.$endpoint_service"
    echo "확인 중: $SERVICE_NAME"
    
    ENDPOINT_ID=$(aws ec2 describe-vpc-endpoints \
        --filters "Name=service-name,Values=$SERVICE_NAME" "Name=vpc-id,Values=$VPC_ID" \
        --query 'VpcEndpoints[0].VpcEndpointId' --output text 2>/dev/null || echo "None")
    
    if [ "$ENDPOINT_ID" != "None" ]; then
        echo -e "${GREEN}✅ VPC 엔드포인트 존재: $ENDPOINT_ID${NC}"
        
        # 엔드포인트 상태 확인
        STATE=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$ENDPOINT_ID" --query 'VpcEndpoints[0].State' --output text)
        echo "상태: $STATE"
        
        # Private DNS 활성화 확인
        PRIVATE_DNS=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$ENDPOINT_ID" --query 'VpcEndpoints[0].PrivateDnsEnabled' --output text)
        echo "Private DNS 활성화: $PRIVATE_DNS"
        
        # 정책 확인
        POLICY=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$ENDPOINT_ID" --query 'VpcEndpoints[0].PolicyDocument' --output text)
        if [ "$POLICY" != "None" ] && [ "$POLICY" != "" ]; then
            echo "정책이 설정되어 있습니다 (상세 내용은 AWS 콘솔에서 확인)"
        else
            echo "기본 정책 사용 중"
        fi
    else
        echo -e "${RED}❌ VPC 엔드포인트가 존재하지 않습니다: $SERVICE_NAME${NC}"
    fi
    echo ""
done

# 5. 보안 그룹 확인
echo -e "${BLUE}=== 5. 보안 그룹 확인 ===${NC}"

# ECS 보안 그룹 확인
ECS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=petclinic-dev-ecs-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

if [ "$ECS_SG_ID" != "None" ]; then
    echo -e "${GREEN}✅ ECS 보안 그룹 발견: $ECS_SG_ID${NC}"
    
    # 아웃바운드 규칙 확인 (443 포트)
    HTTPS_OUTBOUND=$(aws ec2 describe-security-groups --group-ids "$ECS_SG_ID" \
        --query 'SecurityGroups[0].IpPermissionsEgress[?FromPort==`443`]' --output text)
    
    if [ -n "$HTTPS_OUTBOUND" ]; then
        echo -e "${GREEN}✅ HTTPS(443) 아웃바운드 규칙 존재${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTPS(443) 아웃바운드 규칙을 확인할 수 없습니다${NC}"
    fi
else
    echo -e "${RED}❌ ECS 보안 그룹을 찾을 수 없습니다${NC}"
fi
echo ""

# 6. 네트워크 ACL 확인
echo -e "${BLUE}=== 6. 네트워크 ACL 확인 ===${NC}"
if [ "$VPC_ID" != "None" ]; then
    echo "VPC $VPC_ID 의 네트워크 ACL 규칙 (443 포트 관련):"
    aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'NetworkAcls[*].Entries[?PortRange.From==`443` || PortRange.To==`443`].[RuleNumber,Protocol,RuleAction,CidrBlock,PortRange]' \
        --output table 2>/dev/null || echo "네트워크 ACL 정보를 가져올 수 없습니다"
fi
echo ""

# 7. ECS 태스크 정의 확인
echo -e "${BLUE}=== 7. ECS 태스크 정의 확인 ===${NC}"
for service in "${SERVICES[@]}"; do
    TASK_DEF_NAME="petclinic-dev-$service"
    echo "확인 중: $TASK_DEF_NAME"
    
    if aws ecs describe-task-definition --task-definition "$TASK_DEF_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 태스크 정의 존재: $TASK_DEF_NAME${NC}"
        
        # 이미지 URI 확인
        IMAGE_URI=$(aws ecs describe-task-definition --task-definition "$TASK_DEF_NAME" \
            --query 'taskDefinition.containerDefinitions[0].image' --output text 2>/dev/null || echo "ERROR")
        echo "이미지 URI: $IMAGE_URI"
        
        # 실행 역할 확인
        EXECUTION_ROLE=$(aws ecs describe-task-definition --task-definition "$TASK_DEF_NAME" \
            --query 'taskDefinition.executionRoleArn' --output text 2>/dev/null || echo "None")
        echo "실행 역할: $EXECUTION_ROLE"
        
    else
        echo -e "${RED}❌ 태스크 정의를 찾을 수 없습니다: $TASK_DEF_NAME${NC}"
    fi
    echo ""
done

# 8. ECR 로그인 테스트
echo -e "${BLUE}=== 8. ECR 로그인 테스트 ===${NC}"
echo "ECR 로그인 토큰 획득 테스트..."

if aws ecr get-login-password --region "$REGION" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ECR 로그인 토큰 획득 성공${NC}"
else
    echo -e "${RED}❌ ECR 로그인 토큰 획득 실패${NC}"
fi
echo ""

# 9. DNS 해석 테스트 (VPC 엔드포인트)
echo -e "${BLUE}=== 9. DNS 해석 테스트 ===${NC}"
ECR_ENDPOINTS=("api.ecr.$REGION.amazonaws.com" "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com")

for endpoint in "${ECR_ENDPOINTS[@]}"; do
    echo "DNS 해석 테스트: $endpoint"
    if nslookup "$endpoint" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS 해석 성공: $endpoint${NC}"
    else
        echo -e "${YELLOW}⚠️ DNS 해석 실패 또는 nslookup 명령어 없음: $endpoint${NC}"
    fi
done
echo ""

# 10. 요약 및 권장사항
echo -e "${BLUE}=== 진단 요약 및 권장사항 ===${NC}"
echo ""
echo "주요 확인 사항:"
echo "1. ECS 태스크 실행 역할 (ecsTaskExecutionRole) 존재 여부"
echo "2. ECR 리포지토리 및 이미지 존재 여부"
echo "3. VPC 엔드포인트 설정 및 상태"
echo "4. 보안 그룹 및 네트워크 ACL 규칙"
echo "5. ECS 태스크 정의의 이미지 URI 및 실행 역할"
echo ""
echo "다음 단계:"
echo "- 위의 진단 결과를 바탕으로 문제점을 식별하세요"
echo "- 누락된 리소스나 잘못된 설정을 수정하세요"
echo "- 특히 ecsTaskExecutionRole과 ECR 이미지 존재 여부를 우선 확인하세요"
echo ""
echo "=========================================="
echo "ECR 연결성 심화 진단 완료"
echo "진단 결과: $DIAGNOSIS_FILE"
echo "=========================================="