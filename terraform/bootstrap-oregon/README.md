# Terraform Bootstrap (Oregon 리전) 🚀

## 목차
- [개요](#개요)
- [Terraform 상태 관리 기초 개념](#terraform-상태-관리-기초-개념)
- [왜 Bootstrap이 필요한가](#왜-bootstrap이-필요한가)
- [S3 네이티브 잠금 vs DynamoDB](#s3-네이티브-잠금-vs-dynamodb)
- [Bootstrap 구조](#bootstrap-구조)
- [배포 방법](#배포-방법)
- [상태 파일 관리](#상태-파일-관리)
- [문제 해결](#문제-해결)

---

## 개요

**Bootstrap**은 Terraform의 **상태 파일을 저장할 S3 버킷**을 생성하는 특별한 설정입니다.

### 이 폴더가 하는 일
- ✅ **S3 버킷 생성**: Terraform 상태 파일 저장소
- ✅ **버전 관리 활성화**: 상태 파일 변경 이력 보관
- ✅ **암호화 설정**: AES-256 자동 암호화
- ✅ **Public 접근 차단**: 보안 강화
- ✅ **S3 네이티브 잠금**: 동시 수정 방지 (DynamoDB 불필요!)

### Bootstrap의 역할
```
Bootstrap (이 폴더)
    ↓
    S3 버킷 생성 (terraform.tfstate 저장용)
    ↓
    ├─→ 01-network 레이어
    ├─→ 02-security 레이어
    ├─→ 03-database 레이어
    └─→ ... (모든 레이어)
        ↓
        각 레이어의 terraform.tfstate가 S3에 저장됨
```

---

## Terraform 상태 관리 기초 개념

### 1. Terraform 상태 파일이란? 📄

**terraform.tfstate**: Terraform이 **실제 인프라 상태**를 기록하는 JSON 파일

**예시**:
```json
{
  "version": 4,
  "terraform_version": "1.12.0",
  "resources": [
    {
      "type": "aws_vpc",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "vpc-0123456789abcdef0",
            "cidr_block": "10.0.0.0/16",
            "enable_dns_hostnames": true
          }
        }
      ]
    }
  ]
}
```

**왜 중요한가?**
```
Terraform 코드 (main.tf)
    ↓ terraform apply
Terraform 상태 (terraform.tfstate)
    ↓ 비교
실제 AWS 리소스
```

Terraform은 **상태 파일을 보고** 무엇을 생성/수정/삭제할지 결정합니다.

---

### 2. 로컬 상태 vs 원격 상태 🏠☁️

#### 로컬 상태 (기본)
```
terraform apply
    ↓
terraform.tfstate (로컬 파일에 저장)

문제점:
❌ 팀 협업 불가 (각자 다른 상태 파일)
❌ 상태 파일 유실 위험 (PC 고장, 실수로 삭제)
❌ 동시 수정 시 충돌
```

#### 원격 상태 (S3 Backend)
```
terraform apply
    ↓
terraform.tfstate (S3 버킷에 저장)

장점:
✅ 팀 전체가 동일한 상태 공유
✅ S3 버전 관리로 안전한 백업
✅ 잠금 기능으로 동시 수정 방지
```

---

### 3. State Locking (상태 잠금) 🔒

**문제 상황**:
```
시간    개발자 A             개발자 B
10:00   terraform apply     
10:01   VPC 생성 중...       terraform apply
10:02   VPC 생성 완료        VPC 생성 시도
10:03                        ❌ 에러! (VPC 이미 존재)
```

**해결: State Locking**
```
시간    개발자 A             개발자 B
10:00   terraform apply
        🔒 상태 잠금!
10:01   VPC 생성 중...       terraform apply
10:02   VPC 생성 완료        ⏳ 대기 중... (잠금 해제 대기)
10:03   🔓 잠금 해제!        terraform apply 시작
                             ✅ 정상 실행
```

---

### 4. 왜 S3인가? 🗄️

| 요구사항 | S3 | 로컬 파일 | Git |
|----------|-----|----------|-----|
| **팀 협업** | ✅ 공유 가능 | ❌ 개인 PC | ⚠️ 가능 (권장 안 함) |
| **버전 관리** | ✅ 자동 버전 관리 | ❌ 없음 | ✅ 있음 |
| **안정성** | ✅ 99.999999999% | ❌ PC 의존 | ⚠️ 실수로 커밋 가능 |
| **잠금 기능** | ✅ 네이티브 지원 | ❌ 없음 | ❌ 없음 |
| **암호화** | ✅ AES-256 자동 | ❌ 없음 | ⚠️ 수동 |
| **비용** | ✅ 저렴 ($0.023/GB) | ✅ 무료 | ✅ 무료 |

**결론**: S3가 **원격 상태 저장**에 최적!

---

## 왜 Bootstrap이 필요한가

### "닭이 먼저냐, 달걀이 먼저냐" 문제 🥚🐔

**문제**:
```
모든 Terraform 코드는 상태를 S3에 저장하려 함
    ↓
그런데 S3 버킷도 Terraform으로 만들어야 함
    ↓
그럼 S3 버킷의 상태는 어디에 저장?
    ↓
🤔 무한 루프!
```

**해결: Bootstrap**
```
1단계: Bootstrap (이 폴더)
   - 로컬 상태로 S3 버킷 생성 (한 번만!)
   - terraform.tfstate는 로컬에 저장

2단계: 다른 레이어들
   - 원격 상태 (S3)로 인프라 생성
   - terraform.tfstate는 S3에 저장
```

**비유**:
```
Bootstrap = 사다리
다른 레이어 = 2층 방들

사다리를 타고 2층으로 올라간 후,
사다리를 치우고 2층에서 생활
```

---

## S3 네이티브 잠금 vs DynamoDB

### 기존 방식: DynamoDB 잠금

**과거 아키텍처** (Terraform < 1.10.0):
```
Terraform 실행
    ↓
DynamoDB 테이블에 잠금 레코드 생성
    ↓
terraform.tfstate를 S3에 저장
    ↓
DynamoDB 잠금 해제

필요한 리소스:
- S3 버킷 (상태 저장)
- DynamoDB 테이블 (잠금 관리)
```

**문제점**:
```
❌ 2개 리소스 관리 필요 (S3 + DynamoDB)
❌ DynamoDB 비용 발생 ($0.25/월~)
❌ 복잡한 설정 (테이블 생성, 권한 설정)
```

---

### 새 방식: S3 네이티브 잠금 (권장!)

**현재 아키텍처** (Terraform >= 1.10.0):
```
Terraform 실행
    ↓
S3 버킷의 객체 버전 관리로 잠금
    ↓
terraform.tfstate를 S3에 저장 (잠금 포함)

필요한 리소스:
- S3 버킷 (상태 저장 + 잠금)
```

**장점**:
```
✅ 1개 리소스만 필요 (S3만)
✅ 추가 비용 없음 (버전 관리 무료)
✅ 간단한 설정
✅ 동일한 잠금 기능
```

---

### 동작 원리 비교

#### DynamoDB 잠금
```
1. terraform apply 실행
2. DynamoDB 테이블에 Lock ID 생성
   {
     "LockID": "petclinic-tfstate-oregon-dev/dev/01-network/terraform.tfstate-md5",
     "Info": "user:alice operation:apply"
   }
3. 다른 사용자 실행 시
   → DynamoDB 확인 → 잠금 발견 → 대기
4. terraform apply 완료
   → DynamoDB Lock ID 삭제
```

#### S3 네이티브 잠금
```
1. terraform apply 실행
2. S3 객체 메타데이터에 잠금 정보 기록
   x-amz-meta-terraform-lock: "user:alice operation:apply"
3. 다른 사용자 실행 시
   → S3 메타데이터 확인 → 잠금 발견 → 대기
4. terraform apply 완료
   → S3 잠금 메타데이터 삭제
```

**차이점**: S3 자체 기능 활용 → 별도 서비스 불필요!

---

### 우리 프로젝트 선택: S3 네이티브 잠금

**이유**:
1. **비용 절감**: DynamoDB 불필요 ($0.25/월 절약)
2. **단순화**: 관리할 리소스 1개 (S3만)
3. **충분한 기능**: 동시 수정 방지 완벽 동작
4. **Terraform 최신 기능**: 1.10.0+ 권장 방식

**설정 방법**:
```hcl
# backend.hcl (모든 레이어 공통)
bucket         = "petclinic-tfstate-oregon-dev"
key            = "dev/01-network/terraform.tfstate"  # 레이어별 경로
region         = "us-west-2"
encrypt        = true
use_lockfile   = true  # ✅ S3 네이티브 잠금 활성화!
```

---

## Bootstrap 구조

### 생성되는 리소스

```
┌──────────────────────────────────────────────────────────┐
│  S3 Bucket: petclinic-tfstate-oregon-dev                 │
│                                                          │
│  보안 설정:                                               │
│  ✅ Public Access 완전 차단                               │
│  ✅ HTTPS 전용 (HTTP 차단)                                │
│  ✅ 버전 관리 활성화                                       │
│  ✅ AES-256 암호화                                        │
│  ✅ S3 네이티브 잠금 (use_lockfile: true)                 │
│                                                          │
│  저장될 상태 파일:                                         │
│  /dev/01-network/terraform.tfstate                       │
│  /dev/02-security/terraform.tfstate                      │
│  /dev/03-database/terraform.tfstate                      │
│  /dev/04-parameter-store/terraform.tfstate               │
│  ... (모든 레이어)                                        │
│                                                          │
│  버전 관리:                                               │
│  /dev/01-network/terraform.tfstate (Version 1)           │
│  /dev/01-network/terraform.tfstate (Version 2)           │
│  /dev/01-network/terraform.tfstate (Version 3 - latest)  │
└──────────────────────────────────────────────────────────┘
```

---

### main.tf 구성 요소

#### 1. S3 버킷 생성
```hcl
resource "aws_s3_bucket" "tfstate" {
  bucket = "petclinic-tfstate-oregon-dev"
  force_destroy = true  # 삭제 시 모든 객체 자동 삭제
}
```

#### 2. Public 접근 차단 (보안 필수!)
```hcl
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  
  block_public_acls       = true  # 공개 ACL 차단
  block_public_policy     = true  # 공개 정책 차단
  ignore_public_acls      = true  # 기존 공개 ACL 무시
  restrict_public_buckets = true  # 버킷 공개 제한
}
```

**왜 필요?**
```
Terraform 상태 파일에는 민감한 정보 포함:
- 데이터베이스 비밀번호
- API 키
- AWS Access Key
- Private IP 주소
- 리소스 ID

→ 절대 Public 노출 금지!
```

#### 3. 버전 관리 활성화
```hcl
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

**효과**:
```
실수로 상태 파일 삭제/덮어쓰기
    ↓
이전 버전 복원 가능
    ↓
인프라 복구 성공!
```

#### 4. 암호화 설정
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # AWS 관리형 키
    }
  }
}
```

**암호화 방식**:
- **SSE-S3**: AWS 관리형 키 (무료)
- **SSE-KMS**: 고객 관리형 키 (비용 발생)

**우리 선택**: SSE-S3 (충분히 안전하고 무료)

#### 5. HTTPS 전용
```hcl
data "aws_iam_policy_document" "tfstate_deny_insecure_transport" {
  statement {
    effect  = "Deny"
    actions = ["s3:*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]  # HTTP 연결 시 거부
    }
  }
}
```

**효과**:
```
HTTP 연결 시도
    ↓
403 Forbidden
    ↓
HTTPS만 허용
```

---

## 배포 방법

### 사전 요구사항

1. **AWS CLI 설정**
```bash
aws configure --profile petclinic-dev
# AWS Access Key ID: ...
# AWS Secret Access Key: ...
# Default region: us-west-2
# Default output: json
```

2. **Terraform 설치** (>= 1.12.0)
```bash
terraform version
# Terraform v1.12.0
```

---

### Bootstrap 배포 순서

#### 1단계: 디렉토리 이동
```bash
cd terraform/bootstrap-oregon
```

#### 2단계: 변수 확인
```bash
cat variables.tf
```

**중요 변수**:
```hcl
variable "aws_region" {
  default = "us-west-2"  # Oregon 리전
}

variable "aws_profile" {
  default = "petclinic-dev"
}

variable "tfstate_bucket_name" {
  default = "petclinic-tfstate-oregon-dev"
  # ⚠️ 전 세계적으로 고유해야 함!
}
```

#### 3단계: Terraform 초기화
```bash
terraform init
```

**출력**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.x.x...

Terraform has been successfully initialized!
```

**주의**: 이 단계에서는 **로컬 상태 파일** 사용!
```
terraform.tfstate → 로컬 디렉토리에 생성
```

#### 4단계: 실행 계획 확인
```bash
terraform plan
```

**확인사항**:
```
Plan: 4 to add, 0 to change, 0 to destroy

Resources to be created:
+ aws_s3_bucket.tfstate
+ aws_s3_bucket_public_access_block.tfstate
+ aws_s3_bucket_versioning.tfstate
+ aws_s3_bucket_server_side_encryption_configuration.tfstate
+ aws_s3_bucket_policy.tfstate
```

#### 5단계: 배포 실행
```bash
terraform apply
```

**소요 시간**: 약 30초

**출력**:
```
aws_s3_bucket.tfstate: Creating...
aws_s3_bucket.tfstate: Creation complete after 5s [id=petclinic-tfstate-oregon-dev]
...
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
tfstate_bucket_name = "petclinic-tfstate-oregon-dev"
s3_native_locking_enabled = true
tfstate_bucket_arn = "arn:aws:s3:::petclinic-tfstate-oregon-dev"
```

#### 6단계: 배포 확인
```bash
# S3 버킷 확인
aws s3 ls s3://petclinic-tfstate-oregon-dev/

# 버킷 설정 확인
aws s3api get-bucket-versioning \
  --bucket petclinic-tfstate-oregon-dev

# 출력:
# {
#     "Status": "Enabled"
# }
```

---

### Bootstrap 완료 후 다음 단계

#### 1단계: 다른 레이어에서 S3 Backend 사용

**backend.hcl** (모든 레이어 공통):
```hcl
bucket         = "petclinic-tfstate-oregon-dev"
region         = "us-west-2"
encrypt        = true
use_lockfile   = true  # S3 네이티브 잠금
```

**각 레이어의 backend.config**:
```hcl
# 01-network/backend.config
key = "dev/01-network/terraform.tfstate"

# 02-security/backend.config
key = "dev/02-security/terraform.tfstate"

# 03-database/backend.config
key = "dev/03-database/terraform.tfstate"

# ... 레이어별 고유한 경로
```

#### 2단계: 레이어 초기화
```bash
cd ../layers/01-network
terraform init \
  -backend-config=../../backend.hcl \
  -backend-config=backend.config
```

**출력**:
```
Initializing the backend...

Successfully configured the backend "s3"!
You can now apply configurations.
```

**확인**:
```bash
# S3에 상태 파일 생성 확인
aws s3 ls s3://petclinic-tfstate-oregon-dev/dev/01-network/
# terraform.tfstate
```

---

## 상태 파일 관리

### 1. 상태 파일 구조

```
s3://petclinic-tfstate-oregon-dev/
├── dev/
│   ├── 01-network/
│   │   └── terraform.tfstate
│   ├── 02-security/
│   │   └── terraform.tfstate
│   ├── 03-database/
│   │   └── terraform.tfstate
│   ├── 04-parameter-store/
│   │   └── terraform.tfstate
│   ├── 05-cloud-map/
│   │   └── terraform.tfstate
│   ├── 06-lambda-genai/
│   │   └── terraform.tfstate
│   ├── 07-application/
│   │   └── terraform.tfstate
│   ├── 08-api-gateway/
│   │   └── terraform.tfstate
│   ├── 09-aws-native/
│   │   └── terraform.tfstate
│   ├── 10-monitoring/
│   │   └── terraform.tfstate
│   ├── 11-frontend/
│   │   └── terraform.tfstate
│   └── 12-notification/
│       └── terraform.tfstate
└── staging/  (미래 확장)
    └── ...
```

---

### 2. 상태 파일 버전 관리

```bash
# 특정 레이어의 상태 파일 버전 확인
aws s3api list-object-versions \
  --bucket petclinic-tfstate-oregon-dev \
  --prefix dev/01-network/terraform.tfstate

# 출력:
# {
#   "Versions": [
#     {
#       "Key": "dev/01-network/terraform.tfstate",
#       "VersionId": "abc123",
#       "IsLatest": true,
#       "LastModified": "2025-11-09T10:00:00Z"
#     },
#     {
#       "Key": "dev/01-network/terraform.tfstate",
#       "VersionId": "def456",
#       "IsLatest": false,
#       "LastModified": "2025-11-08T15:30:00Z"
#     }
#   ]
# }
```

---

### 3. 상태 파일 복원

**시나리오**: 실수로 인프라 삭제

```bash
# 1. 이전 버전 ID 확인
aws s3api list-object-versions \
  --bucket petclinic-tfstate-oregon-dev \
  --prefix dev/01-network/terraform.tfstate \
  --query 'Versions[1].VersionId' --output text
# def456

# 2. 이전 버전 다운로드
aws s3api get-object \
  --bucket petclinic-tfstate-oregon-dev \
  --key dev/01-network/terraform.tfstate \
  --version-id def456 \
  terraform.tfstate.backup

# 3. 현재 상태로 복원
aws s3 cp terraform.tfstate.backup \
  s3://petclinic-tfstate-oregon-dev/dev/01-network/terraform.tfstate

# 4. Terraform 재실행
terraform init
terraform apply
```

---

### 4. 상태 파일 잠금 확인

```bash
# 누가 terraform apply 실행 중인지 확인
aws s3api head-object \
  --bucket petclinic-tfstate-oregon-dev \
  --key dev/01-network/terraform.tfstate \
  --query 'Metadata'

# 잠금 중일 때 출력:
# {
#   "terraform-lock": "user:alice operation:apply timestamp:2025-11-09T10:00:00Z"
# }
```

---

## 문제 해결

### 문제 1: 버킷 이름 중복
```
Error: BucketAlreadyExists
```

**원인**: S3 버킷 이름은 **전 세계적으로 고유**해야 함

**해결**:
```bash
# variables.tf 수정
variable "tfstate_bucket_name" {
  default = "petclinic-tfstate-oregon-dev-20251109"  # 날짜 추가
}

# 또는
variable "tfstate_bucket_name" {
  default = "mycompany-petclinic-tfstate-oregon-dev"  # 회사명 추가
}
```

---

### 문제 2: 상태 파일 잠금 해제 안 됨
```
Error: state lock already held
```

**원인**: 이전 terraform 실행이 비정상 종료

**해결**:
```bash
# 강제 잠금 해제 (주의!)
terraform force-unlock <LOCK_ID>

# LOCK_ID는 에러 메시지에 표시됨
# 예: terraform force-unlock abc-123-def-456
```

**주의**: 다른 사람이 실행 중일 수 있으므로 확인 후 실행!

---

### 문제 3: 상태 파일 손상
```
Error: state snapshot was created by Terraform v1.11.0, which is newer than current v1.10.0
```

**원인**: Terraform 버전 불일치

**해결**:
```bash
# Terraform 버전 업그레이드
brew upgrade terraform  # macOS
# 또는
apt-get update && apt-get install terraform  # Linux

# 버전 확인
terraform version
```

---

### 문제 4: Bootstrap 삭제 방법
```
Bootstrap을 삭제하고 싶어요
```

**주의**: 모든 레이어 상태 파일이 삭제됨!

**안전한 삭제 순서**:
```bash
# 1. 모든 레이어 인프라 삭제
cd ../layers/12-notification && terraform destroy
cd ../layers/11-frontend && terraform destroy
... (역순으로 모든 레이어 삭제)

# 2. S3 버킷 비우기
aws s3 rm s3://petclinic-tfstate-oregon-dev/ --recursive

# 3. Bootstrap 삭제
cd ../../bootstrap-oregon
terraform destroy
```

---

### 디버깅 명령어

```bash
# S3 버킷 확인
aws s3 ls s3://petclinic-tfstate-oregon-dev/ --recursive

# 버킷 설정 확인
aws s3api get-bucket-versioning \
  --bucket petclinic-tfstate-oregon-dev

# 버킷 암호화 확인
aws s3api get-bucket-encryption \
  --bucket petclinic-tfstate-oregon-dev

# 버킷 Public Access 차단 확인
aws s3api get-public-access-block \
  --bucket petclinic-tfstate-oregon-dev

# 상태 파일 크기 확인
aws s3 ls s3://petclinic-tfstate-oregon-dev/ --recursive --summarize --human-readable
```

---

## 비용 예상

### S3 비용

| 항목 | 사양 | 월 비용 (USD) |
|------|------|---------------|
| **스토리지** | 1GB (상태 파일) | $0.023 |
| **GET 요청** | 10,000개 | $0.004 |
| **PUT 요청** | 1,000개 | $0.005 |
| **버전 관리** | 10개 버전 × 1GB | $0.23 |
| **합계** | - | **$0.26/월** |

**실제 비용**: 대부분 **$1 미만/월** (상태 파일은 매우 작음)

---

## 베스트 프랙티스

### 1. Bootstrap은 한 번만 실행 ⚠️
```
Bootstrap → S3 버킷 생성 (한 번만!)
    ↓
이후로는 절대 수정/삭제 금지
```

### 2. 버킷 이름 규칙 📝
```
<프로젝트>-tfstate-<리전>-<환경>

예시:
- petclinic-tfstate-oregon-dev
- petclinic-tfstate-oregon-staging
- petclinic-tfstate-oregon-prod
```

### 3. 환경별 버킷 분리 🗂️
```
개발: petclinic-tfstate-oregon-dev
스테이징: petclinic-tfstate-oregon-staging
프로덕션: petclinic-tfstate-oregon-prod

→ 환경 간 격리
```

### 4. 백업 전략 💾
```
- S3 버전 관리: 30일 보관
- S3 Lifecycle: 90일 후 Glacier로 이동
- 수동 백업: 주요 변경 전 스냅샷
```

### 5. 접근 권한 제한 🔒
```
IAM 정책:
- 개발자: Read-Only (상태 파일 조회만)
- DevOps: Read-Write (상태 파일 수정 가능)
- CI/CD: Read-Write (자동 배포용)
```

---

## 요약

### 핵심 개념 정리
- ✅ **Bootstrap**: Terraform 상태 파일 저장용 S3 버킷 생성
- ✅ **원격 상태**: 팀 협업, 안전한 백업
- ✅ **S3 네이티브 잠금**: DynamoDB 불필요, 비용 절감
- ✅ **버전 관리**: 상태 파일 복원 가능
- ✅ **보안**: Public 차단, HTTPS 전용, 암호화

### 생성되는 리소스
- S3 버킷 1개 (petclinic-tfstate-oregon-dev)
- Public Access Block
- Versioning Configuration
- Encryption Configuration
- Bucket Policy (HTTPS 전용)

### S3 네이티브 잠금 사용 이유
```
✅ DynamoDB 불필요 → 관리 단순화
✅ 추가 비용 없음 → $0.25/월 절감
✅ Terraform 1.10.0+ 권장 방식
✅ 동일한 잠금 기능 제공
```

### 배포 순서
```bash
# 1. Bootstrap (한 번만!)
cd terraform/bootstrap-oregon
terraform init
terraform apply

# 2. 레이어들 (S3 Backend 사용)
cd ../layers/01-network
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform apply
# ... 다른 레이어들
```

---

**작성일**: 2025-11-09  
**작성자**: DevOps Team  
**버전**: 1.0
