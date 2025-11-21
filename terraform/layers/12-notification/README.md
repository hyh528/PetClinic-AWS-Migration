# 12-notification 레이어 🔔

## 목차
- [개요](#개요)
- [SNS + Lambda 알림 기초 개념](#sns--lambda-알림-기초-개념)
- [우리가 만드는 알림 시스템 구조](#우리가-만드는-알림-시스템-구조)
- [Slack 알림 설정](#slack-알림-설정)
- [배포 방법](#배포-방법)
- [테스트 방법](#테스트-방법)
- [코드 구조](#코드-구조)
- [문제 해결](#문제-해결)

---

## 개요

**12-notification 레이어**는 CloudWatch 알람을 **Slack으로 실시간 전송**하는 알림 시스템입니다.

### 이 레이어가 하는 일
- ✅ **SNS 토픽 생성**: CloudWatch 알람 수신
- ✅ **Lambda 함수 생성**: Slack Webhook 호출
- ✅ **알림 포맷팅**: 가독성 좋은 메시지 생성
- ✅ **이메일 알림**: SNS 이메일 구독 (선택)
- ✅ **테스트 알람**: 알림 시스템 테스트용

### 다른 레이어와의 관계
```
10-monitoring (CloudWatch 알람)
    ↓
12-notification (이 레이어) 🔔
    ↓
    ├─→ SNS 토픽
    └─→ Lambda 함수
        ↓
        Slack (메시지 전송)
```

### 왜 알림 시스템이 필요한가요?

**문제**:
```
CloudWatch 알람 발생
→ 어디서 알람이 발생했는지 모름
→ 대응 지연
→ 서비스 장애 장기화
```

**해결**:
```
CloudWatch 알람 발생
→ Slack 알림 즉시 전송
→ 팀원 모두 확인
→ 즉시 대응
→ 서비스 정상화
```

---

## SNS + Lambda 알림 기초 개념

### 1. SNS (Simple Notification Service) 📨

**SNS**: 메시지를 **여러 구독자**에게 전송하는 서비스

**Pub/Sub 패턴**:
```
Publisher (발행자)         Subscriber (구독자)
   ↓                          ↑
CloudWatch 알람 → SNS 토픽 → Lambda 함수
                    ↓       → 이메일
                    ↓       → SMS
                    ↓       → HTTP Endpoint
```

**SNS 토픽**:
```
SNS 토픽: petclinic-dev-alerts
    ├─ 구독 1: Lambda 함수 (Slack 알림)
    ├─ 구독 2: 이메일 (admin@example.com)
    └─ 구독 3: SMS (010-1234-5678)
```

**동작 원리**:
```
1. CloudWatch 알람 발생
   → SNS 토픽으로 메시지 발행

2. SNS 토픽
   → 모든 구독자에게 메시지 전송

3. Lambda 함수 수신
   → Slack Webhook 호출

4. Slack에 메시지 표시
```

---

### 2. Lambda 함수 (Slack Notifier) 🤖

**역할**: SNS 메시지를 받아 Slack으로 전송

**Lambda 함수 구조**:
```python
import json
import urllib.request

def lambda_handler(event, context):
    # 1. SNS 메시지 파싱
    message = json.loads(event['Records'][0]['Sns']['Message'])
    alarm_name = message['AlarmName']
    new_state = message['NewStateValue']
    
    # 2. Slack 메시지 포맷팅
    slack_message = {
        "text": f"🚨 알람 발생: {alarm_name}",
        "attachments": [{
            "color": "danger" if new_state == "ALARM" else "good",
            "fields": [
                {"title": "상태", "value": new_state},
                {"title": "설명", "value": message['AlarmDescription']}
            ]
        }]
    }
    
    # 3. Slack Webhook 호출
    webhook_url = os.environ['SLACK_WEBHOOK_URL']
    req = urllib.request.Request(webhook_url, 
                                  data=json.dumps(slack_message).encode('utf-8'),
                                  headers={'Content-Type': 'application/json'})
    urllib.request.urlopen(req)
    
    return {'statusCode': 200}
```

---

### 3. Slack Webhook 이해하기 🔗

**Webhook**: 외부에서 Slack으로 메시지를 보내는 **URL**

**Webhook 생성 방법**:
```
1. Slack 워크스페이스 접속
   → https://slack.com/apps

2. "Incoming Webhooks" 앱 검색
   → "Add to Slack" 클릭

3. 채널 선택
   → "#petclinic-alerts" 선택

4. Webhook URL 복사
   → https://hooks.slack.com/services/T1234/B5678/xyz...
```

**Webhook 테스트**:
```bash
curl -X POST https://hooks.slack.com/services/T1234/B5678/xyz... \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "테스트 메시지입니다!",
    "attachments": [{
      "color": "good",
      "text": "알림 시스템이 정상 작동합니다 ✅"
    }]
  }'
```

---

## 우리가 만드는 알림 시스템 구조

### 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CloudWatch Alarms                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │ API 4XX      │  │ Lambda Error │  │ ECS CPU > 80%│            │
│  │ > 20/5분      │  │ > 5/5분       │  │              │            │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │
│         │                 │                 │                      │
└─────────┼─────────────────┼─────────────────┼──────────────────────┘
          │                 │                 │
          └─────────┬───────┴─────────┬───────┘
                    │                 │
                    ↓                 ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  12-notification 레이어                                       ║  │
│  ║                                                               ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  SNS 토픽                                             │    ║  │
│  ║  │  arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts  ║  │
│  ║  │                                                       │    ║  │
│  ║  │  구독자:                                               │    ║  │
│  ║  │  - Lambda 함수 (Slack)                                │    ║  │
│  ║  │  - 이메일 (선택)                                       │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                          │                                    ║  │
│  ║                          ↓                                    ║  │
│  ║  ┌──────────────────────────────────────────────────────┐    ║  │
│  ║  │  Lambda 함수 (Slack Notifier)                         │    ║  │
│  ║  │  - Runtime: Python 3.11                               │    ║  │
│  ║  │  - Memory: 128MB                                      │    ║  │
│  ║  │  - Timeout: 10초                                      │    ║  │
│  ║  │                                                       │    ║  │
│  ║  │  환경변수:                                             │    ║  │
│  ║  │  - SLACK_WEBHOOK_URL                                  │    ║  │
│  ║  │  - SLACK_CHANNEL: #petclinic-alerts                   │    ║  │
│  ║  │  - ENVIRONMENT: dev                                   │    ║  │
│  ║  │  - PROJECT_NAME: petclinic                            │    ║  │
│  ║  └──────────────────────────────────────────────────────┘    ║  │
│  ║                          │                                    ║  │
│  ║                          ↓ HTTPS POST                         ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════════╗  │
│  ║  Slack (#petclinic-alerts)                                    ║  │
│  ║                                                               ║  │
│  ║  🚨 알람 발생: petclinic-dev-api-4xx-error-rate              ║  │
│  ║                                                               ║  │
│  ║  프로젝트: PETCLINIC-DEV                                      ║  │
│  ║  환경: DEV                                                    ║  │
│  ║  리전: US West (Oregon)                                       ║  │
│  ║  상태 변화: OK → ALARM                                        ║  │
│  ║  설명: API Gateway 4XX 에러율이 임계값을 초과했습니다         ║  │
│  ║  원인: 25개 요청 중 25개 에러 (임계값: 20개)                  ║  │
│  ║  발생 시간: 2025-11-09 10:30:00 UTC                          ║  │
│  ║                                                               ║  │
│  ║  [CloudWatch 콘솔 열기]                                       ║  │
│  ╚═══════════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Slack 알림 설정

### 1. Slack Webhook 생성 🔑

#### 1단계: Slack 앱 추가
```
1. Slack 워크스페이스 접속
   https://api.slack.com/apps

2. "Create New App" 클릭
   → "From scratch" 선택

3. 앱 이름 입력
   App Name: PetClinic CloudWatch Alerts
   Workspace: 사용할 워크스페이스 선택

4. "Create App" 클릭
```

#### 2단계: Incoming Webhooks 활성화
```
1. 좌측 메뉴 "Incoming Webhooks" 클릭
2. "Activate Incoming Webhooks" 토글 ON
3. "Add New Webhook to Workspace" 클릭
4. 채널 선택 (#petclinic-alerts)
5. "Allow" 클릭
```

#### 3단계: Webhook URL 복사
```
Webhook URL:
https://hooks.slack.com/services/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jkl

→ 이 URL을 `../../envs/dev.tfvars`에 입력
```

---

### 2. Slack 채널 생성 📢

```
1. Slack 워크스페이스에서 "+" 클릭
2. "Create a channel" 선택
3. 채널 이름: petclinic-alerts
4. Description: PetClinic AWS 알람 알림
5. "Create" 클릭
```

---

### 3. 알림 메시지 포맷 🎨

#### 알람 발생 메시지
```
🚨 알람 발생: petclinic-dev-api-4xx-error-rate

프로젝트: PETCLINIC-DEV
환경: DEV
리전: US West (Oregon)
상태 변화: OK → ALARM
설명: API Gateway 4XX 에러율이 임계값을 초과했습니다
원인: Threshold Crossed: 1 out of the last 1 datapoints [25.0 (09/11/25 10:30:00)] was greater than the threshold (20.0)
발생 시간: 2025-11-09 10:30:00 UTC

[CloudWatch 콘솔 열기]
```

#### 알람 복구 메시지
```
✅ 정상 복구: petclinic-dev-api-4xx-error-rate

프로젝트: PETCLINIC-DEV
환경: DEV
리전: US West (Oregon)
상태 변화: ALARM → OK
설명: API Gateway 4XX 에러율이 정상으로 돌아왔습니다
원인: Threshold Crossed: 1 out of the last 1 datapoints [5.0 (09/11/25 10:35:00)] was less than or equal to the threshold (20.0)
발생 시간: 2025-11-09 10:35:00 UTC
```

---

## 배포 방법

### 사전 요구사항

1. **Slack Webhook URL** 생성 (위 참조)
2. **10-monitoring 레이어** 배포 완료 (선택)

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/12-notification
```

#### 2단계: 변수 파일 수정
```bash
# ../../envs/dev.tfvars 편집
vi ../../envs/dev.tfvars
```

**중요한 변수**:
```hcl
# 공통 설정
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# Slack 설정 (필수!)
slack_webhook_url = "https://hooks.slack.com/services/T01234/B56789/xyz..."
slack_channel     = "#petclinic-alerts"

# 이메일 알림 (선택)
email_endpoint = "2501340070@office.kopo.ac.kr"

# Lambda 설정
log_retention_days = 14

# 테스트 알람 생성
create_test_alarm = true

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
- SNS 토픽 1개
- Lambda 함수 1개 (Slack Notifier)
- CloudWatch Log Group 1개
- CloudWatch 테스트 알람 1개 (선택)
- SNS 이메일 구독 1개 (선택)

#### 5단계: 배포 실행
```bash
terraform apply -var-file=../../envs/dev.tfvars
```

**소요 시간**: 약 1-2분

#### 6단계: 배포 확인
```bash
# SNS 토픽 ARN
terraform output sns_topic_arn
# arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts

# Lambda 함수 이름
terraform output lambda_function_name
# petclinic-dev-slack-notifier
```

---

## 테스트 방법

### 방법 1: 테스트 알람 트리거 (권장) ✅

```bash
# 테스트 알람을 ALARM 상태로 변경
aws cloudwatch set-alarm-state \
  --alarm-name "petclinic-dev-notification-test" \
  --state-value ALARM \
  --state-reason "Testing notification system" \
  --region us-west-2

# 5초 대기 후 Slack 확인
# → 알림 수신 확인!

# 정상 상태로 복구
aws cloudwatch set-alarm-state \
  --alarm-name "petclinic-dev-notification-test" \
  --state-value OK \
  --state-reason "Test completed" \
  --region us-west-2

# → "정상 복구" 알림 수신 확인!
```

---

### 방법 2: 직접 SNS 메시지 전송 📬

```bash
# SNS 토픽 ARN 확인
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)

# CloudWatch 알람 포맷 메시지 전송
aws sns publish \
  --topic-arn "${SNS_TOPIC_ARN}" \
  --message '{
    "AlarmName": "Manual-Test-Alarm",
    "AlarmDescription": "수동 테스트 알람입니다",
    "NewStateValue": "ALARM",
    "OldStateValue": "OK",
    "NewStateReason": "Manual test from CLI",
    "StateChangeTime": "2025-11-09T10:00:00.000+0000",
    "Region": "us-west-2"
  }' \
  --region us-west-2
```

---

### 방법 3: Lambda 함수 직접 호출 🔧

```bash
# Lambda 함수 이름
FUNCTION_NAME=$(terraform output -raw lambda_function_name)

# 테스트 이벤트
cat > test-event.json << 'EOF'
{
  "Records": [{
    "Sns": {
      "Message": "{\"AlarmName\":\"Lambda-Test\",\"AlarmDescription\":\"Lambda 직접 호출 테스트\",\"NewStateValue\":\"ALARM\",\"OldStateValue\":\"OK\",\"NewStateReason\":\"Direct Lambda invocation test\",\"StateChangeTime\":\"2025-11-09T10:00:00.000+0000\",\"Region\":\"us-west-2\"}"
    }
  }]
}
EOF

# Lambda 호출
aws lambda invoke \
  --function-name "${FUNCTION_NAME}" \
  --payload file://test-event.json \
  response.json \
  --region us-west-2

# 응답 확인
cat response.json
# {"statusCode": 200}
```

---

## 코드 구조

### 파일 구성

```
12-notification/
├── main.tf              # SNS, Lambda 모듈 호출
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값 (SNS ARN, Lambda 이름)
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
├── ../../envs/dev.tfvars     # 실제 값 입력 (Slack Webhook!)
└── README.md            # 이 문서
```

---

### main.tf 주요 구성

```hcl
module "notification" {
  source = "../../modules/notification"

  # 기본 설정
  name_prefix = "petclinic"
  environment = "dev"

  # Slack 설정
  slack_webhook_url = "https://hooks.slack.com/services/T01234/B56789/xyz..." # 실제 값은 dev.tfvars에

  slack_channel     = "#petclinic-alerts"

  # 이메일 알림 (선택사항)
  email_endpoint = "2501340070@office.kopo.ac.kr" # 이 URL을 `../../envs/dev.tfvars`에 입력

  # Lambda 설정
  log_retention_days = 14

  # 테스트 설정
  create_test_alarm = true

  tags = local.layer_common_tags
}
```

---

## 문제 해결

### 문제 1: Slack 알림이 오지 않음
```
테스트 알람 발생시켰는데 Slack에 메시지 없음
```

**디버깅**:

1. **Lambda 로그 확인**
```bash
# 최신 로그 확인
aws logs tail /aws/lambda/petclinic-dev-slack-notifier --follow

# 에러 메시지 확인
# "Webhook URL is invalid" → Webhook URL 재확인
# "Connection timeout" → 네트워크 문제
```

2. **Webhook URL 테스트**
```bash
curl -X POST https://hooks.slack.com/services/T.../B.../xyz... \
  -H 'Content-Type: application/json' \
  -d '{"text":"테스트"}'

# 응답: "ok" → Webhook 정상
# 응답: "invalid_payload" → URL 오류
```

3. **Lambda 환경변수 확인**
```bash
aws lambda get-function-configuration \
  --function-name petclinic-dev-slack-notifier \
  --query 'Environment.Variables'

# SLACK_WEBHOOK_URL이 올바른지 확인
```

---

### 문제 2: Lambda 함수 에러
```
Lambda logs show error: "Unable to import module 'app'"
```

**원인**: Lambda 코드 배포 실패

**해결**:
```bash
# Lambda 함수 상태 확인
aws lambda get-function \
  --function-name petclinic-dev-slack-notifier

# 코드 재배포 (모듈에서 자동 처리)
cd ../../modules/notification
terraform apply
```

---

### 문제 3: SNS 구독 확인 이메일 미수신
```
이메일 알림 설정했는데 확인 이메일 안 옴
```

**해결**:
```bash
# SNS 구독 상태 확인
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-west-2:...:petclinic-dev-alerts

# 출력:
# Protocol: email
# Endpoint: admin@example.com
# SubscriptionArn: PendingConfirmation  ← 확인 대기 중

# 해결: 이메일 스팸함 확인 또는 재구독
terraform apply -var-file=../../envs/dev.tfvars
```

---

### 문제 4: 알람이 SNS로 전송되지 않음
```
CloudWatch 알람 발생했는데 SNS 메시지 없음
```

**원인**: 알람에 SNS 연결 안 됨

**해결**:
```bash
# 알람에 SNS 액션 추가
aws cloudwatch put-metric-alarm \
  --alarm-name "petclinic-dev-api-4xx-error-rate" \
  --alarm-actions "arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts" \
  --region us-west-2

# Terraform으로 추가
# 08-api-gateway/main.tf 수정:
alarm_actions = [data.terraform_remote_state.notification.outputs.sns_topic_arn]
```

---

### 디버깅 명령어

```bash
# SNS 토픽 확인
aws sns get-topic-attributes \
  --topic-arn arn:aws:sns:us-west-2:...:petclinic-dev-alerts

# Lambda 함수 확인
aws lambda get-function \
  --function-name petclinic-dev-slack-notifier

# Lambda 로그 실시간 모니터링
aws logs tail /aws/lambda/petclinic-dev-slack-notifier --follow

# SNS 구독자 목록
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-west-2:...:petclinic-dev-alerts

# CloudWatch 알람 목록 (SNS 연결된 알람만)
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[?contains(AlarmActions, `petclinic-dev-alerts`)].[AlarmName]' \
  --output table
```

---

## 비용 예상

### 주요 비용 요소

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| **SNS** | 1,000 알림/월 | $0.00 (100만건까지 무료) |
| **Lambda 호출** | 1,000 호출/월 | $0.00 (100만건까지 무료) |
| **Lambda 실행 시간** | 128MB × 1초 | $0.00 (40만 GB-초까지 무료) |
| **CloudWatch Logs** | 1GB | $0.50 ($0.50/GB) |
| **합계** | - | **$0.50** |

**비용 최적화 팁**:
- Lambda 메모리: 128MB (최소) → 충분
- 로그 보관: 14일 → 7일 (필요시)
- 불필요한 알람 정리 → 알림 수 감소

---

## 베스트 프랙티스

### 1. 알람 우선순위 설정 🎯
```
Critical (즉시 대응):
- 5XX 에러
- Lambda 에러
- Aurora 장애

Warning (모니터링):
- 4XX 에러
- CPU 80% 이상
- 메모리 80% 이상

Info (참고):
- 배포 알림
- 스케일링 이벤트
```

### 2. 알림 채널 분리 📢
```
#petclinic-alerts-critical → P0, P1 알람
#petclinic-alerts-warning  → P2, P3 알람
#petclinic-alerts-info     → 정보성 알림
```

### 3. On-Call 로테이션 👥
```
Slack 사용자 그룹 활용:
@petclinic-oncall → 당직자 그룹
@petclinic-team   → 전체 팀원

알람 메시지에 멘션 추가:
"@petclinic-oncall 즉시 확인 필요!"
```

### 4. 알람 대응 플레이북 📖
```
Slack 채널 설명에 플레이북 링크 추가:
#petclinic-alerts

Channel Description:
PetClinic AWS 알람 알림
📖 Playbook: https://wiki.example.com/petclinic-playbook
🔗 Dashboard: https://cloudwatch.aws.amazon.com/...
```

---

## 다음 단계

Notification 레이어 배포가 완료되면:

1. **10-monitoring 알람 연결**: CloudWatch 알람에 SNS 추가
2. **알람 임계값 튜닝**: 실제 트래픽 패턴에 맞게 조정
3. **추가 알림 채널**: PagerDuty, OpsGenie 통합
4. **자동 복구**: Lambda로 자동 대응 구현

```bash
# 10-monitoring 레이어에서 SNS 연결
cd ../10-monitoring
# main.tf 수정: alarm_actions 추가
terraform apply -var-file=../../envs/dev.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **SNS**: 메시지 발행/구독 서비스
- ✅ **Lambda**: Slack Webhook 호출
- ✅ **Slack Webhook**: 외부에서 Slack으로 메시지 전송
- ✅ **CloudWatch 알람**: SNS로 메시지 발행

### 생성되는 주요 리소스
- SNS 토픽 1개 (petclinic-dev-alerts)
- Lambda 함수 1개 (Slack Notifier)
- CloudWatch Log Group 1개
- 테스트 알람 1개 (선택)

### 알림 흐름
```
CloudWatch 알람 발생
    ↓
SNS 토픽으로 메시지 발행
    ↓
Lambda 함수 트리거
    ↓
Slack Webhook 호출
    ↓
Slack 채널에 메시지 표시
```

### 설정 필수 항목
```bash
# ../../envs/dev.tfvars
slack_webhook_url = "https://hooks.slack.com/services/..."  # 필수!
slack_channel     = "#petclinic-alerts"
```

---

**작성일**: 2025-11-09  
**작성자**: 황영현 
**버전**: 1.0
