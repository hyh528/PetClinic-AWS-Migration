# 도쿄 리전 테스트 가이드

영현님이 도쿄 리전에서 안전하게 인프라를 테스트할 수 있는 가이드입니다.

## 🎯 목적

- **팀 리소스 영향 없음**: 서울 리전(ap-northeast-2) 대신 도쿄 리전(ap-northeast-1) 사용
- **완전한 검증**: 실제 AWS 리소스 생성/삭제까지 테스트
- **안전한 실험**: 개인 계정에서 독립적으로 테스트

## 🚀 빠른 시작

### 방법 1: 자동화 스크립트 사용 (권장)

```bash
# 실행 권한 부여 (Windows에서는 생략 가능)
chmod +x scripts/tokyo-region-test.sh

# 전체 인프라 Plan (검증만)
./scripts/tokyo-region-test.sh plan

# 전체 인프라 Apply (실제 생성)
./scripts/tokyo-region-test.sh apply

# 전체 인프라 Destroy (정리)
./scripts/tokyo-region-test.sh destroy
```

### 방법 2: 수동 레이어별 실행

```bash
# 1. Network 레이어
cd terraform/envs/dev/network
terraform init
terraform plan -var-file="tokyo-test.tfvars"
terraform apply -var-file="tokyo-test.tfvars"

# 2. Security 레이어
cd ../security
terraform init
terraform plan -var-file="tokyo-test.tfvars"
terraform apply -var-file="tokyo-test.tfvars"

# 3. Database 레이어
cd ../database
terraform init
terraform plan -var-file="tokyo-test.tfvars"
terraform apply -var-file="tokyo-test.tfvars"

# 4. Application 레이어
cd ../application
terraform init
terraform plan -var-file="tokyo-test.tfvars"
terraform apply -var-file="tokyo-test.tfvars"
```

## 📋 테스트 설정

### 리전 변경사항
```bash
# 기존 (팀 공용)
리전: ap-northeast-2 (서울)
AZ: ap-northeast-2a, ap-northeast-2c

# 테스트 (영현님 전용)
리전: ap-northeast-1 (도쿄)
AZ: ap-northeast-1a, ap-northeast-1c
```

### 리소스 명명
```bash
# 기존
name_prefix = "petclinic-dev"

# 테스트
name_prefix = "petclinic-tokyo-test"
```

### 태그 구분
```bash
tags = {
  Purpose = "tokyo-region-test"
  Owner   = "yeonghyeon"
  TestEnv = "true"
}
```

## 🔍 검증 포인트

### 1. Network 레이어 검증
- [ ] VPC 생성 (10.0.0.0/16)
- [ ] 서브넷 생성 (Public/Private App/Private DB)
- [ ] Internet Gateway 생성
- [ ] NAT Gateway 생성 (각 AZ별)
- [ ] 라우팅 테이블 설정

### 2. Security 레이어 검증
- [ ] 보안 그룹 생성
- [ ] IAM 역할 및 정책 생성
- [ ] VPC 엔드포인트 생성
- [ ] NACL 규칙 적용

### 3. Database 레이어 검증
- [ ] Aurora Serverless v2 클러스터 생성
- [ ] DB 서브넷 그룹 생성
- [ ] Secrets Manager 설정

### 4. Application 레이어 검증
- [ ] ECS Fargate 클러스터 생성
- [ ] ALB 생성 및 설정
- [ ] ECR 리포지토리 생성
- [ ] CloudWatch 로그 그룹 생성

## 💰 비용 관리

### 예상 비용 (시간당)
```bash
- Aurora Serverless v2: ~$0.50/시간
- NAT Gateway: ~$0.09/시간 (2개)
- ALB: ~$0.05/시간
- ECS Fargate: ~$0.10/시간 (최소 구성)
총 예상: ~$0.74/시간 (~$18/일)
```

### 비용 절약 팁
1. **테스트 후 즉시 삭제**: `terraform destroy`
2. **필요한 레이어만**: 특정 레이어만 테스트
3. **짧은 테스트**: 몇 시간 내로 완료

## 🚨 주의사항

### 1. 상태 파일 관리
- 도쿄 테스트의 상태 파일은 별도 경로에 저장됨
- 팀 상태 파일과 충돌하지 않음

### 2. 리소스 정리
```bash
# 반드시 테스트 후 정리!
./scripts/tokyo-region-test.sh destroy
```

### 3. 프로필 확인
```bash
# 올바른 프로필 사용 확인
aws sts get-caller-identity --profile petclinic-yeonghyeon
```

## 🔧 문제 해결

### 일반적인 문제들

#### 1. 권한 오류
```bash
# AWS 프로필 확인
aws configure list --profile petclinic-yeonghyeon

# 자격 증명 갱신
aws configure --profile petclinic-yeonghyeon
```

#### 2. 리전 서비스 가용성
```bash
# 도쿄 리전에서 서비스 가용성 확인
aws ec2 describe-availability-zones --region ap-northeast-1
```

#### 3. 상태 파일 충돌
```bash
# 상태 파일 경로 확인
terraform show
```

## 📊 테스트 결과 기록

### 성공 기준
- [ ] 모든 레이어 apply 성공
- [ ] 리소스 간 연결성 확인
- [ ] 보안 규칙 정상 작동
- [ ] 모든 레이어 destroy 성공

### 실패 시 대응
1. 오류 로그 수집
2. 부분적 destroy 시도
3. 수동 리소스 정리
4. 팀에 공유 및 개선

## 🎉 성공 후 다음 단계

1. **팀 공유**: 테스트 결과 및 발견사항 공유
2. **문서 업데이트**: 발견된 이슈나 개선사항 반영
3. **서울 리전 적용**: 검증된 설정을 팀 환경에 적용

---

**Happy Testing! 🚀**