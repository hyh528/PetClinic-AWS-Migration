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

### **실행 순서 개요** (실무 방식 - 최적화):
1. **휘권이**: IAM 생성 (학생 계정)
2. **영현이**: Bootstrap + Network (프로젝트 계정)
3. **휘권이**: Security (프로젝트 계정)
4. **준제**: Database (프로젝트 계정)
5. **석겸이**: Application (프로젝트 계정)

---

### **휘권이: 단계 1 (IAM 생성 전용)**
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

### **영현이: 단계 2-3 (Bootstrap + Network)**
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
# tfstate_bucket_name = "petclinic-tfstate-jungsu-kopo"
# tf_lock_table_name = "petclinic-tf-locks-jungsu-kopo"
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
terraform plan -var-file=dev.tfvars

# dev.tfvars 파일에 AWS 프로필 정보가 설정되어 있어
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
terraform apply -var-file=dev.tfvars

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

### **휘권이: 단계 3 (Security Layer)**
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
terraform plan -var-file=dev.tfvars

# dev.tfvars 파일에 AWS 프로필 정보가 설정되어 있어
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
terraform apply -var-file=dev.tfvars

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

### **준제: 단계 4 (Database Layer)**
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
terraform plan -var-file=dev.tfvars

# 생성될 리소스들:
# + RDS MySQL 인스턴스
# + DB 서브넷 그룹
# + IAM 역할 (Enhanced Monitoring)
```

##### 4-4. Database 인프라 생성
```bash
terraform apply -var-file=dev.tfvars

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

### **석겸이: 단계 5 (Application Layer)**
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
# main.tf, providers.tf, dev.tfvars

# 변수 파일 확인
cat dev.tfvars
# 각 팀원의 AWS 프로필이 설정되어 있는지 확인

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
# 애플리케이션 배포 계획 검토
terraform plan -var-file=dev.tfvars

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
terraform apply -var-file=dev.tfvars

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

## **레이어 아키텍처 상세 설명 (Layer Architecture Deep Dive)**

### **레이어 구조란 무엇인가?**

**비유로 이해하기:**
집을 짓는다고 생각해보세요:
- **기초 (Network)**: 땅 다지기, 기둥 세우기
- **벽과 문 (Security)**: 담장 쌓기, 문단속하기
- **배관과 전기 (Database)**: 수도관, 전선 설치
- **인테리어 (Application)**: 가구 배치, 집 꾸미기

**왜 레이어로 나누나요?**
- **독립성**: 각자 자신의 일을 할 수 있음
- **안전성**: 한 사람이 실수해도 다른 부분 영향 적음
- **효율성**: 동시에 여러 작업 가능
- **재사용성**: 다른 프로젝트에서도 같은 구조 사용 가능

---

### **각 레이어 상세 설명**

#### **1️⃣ Bootstrap 레이어 (선행 준비)**
**담당자**: 영현이
**목적**: Terraform 협업을 위한 기반 인프라 생성
**생성하는 것**:
- S3 버킷: 상태 파일 저장소
- DynamoDB 테이블: 작업 잠금

**특징**: 다른 모든 작업의 **기초**
```
bootstrap/
├── main.tf      # S3 + DynamoDB 생성
└── providers.tf # 로컬 백엔드 사용
```

---

#### **2️⃣ Network 레이어 (기반 네트워크)**
**담당자**: 영현이
**목적**: AWS 네트워크 기반 구축
**생성하는 것**:
- VPC (Virtual Private Cloud)
- 서브넷 (Public 2개 + Private App 2개 + Private DB 2개)
- 인터넷 게이트웨이 (IGW)
- NAT 게이트웨이 (AZ당 1개)
- 라우트 테이블

**출력값** (다른 레이어에서 사용):
- `vpc_id`, `vpc_cidr`
- `public_subnet_ids`, `private_app_subnet_ids`, `private_db_subnet_ids`
- `route_table_ids` 등

```
envs/dev/network/
├── main.tf      # VPC 모듈 사용
├── providers.tf # S3 백엔드 + dev 태그
├── variables.tf # 네트워크 설정값들
└── outputs.tf   # 다른 레이어 공유용 ✅
```

---

#### **3️⃣ Security 레이어 (보안 및 IAM)**
**담당자**: 휘권이
**목적**: 팀 접근 관리 및 네트워크 보안
**생성하는 것**:
- IAM 사용자/그룹 (팀원별 계정)
- VPC 엔드포인트 (ECR, CloudWatch 등)
- 보안 그룹 (ALB, ECS, RDS용)

**참조하는 것**:
- Network 레이어의 VPC ID, 서브넷 ID들

```
envs/dev/security/
├── main.tf      # IAM, Endpoints, Security 모듈 사용
└── providers.tf # S3 백엔드 + dev 태그
# outputs.tf 없음 (최종 레이어 아님) ❌
```

---

#### **4️⃣ Database 레이어 (데이터 저장소)**
**담당자**: 준제
**목적**: 애플리케이션 데이터 저장
**생성하는 것**:
- RDS MySQL 인스턴스
- DB 서브넷 그룹
- DB 보안 그룹

**참조하는 것**:
- Network 레이어의 VPC ID, DB 서브넷 ID들
- Security 레이어의 보안 그룹

**출력값**:
- `db_endpoint`, `db_name`

```
envs/dev/database/
├── main.tf      # RDS 모듈 사용
├── providers.tf # S3 백엔드 + dev 태그
├── variables.tf # DB 설정
└── outputs.tf   # Application 공유용 ✅
```

---

#### **5️⃣ Application 레이어 (실제 서비스)**
**담당자**: 석겸이
**목적**: 최종 사용자 서비스 배포
**생성하는 것**:
- Application Load Balancer (ALB)
- ECS 클러스터, 서비스, 태스크
- CloudWatch 로그 그룹

**참조하는 것**:
- Network 레이어의 VPC ID, 서브넷 ID들
- Database 레이어의 DB 엔드포인트

```
envs/dev/application/
├── main.tf      # ALB, ECS 모듈 사용
└── providers.tf # S3 백엔드 + dev 태그
# outputs.tf 없음 (최종 레이어) ❌
```

---

### 🔄 **레이어 간 의존성 (Dependencies)**

```
Bootstrap
    ↓
Network ←─────────────┐
    ↓                 │
Security ─────────────┼─→ Database
    ↓                 │      ↓
    └─────────────────┴─→ Application
```

**읽는 방법:**
- Network는 Bootstrap에 의존
- Security는 Network에 의존
- Database는 Network와 Security에 의존
- Application은 Network와 Database에 의존

---

### 👥 **팀별 담당과 실행 순서**

| 순서 | 레이어 | 담당자 | 의존성 | 예상시간 |
|------|--------|--------|--------|----------|
| 1 | Bootstrap | 영현이 | 없음 | 3-5분 |
| 2 | Network | 영현이 | Bootstrap | 5-8분 |
| 3 | Security | 휘권이 | Network | 3-5분 |
| 4 | Database | 준제 | Network + Security | 5-8분 |
| 5 | Application | 석겸이 | Network + Database | 8-15분 |

**팁:**
- 각 레이어 완료 시 Teams으로 알림
- 다음 담당자가 바로 시작할 수 있도록 준비

---

### 📡 **레이어 간 통신 방법**

#### **방법 1: Remote State (주요 방법)**
```hcl
# Database 레이어에서 Network 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/yeonghyeon/network/terraform.tfstate"
  }
}

# Network의 출력값 사용
resource "aws_db_subnet_group" "this" {
  subnet_ids = values(data.terraform_remote_state.network.outputs.private_db_subnet_ids)
}
```

#### **방법 2: Module Output (같은 레이어 내)**
```hcl
# Security 레이어 내에서
module "iam" {
  source = "../../../modules/iam"
}

module "endpoints" {
  source = "../../../modules/endpoints"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  # IAM 모듈의 출력값도 같은 레이어에서 사용 가능
}
```

---

### **레이어 구조의 장점**

#### **1. 팀 협업 효율성**
- 각자 자신의 전문 영역 담당
- 동시에 작업 가능
- 코드 충돌 최소화

#### **2. 안전성과 안정성**
- 한 레이어 문제해도 다른 레이어 영향 적음
- 단계별 검증 가능
- 롤백이 쉬움

#### **3. 확장성과 재사용성**
- 새로운 환경(dev, staging, prod) 쉽게 추가
- 다른 프로젝트에 동일 구조 적용 가능
- 모듈화로 코드 재사용

#### **4. 비용 관리**
- 필요한 리소스만 생성
- 단계별 비용 추적 가능

---

### 🚨 **주의사항과 베스트 프랙티스**

#### **실행 순서 엄수**
```
❌ 잘못된 예: Database 먼저 실행 → Network 없어서 실패
✅ 올바른 예: Network → Security → Database → Application
```

#### **상태 파일 관리**
- 절대 수동으로 편집 금지
- `terraform.tfstate` 파일은 S3에 자동 저장
- 동시에 같은 레이어 작업 금지 (DynamoDB 잠금)

#### **커뮤니케이션**
- 레이어 완료 시 바로 다음 담당자에게 알림
- 문제가 생기면 즉시 공유
- 코드 변경 시 팀원들과 사전 협의

#### **태그 일관성**
모든 리소스에 동일 태그 적용:
```hcl
tags = {
  Project     = "petclinic"
  Environment = "dev"
  Layer       = "network"  # 각 레이어에 맞게
  ManagedBy   = "terraform"
  Owner       = "team-petclinic"
  CostCenter  = "training"
}
```

---

### **성공 사례**

이 레이어 구조로 여러분의 팀은:
- **혼란 없는 협업** 가능
- **실무 수준의 인프라** 구축
- **안전한 배포** 경험
- **재사용 가능한 코드** 확보

이제 각자 자신의 레이어를 책임지고 완성해봅시다! 🤝

## 협업 모범 사례 (Collaboration Best Practices)

### 모듈 관리 전략
**중요**: Terraform 모듈은 **로컬 저장소에 유지**하는 것을 권장합니다.

#### ✅ 권장 방식: 로컬 모듈 (현재 설정)
- 모듈 코드를 `terraform/modules/` 디렉토리에 저장
- Git을 통한 버전 관리 및 협업
- 상대 경로로 참조: `../../../modules/vpc`
- 장점: 간단하고, 버전 관리가 쉽고, 팀 협업에 최적화

#### ❌ 비권장: S3에 모듈 업로드
- S3 버킷에 모듈을 ZIP 파일로 업로드하는 것은 **불필요**
- 복잡성 증가, 버전 관리 어려움
- 협업 시 추가적인 조율 필요

#### 모듈 vs 상태 파일
- **상태 파일 (.tfstate)**: S3 + DynamoDB에 원격 저장 (협업 필수)
- **모듈 코드**: 로컬 Git 저장소에 유지 (협업 용이)

### 상태 파일 접근 및 협업 방식
**팀원이 자신의 레이어를 작업할 때:**

1. **자동 다운로드**: `terraform init` 실행 시 S3에서 자신의 상태 파일을 자동으로 다운로드
2. **실행**: `terraform plan/apply`로 작업 진행
3. **자동 업로드**: 변경사항이 S3에 자동 저장
4. **참조**: 다른 레이어의 출력값은 `data.terraform_remote_state`로 자동 참조

**예시 (준제의 Database 레이어 작업)**:
```bash
cd terraform/envs/dev/database
terraform init  # S3에서 dev/junje/database/terraform.tfstate 다운로드
terraform plan  # Network/Security 레이어 상태 자동 참조
terraform apply # 변경사항 S3에 자동 저장
```

**주의사항**:
- 각 레이어는 고유한 S3 키 경로 사용 (`dev/[이름]/[레이어]/terraform.tfstate`)
- DynamoDB 잠금으로 동시 작업 방지
- 상태 파일은 절대 수동으로 편집하지 말 것

### 협업 시 주의사항
1. **모듈 변경**: 팀원들과 사전 협의 후 진행
2. **상태 파일**: S3에 자동 저장되므로 별도 관리 불필요
3. **잠금**: DynamoDB가 동시 실행 방지
4. **브랜치**: 모듈 변경 시 브랜치/PR 사용
5. **의존성**: 이전 레이어 완료 후 다음 레이어 작업 시작

## 👶 이해 안 가는 팀원을 위해 한 번 더 상세 가이드 (Step by Step)

### 📚 먼저 이해하기: Terraform 상태 파일이란?

**비유로 이해하기:**
- 여러 명이 함께 레고를 조립한다고 생각해보세요
- 각자 자신이 만든 부분을 기록해두어야 다음 사람이 이어서 만들 수 있죠
- Terraform의 상태 파일(.tfstate)이 바로 그 "조립 기록"입니다

**왜 S3에 저장하나요?**
- **혼자 작업**: 로컬 컴퓨터에 저장해도 됩니다
- **팀 작업**: 모두가 같은 "조립 기록"을 공유해야 합니다
- S3는 "공유 저장소" 역할을 합니다

**무엇이 저장되나요?**
- AWS에 만든 리소스들의 ID, 이름, 설정값 등
- 다음 작업에서 이 정보를 참조합니다

---

### 🚀 팀원별 첫 작업 시작하기

#### **준비 단계 (모든 팀원이 해야 함)**

##### 1단계: 프로젝트 다운로드
```bash
# Git이 설치되어 있어야 합니다
git clone https://github.com/hyh528/PetClinic-AWS-Migration.git
cd PetClinic-AWS-Migration
```

##### 2단계: 자신의 작업 폴더로 이동
```bash
# 영현이 (Network 담당)
cd terraform/envs/dev/network

# 휘권이 (Security 담당)
cd terraform/envs/dev/security

# 준제 (Database 담당)
cd terraform/envs/dev/database

# 석겸이 (Application 담당)
cd terraform/envs/dev/application
```

##### 3단계: AWS 프로필 확인
```bash
# 자신의 프로필로 AWS에 연결되는지 확인
aws sts get-caller-identity --profile [자신의 프로필명]

# 예시 출력:
# Account: 123456789012
# UserId: AIDAXXXXXXXXXXXXXXXXX
# Arn: arn:aws:iam::123456789012:user/petclinic-yeonghyeon
```

---

#### **실제 작업 단계 (영현이의 Network 작업 예시)**

##### 4단계: Terraform 초기화 (가장 중요!)
```bash
terraform init
```

**무슨 일이 일어나나요?**
- S3 버킷에 연결을 시도합니다
- 자신의 상태 파일을 다운로드합니다
- 로컬에 `.terraform` 폴더를 만듭니다
- 필요한 플러그인을 설치합니다

**성공 시 출력 예시:**
```
Initializing the backend...
Successfully configured the backend "s3"! Init complete!

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.0.0...
- Installed hashicorp/aws v6.0.0 (signed by HashiCorp)
```

**실패 시?** → 아래 문제 해결 참고

##### 5단계: 현재 상태 확인 (안전하게 미리 보기)
```bash
terraform plan
```

**무슨 일이 일어나나요?**
- 현재 AWS에 무엇이 있는지 확인
- 어떤 변경을 할지 계획을 세움
- 예상 비용 표시
- 실제로는 아무것도 만들지 않음 (안전!)

**출력 예시:**
```
Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_vpc.this will be created
  + resource "aws_vpc" "this" {
      + cidr_block = "10.0.0.0/16"
      + tags       = {
          + Name = "petclinic-dev-vpc"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

##### 6단계: 실제로 만들기
```bash
terraform apply
```

**무슨 일이 일어나나요?**
- 정말 실행할지 물어봅니다: `Do you want to perform these actions? (yes/no)`
- AWS에 리소스를 만듭니다 (시간 걸릴 수 있음)
- 변경사항을 S3에 자동 저장합니다

**성공 시 출력:**
```
aws_vpc.this: Creating...
aws_vpc.this: Creation complete after 2s
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

##### 7단계: 결과 확인
```bash
terraform output
```

**출력 예시:**
```
vpc_id = "vpc-1234567890abcdef0"
public_subnet_ids = [
  "subnet-1234567890abcdef1",
  "subnet-1234567890abcdef2",
]
```

---

#### **다음 팀원 작업 방법 (휘권이의 Security 작업 예시)**

##### 1단계: 자신의 폴더로 이동
```bash
cd terraform/envs/dev/security
```

##### 2단계: 초기화 (Network 상태 자동 참조)
```bash
terraform init
```

**특별한 점:** 코드에 이렇게 써있어서 자동으로 Network 상태를 가져옵니다
```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/yeonghyeon/network/terraform.tfstate"  # 영현이의 상태 파일
  }
}
```

##### 3단계: 계획 및 실행
```bash
terraform plan
terraform apply
```

---

### 🔧 문제 해결 가이드 (초보자용)

#### **문제 1: terraform init 실패**
```
Error: Failed to get existing workspaces: AccessDenied
```

**해결:**
```bash
# 1. AWS 프로필 확인
aws sts get-caller-identity --profile [자신의 프로필명]

# 2. S3 버킷 접근 권한 확인
aws s3 ls s3://petclinic-tfstate-team-jungsu-kopo --profile [자신의 프로필명]

# 3. 캐시 삭제 후 재시도
rm -rf .terraform
terraform init
```

#### **문제 2: Backend configuration이 잘못됨**
```
Error: Backend configuration changed
```

**해결:**
```bash
# providers.tf 파일의 backend 설정을 확인하세요
# bucket, key, profile이 맞는지 확인
terraform init -reconfigure
```

#### **문제 3: 다른 레이어 상태를 찾을 수 없음**
```
Error: data.terraform_remote_state.network: no such file
```

**의미:** 이전 팀원(Network)이 아직 완료하지 않았음
**해결:** 이전 팀원에게 완료 여부 확인

#### **문제 4: 동시에 작업하려고 함**
```
Error: Error acquiring the state lock
```

**의미:** 다른 사람이 이미 작업 중
**해결:** 잠시 기다렸다가 다시 시도

#### **문제 5: AWS 권한 부족**
```
Error: AccessDenied
```

**해결:**
- IAM 정책 확인
- 올바른 프로필 사용인지 확인
- 학교 계정 vs 프로젝트 계정 구분

---

### 초보자를 위한 팁

1. **항상 `terraform plan` 먼저!** 실제 변경 전에 미리 보기
2. **에러 메시지 읽기** - 영어지만 힌트가 됩니다
3. **천천히 하기** - 급하게 실행하지 말고 한 단계씩 확인
4. **팀 커뮤니케이션** - 완료 시 바로 알리기
5. **백업** - 중요한 건 Git에 커밋하기
6. **실행 순서** - Network → Security → Database → Application
7. **프로필 확인** - 각자 자신의 AWS 계정 사용

---

### 간단 버전 체크리스트

- [ ] Git 저장소 클론
- [ ] 자신의 폴더로 이동 (`cd terraform/envs/dev/[레이어]`)
- [ ] AWS 프로필 확인 (`aws sts get-caller-identity`)
- [ ] Terraform 초기화 (`terraform init`)
- [ ] 계획 확인 (`terraform plan`)
- [ ] 실제 실행 (`terraform apply`)
- [ ] 결과 확인 (`terraform output`)
- [ ] 팀원들에게 완료 알림

---

## **Terraform 파일 구조 완전 가이드**

### **🏗️ 전체 프로젝트 구조**

```
spring-petclinic-microservices/
├── terraform/                          # Terraform 작업 디렉토리
│   ├── backend.tfvars                  # 🔧 백엔드 공유 설정
│   ├── bootstrap/                      # 🚀 초기 인프라 생성
│   │   ├── main.tf                     # S3 + DynamoDB 생성
│   │   └── providers.tf                # 로컬 백엔드
│   ├── modules/                        # 📚 재사용 가능한 모듈들
│   │   ├── vpc/                        # 네트워크 모듈
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── iam/                        # IAM 모듈
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── security/                    # 보안 그룹 모듈
│   │   ├── endpoints/                   # VPC 엔드포인트 모듈
│   │   ├── alb/                         # ALB 모듈
│   │   └── ...
│   └── envs/                           # 🌍 환경별 설정
│       └── dev/                        # 개발 환경
│           ├── network/                 # 네트워크 레이어
│           │   ├── main.tf              # VPC 모듈 사용
│           │   ├── providers.tf         # 백엔드 + AWS 설정
│           │   ├── variables.tf         # 환경별 변수
│           │   └── outputs.tf           # 다른 레이어 공유
│           ├── security/                # 보안 레이어
│           │   ├── main.tf              # IAM, 보안그룹 모듈 사용
│           │   └── providers.tf         # 백엔드 + AWS 설정
│           ├── database/                # 데이터베이스 레이어
│           │   ├── main.tf              # RDS 모듈 사용
│           │   ├── providers.tf
│           │   ├── variables.tf
│           │   └── outputs.tf
│           └── application/             # 애플리케이션 레이어
│               ├── main.tf              # ALB, ECS 모듈 사용
│               └── providers.tf
└── docs/                               # 📖 문서
```

---

### **로컬 모듈 시스템 이해하기**

#### **모듈이란?**
**비유로 이해하기:**
- **집 짓기**: 벽돌, 문, 창문 등을 표준화된 "블록"으로 만들어 재사용
- **프로그래밍**: 함수나 클래스를 만들어 반복 사용
- **Terraform**: 네트워크, 데이터베이스 등의 인프라를 표준화된 "모듈"로 만들어 재사용

#### **우리 프로젝트의 모듈 구조**
```
modules/
├── vpc/           # 네트워크 블록
├── iam/           # 사용자 권한 블록
├── security/      # 보안 그룹 블록
├── alb/           # 로드밸런서 블록
└── ...
```

**각 모듈 구성:**
```
vpc/
├── main.tf        # 실제 AWS 리소스 생성 코드
├── variables.tf   # 입력 파라미터 정의
└── outputs.tf     # 출력 값 정의
```

---

### **모듈 사용 방식 (실제 코드 예시)**

#### **1. 환경에서 모듈 호출**
```hcl
# envs/dev/network/main.tf
module "vpc" {
  source = "../../../modules/vpc"    # 상대 경로로 모듈 참조

  # 입력 파라미터 전달
  name_prefix = var.name_prefix
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  azs         = var.azs
  # ...
}
```

#### **2. 모듈 내부 구현**
```hcl
# modules/vpc/main.tf
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.name_prefix}-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  # 서브넷 생성 로직
}
```

#### **3. 모듈 출력**
```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "생성된 VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID들"
  value       = values(aws_subnet.public)[*].id
}
```

---

### **데이터 흐름: 모듈 → 환경 → 레이어 간 공유**

```
1. 모듈 실행
   modules/vpc/main.tf → AWS에 VPC 생성

2. 모듈 출력
   modules/vpc/outputs.tf → vpc_id, subnet_ids 반환

3. 환경에서 모듈 출력 사용
   envs/dev/network/main.tf → module.vpc.vpc_id 받음

4. 환경 출력으로 공유
   envs/dev/network/outputs.tf → vpc_id를 다른 레이어에 공유

5. 다른 레이어에서 참조
   envs/dev/security/providers.tf → data.terraform_remote_state.network.outputs.vpc_id
```

---

### **실무적 장점**

#### **1. 코드 재사용**
```hcl
# 다른 환경에서도 동일 모듈 사용
module "vpc" {
  source = "../../../modules/vpc"
  environment = "staging"  # 환경만 변경
}
```

#### **2. 유지보수 용이**
- 모듈 하나 수정 → 모든 환경에 적용
- 표준화된 인프라 코드
- 버그 수정이 중앙 집중적

#### **3. 협업 효율**
- 팀원들이 각자 환경만 관리
- 모듈은 공유하므로 일관성 유지
- 코드 리뷰와 테스트 용이

---

### **Bootstrap: 특별한 시작점**

#### **Bootstrap의 역할**
```
bootstrap/
├── main.tf    # S3 버킷 + DynamoDB 생성
└── providers.tf # 로컬 백엔드 (특별!)
```

**왜 로컬 백엔드?**
- S3와 DynamoDB를 생성해야 하는데, S3가 없으면 백엔드를 설정할 수 없음
- **부트스트랩 문제 해결**: 로컬로 시작해서 클라우드를 만든 후 전환

#### **Bootstrap 실행 후**
```bash
# 1. Bootstrap 실행
cd terraform/bootstrap
terraform init   # 로컬 백엔드
terraform apply  # S3 + DynamoDB 생성

# 2. 다른 환경들은 S3 백엔드 사용
cd ../envs/dev/network
terraform init   # 이제 S3 백엔드 자동 연결!
```

---

### **초보자를 위한 Q&A**

#### **Q: 왜 상대 경로를 사용할까?**
**A:** `../../../modules/vpc`처럼 상대 경로를 사용하면:
- Git 저장소 어디에서나 실행 가능
- 절대 경로 의존성 없음
- 프로젝트 구조 변경에 유연

#### **Q: 모듈을 수정하면 어떻게 되나?**
**A:** 모듈 수정 → Git 커밋 → 팀원들이 `terraform get`으로 업데이트

#### **Q: 환경별로 다른 설정은?**
**A:** `variables.tf`에서 환경별 값 정의:
```hcl
# dev/variables.tf
vpc_cidr = "10.0.0.0/16"

# staging/variables.tf
vpc_cidr = "10.1.0.0/16"
```

이제 팀원들이 **파일 구조와 모듈 시스템을 완벽하게 이해**할 수 있을 것입니다! 🎯

## **Clean Architecture: 백엔드 설정 개선**

### **왜 변수를 사용하나?**

이전에는 백엔드 설정을 하드코딩했지만, **실무에서는 변수를 사용하는 것이 Clean Architecture**입니다:

#### **✅ 개선된 방식 (현재 적용)**
```hcl
# terraform/backend.tfvars (공유 설정 파일)
tfstate_bucket_name = "petclinic-tfstate-team-jungsu-kopo"
tf_lock_table_name = "petclinic-tf-locks"
aws_region = "ap-northeast-2"
encrypt_state = true

# 각 providers.tf에서 변수 사용
backend "s3" {
  bucket         = var.tfstate_bucket_name
  key            = "dev/yeonghyeon/network/terraform.tfstate"
  region         = var.aws_region
  dynamodb_table = var.tf_lock_table_name
  encrypt        = var.encrypt_state
}
```

#### **❌ 이전 방식 (하드코딩)**
```hcl
backend "s3" {
  bucket         = "petclinic-tfstate-team-jungsu-kopo"  # 직접 값
  key            = "dev/yeonghyeon/network/terraform.tfstate"
  region         = "ap-northeast-2"  # 직접 값
  dynamodb_table = "petclinic-tf-locks"  # 직접 값
  encrypt        = true  # 직접 값
}
```

### **실무적 장점**

1. **환경별 유연성**: dev/staging/prod 환경에서 다른 백엔드 사용 가능
2. **보안**: 민감한 값들을 별도 파일로 분리
3. **유지보수성**: 백엔드 변경 시 한 곳만 수정
4. **재사용성**: 다른 프로젝트에서 동일 구조 적용 용이

### **사용 방법**

```bash
# 백엔드 설정 파일을 지정해서 초기화
terraform init -backend-config=../backend.tfvars

# 또는 자동 인식 (backend.tfvars가 같은 디렉토리에 있으면)
terraform init
```

이제 **실무 수준의 Clean Architecture**를 따르고 있습니다!

## 실행 체크리스트 (팀별 담당)

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

## 초보자를 위한 팁

1. **항상 `terraform plan` 먼저 실행**: 무엇이 생성/변경되는지 확인
2. **팀 커뮤니케이션**: 각 레이어 완료 시 팀원들에게 공유
3. **출력 값 저장**: 다음 레이어에서 참조해야 함
4. **프로필 확인**: 각자 자신의 AWS 프로필 사용
5. **에러 메시지 읽기**: AWS 권한이나 네트워크 문제일 수 있음
6. **천천히 진행**: 각 레이어 완료 확인 후 다음 담당자에게 전달
7. **문서화**: 변경사항은 기록해두세요

## **실무 협업 완성!**

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
