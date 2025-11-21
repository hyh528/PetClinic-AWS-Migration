# Terraform 레이어 실행 순서 가이드

## 개요
PetClinic AWS 마이그레이션 프로젝트의 Terraform 레이어들을 올바른 순서로 실행하기 위한 가이드입니다. 의존성을 고려하여 단계별로 진행해야 합니다.

## 🚀 실행 순서

### Phase 1: 기반 인프라 (Foundation)

#### 1. Network Layer (최우선)
```bash
cd terraform/layers/01-network
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 모든 리소스가 VPC, 서브넷, 라우팅에 의존하므로 가장 먼저 실행

**생성 리소스**:
- VPC (10.0.0.0/16)
- Public/Private 서브넷 (6개)
- Internet Gateway, NAT Gateway
- Route Tables
- Elastic IP

---

#### 2. Security Layer
```bash
cd terraform/layers/02-security
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 보안 그룹과 IAM 역할이 다른 서비스들에 필요

**생성 리소스**:
- Security Groups (ALB, ECS, Aurora용)
- IAM 역할 및 정책
- VPC 엔드포인트 (ECR, CloudWatch, SSM 등)
- Network ACLs

---

### Phase 2: 데이터 및 설정 관리

#### 3. Database Layer
```bash
cd terraform/layers/03-database
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 애플리케이션 서비스들이 데이터베이스에 의존

**생성 리소스**:
- Aurora MySQL 클러스터 (Serverless v2)
- DB 서브넷 그룹
- Secrets Manager (DB 비밀번호)
- Aurora 인스턴스 (Writer + Reader)

---

#### 4. Parameter Store Layer
```bash
cd terraform/layers/04-parameter-store
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 애플리케이션 설정이 Parameter Store에 저장됨

**생성 리소스**:
- Systems Manager Parameter Store 파라미터들
- 계층적 설정 구조 (/petclinic/dev/*)
- 암호화된 설정값들

---

### Phase 3: 서비스 디스커버리 및 AI

#### 5. Cloud Map Layer
```bash
cd terraform/layers/05-cloud-map
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: ECS 서비스들이 서비스 디스커버리에 등록됨

**생성 리소스**:
- Service Discovery 네임스페이스 (petclinic.local)
- DNS 기반 서비스 등록

---

#### 6. Lambda GenAI Layer
```bash
cd terraform/layers/06-lambda-genai
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 독립적인 서버리스 서비스로 다른 서비스와 의존성 낮음

**생성 리소스**:
- Lambda 함수 (AI 서비스)
- IAM 역할 (Bedrock 접근용)
- Lambda 레이어 (필요시)

---

### Phase 4: 애플리케이션 및 로드밸런싱

#### 7. Application Layer
```bash
cd terraform/layers/07-application
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: ECS 서비스와 ALB가 네트워크, 보안, 데이터베이스에 의존

**생성 리소스**:
- ECR 리포지토리들
- Application Load Balancer
- ECS Fargate 클러스터
- ECS 서비스들 (customers, vets, visits, admin)
- CloudWatch 로그 그룹

---

#### 8. API Gateway Layer
```bash
cd terraform/layers/08-api-gateway
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: ALB와 Lambda 함수에 의존

**생성 리소스**:
- API Gateway REST API
- API Gateway 스테이지
- Lambda 통합 설정
- ALB 통합 설정

---

### Phase 5: 모니터링 및 통합

#### 9. AWS Native Integration Layer
```bash
cd terraform/layers/09-aws-native
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 모든 AWS 네이티브 서비스들 간의 통합과 오케스트레이션

**생성 리소스**:
- API Gateway와 Lambda GenAI 통합
- 서비스 간 연결 검증 및 모니터링
- 통합 CloudWatch 대시보드
- WAF 보안 설정 (선택사항)
- Route 53 헬스체크 (선택사항)
- 비용 최적화 태그 및 정책

---

#### 10. Monitoring Layer
```bash
cd terraform/layers/10-monitoring
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 모든 서비스가 실행된 후 모니터링 설정

**생성 리소스**:
- CloudWatch 대시보드
- CloudWatch 알람
- SNS 토픽 (알림용)
- X-Ray 설정

---

#### 11. Frontend Hosting Layer
```bash
cd terraform/layers/11-frontend
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: 프론트엔드 애플리케이션을 S3 + CloudFront로 호스팅 (API Gateway에 의존)

**생성 리소스**:
- S3 버킷 (프론트엔드 정적 파일 호스팅)
- CloudFront 배포 (CDN 및 API 라우팅)
- SPA 라우팅을 위한 CloudFront 함수
- CORS 헤더 처리를 위한 Lambda@Edge
- CloudWatch 모니터링 및 알람

---

#### 12. Notification Layer
```bash
cd terraform/layers/12-notification
terraform init -backend-config=backend.config -reconfigure
terraform plan -var-file=../../envs/dev.tfvars
terraform apply -var-file=../../envs/dev.tfvars
```
**이유**: CloudWatch 알람을 Slack으로 전송하기 위한 알림 시스템 구축

**생성 리소스**:
- SNS 토픽 (알림용)
- Lambda 함수 (Slack Notifier)
- CloudWatch Log Group
- 테스트 알람 (선택사항)

---

### Phase 6: 유틸리티 (Utilities)

#### 13. State Management (Bootstrap)
**이유**: 다른 레이어들의 상태 관리를 위한 유틸리티 레이어

**생성 리소스**:
- 상태 관리 도구
- 백업 및 복원 스크립트

---

## 🔄 실행 스크립트

### 전체 자동 실행 스크립트
```bash
#!/bin/bash
# 전체 레이어 순차 실행 스크립트

LAYERS=(
    "01-network"
    "02-security"
    "03-database"
    "04-parameter-store"
    "05-cloud-map"
    "06-lambda-genai"
    "07-application"
    "08-api-gateway"
    "09-aws-native"
    "10-monitoring"
    "11-frontend"
    "12-notification"
)

BASE_DIR="terraform/layers"

for layer in "${LAYERS[@]}"; do
    echo "=========================================="
    echo "실행 중: $layer 레이어"
    echo "=========================================="
    
    cd "$BASE_DIR/$layer"
    
    echo "terraform init 실행..."
    terraform init -backend-config=backend.config -reconfigure
    
    echo "terraform plan 실행..."
    terraform plan -var-file=../../envs/dev.tfvars
    
    read -p "$layer 레이어를 apply하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "terraform apply 실행..."
        terraform apply -auto-approve -var-file=../../envs/dev.tfvars
    else
        echo "$layer 레이어 건너뜀"
    fi
    
    cd - > /dev/null
    echo ""
done
```

### PowerShell 버전
```powershell
# 전체 레이어 순차 실행 스크립트 (PowerShell)

$Layers = @(
    "01-network",
    "02-security",
    "03-database",
    "04-parameter-store",
    "05-cloud-map",
    "06-lambda-genai",
    "07-application",
    "08-api-gateway",
    "09-aws-native",
    "10-monitoring",
    "11-frontend",
    "12-notification"
)

$BaseDir = "terraform\layers"

foreach ($layer in $Layers) {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "실행 중: $layer 레이어" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $layerPath = Join-Path $BaseDir $layer
    Push-Location $layerPath
    
    Write-Host "terraform init 실행..." -ForegroundColor Yellow
    terraform init -backend-config=backend.config -reconfigure
    
    Write-Host "terraform plan 실행..." -ForegroundColor Yellow
    terraform plan -var-file=..\..\envs\dev.tfvars
    
    $response = Read-Host "$layer 레이어를 apply하시겠습니까? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "terraform apply 실행..." -ForegroundColor Green
        terraform apply -auto-approve -var-file=..\..\envs\dev.tfvars
    } else {
        Write-Host "$layer 레이어 건너뜀" -ForegroundColor Yellow
    }
    
    Pop-Location
    Write-Host ""
}
```

## ⚠️ 주의사항

### 1. 의존성 확인
각 레이어 실행 전에 이전 레이어들이 성공적으로 완료되었는지 확인하세요.

### 2. 오류 발생 시
특정 레이어에서 오류가 발생하면:
1. 오류 메시지를 자세히 확인
2. 의존성 리소스가 제대로 생성되었는지 확인
3. AWS 콘솔에서 리소스 상태 확인
4. 필요시 이전 레이어부터 다시 실행

### 3. 리소스 정리 시 (terraform destroy)
**역순으로 실행해야 합니다**:
```bash
# 정리 순서 (역순)
12-notification → 11-frontend → 10-monitoring → 09-aws-native → 08-api-gateway →
07-application → 06-lambda-genai → 05-cloud-map → 04-parameter-store →
03-database → 02-security → 01-network
```

### 4. 비용 관리
- 테스트 후에는 불필요한 리소스 정리
- Aurora Serverless v2는 최소 ACU로 설정되어 있지만 비용 발생
- NAT Gateway도 시간당 비용 발생

## 🔍 검증 방법

각 레이어 실행 후 다음을 확인하세요:

### 1. Terraform 상태 확인
```bash
terraform show
terraform output
```

### 2. AWS 콘솔 확인
- 해당 레이어의 리소스들이 정상 생성되었는지 확인
- 태그가 올바르게 적용되었는지 확인

### 3. 의존성 테스트
- 다음 레이어에서 필요한 리소스들이 사용 가능한지 확인

## 📊 예상 실행 시간

| 레이어 | 예상 시간 | 주요 대기 요소 |
|--------|-----------|----------------|
| network | 3-5분 | NAT Gateway 생성 |
| security | 2-3분 | VPC 엔드포인트 생성 |
| database | 10-15분 | Aurora 클러스터 생성 |
| parameter-store | 1-2분 | 파라미터 생성 |
| cloud-map | 1-2분 | 네임스페이스 생성 |
| lambda-genai | 2-3분 | Lambda 함수 배포 |
| application | 5-8분 | ECS 서비스 시작 |
| api-gateway | 2-3분 | API 배포 |
| aws-native | 1-2분 | 통합 설정 |
| monitoring | 2-3분 | 대시보드 생성 |
| frontend | 3-5분 | S3 + CloudFront 배포 |
| notification | 1-2분 | SNS + Lambda 배포 |

**총 예상 시간**: 36-52분

이 순서를 따라 실행하면 의존성 문제 없이 전체 인프라를 성공적으로 구축할 수 있습니다!