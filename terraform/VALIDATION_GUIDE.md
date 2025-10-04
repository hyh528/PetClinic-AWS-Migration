# Terraform 인프라 검증 가이드

## 📋 개요

이 문서는 팀원들이 Terraform 인프라를 안전하게 검증하고 배포할 수 있도록 단계별 가이드를 제공합니다.

## 🚨 중요 사항

- **절대 운영 환경에서 바로 테스트하지 마세요**
- **각 단계를 순서대로 진행하세요**
- **오류 발생 시 즉시 중단하고 팀에 문의하세요**

## 📁 현재 인프라 구조

```
terraform/
├── envs/dev/                    # 개발 환경 설정
│   ├── network/                 # ✅ VPC, 서브넷, 게이트웨이
│   ├── security/                # ✅ 보안 그룹, IAM, VPC 엔드포인트
│   ├── database/                # ✅ Aurora 클러스터
│   ├── application/             # ⚠️  ECS, ALB, ECR (검증 필요)
│   ├── monitoring/              # ✅ CloudWatch, X-Ray
│   ├── aws-native/              # ✅ API Gateway, Parameter Store 등
│   └── state-management/        # 🆕 원격 상태 관리 (신규)
└── modules/                     # 재사용 가능한 모듈들
```

## 🔍 1단계: 사전 검증

### 1.1 필수 도구 확인

```bash
# Terraform 버전 확인 (1.0 이상 필요)
terraform version

# AWS CLI 확인
aws --version

# AWS 자격 증명 확인
aws sts get-caller-identity
```

### 1.2 현재 상태 확인

```bash
# 프로젝트 루트로 이동
cd terraform/envs/dev

# 각 레이어별 상태 확인
for dir in network security database application monitoring; do
    echo "=== $dir 레이어 확인 ==="
    cd $dir
    if [ -f "terraform.tfstate" ]; then
        echo "✅ 로컬 상태 파일 존재"
        terraform state list | head -5
    else
        echo "❌ 상태 파일 없음"
    fi
    cd ..
    echo
done
```

## 🔧 2단계: 문법 검증

### 2.1 모든 모듈 검증

```bash
# 모듈별 문법 검증
cd terraform/modules

for module in */; do
    echo "=== $module 모듈 검증 ==="
    cd "$module"
    terraform fmt -check
    terraform validate
    cd ..
    echo
done
```

### 2.2 환경별 설정 검증

```bash
# 개발 환경 검증
cd terraform/envs/dev

for env in */; do
    echo "=== $env 환경 검증 ==="
    cd "$env"
    terraform fmt -check
    terraform init -backend=false  # 백엔드 없이 초기화
    terraform validate
    cd ..
    echo
done
```

## 🏗️ 3단계: 단계별 배포 (권장 순서)

### 3.1 상태 관리 인프라 (최우선)

```bash
cd terraform/envs/dev/state-management

# 1. 설정 파일 복사
cp terraform.tfvars.example terraform.tfvars

# 2. 설정 값 수정 (버킷 이름을 고유하게 변경)
# terraform.tfvars 파일에서 bucket_name 수정 필요

# 3. 초기화 및 배포
terraform init
terraform plan
terraform apply  # 신중하게 검토 후 yes 입력
```

### 3.2 네트워크 레이어 (기반 인프라)

```bash
cd terraform/envs/dev/network

# 1. 백엔드 설정 적용 (상태 관리 완료 후)
terraform init

# 2. 계획 확인
terraform plan

# 3. 배포 (기존 리소스가 있다면 import 필요)
terraform apply
```

### 3.3 보안 레이어

```bash
cd terraform/envs/dev/security

terraform init
terraform plan
terraform apply
```

### 3.4 데이터베이스 레이어

```bash
cd terraform/envs/dev/database

terraform init
terraform plan
terraform apply
```

### 3.5 애플리케이션 레이어 (주의 필요)

```bash
cd terraform/envs/dev/application

# ⚠️ 현재 알려진 이슈: task_role_arn 속성 오류
# 배포 전 이슈 해결 필요

terraform init
terraform plan  # 오류 확인
```

## 🚨 4단계: 문제 해결

### 4.1 알려진 이슈들

#### Issue #1: Application 레이어 - task_role_arn 오류
```
Error: Unexpected attribute: An attribute named "task_role_arn" is not expected here
```

**해결 방법:**
1. ECS 모듈 캐시 정리
2. 모듈 재초기화
3. 필요시 팀에 문의

#### Issue #2: 상태 파일 충돌
```
Error: Error acquiring the state lock
```

**해결 방법:**
```bash
# 잠금 해제 (주의: 다른 사람이 작업 중이 아닌지 확인)
terraform force-unlock LOCK_ID
```

### 4.2 일반적인 문제 해결

```bash
# 캐시 정리
rm -rf .terraform
rm .terraform.lock.hcl

# 재초기화
terraform init

# 포맷팅 수정
terraform fmt -recursive
```

## 📊 5단계: 배포 후 검증

### 5.1 리소스 확인

```bash
# 생성된 리소스 목록
terraform state list

# 특정 리소스 상세 정보
terraform state show aws_vpc.main

# 출력 값 확인
terraform output
```

### 5.2 AWS 콘솔 확인

1. **VPC**: 서브넷, 라우팅 테이블, 게이트웨이
2. **ECS**: 클러스터, 서비스, 태스크
3. **RDS**: Aurora 클러스터 상태
4. **CloudWatch**: 로그 그룹, 메트릭

## 🔄 6단계: 원격 상태 마이그레이션

### 6.1 자동 마이그레이션 (권장)

```bash
cd terraform/envs/dev/state-management

# 마이그레이션 스크립트 실행
chmod +x scripts/migrate-to-remote-state.sh
./scripts/migrate-to-remote-state.sh
```

### 6.2 수동 마이그레이션

```bash
# 각 레이어별로 수동 마이그레이션
cd terraform/envs/dev/network
terraform init  # 백엔드 마이그레이션 프롬프트에서 'yes'
```

## 📞 7단계: 문제 발생 시 대응

### 7.1 즉시 중단해야 하는 상황

- ❌ 예상치 못한 리소스 삭제 계획
- ❌ 운영 환경 리소스 변경 감지
- ❌ 비용이 많이 드는 리소스 생성 계획

### 7.2 도움 요청

1. **오류 메시지 전체 복사**
2. **실행한 명령어 기록**
3. **현재 작업 디렉토리 확인**
4. **팀 채널에 공유**

## 📚 추가 자료

- [Terraform 공식 문서](https://www.terraform.io/docs)
- [AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [팀 내부 Terraform 가이드](./README.md)

---

**⚠️ 주의**: 이 가이드는 개발 환경 기준입니다. 운영 환경 배포 시에는 별도 승인 절차가 필요합니다.