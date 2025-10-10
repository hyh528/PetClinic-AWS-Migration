# 06-lambda-genai 레이어 - 서버리스 AI 서비스 (단순화됨)

## 개요

GenAI ECS 서비스를 Lambda + Bedrock으로 대체하는 서버리스 AI 서비스를 제공합니다.
복잡한 모니터링과 설정을 제거하고 기본적인 AI 기능만 제공합니다.

## 주요 기능

- **Lambda 함수**: Python 3.11 기반 서버리스 AI 서비스
- **Amazon Bedrock 통합**: Claude 3 Haiku 모델 사용
- **기본 IAM 권한**: Bedrock 모델 호출 권한만
- **CloudWatch 로그**: 기본 로깅 기능

## 생성 리소스

- `aws_lambda_function`: GenAI Lambda 함수
- `aws_iam_role`: Lambda 실행 역할
- `aws_iam_role_policy`: Bedrock 호출 정책
- `aws_cloudwatch_log_group`: Lambda 로그 그룹

## 의존성

- **01-network**: 없음 (VPC 외부 실행)
- **02-security**: 없음 (기본 IAM 권한만)

## 사용법

```bash
# 초기화 (backend 설정)
terraform init -backend-config="bucket=petclinic-yeonghyeon-test" \
               -backend-config="key=dev/06-lambda-genai/terraform.tfstate" \
               -backend-config="region=ap-northeast-1" \
               -backend-config="profile=petclinic-dev"

# 계획 확인 (공유 변수 시스템 사용)
terraform plan -var="shared_config=$(terraform output -json shared_config)" \
               -var="state_config=$(terraform output -json state_config)"

# 적용
terraform apply -var="shared_config=$(terraform output -json shared_config)" \
                -var="state_config=$(terraform output -json state_config)"
```

### 공유 변수 시스템 사용

이 레이어는 `shared-variables.tf`에서 정의된 공통 변수를 사용합니다:
- `shared_config`: 기본 프로젝트 설정 (name_prefix, environment, aws_region 등)
- `state_config`: Terraform 상태 관리 설정 (bucket_name, region, profile)

## 출력값

- `lambda_function_name`: Lambda 함수 이름
- `lambda_function_arn`: Lambda 함수 ARN
- `lambda_function_invoke_arn`: API Gateway 통합용 ARN
- `bedrock_model_id`: 사용 중인 Bedrock 모델 ID

## 마이그레이션 정보

- **기존**: GenAI ECS 서비스
- **신규**: Lambda + Bedrock
- **장점**: 완전 서버리스, 사용량 기반 과금, 자동 스케일링