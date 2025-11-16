# 테라폼 왕초보 가이드: .terraform, lockfile, reconfigure, import, drift 완벽 이해

> "테라폼이 처음이라면, 이 문서가 당신의 첫 번째 친구가 될 것입니다. 하나씩 차근차근 따라해보세요!"

---

## 📋 목차

1. [테라폼이 뭐예요?](#1-테라폼이-뭐예요)
2. [.terraform 폴더란?](#2-terraform-폴더란)
3. [terraform.lock.hcl 파일이란?](#3-terraformlockhcl-파일이란)
4. [언제 terraform init --reconfigure 해야 하나요?](#4-언제-terraform-init---reconfigure-해야-하나요)
5. [언제 terraform import 해야 하나요?](#5-언제-terraform-import-해야-하나요)
6. [Drift(드리프트)란 무엇인가?](#6-drift드리프트란-무엇인가)
7. [문제 해결 가이드](#7-문제-해결-가이드)
8. [왕초보자를 위한 팁](#8-왕초보자를-위한-팁)

---

## 1. 테라폼이 뭐예요?

테라폼(Terraform)은 **인프라를 코드로 관리하는 도구**입니다.

### 비유로 이해하기

```
기존 방식 (수동):
개발자: "AWS 콘솔에서 EC2 인스턴스 만들어주세요"
운영팀: (클릭 클릭...) "만들었습니다!"

테라폼 방식:
개발자: 코드 작성
terraform apply 실행
→ AWS에 인프라 자동 생성!
```

### 왜 테라폼을 사용하나요?

1. **재현성**: 같은 코드를 실행하면 같은 인프라가 만들어짐
2. **버전 관리**: Git으로 인프라 변경사항 추적
3. **협업**: 팀원들이 같은 인프라 환경 공유
4. **안전성**: 변경사항 미리 확인 가능 (plan 명령어)

---

## 2. .terraform 폴더란?

`.terraform` 폴더는 테라폼의 **작업 공간**입니다.

### 폴더 구조

```
.terraform/
├── providers/           # Provider 플러그인들
│   ├── registry.terraform.io/hashicorp/aws/5.0.0/
│   └── registry.terraform.io/hashicorp/random/3.5.1/
├── modules/             # 다운로드된 모듈들
└── plugin_cache/        # 플러그인 캐시
```

### 왜 중요한가?

1. **플러그인 저장**: AWS, GCP 등 클라우드 provider 플러그인
2. **모듈 캐시**: 재사용 가능한 코드 블록들
3. **성능 향상**: 같은 플러그인 재다운로드 방지

### 주의사항

- **Git에 포함하지 마세요!** (`.gitignore`에 추가)
- **삭제해도 괜찮아요**: `terraform init`으로 다시 생성됨
- **용량**: 보통 수십 MB ~ 수백 MB

---

## 3. terraform.lock.hcl 파일이란?

`terraform.lock.hcl`은 테라폼의 **버전 잠금 파일**입니다.

### 파일 내용 예시

```hcl
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.0.0"
  constraints = "~> 5.0"
  hashes = [
    "h1:xxxxx...",
    "zh:xxxxx...",
  ]
}
```

### 왜 필요한가?

1. **버전 고정**: 같은 버전의 provider 사용 보장
2. **팀 협업**: 모든 팀원이 같은 환경 사용
3. **재현성**: 언제 실행해도 같은 결과

### 언제 업데이트되나요?

- `terraform init` 실행 시
- Provider 버전 변경 시
- `terraform.lock.hcl`을 Git에 커밋하세요!

---

## 4. 언제 terraform init --reconfigure 해야 하나요?

`--reconfigure` 옵션은 **백엔드 설정을 강제로 다시 구성**할 때 사용합니다.

### 일반적인 terraform init

```bash
terraform init
```

### reconfigure가 필요한 상황

#### 상황 1: 백엔드 설정 변경

**문제**: `backend.tf` 파일을 수정했는데 적용되지 않음

```hcl
# backend.tf (변경 전)
terraform {
  backend "s3" {
    bucket = "old-bucket"
    key    = "terraform.tfstate"
  }
}

# backend.tf (변경 후)
terraform {
  backend "s3" {
    bucket = "new-bucket"
    key    = "terraform.tfstate"
  }
}
```

**해결**:
```bash
terraform init --reconfigure
```

#### 상황 2: 로컬에서 원격 백엔드로 전환

**문제**: 로컬 개발 중인데 S3 백엔드로 전환해야 함

```bash
# 로컬 상태에서 S3 백엔드로 전환
terraform init --reconfigure
```

#### 상황 3: 백엔드 인증 정보 변경

**문제**: AWS 자격증명 변경으로 백엔드 접근 실패

```bash
terraform init --reconfigure
```

### 주의사항

- **상태 파일 이동됨**: 기존 로컬 상태가 백엔드로 복사됨
- **팀 협업 시 주의**: 다른 사람이 동시에 실행하지 않도록
- **프로덕션에서는 신중히**: 상태 파일 손상 위험

---

## 5. 언제 terraform import 해야 하나요?

`terraform import`는 **이미 존재하는 인프라를 테라폼으로 가져올 때** 사용합니다.

### 기본 문법

```bash
terraform import [리소스 주소] [실제 리소스 ID]
```

### 상황별 예시

#### 상황 1: 실수로 콘솔에서 생성한 EC2

**문제**: AWS 콘솔에서 EC2를 만들었는데 테라폼 코드가 없음

```bash
# EC2 인스턴스 import
terraform import aws_instance.web i-1234567890abcdef0
```

**그 다음**:
```hcl
# main.tf에 코드 추가
resource "aws_instance" "web" {
  # import 후 terraform show로 설정 확인
  ami           = "ami-12345"
  instance_type = "t3.micro"
}
```

#### 상황 2: 기존 S3 버킷 가져오기

```bash
terraform import aws_s3_bucket.my_bucket my-existing-bucket-name
```

#### 상황 3: Route 53 호스팅 존

```bash
terraform import aws_route53_zone.primary Z123456789
```

### Import 절차

1. **실제 리소스 ID 확인**
   ```bash
   aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId'
   ```

2. **Import 실행**
   ```bash
   terraform import aws_instance.web i-12345
   ```

3. **코드 작성**
   ```bash
   terraform show  # 현재 설정 확인
   # main.tf에 resource 블록 추가
   ```

4. **Plan 실행**
   ```bash
   terraform plan  # 변경사항 없어야 함
   ```

### 주의사항

- **한 번에 하나씩**: 여러 리소스 동시 import 불가
- **코드 먼저 작성**: Import 후 코드 작성하는 것이 좋음
- **모듈 내 import**: 모듈 안의 리소스는 모듈 경로 포함

---

## 6. Drift(드리프트)란 무엇인가?

Drift는 **코드와 실제 인프라가 일치하지 않는 상태**를 의미합니다.

### 비유로 이해하기

```
코드 (설계도): 2층 집을 지으라고 했는데...
현실 (실제 집): 3층 집이 지어짐

→ 이것이 Drift!
```

### Drift 발생 원인

#### 1. 수동 변경

**문제**: 팀원이 AWS 콘솔에서 직접 EC2 타입 변경

```bash
# 코드에는 t3.micro
resource "aws_instance" "web" {
  instance_type = "t3.micro"
}

# 실제로는 t3.small로 변경됨 (콘솔에서)
```

#### 2. 자동 스케일링

**문제**: Auto Scaling Group이 인스턴스 추가

```hcl
resource "aws_autoscaling_group" "web" {
  desired_capacity = 2  # 코드상 2대
  # 실제로는 3대로 증가 (트래픽 증가로)
}
```

#### 3. 외부 시스템 변경

**문제**: 다른 팀이 Security Group 규칙 변경

### Drift 감지 방법

#### 방법 1: terraform plan 실행

```bash
terraform plan
```

**출력**:
```
Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform:

# aws_instance.web has been changed
~ resource "aws_instance" "web" {
  ~ instance_type = "t3.micro" -> "t3.small"  # ← Drift 감지!
  }
```

#### 방법 2: terraform refresh

```bash
terraform refresh  # 상태 파일 업데이트만 (변경 없음)
terraform plan     # 변경사항 확인
```

### Drift 해결 방법

#### 방법 1: 코드에 맞춰 인프라 변경 (권장)

```bash
# 코드에 맞춰 실제 인프라 변경
terraform apply
```

#### 방법 2: 인프라에 맞춰 코드 변경

```bash
# 실제 인프라 상태를 코드에 반영
terraform refresh
# main.tf 수정하여 실제 상태와 일치시킴
```

#### 방법 3: terraform state rm (극단적)

```bash
# 테라폼 관리에서 제외 (위험!)
terraform state rm aws_instance.web
```

### Drift 방지 팁

1. **콘솔 사용 금지**: 모든 변경을 코드로
2. **정기적 plan 실행**: `terraform plan`으로 모니터링
3. **팀 규칙 수립**: 수동 변경 시 즉시 코드 반영
4. **자동화**: CI/CD에서 plan 실행하여 drift 감지

---

## 7. 문제 해결 가이드

### 문제 1: "Backend configuration changed" 에러

**증상**:
```
Error: Backend configuration changed
```

**해결**:
```bash
terraform init --reconfigure
```

### 문제 2: "Resource already exists" 에러

**증상**:
```
Error: resource already exists in state
```

**해결**:
```bash
# 이미 존재하는 리소스 import
terraform import aws_instance.web i-12345
```

### 문제 3: "Provider version mismatch" 에러

**증상**:
```
Error: provider version mismatch
```

**해결**:
```bash
# lock 파일 재생성
rm terraform.lock.hcl
terraform init
```

### 문제 4: State 파일 충돌

**증상**:
```
Error: state lock is held by another process
```

**해결**:
```bash
# 다른 사람이 작업 중인지 확인
# 잠시 기다렸다가 다시 시도
terraform plan
```

### 문제 5: "No configuration files found" 에러

**증상**:
```
Error: No configuration files found
```

**해결**:
```bash
# .tf 파일이 있는 디렉토리인지 확인
ls *.tf
# 없으면 main.tf 생성
```

---

## 8. 왕초보자를 위한 팁

### 🎯 시작하기 전에

1. **AWS 계정 준비**
   ```bash
   # AWS CLI 설치 및 설정
   aws configure
   ```

2. **프로젝트 구조 이해**
   ```
   terraform/
   ├── main.tf          # 주요 리소스
   ├── variables.tf     # 변수 정의
   ├── outputs.tf       # 출력 값
   ├── terraform.tfvars # 변수 값
   └── backend.tf       # 상태 저장소
   ```

3. **첫 번째 실습**
   ```bash
   # 간단한 S3 버킷부터 시작
   resource "aws_s3_bucket" "example" {
     bucket = "my-first-terraform-bucket"
   }
   ```

### 🚨 절대 잊지 말 것

1. **항상 plan 먼저 실행**
   ```bash
   terraform plan  # 실행 전 필수!
   terraform apply # plan 확인 후 실행
   ```

2. **Git에 민감한 정보 넣지 말기**
   ```bash
   # .gitignore에 추가
   .terraform/
   terraform.tfstate*
   *.tfvars
   ```

3. **작은 단위부터 시작**
   ```
   큰 프로젝트 → 작은 모듈로 분리
   복잡한 코드 → 간단한 예제부터
   ```

### 📚 학습 로드맵

```
레벨 1: .terraform 폴더와 lock 파일 이해
    ↓
레벨 2: reconfigure와 import 마스터
    ↓
레벨 3: Drift 감지와 해결
    ↓
레벨 4: 문제 해결 능력 향상
    ↓
레벨 5: 팀 협업과 고급 기능
```

### 🆘 도움이 필요할 때

1. **공식 문서**: https://www.terraform.io/docs
2. **AWS Provider 문서**: https://registry.terraform.io/providers/hashicorp/aws
3. **커뮤니티**: Terraform Slack, Reddit r/Terraform
4. **실습**: https://learn.hashicorp.com/terraform

---

## 🎉 마무리

축하합니다! 테라폼의 핵심 개념을 모두 이해했습니다.

**기억할 것**:
- `.terraform`: 플러그인 저장소
- `terraform.lock.hcl`: 버전 잠금
- `--reconfigure`: 백엔드 설정 변경 시
- `import`: 기존 인프라 가져오기
- `drift`: 코드 vs 실제 불일치

**실천할 것**:
- 항상 plan 먼저 실행
- 코드를 Git에 커밋
- 팀원과 협업

이제 실제 프로젝트에서 테라폼을 사용해보세요. 처음은 어렵지만, 익숙해지면 인프라 관리가 훨씬 쉬워집니다!

**궁금한 점이 있으면 언제든 물어보세요!** 🚀

---

**작성일**: 2025-11-11
**버전**: 1.0
**대상**: 테라폼 왕초보