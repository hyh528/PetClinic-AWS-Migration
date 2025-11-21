# 10-monitoring 레이어 📊

## 목차
- [개요](#개요)
- [CloudWatch 기초 개념](#cloudwatch-기초-개념)
- [우리가 만드는 모니터링 구조](#우리가-만드는-모니터링-구조)
- [대시보드 구성](#대시보드-구성)
- [CloudTrail 감사 로그](#cloudtrail-감사-로그)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**10-monitoring 레이어**는 전체 시스템의 **통합 모니터링**을 담당하는 레이어입니다.

### 이 레이어가 하는 일
- ✅ **CloudWatch Dashboard**: 모든 서비스 메트릭 통합 표시
- ✅ **CloudWatch Alarms**: 임계값 초과 시 알림 (SNS)
- ✅ **CloudWatch Logs**: 로그 수집 및 보관 (30일)
- ✅ **CloudTrail**: AWS API 호출 감사 로그 (90일)
- ✅ **SNS 통합**: 이메일/SMS 알림

### 다른 레이어와의 관계
```
03-database (Aurora)
    ↓
07-application (ECS, ALB)
    ↓
08-api-gateway (API Gateway)
    ↓
09-aws-native (Lambda GenAI)
    ↓
10-monitoring (이 레이어) 📊
    ↓
    ├─→ CloudWatch Dashboard (통합 뷰)
    ├─→ CloudWatch Alarms (알림)
    └─→ CloudTrail (감사 로그)
```

### 모니터링 대상 리소스

| 레이어 | 리소스 | 메트릭 |
|--------|--------|--------|
| **03-database** | Aurora MySQL | Connections, CPU, Latency |
| **07-application** | ECS, ALB | TaskCount, TargetResponseTime |
| **08-api-gateway** | API Gateway | Count, 4XX, 5XX, Latency |
| **09-aws-native** | Lambda GenAI | Invocations, Errors, Duration |

---

## CloudWatch 기초 개념

### 1. CloudWatch란? 📈

**쉽게 설명**: CloudWatch는 AWS 리소스를 **실시간 모니터링**하는 서비스입니다.

```
AWS 리소스들
    ↓ (메트릭 전송)
CloudWatch
    ↓ (시각화)
대시보드
```

**주요 기능**:
1. **메트릭 수집**: CPU, 메모리, 네트워크 등
2. **로그 수집**: 애플리케이션 로그, 시스템 로그
3. **알람 설정**: 임계값 초과 시 알림
4. **대시보드**: 그래프, 차트로 시각화

---

### 2. 메트릭 (Metrics) 📊

**메트릭**: 시간에 따른 **측정 데이터**

**예시**:
```
API Gateway Count 메트릭:
시간    | 요청 수
--------|--------
10:00   | 120
10:05   | 145
10:10   | 132
10:15   | 158
```

**AWS 기본 메트릭**:
| 서비스 | 메트릭 | 설명 |
|--------|--------|------|
| **API Gateway** | Count | 총 요청 수 |
| **API Gateway** | 4XXError | 클라이언트 에러 |
| **API Gateway** | 5XXError | 서버 에러 |
| **API Gateway** | Latency | 응답 시간 (ms) |
| **Lambda** | Invocations | 호출 횟수 |
| **Lambda** | Errors | 에러 횟수 |
| **Lambda** | Duration | 실행 시간 (ms) |
| **ECS** | CPUUtilization | CPU 사용률 (%) |
| **ECS** | MemoryUtilization | 메모리 사용률 (%) |
| **Aurora** | DatabaseConnections | 연결 수 |
| **Aurora** | CPUUtilization | CPU 사용률 (%) |
| **ALB** | TargetResponseTime | 응답 시간 (초) |
| **ALB** | HealthyHostCount | 정상 타겟 수 |

---

### 3. 알람 (Alarms) 🚨

**알람**: 메트릭이 **임계값을 초과**하면 알림

**알람 상태**:
```
OK         : 정상 (임계값 이하)
ALARM      : 경고 (임계값 초과)
INSUFFICIENT_DATA: 데이터 부족
```

**예시**:
```
알람: API Gateway 5XX 에러
임계값: 5분간 10개
평가 기간: 2회 연속

시나리오:
10:00-10:05 → 5XX: 12개 (1회 초과)
10:05-10:10 → 5XX: 15개 (2회 초과)
→ 알람 발생! SNS 알림 전송
```

---

### 4. 대시보드 (Dashboard) 📺

**대시보드**: 여러 메트릭을 **한 화면에 시각화**

```
┌─────────────────────────────────────────────┐
│  PetClinic Monitoring Dashboard             │
├─────────────────────────────────────────────┤
│  [API Gateway Requests]  [Lambda Invokes]   │
│  [ECS CPU Usage]         [Aurora Connections]│
│  [ALB Response Time]     [Error Rate]       │
└─────────────────────────────────────────────┘
```

---

### 5. CloudTrail 📝

**CloudTrail**: AWS API 호출을 **기록**하는 감사 서비스

**기록 내용**:
```
누가 (Who): IAM User / Role
언제 (When): 2025-11-09 10:30:00
무엇을 (What): CreateFunction
어디서 (Where): us-west-2
어떻게 (How): API / Console
```

**예시**:
```json
{
  "eventName": "CreateFunction",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDAI...",
    "arn": "arn:aws:iam::123456789012:user/admin"
  },
  "eventTime": "2025-11-09T10:30:00Z",
  "awsRegion": "us-west-2",
  "sourceIPAddress": "1.2.3.4"
}
```

**용도**:
- 🔍 **보안 감사**: 누가 무엇을 했는지
- 🐛 **디버깅**: 문제 발생 시 원인 추적
- 📋 **컴플라이언스**: 감사 로그 보관

---

## 우리가 만드는 모니터링 구조

### 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Resources                                    │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │ API Gateway  │  │ Lambda       │  │ ECS Services │            │
│  │ (08-layer)   │  │ (06-layer)   │  │ (07-layer)   │            │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │
│         │                 │                 │                      │
│         └─────────┬───────┴─────────┬───────┘                     │
│                   │                 │                              │
│                   ↓                 ↓                              │
│  ┌──────────────┐  ┌──────────────┐                               │
│  │ ALB          │  │ Aurora DB    │                               │
│  │ (07-layer)   │  │ (03-layer)   │                               │
│  └──────┬───────┘  └──────┬───────┘                               │
│         │                 │                                        │
└─────────┼─────────────────┼────────────────────────────────────────┘
          │                 │
          │ (메트릭 전송)    │
          ↓                 ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  10-monitoring 레이어                                         ║  │
│  ║                                                               ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  CloudWatch Dashboard                                 │    ║  │
│  ║  │  - API Gateway: Count, 4XX, 5XX, Latency             │    ║  │
│  ║  │  - Lambda: Invocations, Errors, Duration             │    ║  │
│  ║  │  - ECS: CPU, Memory, TaskCount                       │    ║  │
│  ║  │  - ALB: TargetResponseTime, HealthyHostCount         │    ║  │
│  ║  │  - Aurora: DatabaseConnections, CPUUtilization       │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                               ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  CloudWatch Alarms                                    │    ║  │
│  ║  │  - API Gateway 5XX > 10                               │    ║  │
│  ║  │  - Lambda Errors > 5                                  │    ║  │
│  ║  │  - ECS CPU > 80%                                      │    ║  │
│  ║  │  - Aurora Connections > 100                           │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                               ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  CloudWatch Logs                                      │    ║  │
│  ║  │  - 보관 기간: 30일                                     │    ║  │
│  ║  │  - 로그 그룹: /aws/apigateway, /aws/lambda, /aws/ecs │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                                                               ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  CloudTrail                                           │    ║  │
│  ║  │  - 감사 로그: AWS API 호출                             │    ║  │
│  ║  │  - 보관 기간: 90일                                     │    ║  │
│  ║  │  - S3 버킷: petclinic-dev-cloudtrail-logs            │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
│                          │                                           │
│                          ↓                                           │
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  SNS (알림)                                                    ║  │
│  ║  - Email: 2501340070@office.kopo.ac.kr                        ║  │
│  ║  - 알람 발생 시 즉시 전송                                       ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 대시보드 구성

### CloudWatch Dashboard 위젯

```
┌──────────────────────────────────────────────────────────────┐
│  PetClinic Dev Dashboard                                     │
│  Region: us-west-2                                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │ API Gateway          │  │ Lambda GenAI         │          │
│  │ ──────────────       │  │ ──────────────       │          │
│  │ Count: 1,234         │  │ Invocations: 456     │          │
│  │ 4XX: 12              │  │ Errors: 2            │          │
│  │ 5XX: 1               │  │ Duration: 2.3s       │          │
│  │ Latency: 150ms       │  │ Throttles: 0         │          │
│  └──────────────────────┘  └──────────────────────┘          │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │ ECS Cluster          │  │ ALB                  │          │
│  │ ──────────────       │  │ ──────────────       │          │
│  │ Running Tasks: 4     │  │ Requests: 980        │          │
│  │ CPU: 45%             │  │ Response Time: 0.2s  │          │
│  │ Memory: 60%          │  │ Healthy Targets: 4   │          │
│  │ Desired: 4           │  │ 5XX Errors: 0        │          │
│  └──────────────────────┘  └──────────────────────┘          │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │ Aurora MySQL         │  │ Error Rate           │          │
│  │ ──────────────       │  │ ──────────────       │          │
│  │ Connections: 23      │  │ Overall: 0.1%        │          │
│  │ CPU: 15%             │  │ 4XX: 1.0%            │          │
│  │ Read Latency: 5ms    │  │ 5XX: 0.08%           │          │
│  │ Write Latency: 8ms   │  │ Lambda: 0.4%         │          │
│  └──────────────────────┘  └──────────────────────┘          │
└──────────────────────────────────────────────────────────────┘
```

### 대시보드 접근 방법

```bash
# AWS Console
https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=petclinic-dev-Dashboard

# 또는 Terraform output
cd terraform/layers/10-monitoring
terraform output dashboard_url
```

---

## CloudTrail 감사 로그

### 1. 감사 로그란? 📝

**목적**: "누가, 언제, 무엇을" 했는지 기록

**기록되는 작업**:
- ✅ Lambda 함수 생성/삭제
- ✅ API Gateway 설정 변경
- ✅ ECS 서비스 업데이트
- ✅ Aurora 클러스터 수정
- ✅ IAM 권한 변경

---

### 2. 로그 저장 위치

```
S3 Bucket: petclinic-dev-cloudtrail-logs
    └── AWSLogs/
        └── 123456789012/
            └── CloudTrail/
                └── us-west-2/
                    └── 2025/11/09/
                        └── 123456789012_CloudTrail_us-west-2_20251109T1030Z_abc123.json.gz
```

**보관 기간**: 90일

---

### 3. 로그 조회

#### 방법 1: AWS Console
```
CloudTrail → Event history → Filter
```

#### 방법 2: AWS CLI
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateFunction \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z
```

#### 방법 3: S3에서 직접 다운로드
```bash
aws s3 cp s3://petclinic-dev-cloudtrail-logs/AWSLogs/123456789012/CloudTrail/us-west-2/2025/11/09/ . --recursive
```

---

### 4. 중요 감사 이벤트 예시

```json
{
  "eventVersion": "1.08",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDAI...",
    "arn": "arn:aws:iam::123456789012:user/admin",
    "accountId": "123456789012",
    "accessKeyId": "AKIAI...",
    "userName": "admin"
  },
  "eventTime": "2025-11-09T10:30:00Z",
  "eventSource": "lambda.amazonaws.com",
  "eventName": "CreateFunction20150331",
  "awsRegion": "us-west-2",
  "sourceIPAddress": "1.2.3.4",
  "userAgent": "aws-cli/2.13.0",
  "requestParameters": {
    "functionName": "petclinic-dev-genai",
    "runtime": "python3.11",
    "role": "arn:aws:iam::123456789012:role/lambda-execution-role",
    "handler": "app.lambda_handler",
    "code": {
      "s3Bucket": "petclinic-lambda-code",
      "s3Key": "genai/v1.0.0.zip"
    }
  },
  "responseElements": {
    "functionName": "petclinic-dev-genai",
    "functionArn": "arn:aws:lambda:us-west-2:123456789012:function:petclinic-dev-genai",
    "runtime": "python3.11",
    "role": "arn:aws:iam::123456789012:role/lambda-execution-role",
    "handler": "app.lambda_handler",
    "codeSize": 1234567,
    "state": "Active"
  }
}
```

---

## 코드 구조

### 파일 구성

```
10-monitoring/
├── main.tf              # CloudWatch, CloudTrail 모듈 호출
├── data.tf              # Remote State 참조 (모든 레이어)
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
├── ../../envs/dev.tfvars     # 실제 값 입력
└── README.md            # 이 문서
```

---

### main.tf 주요 구성

```hcl
# CloudWatch 모니터링 모듈 호출
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  dashboard_name = "petclinic-dev-Dashboard"
  aws_region     = "us-west-2"

  # 각 레이어에서 가져온 리소스 정보 (의존성 역전)
  api_gateway_name     = local.api_gateway_name
  ecs_cluster_name     = data.terraform_remote_state.application.outputs.ecs_cluster_name
  lambda_function_name = local.lambda_function_name
  aurora_cluster_name  = local.aurora_cluster_name

  # 멀티 서비스 지원 (CloudMap 아키텍처)
  ecs_services   = data.terraform_remote_state.application.outputs.ecs_services
  alb_arn_suffix = data.terraform_remote_state.application.outputs.alb_arn_suffix
  target_groups  = data.terraform_remote_state.application.outputs.target_group_arns

  # 레거시 단일 서비스 지원 (하위 호환성)
  ecs_service_name = try(data.terraform_remote_state.application.outputs.ecs_services["customers"].service_name, "")
  alb_name         = try(data.terraform_remote_state.application.outputs.alb_dns_name, "")

  log_retention_days = 30
  sns_topic_arn      = "arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts"

  tags = var.tags
}

# CloudTrail 감사 로그 모듈 호출
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  cloudtrail_name        = "petclinic-dev-audit-trail"
  cloudtrail_bucket_name = "petclinic-dev-cloudtrail-logs"
  aws_region             = "us-west-2"
  log_retention_days     = 90
  sns_topic_arn          = "arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts"

  tags = var.tags
}
```

---

## 배포 방법

### 사전 요구사항

**모든 이전 레이어 배포 완료**:
1. 03-database (Aurora)
2. 07-application (ECS, ALB)
3. 08-api-gateway (API Gateway)
4. 09-aws-native (Lambda GenAI)

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/10-monitoring
```

#### 2단계: 변수 파일 확인
```bash
cat ../../envs/dev.tfvars
```

예시:
```hcl
# 공통 설정
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# 알림 설정
alert_email = "2501340070@office.kopo.ac.kr"
sns_topic_arn = ""  # 생성 후 자동 설정

# 백엔드
tfstate_bucket_name = "petclinic-tfstate-oregon-dev"

tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
}
```

#### 3단계: Terraform 초기화
```bash
terraform init \
  -backend-config=../../backend.hcl \
  -backend-config=backend.config
```

#### 4단계: 실행 계획 확인
```bash
terraform plan -var-file=../../envs/dev.tfvars
```

**확인사항**:
- CloudWatch Dashboard 1개
- CloudWatch Alarms 5-10개
- CloudWatch Log Groups 여러 개
- CloudTrail 1개
- S3 Bucket 1개 (CloudTrail 로그)

#### 5단계: 배포 실행
```bash
terraform apply -var-file=../../envs/dev.tfvars
```

**소요 시간**: 약 2-3분

#### 6단계: 배포 확인
```bash
# 대시보드 URL
terraform output dashboard_url

# CloudTrail 버킷
terraform output cloudtrail_bucket_name
```

---

### 배포 후 확인

#### 1. 대시보드 접근
```bash
# 브라우저에서 열기
open "$(terraform output -raw dashboard_url)"
```

#### 2. SNS 이메일 구독 확인
```
1. 이메일 확인 (2501340070@office.kopo.ac.kr)
2. "AWS Notification - Subscription Confirmation" 제목 이메일 열기
3. "Confirm subscription" 링크 클릭
4. 구독 확인 완료
```

#### 3. 알람 테스트
```bash
# Lambda 함수 강제 에러 발생
aws lambda invoke \
  --function-name petclinic-dev-genai \
  --payload '{"invalid": "data"}' \
  response.json

# 5분 후 알람 확인
aws cloudwatch describe-alarms \
  --alarm-names petclinic-lambda-genai-errors
```

---

## 문제 해결

### 문제 1: 대시보드 위젯 데이터 없음
```
Dashboard shows "No data available"
```

**원인**: 메트릭 생성 전 대시보드 생성

**해결**:
```bash
# 메트릭 생성 (API 호출)
curl https://abc123.execute-api.us-west-2.amazonaws.com/v1/api/customers

# 5분 대기 (CloudWatch는 5분마다 메트릭 수집)

# 대시보드 새로고침
```

---

### 문제 2: CloudTrail 로그 없음
```
S3 bucket is empty
```

**원인**: CloudTrail은 생성 후부터 기록 시작

**해결**:
```bash
# CloudTrail 상태 확인
aws cloudtrail get-trail-status \
  --name petclinic-dev-audit-trail

# IsLogging: true 확인

# 테스트 이벤트 생성 (Lambda 함수 조회)
aws lambda get-function --function-name petclinic-dev-genai

# 15분 대기 (CloudTrail은 15분마다 S3에 전송)

# S3 확인
aws s3 ls s3://petclinic-dev-cloudtrail-logs/AWSLogs/ --recursive
```

---

### 문제 3: 알람 발생 안 함
```
No alarm notification received
```

**디버깅**:

1. **SNS 구독 확인**
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-west-2:123456789012:petclinic-alerts

# Status: "Confirmed" 확인
```

2. **알람 상태 확인**
```bash
aws cloudwatch describe-alarms \
  --alarm-names petclinic-api-gateway-5xx-errors

# StateValue: "OK", "ALARM", "INSUFFICIENT_DATA"
```

3. **메트릭 확인**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 5XXError \
  --dimensions Name=ApiName,Value=petclinic-api \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z \
  --period 300 \
  --statistics Sum
```

---

### 디버깅 명령어

```bash
# 대시보드 목록
aws cloudwatch list-dashboards

# 알람 목록
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[?Namespace==`AWS/ApiGateway`].[AlarmName,StateValue]' \
  --output table

# CloudTrail 이벤트 조회
aws cloudtrail lookup-events \
  --max-results 10 \
  --query 'Events[].[EventTime,EventName,Username]' \
  --output table

# 로그 그룹 목록
aws logs describe-log-groups \
  --query 'logGroups[?starts_with(logGroupName, `/aws/`)].logGroupName' \
  --output table
```

---

## 비용 예상

### 주요 비용 요소

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| **CloudWatch Dashboard** | 1개 (3위젯 이상) | $3.00 |
| **CloudWatch Alarms** | 10개 (표준) | $1.00 ($0.10/개) |
| **CloudWatch Logs** | 5GB 수집 + 30일 보관 | $3.00 |
| **CloudTrail** | 이벤트 기록 (첫 번째 Trail 무료) | $0.00 |
| **S3 (CloudTrail)** | 10GB 저장 + 90일 | $0.25 |
| **SNS** | 100 알림/월 | $0.01 |
| **합계** | - | **$7.26** |

**비용 최적화 팁**:
- 대시보드 비활성화 (개발 환경): $3.00 절감
- 로그 보관 기간 단축 (30일 → 7일): $1.50 절감
- CloudTrail S3 Intelligent-Tiering: $0.10 절감

---

## 다음 단계

Monitoring 레이어 배포가 완료되면:

1. **11-frontend**: 프론트엔드 배포 (S3, CloudFront, Route53)
2. **12-notification**: 이벤트 기반 알림 (EventBridge, SQS)

```bash
cd ../11-frontend
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=../../envs/dev.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **CloudWatch Dashboard**: 모든 메트릭 통합 표시
- ✅ **CloudWatch Alarms**: 임계값 초과 시 SNS 알림
- ✅ **CloudWatch Logs**: 30일 보관
- ✅ **CloudTrail**: AWS API 감사 로그 (90일)
- ✅ **SNS**: 이메일/SMS 알림

### 모니터링 대상
- API Gateway: Count, 4XX, 5XX, Latency
- Lambda: Invocations, Errors, Duration
- ECS: CPU, Memory, TaskCount
- ALB: TargetResponseTime, HealthyHostCount
- Aurora: DatabaseConnections, CPUUtilization

### 알람 임계값
- API Gateway 5XX > 10 (5분간)
- Lambda Errors > 5 (5분간)
- ECS CPU > 80% (5분간)
- Aurora Connections > 100

### 로그 보관
- CloudWatch Logs: 30일
- CloudTrail: 90일 (S3)

---

**작성일**: 2025-11-09  
**작성자**: 황영현 
**버전**: 1.0
