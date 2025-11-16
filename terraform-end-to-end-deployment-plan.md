# 테라폼 엔드투엔드 배포 계획 (서울 리전)

## 📋 개요

기존 us-west-2 (오레곤) dev 환경을 ap-northeast-2 (서울) 리전으로 복제하여 엔드투엔드 배포를 수행하는 계획입니다.

## 🎯 목표

- 서울 리전에서 Spring PetClinic 마이크로서비스 인프라 완전 구축
- 11개 레이어 순차 배포 검증
- 애플리케이션 기능 테스트
- 모니터링 및 알림 시스템 확인

## 📁 현재 상태

- **기존 환경**: dev (us-west-2)
- **대상 환경**: dev-seoul (ap-northeast-2)
- **기반 코드**: terraform/ 폴더의 모든 레이어 및 모듈

## 🚀 배포 단계

### Phase 1: 환경 준비

#### 1.1 서울 리전용 환경 설정 생성
```bash
# terraform/envs/dev-seoul.tfvars 생성
# dev.tfvars를 복사하여 아래 항목 수정:
- aws_region = "ap-northeast-2"
- aws_profile = "petclinic-dev-seoul" (또는 기존 프로필)
- tfstate_bucket_name = "petclinic-tfstate-seoul-dev"
- azs = ["ap-northeast-2a", "ap-northeast-2b"]
- service_image_map의 ECR 리포지토리 URL을 서울 리전으로 변경
```

#### 1.2 AWS 프로필 및 권한 확인
```bash
# AWS CLI 설정 확인
aws configure --profile petclinic-dev-seoul

# 필수 권한 확인 (IAM, S3, DynamoDB, EC2, ECS, RDS 등)
aws sts get-caller-identity --profile petclinic-dev-seoul
```

### Phase 2: Bootstrap (상태 관리 인프라)

#### 2.1 Bootstrap 레이어 준비
```bash
cd terraform/bootstrap

# 서울 리전용 bootstrap 생성 (bootstrap-seoul/)
cp -r . ../bootstrap-seoul
cd ../bootstrap-seoul

# providers.tf 수정: region = "ap-northeast-2"
# variables.tf의 bucket_name 등 조정
```

#### 2.2 S3 버킷 생성 (Lockfile 방식)
```bash
terraform init
terraform plan -var-file=../envs/dev-seoul.tfvars
terraform apply -var-file=../envs/dev-seoul.tfvars
```

**생성 리소스**:
- S3 버킷: petclinic-tfstate-seoul-dev
- **참고**: DynamoDB 락 테이블 불필요 (S3 네이티브 locking 사용)

### Phase 3: 레이어 초기화

#### 3.1 모든 레이어 백엔드 설정 확인
```bash
# 각 레이어의 backend.config 파일 확인
# key = "dev-seoul/01-network/terraform.tfstate" 등으로 설정
```

#### 3.2 일괄 초기화 스크립트 실행
```bash
# terraform/scripts/local/init-all.ps1 수정하여 서울 리전용으로 실행
# 또는 수동으로 각 레이어 초기화:
cd terraform/layers/01-network
terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure
```

### Phase 4: 단계별 배포 (11개 레이어)

#### 4.1 Network Layer (01-network)
```bash
cd terraform/layers/01-network
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 3-5분
**주요 리소스**: VPC, 서브넷, NAT Gateway, 라우팅 테이블

#### 4.2 Security Layer (02-security)
```bash
cd terraform/layers/02-security
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 2-3분
**주요 리소스**: 보안 그룹, IAM 역할, VPC 엔드포인트

#### 4.3 Database Layer (03-database)
```bash
cd terraform/layers/03-database
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 10-15분
**주요 리소스**: Aurora MySQL 클러스터, Secrets Manager

#### 4.4 Parameter Store Layer (04-parameter-store)
```bash
cd terraform/layers/04-parameter-store
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 1-2분
**주요 리소스**: Systems Manager 파라미터

#### 4.5 Cloud Map Layer (05-cloud-map)
```bash
cd terraform/layers/05-cloud-map
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 1-2분
**주요 리소스**: Service Discovery 네임스페이스

#### 4.6 Lambda GenAI Layer (06-lambda-genai)
```bash
cd terraform/layers/06-lambda-genai
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 2-3분
**주요 리소스**: Lambda 함수, Bedrock 접근 IAM 역할

#### 4.7 Application Layer (07-application)
```bash
cd terraform/layers/07-application
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 5-8분
**주요 리소스**: ECS 클러스터, 서비스, ALB, ECR 리포지토리

#### 4.8 API Gateway Layer (08-api-gateway)
```bash
cd terraform/layers/08-api-gateway
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 2-3분
**주요 리소스**: API Gateway, Lambda 통합

#### 4.9 AWS Native Integration Layer (09-aws-native)
```bash
cd terraform/layers/09-aws-native
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 1-2분
**주요 리소스**: 서비스 간 통합 설정

#### 4.10 Monitoring Layer (10-monitoring)
```bash
cd terraform/layers/10-monitoring
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 2-3분
**주요 리소스**: CloudWatch 대시보드, 알람, SNS 토픽

#### 4.11 Frontend Hosting Layer (11-frontend)
```bash
cd terraform/layers/11-frontend
terraform plan -var-file=../../envs/dev-seoul.tfvars
terraform apply -var-file=../../envs/dev-seoul.tfvars
```
**소요시간**: 3-5분
**주요 리소스**: S3 버킷, CloudFront 배포

### Phase 5: 배포 검증

#### 5.1 인프라 검증
```bash
# 각 레이어 상태 확인
terraform state list

# 리소스 출력 확인
terraform output

# AWS 콘솔에서 리소스 확인
```

#### 5.2 애플리케이션 테스트
```bash
# ALB 엔드포인트 확인
terraform output -json | jq '.alb_dns_name.value'

# API Gateway 엔드포인트 확인
terraform output -json | jq '.api_gateway_url.value'

# 서비스 헬스체크
curl https://[ALB-DNS]/actuator/health
curl https://[API-GATEWAY-URL]/api/vets
```

#### 5.3 모니터링 확인
```bash
# CloudWatch 대시보드 확인
# 알람 상태 확인
# 로그 그룹 확인
```

## ⚠️ 주의사항

### 1. 비용 관리
- Aurora Serverless v2는 시간당 비용 발생
- NAT Gateway는 시간당 비용 발생
- 테스트 완료 후 즉시 정리 권장

### 2. 의존성 준수
- 각 레이어를 순서대로 배포
- 이전 레이어 실패 시 다음 레이어 진행하지 말 것

### 3. 오류 처리
- 특정 레이어 실패 시 오류 로그 확인
- 의존성 리소스 상태 검증
- 필요시 이전 레이어부터 재배포

### 4. 보안 고려사항
- 서울 리전의 컴플라이언스 요구사항 확인
- 데이터 저장 위치 제한 확인

## 📊 예상 일정 및 리소스

| 단계 | 소요시간 | 주요 작업 |
|------|----------|-----------|
| 환경 준비 | 30분 | 설정 파일 생성, AWS 권한 확인 |
| Bootstrap | 10분 | S3 + DynamoDB 생성 |
| 레이어 초기화 | 15분 | 11개 레이어 init |
| 단계별 배포 | 35-50분 | 11개 레이어 apply |
| 검증 및 테스트 | 30분 | 기능 테스트, 모니터링 확인 |
| **총계** | **2-3시간** | 완전한 인프라 구축 |

## 🔄 정리 계획

테스트 완료 후 리소스 정리:
```bash
# 역순으로 terraform destroy 실행
# 11-frontend → 10-monitoring → ... → 01-network → bootstrap
```

