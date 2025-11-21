# 🚀 Terraform 서울 리전 레이어 단일화 구조 사용법

## 📁 구조 개요

```
terraform-seoul/
├── layers/              # 레이어 단일화 (환경 공통)
│   ├── dependencies.tf  # 환경 변수 주입 + 의존성 관리
│   ├── 01-network/
│   ├── 02-security/
│   └── ...
├── envs/               # 환경별 tfvars
│   └── seoul.tfvars    # 서울 리전 환경 설정
├── modules/            # 재사용 가능한 모듈
├── scripts/            # 자동화 스크립트
│   └── local/
├── backend.hcl         # 서울 리전 백엔드 설정 (ap-northeast-2)
├── provider.tf         # 공통 프로바이더 설정
└── versions.tf         # Terraform 버전 제약
```

## 🎯 사용법

### 1. 서울 개발 환경 배포 (권장: 자동화 스크립트 사용)

#### 자동화 스크립트 사용 (권장)
```bash
# 프로젝트 루트에서 실행
cd terraform-seoul

# 1. Network 레이어 초기화 및 배포
./scripts/local/init-layer.sh 01-network seoul
./scripts/local/plan-layer.ps1 -Layer 01-network -Environment seoul
./scripts/local/apply-layer.ps1 -Layer 01-network -Environment seoul

# 2. Security 레이어 초기화 및 배포
./scripts/local/init-layer.sh 02-security seoul
./scripts/local/plan-layer.ps1 -Layer 02-security -Environment seoul
./scripts/local/apply-layer.ps1 -Layer 02-security -Environment seoul

# 3. Database 레이어 초기화 및 배포
./scripts/local/init-layer.sh 03-database seoul
./scripts/local/plan-layer.ps1 -Layer 03-database -Environment seoul
./scripts/local/apply-layer.ps1 -Layer 03-database -Environment seoul
```

#### 수동 명령어 사용
```bash
# 프로젝트 루트에서 실행
cd terraform-seoul

# 1. Network 레이어
cd layers/01-network
terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/seoul.tfvars
terraform apply -var-file=../../envs/seoul.tfvars

# 2. Security 레이어
cd ../02-security
terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/seoul.tfvars
terraform apply -var-file=../../envs/seoul.tfvars

# 3. Database 레이어
cd ../03-database
terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/seoul.tfvars
terraform apply -var-file=../../envs/seoul.tfvars
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

## 📋 서울 리전 환경 설정

| 환경 | VPC CIDR | AZ | 리전 | 프로파일 | 용도 |
|------|----------|----|------|----------|------|
| **seoul-dev** | 10.0.0.0/16 | ap-northeast-2a, ap-northeast-2c | ap-northeast-2 | petclinic-dev | 서울 리전 개발/테스트 |

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

## 🔧 자동화 스크립트

### 사용 가능한 스크립트
- `init-layer.sh` / `init-layer.ps1`: 레이어 초기화 및 검증
- `plan-layer.ps1`: Terraform plan 실행
- `apply-layer.ps1`: Terraform apply 실행
- `drift-detect.sh`: 인프라 드리프트 감지

### 스크립트 사용 예시
```bash
# Bash
./scripts/local/init-layer.sh 01-network seoul
./scripts/local/drift-detect.sh seoul

# PowerShell
.\scripts\local\init-layer.ps1 -Layer 01-network -Environment seoul
.\scripts\local\plan-layer.ps1 -Layer 01-network -Environment seoul
.\scripts\local\apply-layer.ps1 -Layer 01-network -Environment seoul
```

## 💡 서울 리전 특화 기능

### ✅ **서울 리전 최적화**
- AWS 리전: `ap-northeast-2` (서울)
- 가용 영역: `ap-northeast-2a`, `ap-northeast-2c`
- ECR 리포지토리: 서울 리전 네이티브
- Bedrock 모델: Meta Llama 3 8B (서울 리전 지원)

### ✅ **보안 강화**
- WAF Rate Limiting: API Gateway 및 ALB용
- VPC Flow Logs: 네트워크 트래픽 모니터링
- CloudTrail: API 호출 감사

### ✅ **모니터링 및 알림**
- CloudWatch 대시보드
- Slack 알림 통합
- X-Ray 분산 추적

## 💡 팁

- 자동화 스크립트 사용으로 배포 표준화
- 각 레이어에서 `dependencies.tf`를 참조하여 다른 레이어 상태 접근
- 드리프트 감지: `./scripts/local/drift-detect.sh seoul`
- State key는 `seoul/{layer}/terraform.tfstate` 형식 자동 적용
- 서울 리전 특화 설정은 `envs/seoul.tfvars`에서 관리