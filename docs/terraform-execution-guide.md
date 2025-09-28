# Terraform 실행 가이드 (Step by Step)

이 가이드는 spring-petclinic-microservices 프로젝트의 Terraform 코드를 안전하고 올바른 순서로 실행하는 방법을 설명합니다. 초보자도 따라할 수 있도록 각 단계마다 자세한 설명과 주의사항을 포함했습니다.

**중요**: 이 프로젝트는 팀 협업 방식으로 설계되어 각 레이어를 담당 팀원이 실행합니다.

## 사전 준비사항

### 1. Terraform 및 AWS CLI 설치 확인
```bash
# Terraform 버전 확인 (1.13.0 이상 필요)
terraform version

# AWS CLI 버전 확인
aws --version
```

### ⚠️ **중요: 팀별 AWS Credentials 설정**

이 프로젝트는 **실무 협업 방식**으로 각 팀원이 자신의 레이어를 담당합니다.

#### 팀별 담당 및 계정:
- **휘권이**: IAM 생성 (학생 계정) → Security (프로젝트 계정: `petclinic-hwigwon`)
- **영현이**: Bootstrap + Network (프로젝트 계정: `petclinic-yeonghyeon`)
- **준제**: Database (프로젝트 계정: `petclinic-junje`)
- **석겸이**: Application (프로젝트 계정: `petclinic-seokgyeom`)

#### AWS 프로필 설정 (각 팀원별):

**영현이 (프로젝트 계정)**:
```bash
# IAM 생성 후 프로젝트 계정 설정
aws configure --profile petclinic-yeonghyeon
# Access Key는 IAM 생성 후 휘권이로부터 공유받음
```

**휘권이 (프로젝트 계정)**:
```bash
# Security 단계에서 IAM 사용자 생성 후 설정
aws configure --profile petclinic-hwigwon
# Access Key는 Security 레이어 생성 후 AWS 콘솔에서 확인
```

**준제 (프로젝트 계정)**:
```bash
aws configure --profile petclinic-junje
# Access Key는 Security 레이어 생성 후 AWS 콘솔에서 확인
```

**석겸이 (프로젝트 계정)**:
```bash
aws configure --profile petclinic-seokgyeom
# Access Key는 Security 레이어 생성 후 AWS 콘솔에서 확인
```

#### 프로필 설정 확인:
```bash
# 각자 자신의 프로필로 확인
aws sts get-caller-identity --profile [자신의 프로필명]
```

### 2. 프로젝트 디렉토리 준비
```bash
# 프로젝트 루트로 이동
cd spring-petclinic-microservices/terraform

# 디렉토리 구조 확인
ls -la
# bootstrap/, envs/, modules/ 폴더 확인

# 각 환경별 폴더 구조 확인
ls -la envs/dev/
# network/, security/, application/ 폴더 확인
```

### 3. 프로젝트 구조 최종 확인
**참고**: 이 프로젝트는 모든 변수가 코드에 기본값으로 설정되어 있어 별도의 설정 파일이 필요하지 않습니다.

```bash
# 프로젝트 구조 최종 확인
find . -name "*.tf" -type f | head -10

# 실행 준비 상태 확인
terraform version
```

## 실행 순서 및 담당자별 가이드

### 📋 **실행 순서 개요** (실무 방식 - 최적화):
1. **휘권이**: IAM 생성 (학생 계정)
2. **영현이**: Bootstrap + Network (프로젝트 계정)
3. **휘권이**: Security (프로젝트 계정)
4. **준제**: Database (프로젝트 계정)
5. **석겸이**: Application (프로젝트 계정)

---

### 👤 **휘권이: 단계 1 (IAM 생성 전용)**
**사용 계정**: 학생 계정 (Administrator 권한)
**예상 시간**: 2-3분

#### 단계 1: IAM 사용자 생성 (프로젝트 계정 준비)
**목적**: 팀원별 프로젝트 IAM 계정 생성

##### 1-1. IAM 전용 실행 (학생 계정)
```bash
# Security 레이어에서 IAM 모듈만 실행
cd spring-petclinic-microservices/terraform/envs/dev/security

# IAM 모듈만 실행
terraform init
terraform plan -target=module.iam
terraform apply -target=module.iam
```

##### 1-2. IAM 사용자 생성 확인
```bash
# 생성된 IAM 사용자 확인
aws iam list-users --query 'Users[?starts_with(UserName, `petclinic`)].UserName'

# Access Key 생성 및 팀원들에게 공유
aws iam create-access-key --user-name petclinic-[팀원명]
```

##### 1-3. 각 팀원 프로젝트 계정 설정
```bash
# 휘권이
aws configure --profile petclinic-hwigwon

# 준제
aws configure --profile petclinic-junje

# 석겸이
aws configure --profile petclinic-seokgyeom

# 영현이 (선택사항)
aws configure --profile petclinic-yeonghyeon
```

---

### 👤 **영현이: 단계 2-3 (Bootstrap + Network)**
**사용 계정**: 프로젝트 계정 (`petclinic-yeonghyeon`)
**의존성**: IAM 생성 완료 필수
**예상 시간**: 8-13분

#### 단계 2: Bootstrap (백엔드 인프라 생성)
**목적**: Terraform 상태를 저장할 S3 버킷과 DynamoDB 테이블 생성
**왜 먼저?**: 다른 모든 Terraform 실행에서 이 백엔드를 사용하기 때문
**예상 시간**: 3-5분

#### 1-1. 디렉토리 이동 및 확인
```bash
# Bootstrap 디렉토리로 이동
cd spring-petclinic-microservices/terraform/bootstrap

# 현재 위치와 파일 확인
pwd
ls -la
```

#### 1-2. Terraform 초기화
```bash
# Provider 다운로드 및 로컬 백엔드 초기화
terraform init

# 성공 시 출력 예시:
# Terraform has been successfully initialized!
# ...
# Terraform Cloud has been successfully initialized!
```

#### 1-3. 실행 계획 확인 (필수!)
```bash
# 생성될 리소스 미리보기 (실제로는 생성하지 않음)
terraform plan

# 확인할 사항:
# - S3 버킷 생성 (petclinic-tfstate)
# - DynamoDB 테이블 생성 (petclinic-tf-locks)
# - IAM 정책 및 버전 관리 설정
# - 예상 비용 표시
```

#### 1-4. 리소스 생성 실행
```bash
# 계획을 확인한 후 실제 생성
terraform apply

# 확인 질문에 'yes' 입력
# Do you want to perform these actions? (yes/no): yes
```

#### 1-5. 생성 결과 확인
```bash
# 생성된 리소스 정보 출력
terraform output

# 출력 예시:
# tfstate_bucket_name = "petclinic-tfstate"
# tf_lock_table_name = "petclinic-tf-locks"
```

#### 1-6. AWS 콘솔에서 확인 (선택)
```bash
# S3 버킷 확인
aws s3 ls s3://petclinic-tfstate --profile petclinic-[이름]

# DynamoDB 테이블 확인
aws dynamodb describe-table --table-name petclinic-tf-locks --profile petclinic-[이름]
```

#### 1-7. 정리 (필요시)
```bash
# 모든 리소스 삭제 (주의: 다른 단계 진행 후에는 실행 금지!)
terraform destroy
```

#### 단계 3: Network Layer (네트워크 구성)
**목적**: VPC, 서브넷, 인터넷 게이트웨이, NAT 게이트웨이 생성
**의존성**: Bootstrap 완료 필수
**예상 시간**: 5-8분

#### 2-1. 디렉토리 이동 및 파일 확인
```bash
# Network 레이어로 이동
cd ../envs/dev/network

# 필수 파일들 확인
ls -la
# main.tf, providers.tf, variables.tf, outputs.tf

# 변수 기본값 확인 (variables.tf에 정의됨)
cat variables.tf | grep default
```

#### 2-2. 백엔드 초기화 (중요!)
```bash
# Bootstrap에서 생성한 S3/DynamoDB 백엔드로 전환
terraform init

# 성공 시 출력:
# Initializing the backend...
# Successfully configured the backend "s3"! Init complete!
```

#### 2-3. 실행 계획 검토
```bash
# 네트워크 리소스 생성 계획 확인
terraform plan

# 모든 변수가 variables.tf에서 기본값으로 설정되어 있어
# 별도의 설정 파일 없이 바로 실행 가능

# 확인할 주요 리소스들:
# + VPC (10.0.0.0/16)
# + 퍼블릭 서브넷 2개 (10.0.1.0/24, 10.0.2.0/24)
# + 프라이빗 앱 서브넷 2개 (10.0.3.0/24, 10.0.4.0/24)
# + 프라이빗 DB 서브넷 2개 (10.0.5.0/24, 10.0.6.0/24)
# + 인터넷 게이트웨이 (IGW)
# + NAT 게이트웨이 2개 (AZ당 1개)
# + 라우트 테이블 및 연결
```

#### 2-4. 네트워크 인프라 생성
```bash
# 계획 확인 후 실제 생성
terraform apply

# 진행 상황 모니터링:
# aws_vpc.this: Creating...
# aws_subnet.public[0]: Creating...
# aws_internet_gateway.this: Creating...
# ... (3-5분 소요)
```

#### 2-5. 생성 결과 검증
```bash
# 출력 값 확인 (다음 단계에서 사용)
terraform output

# 주요 출력 값들:
# vpc_id = "vpc-xxxxxxxx"
# public_subnet_ids = ["subnet-xxxx1", "subnet-xxxx2"]
# private_app_subnet_ids = ["subnet-xxxx3", "subnet-xxxx4"]
# private_db_subnet_ids = ["subnet-xxxx5", "subnet-xxxx6"]
```

#### 2-6. AWS 콘솔에서 확인
```bash
# VPC 생성 확인
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=petclinic-dev-vpc" --profile petclinic-[이름]

# 서브넷 확인
aws ec2 describe-subnets --filters "Name=vpc-id,Values=[vpc_id]" --profile petclinic-[이름]
```

#### 2-7. 상태 파일 백업 확인
```bash
# S3에 상태 파일이 저장되었는지 확인
aws s3 ls s3://petclinic-tfstate/dev/network/ --profile petclinic-[이름]
# terraform.tfstate 파일이 있어야 함
```

---

### 👤 **휘권이: 단계 3 (Security Layer)**
**사용 계정**: 프로젝트 계정 (`petclinic-hwigwon`)
**의존성**: IAM 생성 + Network Layer 완료 필수
**예상 시간**: 3-5분

#### 단계 3: Security Layer (보안 구성)
**목적**: IAM 역할, 보안 그룹, VPC 엔드포인트 생성

#### 3-1. 디렉토리 이동 및 확인
```bash
# Security 레이어로 이동
cd ../security

# 파일 구조 확인
ls -la
# main.tf, providers.tf

# Network 레이어의 출력 값 참조 확인
cat main.tf | grep data.terraform_remote_state
# Network 레이어의 VPC ID, 서브넷 ID들을 참조하는지 확인
```

#### 3-2. 백엔드 초기화
```bash
# Security 레이어용 S3 백엔드 초기화
terraform init

# 백엔드 구성 확인:
# bucket: petclinic-tfstate
# key: dev/security/terraform.tfstate
```

#### 3-3. 보안 리소스 계획 검토
```bash
# 보안 관련 리소스 생성 계획 확인
terraform plan

# 팀 멤버 정보와 설정이 코드에 하드코딩되어 있어
# 별도의 설정 파일 없이 바로 실행 가능

# 생성될 주요 리소스들:
# + IAM 사용자/그룹 (팀 멤버별 AdministratorAccess)
# + VPC 엔드포인트 (ECR, CloudWatch, X-Ray, Secrets Manager 등)
# + 보안 그룹 (ALB, ECS, RDS용)
# + 인터페이스 엔드포인트와 게이트웨이 엔드포인트
```

#### 3-4. 보안 인프라 생성
```bash
# 보안 리소스 생성 실행
terraform apply

# 생성 과정 모니터링:
# module.iam.aws_iam_user.team_member[0]: Creating...
# module.endpoints.aws_vpc_endpoint.interface["ecr"]: Creating...
# ... (2-3분 소요)
```

#### 3-5. 생성 결과 및 권한 확인
```bash
# IAM 사용자 생성 확인
aws iam list-users --query 'Users[?starts_with(UserName, `petclinic`)].UserName' --profile petclinic-[이름]

# VPC 엔드포인트 확인
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=[vpc_id]" --profile petclinic-[이름]

# 생성된 보안 그룹 확인
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=[vpc_id]" --profile petclinic-[이름]
```

#### 3-6. 팀 멤버 IAM 계정 설정
```bash
# 각 팀 멤버별로 AWS 콘솔 접근을 위한 초기 비밀번호 설정
aws iam create-login-profile --user-name petclinic-[팀원명] --password '[임시비밀번호]' --profile petclinic-[이름]

# 각 팀 멤버에게 AWS 계정 ID와 초기 비밀번호 공유
aws sts get-caller-identity --query Account --profile petclinic-[이름]

# 이제 생성된 IAM 프로필로 권한 확인 가능
aws sts get-caller-identity --profile petclinic-[팀원명]
```

---

### 👤 **준제: 단계 4 (Database Layer)**
**사용 계정**: 프로젝트 계정 (`petclinic-junje`)
**의존성**: Network + Security Layer 완료 필수
**예상 시간**: 5-8분

#### 단계 4: Database Layer (데이터베이스 구성)
**목적**: RDS MySQL 인스턴스 생성 및 구성

##### 4-1. 디렉토리 이동 및 확인
```bash
# Database 레이어로 이동
cd ../database

# 파일 구조 확인
ls -la
# main.tf, providers.tf, variables.tf, outputs.tf
```

##### 4-2. Database 백엔드 초기화
```bash
terraform init

# 백엔드 구성 확인:
# bucket: petclinic-tfstate-team-jungsu-kopo
# key: dev/junje/database/terraform.tfstate
```

##### 4-3. Database 생성 계획 검토
```bash
terraform plan

# 생성될 리소스들:
# + RDS MySQL 인스턴스
# + DB 서브넷 그룹
# + IAM 역할 (Enhanced Monitoring)
```

##### 4-4. Database 인프라 생성
```bash
terraform apply

# DB 비밀번호 입력 필요
# var.db_password: [데이터베이스 비밀번호 입력]
```

##### 4-5. Database 접속 정보 확인
```bash
terraform output

# 출력 값들:
# db_endpoint = "petclinic-dev-mysql.xxxx.ap-northeast-2.rds.amazonaws.com:3306"
# db_name = "petclinic"
```

---

### 👤 **석겸이: 단계 5 (Application Layer)**
**사용 계정**: 프로젝트 계정 (`petclinic-seokgyeom`)
**의존성**: Network + Security + Database Layer 완료 필수
**예상 시간**: 8-15분 (Docker 이미지 다운로드 포함)

#### 단계 5: Application Layer (애플리케이션 배포)
**목적**: ALB, ECS 클러스터, 서비스, 태스크 배포

#### 4-1. 디렉토리 이동 및 사전 확인
```bash
# Application 레이어로 이동
cd ../application

# 필수 파일들 확인
ls -la
# main.tf, providers.tf

# 이전 레이어들의 출력 값 참조 확인
cat main.tf | grep data.terraform_remote_state
# Network와 Security 레이어의 리소스들을 참조하는지 확인
```

#### 4-2. 애플리케이션 백엔드 초기화
```bash
# Application 레이어용 S3 백엔드 초기화
terraform init

# 백엔드 구성 확인:
# bucket: petclinic-tfstate
# key: dev/application/terraform.tfstate
```

#### 4-3. 애플리케이션 배포 계획 검토
```bash
# 전체 애플리케이션 스택 생성 계획 확인
terraform plan

# 모든 설정이 코드에 하드코딩되어 있어
# 별도의 설정 파일 없이 바로 실행 가능

# 생성될 주요 리소스들:
# + Application Load Balancer (ALB)
# + 대상 그룹 (Target Groups) - HTTP 8080
# + ECS 클러스터
# + ECS 태스크 정의 (Spring Boot 애플리케이션)
# + ECS 서비스 (원하는 태스크 수만큼)
# + CloudWatch 로그 그룹
# + ALB 리스너 (HTTP 80)
```

#### 4-4. 애플리케이션 인프라 생성
```bash
# 애플리케이션 배포 실행
terraform apply

# 배포 과정 모니터링 (시간이 오래 걸릴 수 있음):
# module.alb.aws_lb.this: Creating...
# module.alb.aws_lb_target_group.default: Creating...
# aws_ecs_cluster.this: Creating...
# aws_ecs_service.spring_petclinic: Creating...
# ... (8-15분 소요, Docker 이미지 pull 포함)
```

#### 4-5. 배포 상태 모니터링
```bash
# ECS 클러스터 상태 확인
aws ecs describe-clusters --cluster petclinic-dev-cluster --profile petclinic-[이름]

# ECS 서비스 상태 확인
aws ecs describe-services --cluster petclinic-dev-cluster --service spring-petclinic-service --profile petclinic-[이름]

# 실행 중인 태스크 확인
aws ecs list-tasks --cluster petclinic-dev-cluster --profile petclinic-[이름]
```

#### 4-6. 애플리케이션 접속 확인
```bash
# ALB DNS 이름 확인
terraform output alb_dns_name

# ALB 상태 확인
aws elbv2 describe-load-balancers --names petclinic-dev-alb --profile petclinic-[이름]

# 애플리케이션 접속 테스트
curl http://[alb_dns_name]
# 또는 브라우저에서 http://[alb_dns_name] 접속

# 성공 시 Spring Petclinic 애플리케이션 메인 페이지 표시
```

#### 4-7. 로그 및 모니터링 확인
```bash
# CloudWatch 로그 그룹 확인
aws logs describe-log-groups --log-group-name-prefix /ecs/spring-petclinic --profile petclinic-[이름]

# 최근 로그 확인
aws logs tail /ecs/spring-petclinic --follow --profile petclinic-[이름]
```

#### 4-8. 최종 검증
```bash
# 모든 리소스 상태 확인
terraform output

# 주요 출력 값들:
# alb_dns_name = "petclinic-dev-alb-xxxx.ap-northeast-2.elb.amazonaws.com"
# ecs_cluster_name = "petclinic-dev-cluster"
# ecs_service_name = "spring-petclinic-service"
```

---

## 🔧 문제 해결 가이드

### 초기화 실패 시
```bash
# 캐시 삭제 후 재시도
rm -rf .terraform
terraform init
```

### 계획 실패 시
```bash
# 변수 기본값 확인 (variables.tf에 정의됨)
cat variables.tf | grep default

# AWS 권한 확인
aws sts get-caller-identity --profile petclinic-[이름]
```

### 적용 실패 시
```bash
# 상태 잠금 해제 (주의해서 사용)
terraform force-unlock [LOCK_ID]

# 부분 적용된 리소스 정리
terraform apply -auto-approve
```

---

## 📊 상태 관리

### 상태 파일 위치
- S3 버킷: `petclinic-tfstate`
- 키 경로: `dev/[layer]/terraform.tfstate`

### 상태 확인
```bash
# 현재 상태 보기
terraform show

# 상태 파일 내용 보기
aws s3 cp s3://petclinic-tfstate/dev/network/terraform.tfstate - --profile petclinic-[이름]
```

---

## 🧹 정리 및 삭제

### 부분 삭제 (특정 레이어)
```bash
# 애플리케이션 레이어 삭제
cd envs/dev/application
terraform destroy

# 네트워크 레이어 삭제 (주의!)
cd ../network
terraform destroy
```

### 전체 삭제 순서
1. Application Layer 삭제
2. Security Layer 삭제
3. Network Layer 삭제
4. Bootstrap 삭제 (가장 마지막에)

**⚠️ 주의**: Bootstrap 삭제 시 모든 상태 파일이 사라지므로 매우 신중하게!

---

## 🎯 실행 체크리스트 (팀별 담당)

### **공통 준비사항**:
- [ ] AWS CLI 설치 및 버전 확인
- [ ] Terraform 1.13.0 이상 설치 및 버전 확인
- [ ] 프로젝트 디렉토리 구조 확인

### **휘권이 (학생 계정)**:
- [ ] **IAM 생성**: 팀 멤버별 프로젝트 계정 생성 (학생 계정 사용)
- [ ] 팀 멤버별 Access Key 생성 및 공유

### **영현이 (프로젝트 계정: petclinic-yeonghyeon)**:
- [ ] **Bootstrap**: S3/DynamoDB 백엔드 생성 완료
- [ ] **Network**: VPC, 서브넷, IGW, NAT 생성 완료

### **휘권이 (프로젝트 계정: petclinic-hwigwon)**:
- [ ] **Security**: 보안 그룹, VPC 엔드포인트 생성 완료

### **준제 (프로젝트 계정: petclinic-junje)**:
- [ ] **Database**: RDS MySQL 인스턴스 생성 완료
- [ ] Database 접속 정보 확인 (엔드포인트, 포트 등)

### **석겸이 (프로젝트 계정: petclinic-seokgyeom)**:
- [ ] **Application**: ALB, ECS 클러스터, 서비스 배포 완료
- [ ] ALB DNS로 애플리케이션 접속 확인
- [ ] CloudWatch 로그 및 모니터링 확인

## 💡 초보자를 위한 팁

1. **항상 `terraform plan` 먼저 실행**: 무엇이 생성/변경되는지 확인
2. **팀 커뮤니케이션**: 각 레이어 완료 시 팀원들에게 공유
3. **출력 값 저장**: 다음 레이어에서 참조해야 함
4. **프로필 확인**: 각자 자신의 AWS 프로필 사용
5. **에러 메시지 읽기**: AWS 권한이나 네트워크 문제일 수 있음
6. **천천히 진행**: 각 레이어 완료 확인 후 다음 담당자에게 전달
7. **문서화**: 변경사항은 기록해두세요

## 🎉 **실무 협업 완성!**

이제 각 팀원이 자신의 역할을 담당하여 **실무 방식으로 협업**할 수 있습니다!

### **실행 순서 (최적화 버전)**:
1. **휘권이**: IAM 생성 (학생 계정)
2. **영현이**: Bootstrap + Network (프로젝트 계정)
3. **휘권이**: Security (프로젝트 계정)
4. **준제**: Database (프로젝트 계정)
5. **석겸이**: Application (프로젝트 계정)

### **담당 역할**:
- **영현이**: 인프라 베이스 구축 👷‍♀️
- **휘권이**: IAM + 보안 관리 🔐
- **준제**: 데이터베이스 관리 🗄️
- **석겸이**: 애플리케이션 배포 🚀

이제 **혼란 없이 순차적으로 진행**할 수 있습니다! 🤝