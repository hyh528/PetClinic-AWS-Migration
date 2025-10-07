# Terraform Security Layer 배포 오류 해결 가이드

## 개요

이 문서는 PetClinic AWS 마이그레이션 프로젝트에서 Terraform Security Layer를 배포하는 과정에서 발생한 오류들과 해결 방법을 정리한 것입니다.

## 발생한 오류 목록

### 1. Terraform Init 단계 오류

#### 1.1 Cognito 모듈 디렉토리 오류

**오류 메시지:**
```
Error: Unreadable module directory
Unable to evaluate directory symlink: CreateFile ..\..\..\modules\cognito\modules: The system cannot find the file specified.

Error: Unreadable module directory
The directory  could not be read for module "cognito_dev" at ..\..\..\modules\cognito\example-usage.tf:5.
```

**원인:**
- `terraform/modules/cognito/example-usage.tf` 파일에서 잘못된 모듈 경로를 참조
- 예시 파일이 실제 terraform init 과정에서 모듈로 인식되어 오류 발생

**해결 방법:**
```bash
# cognito 모듈 디렉토리에서 example-usage.tf 파일을 백업으로 이름 변경
cd terraform/modules/cognito
mv example-usage.tf example-usage.tf.bak
```

**예방 방법:**
- 모듈 디렉토리에는 실제 모듈 파일만 포함 (main.tf, variables.tf, outputs.tf)
- 예시 파일은 별도 examples 디렉토리에 보관하거나 .tf.example 확장자 사용

---

### 2. Terraform Plan 단계 오류

#### 2.1 AWS 프로필 인식 오류

**오류 메시지:**
```
Error: failed to get shared config profile, dev-admin
```

**원인:**
- 지정한 AWS 프로필이 존재하지 않음
- 실제 프로필명과 다름

**해결 방법:**
```bash
# 사용 가능한 AWS 프로필 확인
aws configure list-profiles

# 올바른 프로필명 사용 (petclinic-dev-admin)
terraform plan -var-file="dev.tfvars" -var="aws_profile=petclinic-dev-admin" -var="network_state_profile=petclinic-dev-admin"
```

#### 2.2 Cognito 메시지 템플릿 오류

**오류 메시지:**
```
Error: "admin_create_user_config.0.invite_message_template.0.email_message" does not contain {####}
Error: "admin_create_user_config.0.invite_message_template.0.email_message" does not contain {username}
Error: "admin_create_user_config.0.invite_message_template.0.sms_message" does not contain {####}
Error: "admin_create_user_config.0.invite_message_template.0.sms_message" does not contain {username}
```

**원인:**
- Cognito 사용자 초대 메시지 템플릿에서 필수 플레이스홀더 누락
- AWS Cognito는 `{username}`과 `{####}` 플레이스홀더를 필수로 요구

**해결 방법:**
```hcl
# terraform/modules/cognito/main.tf 수정
invite_message_template {
  email_message = "안녕하세요 {username}님! PetClinic에 오신 것을 환영합니다. 임시 비밀번호: {####}"
  email_subject = "PetClinic 계정 생성"
  sms_message   = "{username}님, PetClinic 임시 비밀번호: {####}"
}
```

---

### 3. Terraform Apply 단계 오류

#### 3.1 IAM 사용자 중복 생성 오류

**오류 메시지:**
```
Error: creating IAM User (petclinic-junje): operation error IAM: CreateUser, https response error StatusCode: 409, RequestID: d3144575-ca27-4b68-9585-7b3ed5c90428, EntityAlreadyExists: User with name petclinic-junje already exists.
Error: creating IAM User (petclinic-yeonghyeon): operation error IAM: CreateUser, https response error StatusCode: 409, RequestID: 784b38c6-5d2e-40d1-9603-fc4dd3548f8b, EntityAlreadyExists: User with name petclinic-yeonghyeon already exists.
Error: creating IAM User (petclinic-hwigwon): operation error IAM: CreateUser, https response error StatusCode: 409, RequestID: 7a5f79cb-5b1a-4415-b9c5-89899851f392, EntityAlreadyExists: User with name petclinic-hwigwon already exists.
Error: creating IAM User (petclinic-seokgyeom): operation error IAM: CreateUser, https response error StatusCode: 409, RequestID: 635083d6-0856-4164-b55d-2617ee13af1d, EntityAlreadyExists: User with name petclinic-seokgyeom already exists.
```

**원인:**
- 이미 생성된 IAM 사용자들을 다시 생성하려고 시도
- Terraform state에 기존 리소스가 관리되지 않음

**해결 방법 (옵션 1 - 임시 주석 처리):**
```hcl
# terraform/envs/dev/security/main.tf에서 IAM 모듈 주석 처리
# module "iam" {
#   source = "../../../modules/iam"
#   project_name = "petclinic"
#   team_members = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
# }
```

**해결 방법 (옵션 2 - Terraform Import):**
```bash
# 기존 IAM 사용자들을 Terraform state로 import
terraform import 'module.iam.aws_iam_user.members["yeonghyeon"]' petclinic-yeonghyeon
terraform import 'module.iam.aws_iam_user.members["seokgyeom"]' petclinic-seokgyeom
terraform import 'module.iam.aws_iam_user.members["junje"]' petclinic-junje
terraform import 'module.iam.aws_iam_user.members["hwigwon"]' petclinic-hwigwon
```

#### 3.2 Cognito MFA 설정 오류

**오류 메시지:**
```
Error: setting Cognito User Pool (ap-northeast-2_CgcVrLqbS) MFA configuration: operation error Cognito Identity Provider: SetUserPoolMfaConfig, https response error StatusCode: 400, RequestID: 02ad33e6-0039-4643-940d-512750aef5dd, InvalidParameterException: Invalid MFA configuration given, can't disable all MFAs with a required or optional configuration.
```

**원인:**
- MFA 설정이 "OPTIONAL"로 되어 있지만 실제 MFA 방법이 구성되지 않음
- Cognito에서 MFA를 활성화하려면 SMS나 TOTP 등의 방법이 설정되어야 함

**해결 방법:**
```hcl
# terraform/modules/cognito/main.tf 수정
# MFA 설정을 OFF로 변경
mfa_configuration = "OFF"
```

#### 3.3 IPv6 CIDR 블록 오류

**오류 메시지:**
```
Error: creating EC2 Network ACL (acl-051f4f5d0a7319418) Rule (egress: true)(110): operation error EC2: CreateNetworkAclEntry, https response error StatusCode: 400, RequestID: 8dc6e719-b677-47ec-8dc6-83936ab256d2, api error InvalidParameterValue: Value (::/0) for parameter cidrBlock is invalid. This is not a valid CIDR block.
```

**원인:**
- VPC에는 IPv6가 활성화되어 있지만, NACL 규칙에서 IPv6 CIDR 블록을 잘못된 속성에 설정
- `aws_network_acl_rule` 리소스에서 IPv6 주소는 `cidr_block` 대신 `ipv6_cidr_block` 속성을 사용해야 함
- `::/0`을 `cidr_block`에 넣으면 "This is not a valid CIDR block" 오류 발생

**실제 VPC 상태 확인:**
```bash
# VPC에 IPv6가 실제로 활성화되어 있는지 확인
cd terraform/envs/dev/network
terraform output
# 출력: vpc_ipv6_cidr = "2406:da12:a67:9500::/56" (IPv6 활성화됨)
```

**해결 방법 (옵션 1 - IPv6 규칙 올바르게 수정):**
```hcl
# terraform/modules/nacl/main.tf에서 IPv6 규칙을 올바르게 수정
resource "aws_network_acl_rule" "egress" {
  for_each = local.current_nacl_rules.egress

  network_acl_id = aws_network_acl.this.id
  rule_number    = each.value.rule_no
  egress         = true
  rule_action    = each.value.action
  protocol       = each.value.protocol
  
  # IPv4와 IPv6를 구분하여 처리
  cidr_block      = can(regex(":", each.value.cidr_block)) ? null : each.value.cidr_block
  ipv6_cidr_block = can(regex(":", each.value.cidr_block)) ? each.value.cidr_block : null
  
  from_port = each.value.from_port
  to_port   = each.value.to_port
}
```

**해결 방법 (옵션 2 - IPv6 규칙 제거):**
```hcl
# terraform/modules/nacl/main.tf에서 IPv6 규칙 완전 제거
private_db_egress_rules = {
  "vpc_internal_response" = {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = var.vpc_cidr
    from_port  = 32768
    to_port    = 65535
  }
  # IPv6 규칙 제거 (이미 제거됨)
}
```

#### 3.4 Secrets Manager 시크릿 삭제 예정 오류

**오류 메시지:**
```
Error: creating Secrets Manager Secret (petclinic/dev/db-password): operation error Secrets Manager: CreateSecret, https response error StatusCode: 400, RequestID: 13da7117-8245-4a77-b73f-74c0582ba3cc, InvalidRequestException: You can't create this secret because a secret with this name is already scheduled for deletion.
```

**원인:**
- 동일한 이름의 시크릿이 이미 존재하고 삭제 예정 상태
- Secrets Manager는 삭제 예정 기간(기본 30일) 동안 같은 이름 사용 불가

**해결 방법 (옵션 1 - 이름 변경):**
```hcl
# terraform/envs/dev/security/main.tf 수정
module "db_password_secret" {
  source = "../../../modules/secrets-manager"
  secret_name = "${var.name_prefix}/dev/db-password-v2"  # 이름 변경
  # ... 기타 설정
}
```

**해결 방법 (옵션 2 - 기존 시크릿 복구):**
```bash
# AWS CLI로 기존 시크릿 복구
aws secretsmanager restore-secret --secret-id "petclinic/dev/db-password"
```

---

## 권장 해결 순서

### 1단계: 모듈 파일 정리
```bash
# 예시 파일 백업
cd terraform/modules/cognito
mv example-usage.tf example-usage.tf.bak
```

### 2단계: 코드 수정
```bash
# Cognito MFA 설정 수정
# NACL IPv6 규칙 제거
# Secrets Manager 이름 변경
# IAM 모듈 임시 주석 처리
```

### 3단계: Terraform 실행
```bash
cd terraform/envs/dev/security
terraform init
terraform plan -var-file="dev.tfvars" -var="aws_profile=petclinic-dev-admin" -var="network_state_profile=petclinic-dev-admin"
terraform apply -var-file="dev.tfvars" -var="aws_profile=petclinic-dev-admin" -var="network_state_profile=petclinic-dev-admin" -auto-approve
```

---

## 예방 방법

### 1. 모듈 구조 관리
- 모듈 디렉토리에는 실제 Terraform 파일만 포함
- 예시 파일은 별도 디렉토리나 다른 확장자 사용

### 2. 리소스 상태 관리
- 기존 리소스는 `terraform import`로 상태 관리에 포함
- 또는 `terraform state` 명령어로 상태 확인 후 처리

### 3. 환경별 설정 분리
- 개발/운영 환경별로 다른 설정 값 사용
- MFA, 보안 설정 등은 환경에 맞게 조정

### 4. 네트워크 설정 확인
- IPv6 사용 전 VPC에서 IPv6 활성화 확인
- CIDR 블록 설정 시 네트워크 구성과 일치하는지 검증

### 5. AWS 서비스 제약사항 확인
- Secrets Manager 삭제 정책 (30일 대기 기간)
- Cognito MFA 설정 요구사항
- IAM 사용자 이름 중복 제약

---

## 참고 자료

- [AWS Cognito User Pool 설정 가이드](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings.html)
- [Terraform AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Secrets Manager 삭제 정책](https://docs.aws.amazon.com/secretsmanager/latest/userguide/managing-secrets_versioning.html)
- [Terraform Import 가이드](https://www.terraform.io/docs/import/index.html)

---

**작성일:** 2025-01-05  
**작성자:** Kiro AI Assistant  
**프로젝트:** PetClinic AWS Migration  
**레이어:** Security Layer