# 남은 작업 목록 - Spring PetClinic AWS 마이그레이션

## 📋 현재 상태
- ✅ Terraform 코드 개선 및 하드코딩 제거 완료
- ✅ 공유 AWS 프로필(petclinic-dev) 전환 완료
- ✅ Git 커밋 완료
- ❌ Parameter Store 파라미터 생성 필요
- ❌ Terraform 레이어 배포 미완료

## 🎯 남은 작업 목록

### Phase 1: 사전 준비 (필수)

#### 1. Parameter Store 파라미터 생성 🔴
**우선순위: 높음 | 예상시간: 5분**

```bash
# DB 사용자명 파라미터 생성
aws ssm put-parameter \
  --name "/petclinic/dev/customers/database.username" \
  --value "petclinic" \
  --type "String" \
  --profile petclinic-dev

# DB 이름 파라미터 생성
aws ssm put-parameter \
  --name "/petclinic/dev/customers/database.name" \
  --value "petclinic_customers" \
  --type "String" \
  --profile petclinic-dev
```

**확인 방법:**
```bash
aws ssm get-parameter --name "/petclinic/dev/customers/database.username" --profile petclinic-dev
```

#### 2. Backend 변경 적용 🟡
**우선순위: 높음 | 예상시간: 10분**

각 레이어에서 terraform init을 실행하여 공유 프로필로 backend 변경 적용:

```bash
# Network 레이어
cd terraform/envs/dev/network
terraform init

# Security 레이어
cd terraform/envs/dev/security
terraform init

# Database 레이어
cd terraform/envs/dev/database
terraform init

# Application 레이어
cd terraform/envs/dev/application
terraform init
```

### Phase 2: 인프라 배포

#### 3. Network 레이어 배포 🟢
**우선순위: 높음 | 예상시간: 15분**

```bash
cd terraform/envs/dev/network
terraform plan
terraform apply
```

**생성 리소스:**
- VPC (10.0.0.0/16)
- Public/Private 서브넷 (6개)
- Internet Gateway, NAT Gateway
- Route Tables

#### 4. Security 레이어 배포 🟢
**우선순위: 높음 | 예상시간: 15분**

```bash
cd terraform/envs/dev/security
terraform plan
terraform apply
```

**생성 리소스:**
- 보안 그룹 (ALB, ECS, Aurora용)
- IAM 역할 및 정책
- VPC 엔드포인트 (ECR, CloudWatch, SSM 등)

#### 5. Database 레이어 배포 🟢
**우선순위: 높음 | 예상시간: 20분**

```bash
cd terraform/envs/dev/database
terraform plan
terraform apply
```

**생성 리소스:**
- Aurora MySQL 클러스터 (Writer + Reader)
- DB 서브넷 그룹
- Secrets Manager (DB 비밀번호)

#### 6. Application 레이어 배포 🟢
**우선순위: 높음 | 예상시간: 25분**

```bash
cd terraform/envs/dev/application
terraform plan
terraform apply
```

**생성 리소스:**
- ECR 리포지토리
- Application Load Balancer
- ECS Fargate 클러스터 및 서비스
- CloudWatch 로그 그룹

### Phase 3: 검증 및 테스트

#### 7. 인프라 검증 🔵
**우선순위: 높음 | 예상시간: 15분**

```bash
# 네트워크 연결성 검증
./scripts/terraform-validation/validate-network-connectivity.sh

# 각 서비스 헬스체크
curl https://[ALB-DNS]/actuator/health
```

#### 8. 애플리케이션 기능 테스트 🔵
**우선순위: 높음 | 예상시간: 20분**

```bash
# API 엔드포인트 테스트
curl https://[ALB-DNS]/api/customers
curl https://[ALB-DNS]/api/vets
curl https://[ALB-DNS]/api/visits

# 부하 테스트 (선택)
./scripts/test/performance-test.sh
```

## ⚠️ 주의사항

### 실행 순서 엄수
1. Parameter Store 파라미터 생성
2. terraform init (모든 레이어)
3. Network → Security → Database → Application 순서로 배포

### 필수 조건 확인
- ✅ AWS CLI 프로필 `petclinic-dev` 설정 완료
- ✅ 각 레이어의 IAM 권한 확인
- ❌ Parameter Store 파라미터 생성 필요

### 모니터링
- AWS Cost Explorer에서 비용 추적
- CloudWatch에서 리소스 상태 모니터링
- 배포 실패 시 로그 확인

## 📊 진행 상황 추적

- [ ] Parameter Store 파라미터 생성
- [ ] Network 레이어 terraform init
- [ ] Security 레이어 terraform init
- [ ] Database 레이어 terraform init
- [ ] Application 레이어 terraform init
- [ ] Network 레이어 배포
- [ ] Security 레이어 배포
- [ ] Database 레이어 배포
- [ ] Application 레이어 배포
- [ ] 인프라 검증
- [ ] 애플리케이션 테스트

## 🎯 다음 단계

1. **Parameter Store 파라미터 생성**부터 시작
2. 각 레이어 **terraform init** 실행
3. **Network 레이어**부터 순차적으로 배포
4. 배포 완료 후 **검증 및 테스트**

---
*최종 업데이트: 2025-10-09*