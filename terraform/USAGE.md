# 🚀 Terraform 레이어 단일화 구조 사용법

## 📁 구조 개요

```
terraform/
├── layers/              # 레이어 단일화 (환경 공통)
│   ├── dependencies.tf  # 환경 변수 주입 + 의존성 관리
│   ├── 01-network/
│   ├── 02-security/
│   └── ...
├── envs/               # 환경별 tfvars
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
├── modules/            # 재사용 가능한 모듈
├── backend.hcl         # 공통 백엔드 설정
├── provider.tf         # 공통 프로바이더 설정
└── versions.tf         # Terraform 버전 제약
```

## 🎯 사용법

### 1. 개발 환경 배포

```bash
# 1. Network 레이어
cd terraform/layers/01-network
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars

# 2. Security 레이어
cd ../02-security
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars

# 3. Database 레이어
cd ../03-database
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```

### 2. 스테이징 환경 배포

```bash
# Network 레이어
cd terraform/layers/01-network
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/staging.tfvars
terraform apply -var-file=../../envs/staging.tfvars
```

### 3. 프로덕션 환경 배포

```bash
# Network 레이어
cd terraform/layers/01-network
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/prod.tfvars
terraform apply -var-file=../../envs/prod.tfvars
```

## 🔧 주요 특징

### ✅ **레이어 단일화**
- 각 레이어는 하나의 디렉토리에만 존재
- 환경별 복사 불필요
- 코드 중복 제거

### ✅ **환경별 변수 주입**
- `dependencies.tf`는 환경 공통 (수정 불필요)
- 환경별 차이는 `{env}.tfvars`로 주입
- State key도 환경별로 자동 분리

### ✅ **실무 표준 구조**
- 의존성 방향: network ← security
- 모듈 기반 재사용
- Multi-environment 지원

## 📋 환경별 차이점

| 환경 | VPC CIDR | AZ 수 | 프로파일 | 용도 |
|------|----------|-------|----------|------|
| **dev** | 10.0.0.0/16 | 2개 | petclinic-dev | 개발/테스트 |
| **staging** | 10.1.0.0/16 | 2개 | petclinic-staging | 스테이징 |
| **prod** | 10.2.0.0/16 | 3개 | petclinic-prod | 프로덕션 |

## 🚀 실행 순서

1. **01-network**: VPC, 서브넷, VPC 엔드포인트
2. **02-security**: 보안 그룹, IAM
3. **03-database**: Aurora 클러스터
4. **07-application**: ECS, ALB, ECR
5. **04-parameter-store**: Parameter Store
6. **05-cloud-map**: Cloud Map
7. **06-lambda-genai**: Lambda + Bedrock
8. **08-api-gateway**: API Gateway
9. **09-monitoring**: CloudWatch
10. **10-aws-native**: AWS 네이티브 통합

## 💡 팁

- 각 레이어에서 `dependencies.tf`를 참조하여 다른 레이어 상태 접근
- 환경 추가 시 `envs/{new-env}.tfvars` 파일만 생성
- State key는 `envs/${var.environment}/layer/terraform.tfstate` 형식 자동 적용