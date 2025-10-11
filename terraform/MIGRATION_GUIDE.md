# Terraform Infrastructure Migration Guide

## 개요

이 가이드는 Terraform 인프라를 v1.0.0에서 v2.0.0으로 마이그레이션하는 방법을 설명합니다.

## 🎯 마이그레이션 목표

### 주요 개선사항
- **공유 변수 시스템**: 모든 레이어에서 일관된 변수 사용
- **단일 책임 원칙**: 각 레이어의 책임 명확히 분리
- **코드 중복 제거**: DRY 원칙 적용
- **보안 강화**: AWS Well-Architected 보안 원칙 준수
- **운영 효율성**: 자동화된 스크립트 및 검증 도구

## 📋 사전 준비사항

### 1. 백업 생성
```bash
# 현재 Terraform 상태 백업
cd terraform
for layer in layers/*/; do
    if [ -d "$layer/.terraform" ]; then
        echo "Backing up $(basename $layer)..."
        cd "$layer"
        terraform state pull > "backup-$(basename $layer)-$(date +%Y%m%d).json"
        cd ../..
    fi
done

# Git 백업
git checkout -b backup-v1.0.0
git add .
git commit -m "Backup before v2.0.0 migration"
```

### 2. 환경 검증
```bash
# Terraform 버전 확인
terraform version  # >= 1.8.0 필요

# AWS CLI 설정 확인
aws sts get-caller-identity

# 필요한 도구 설치 확인
which jq
which bash
```

## 🔄 마이그레이션 단계

### Phase 1: 코드 업데이트 (완료됨)

#### 1.1 공유 변수 시스템 적용 ✅
- `shared-variables.tf` 파일 생성
- 모든 레이어에서 공통 변수 사용
- 중복 변수 정의 제거

#### 1.2 상태 참조 표준화 ✅
- 개인별 경로 제거 (`dev/yeonghyeon/network` → `dev/01-network`)
- 표준 키 형식 적용: `dev/{레이어번호-레이어명}/terraform.tfstate`
- 모든 terraform_remote_state 참조 업데이트

#### 1.3 레이어 책임 분리 ✅
- **02-security**: 단일 책임 원칙 적용
- **07-application**: ECR, ALB, ECS 모듈 분리
- **08-api-gateway**: AWS API Gateway 완전 대체
- **09-monitoring**: 핵심 모니터링만 유지
- **10-aws-native**: 기본 통합 기능만 유지

### Phase 2: 검증 및 테스트

#### 2.1 코드 품질 검증
```bash
# Terraform 포맷 검증
terraform fmt -recursive -check

# 모든 레이어 검증
cd terraform
for layer in layers/*/; do
    echo "Validating $(basename $layer)..."
    cd "$layer"
    terraform validate
    cd ../..
done
```

#### 2.2 의존성 검증
```bash
# 의존성 검증 스크립트 실행
cd terraform
bash scripts/validate-dependencies.sh -a

# 배포 순서 확인
bash scripts/validate-dependencies.sh -o
```

#### 2.3 보안 검증
```bash
# Checkov 보안 스캔
cd terraform
checkov -d . --framework terraform

# 하드코딩된 값 검색
grep -r "10\.0\." layers/ || echo "No hardcoded CIDR found"
grep -r "password.*=" layers/ || echo "No hardcoded passwords found"
```

### Phase 3: 점진적 배포

#### 3.1 개발 환경 배포
```bash
# 환경 변수 설정
export AWS_PROFILE=petclinic-dev
export AWS_REGION=ap-northeast-2

# 의존성 순서대로 배포
cd terraform

# 1. Network Layer
cd layers/01-network
terraform init -reconfigure
terraform plan -var-file="../../envs/dev.tfvars"
terraform apply -var-file="../../envs/dev.tfvars"

# 2. Security Layer
cd ../02-security
terraform init -reconfigure
terraform plan -var-file="../../envs/dev.tfvars"
terraform apply -var-file="../../envs/dev.tfvars"

# 3. Database Layer
cd ../03-database
terraform init -reconfigure
terraform plan -var-file="../../envs/dev.tfvars"
terraform apply -var-file="../../envs/dev.tfvars"

# 나머지 레이어들도 순서대로...
```

#### 3.2 자동화된 배포 (권장)
```bash
# 전체 레이어 순차 배포
cd terraform
bash scripts/apply-all.sh dev
```

### Phase 4: 검증 및 테스트

#### 4.1 인프라 검증
```bash
# 리소스 상태 확인
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=petclinic"
aws ecs list-clusters
aws rds describe-db-clusters

# 애플리케이션 접근 테스트
curl -f http://$(terraform output -raw alb_dns_name)/actuator/health
```

#### 4.2 기능 테스트
```bash
# E2E 테스트 실행 (있는 경우)
cd terraform
bash scripts/test/e2e-full-test.sh
```

## 🚨 문제 해결

### 일반적인 문제들

#### 1. Backend Configuration Changed
```bash
# 문제: Backend configuration has been detected
# 해결: 
terraform init -reconfigure
```

#### 2. Module Not Installed
```bash
# 문제: Module not installed
# 해결:
terraform init -upgrade
```

#### 3. State Lock 오류
```bash
# 문제: Error acquiring the state lock
# 해결:
terraform force-unlock <LOCK_ID>
```

#### 4. 출력값 참조 오류
```bash
# 문제: Unsupported attribute
# 해결: 출력값 이름 확인 및 별칭 사용
terraform output  # 사용 가능한 출력값 확인
```

### 레이어별 특정 문제

#### 02-security 레이어
```bash
# ALB 통합 오류 시
# dev.tfvars에서 설정 확인
enable_alb_integration = false  # 첫 배포 시
enable_alb_integration = true   # application 레이어 배포 후
```

#### 07-application 레이어
```bash
# ECR 이미지 없음 오류 시
# 기본 이미지 푸시 또는 이미지 태그 확인
docker_image_tag = "latest"  # 존재하는 태그 사용
```

#### 08-api-gateway 레이어
```bash
# Spring Cloud Gateway 마이그레이션
# 기존 설정 제거 후 AWS API Gateway 설정 적용
```

## 📊 마이그레이션 체크리스트

### 사전 준비 ✅
- [ ] 현재 상태 백업 완료
- [ ] Git 백업 브랜치 생성
- [ ] 환경 변수 설정 확인
- [ ] 필요한 도구 설치 확인

### 코드 업데이트 ✅
- [x] 공유 변수 시스템 적용
- [x] 상태 참조 표준화
- [x] 레이어 책임 분리
- [x] 하드코딩 제거
- [x] 출력값 호환성 확보

### 검증 및 테스트 ✅
- [x] Terraform 검증 통과
- [x] 의존성 검증 통과
- [x] 보안 스캔 통과
- [x] 스크립트 동작 확인

### 배포 및 운영
- [ ] 개발 환경 배포 완료
- [ ] 기능 테스트 통과
- [ ] 모니터링 설정 확인
- [ ] 문서화 업데이트 완료

## 🔄 롤백 계획

### 긴급 롤백 (문제 발생 시)
```bash
# 1. 이전 상태로 복원
cd terraform/layers/<LAYER>
terraform state push backup-<LAYER>-<DATE>.json

# 2. 이전 코드로 복원
git checkout backup-v1.0.0

# 3. 이전 설정으로 재배포
terraform apply -var-file="../../envs/dev.tfvars"
```

### 점진적 롤백
```bash
# 특정 레이어만 롤백
cd terraform/layers/<LAYER>
terraform destroy -var-file="../../envs/dev.tfvars"
git checkout backup-v1.0.0 -- <LAYER>/
terraform apply -var-file="../../envs/dev.tfvars"
```

## 📈 성공 기준

### 기술적 성공 기준
- [ ] 모든 레이어에서 `terraform validate` 통과
- [ ] 의존성 검증 스크립트 통과
- [ ] 보안 스캔 (Checkov) 통과
- [ ] 기존 기능 정상 동작
- [ ] 새로운 기능 정상 동작

### 운영적 성공 기준
- [ ] 배포 시간 단축 (자동화 스크립트)
- [ ] 코드 중복 제거 (DRY 원칙)
- [ ] 문서화 완성도 향상
- [ ] 팀 협업 효율성 향상

### 비즈니스 성공 기준
- [ ] 인프라 비용 5-15% 절감
- [ ] 보안 컴플라이언스 향상
- [ ] 운영 안정성 향상
- [ ] 개발 생산성 향상

---

**마이그레이션 완료 후 이 문서를 업데이트하여 실제 경험을 반영해주세요.**