# 🔔 알림 시스템 설정 가이드

## 개요

PetClinic 프로젝트의 CloudWatch 알람을 Slack으로 전송하는 알림 시스템 설정 가이드입니다.

## 아키텍처

```
CloudWatch Alarms → SNS Topic → Lambda Function → Slack
                              ↘ Email (선택사항)
```

## 1. Slack Webhook URL 생성

### 1.1 Slack App 생성
1. [Slack API](https://api.slack.com/apps) 접속
2. "Create New App" → "From scratch" 선택
3. App 이름: `PetClinic Alerts`
4. Workspace 선택

### 1.2 Incoming Webhook 활성화
1. 생성된 앱에서 "Incoming Webhooks" 선택
2. "Activate Incoming Webhooks" 토글 ON
3. "Add New Webhook to Workspace" 클릭
4. 알림을 받을 채널 선택 (예: `#petclinic-alerts`)
5. Webhook URL 복사 (예: `https://hooks.slack.com/services/YOUR/TEAM/CHANNEL`)

## 2. 알림 시스템 배포

### 2.1 환경 변수 설정
`terraform/envs/dev.tfvars` 파일에 Slack 설정 추가:

```hcl
# Slack 알림 설정
slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
slack_channel     = "#petclinic-alerts"
email_endpoint    = "admin@yourcompany.com"  # 선택사항

# 테스트 설정 (개발 환경에서만)
create_test_alarm = true
```

### 2.2 알림 레이어 배포
```bash
cd terraform/layers/12-notification

# 초기화
terraform init -backend-config="../../backend.hcl" -backend-config="backend.config"

# 계획 확인
terraform plan -var-file="../../envs/dev.tfvars"

# 배포
terraform apply -var-file="../../envs/dev.tfvars"
```

### 2.3 SNS 토픽 ARN 확인
배포 완료 후 출력되는 SNS 토픽 ARN을 복사:
```bash
terraform output sns_topic_arn
# 출력 예: arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts
```

## 3. 다른 레이어에 알림 연결

### 3.1 dev.tfvars 업데이트
SNS 토픽 ARN을 `alarm_actions`에 추가:

```hcl
# 알람 액션
alarm_actions = ["arn:aws:sns:us-west-2:123456789012:petclinic-dev-alerts"]
```

### 3.2 기존 레이어 재배포
알림이 필요한 레이어들을 재배포:

```bash
# API Gateway 레이어
cd terraform/layers/08-api-gateway
terraform apply -var-file="../../envs/dev.tfvars"

# Application 레이어 (ALB 알람)
cd terraform/layers/07-application
terraform apply -var-file="../../envs/dev.tfvars"

# Monitoring 레이어
cd terraform/layers/10-monitoring
terraform apply -var-file="../../envs/dev.tfvars"
```

## 4. 알림 테스트

### 4.1 테스트 알람 발생
개발 환경에서 테스트 알람을 수동으로 발생시킬 수 있습니다:

```bash
# CloudWatch에서 테스트 메트릭 전송
aws cloudwatch put-metric-data \
  --namespace "Custom/Test" \
  --metric-data MetricName=TestMetric,Value=1,Unit=Count \
  --region us-west-2
```

### 4.2 Slack 알림 확인
- Slack 채널에서 알림 메시지 확인
- 알람 상태, 시간, 원인 등 정보 포함
- CloudWatch 콘솔 링크 제공

## 5. 알림 메시지 예시

### 알람 발생 시
```
🚨 알람 발생: petclinic-dev-api-4xx-error-rate

프로젝트: PETCLINIC
환경: DEV
리전: us-west-2
상태 변화: OK → ALARM

설명: API Gateway 4XX 에러율이 임계값을 초과했습니다
원인: Threshold Crossed: 25.0 > 20.0
발생 시간: 2024-10-28 10:30:00 UTC

[CloudWatch 콘솔 열기]
```

### 정상 복구 시
```
✅ 정상 복구: petclinic-dev-api-4xx-error-rate

프로젝트: PETCLINIC
환경: DEV
상태 변화: ALARM → OK

발생 시간: 2024-10-28 10:35:00 UTC
```

## 6. 보안 고려사항

### 6.1 Webhook URL 보안
- Webhook URL은 민감한 정보로 취급
- Terraform 변수에 `sensitive = true` 설정
- AWS Secrets Manager 사용 권장 (프로덕션 환경)

### 6.2 IAM 권한 최소화
Lambda 함수는 다음 권한만 보유:
- CloudWatch Logs 쓰기
- 인터넷 접근 (Slack API 호출)

## 7. 트러블슈팅

### 7.1 Slack 알림이 오지 않는 경우
1. Webhook URL 확인
2. Lambda 함수 로그 확인:
   ```bash
   aws logs tail /aws/lambda/petclinic-dev-slack-notifier --follow
   ```
3. SNS 토픽 구독 상태 확인

### 7.2 Lambda 함수 오류
```bash
# Lambda 함수 로그 확인
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/petclinic-dev-slack-notifier"

# 최근 로그 확인
aws logs tail /aws/lambda/petclinic-dev-slack-notifier --since 1h
```

## 8. 고급 설정

### 8.1 알림 필터링
특정 알람만 Slack으로 전송하려면 Lambda 함수 코드 수정:

```python
# 중요한 알람만 필터링
if 'critical' in alarm_name.lower() or 'error' in alarm_name.lower():
    send_slack_notification(message)
```

### 8.2 다중 채널 지원
서로 다른 알람을 다른 채널로 전송:

```python
# 알람 유형별 채널 분기
if 'security' in alarm_name.lower():
    channel = '#security-alerts'
elif 'performance' in alarm_name.lower():
    channel = '#performance-alerts'
else:
    channel = '#general-alerts'
```

## 9. 정리 (Clean Up)

알림 시스템 제거:
```bash
cd terraform/layers/12-notification
terraform destroy -var-file="../../envs/dev.tfvars"
```

---

**참고**: 프로덕션 환경에서는 Webhook URL을 AWS Secrets Manager에 저장하고 Lambda 함수에서 동적으로 가져오는 것을 권장합니다.