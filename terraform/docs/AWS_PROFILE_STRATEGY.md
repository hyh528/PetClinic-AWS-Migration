# AWS 프로파일 전략 및 해결 방안

## 🎯 목표
- **Dev 환경**: 영현님이 모든 레이어 확인 가능
- **보안**: 적절한 권한 분리 유지
- **효율성**: 개발 및 운영 편의성 향상

## 📋 현재 상황 분석

### 기존 설계 의도 (좋은 점)
```
각 팀원별 책임 분리:
├── Network (영현): petclinic-yeonghyeon
├── Security (휘권): petclinic-hwigwon  
├── Database (준제): petclinic-jungsu
└── Application (석겸): petclinic-seokgyeom
```

**장점**: 
- 명확한 책임 분리
- 보안 원칙 준수
- 팀원별 전문성 집중

### 현재 문제점
1. **크로스 레이어 의존성**: Application이 다른 레이어 상태 읽기 어려움
2. **통합 관리 어려움**: 영현님이 전체 확인 시 4개 프로파일 필요
3. **개발 효율성**: 로컬 테스트 시 프로파일 전환 번거로움

## 🚀 해결 방안

### 방안 1: Dev 환경 통합 프로파일 (권장)

#### 구조
```
환경별 프로파일 전략:
├── Dev: petclinic-dev-admin (통합 권한)
├── Staging: 개별 프로파일 유지
└── Prod: 엄격한 개별 프로파일
```

#### 구현 방법

**1. 통합 프로파일 생성**
```bash
# AWS CLI 프로파일 생성
aws configure --profile petclinic-dev-admin
```

**2. 환경 변수 기반 오버라이드**
```bash
# 영현님 사용 시
export AWS_PROFILE=petclinic-dev-admin

# 개별 팀원 사용 시 (기존 유지)
export AWS_PROFILE=petclinic-yeonghyeon
```

**3. Terraform 변수 수정**
```hcl
# 각 레이어의 variables.tf
variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
  default     = "petclinic-dev-admin"  # 기본값 변경
}

# 환경 변수로 오버라이드 가능
# TF_VAR_aws_profile=petclinic-yeonghyeon terraform plan
```

### 방안 2: 조건부 프로파일 설정

#### 구현
```hcl
# locals.tf
locals {
  # 환경 변수 또는 기본값 사용
  aws_profile = coalesce(
    var.override_aws_profile,
    var.aws_profile,
    "petclinic-dev-admin"
  )
}

# variables.tf
variable "override_aws_profile" {
  description = "프로파일 오버라이드 (선택사항)"
  type        = string
  default     = null
}
```

### 방안 3: 역할 기반 접근 (고급)

#### 개념
```
Base Profile → Assume Role → Layer-specific Role
petclinic-dev-admin → AssumeRole → petclinic-network-role
```

## 🛠️ 즉시 적용 가능한 해결책

### 1단계: 통합 프로파일 생성 (영현님)

```bash
# 1. 새 프로파일 생성
aws configure --profile petclinic-dev-admin

# 2. 기존 자격 증명 복사 (임시)
aws configure set aws_access_key_id $(aws configure get aws_access_key_id --profile default) --profile petclinic-dev-admin
aws configure set aws_secret_access_key $(aws configure get aws_secret_access_key --profile default) --profile petclinic-dev-admin
aws configure set region ap-northeast-2 --profile petclinic-dev-admin

# 3. 테스트
aws sts get-caller-identity --profile petclinic-dev-admin
```

### 2단계: 환경 변수 설정

```bash
# 영현님 전용 설정
export AWS_PROFILE=petclinic-dev-admin

# 또는 .bashrc/.zshrc에 추가
echo 'export AWS_PROFILE=petclinic-dev-admin' >> ~/.bashrc
```

### 3단계: Terraform 변수 업데이트

각 레이어의 기본 프로파일을 통합 프로파일로 변경:

```bash
# 자동 업데이트 스크립트
cd terraform/envs/dev

for layer in network security database application; do
    if [ -f "$layer/variables.tf" ]; then
        sed -i 's/default.*=.*"petclinic-[^"]*"/default = "petclinic-dev-admin"/' "$layer/variables.tf"
    fi
done
```

## 📊 권장 구현 계획

### Phase 1: 즉시 (오늘)
- [x] 통합 프로파일 생성
- [x] 환경 변수 설정
- [x] 기본 테스트

### Phase 2: 단기 (내일)
- [ ] 각 레이어 variables.tf 업데이트
- [ ] 팀원들에게 사용법 공유
- [ ] 문서 업데이트

### Phase 3: 중기 (이번 주)
- [ ] CI/CD 파이프라인 업데이트
- [ ] 모니터링 및 로깅 설정
- [ ] 보안 검토

## 🔒 보안 고려사항

### Dev 환경 통합 프로파일 권한
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "rds:*",
        "s3:*",
        "iam:*",
        "logs:*",
        "secretsmanager:*",
        "ssm:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-northeast-2"
        }
      }
    }
  ]
}
```

### 제한사항
- **리전 제한**: ap-northeast-2만 허용
- **태그 기반 제한**: Project=petclinic 리소스만
- **시간 제한**: 업무 시간만 허용 (선택사항)

## 🎯 최종 권장사항

**Dev 환경**: `petclinic-dev-admin` 통합 프로파일 사용
- 영현님: 모든 레이어 접근 가능
- 팀원들: 기존 개별 프로파일 또는 통합 프로파일 선택 사용
- 환경 변수로 유연한 전환 가능

**Staging/Prod 환경**: 개별 프로파일 유지
- 엄격한 권한 분리
- 승인 프로세스 필요
- 감사 로그 강화

이렇게 하면 **개발 효율성과 보안을 모두 만족**할 수 있습니다!