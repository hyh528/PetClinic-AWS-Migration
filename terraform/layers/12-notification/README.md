# 12-Notification 레이어 - 알림 시스템

## 개요

12-notification 레이어는 CloudWatch 알람을 Slack으로 자동 전송하는 알림 시스템을 구축합니다. SNS + Lambda를 활용하여 실시간 모니터링 알림을 제공합니다.

## 아키텍처

```
CloudWatch Alarm → SNS Topic → Lambda Function → Slack Webhook
```

## 구성 요소

### 1. SNS 토픽 (`petclinic-dev-alerts`)
- CloudWatch 알람 메시지를 수신
- Lambda 함수로 메시지 전달
- 이메일 알림도 지원 (선택사항)

### 2. Lambda 함수 (`petclinic-dev-slack-notifier`)
- Python 3.11 런타임
- Slack Webhook을 통해 메시지 전송
- CloudWatch 알람 데이터를 포맷팅하여 가독성 있는 메시지 생성

### 3. CloudWatch 로그 그룹
- Lambda 함수 실행 로그 저장
- 14일 보관 기간

## 배포된 알람들

### 현재 SNS 토픽에 연결된 알람들

#### 1. 테스트 알람
- **이름**: `petclinic-dev-notification-test`
- **목적**: 알림 시스템 테스트용
- **임계값**: TestMetric > 0
- **주기**: 60초
- **설명**: 알림 시스템이 정상 작동하는지 확인하는 용도
- **연결 상태**: ✅ SNS 토픽에 연결됨 (`arn:aws:sns:us-west-2:897722691159:petclinic-dev-alerts`)

### 실제 운영 알람들 (현재 연결되지 않음 - Terraform에서 alarm_actions 추가 필요)

#### API Gateway 알람들
- **4XX 에러율**: `petclinic-dev-api-4xx-error-rate`
  - 임계값: 4XX 에러 > 20회/5분
  - 설명: API Gateway 4XX 에러율이 임계값을 초과했습니다

- **5XX 에러율**: `petclinic-dev-api-5xx-error-rate`
  - 임계값: 5XX 에러 > 10회/5분
  - 설명: API Gateway 5XX 에러율이 임계값을 초과했습니다

- **응답 지연**: `petclinic-dev-api-latency`
  - 임계값: 평균 응답 시간 > 2000ms
  - 설명: API Gateway 응답 시간이 임계값을 초과했습니다

- **백엔드 지연**: `petclinic-dev-api-integration-latency`
  - 임계값: 백엔드 응답 시간 > 1500ms
  - 설명: API Gateway 백엔드 통합 응답 시간이 임계값을 초과했습니다

#### CloudFront 알람들
- **4XX 에러율**: `petclinic-dev-cloudfront-4xx-errors`
  - 임계값: 4XX 에러율 > 5%
  - 설명: CloudFront 4XX 에러율이 임계값을 초과했습니다

- **5XX 에러율**: `petclinic-dev-cloudfront-5xx-errors`
  - 임계값: 5XX 에러율 > 2%
  - 설명: CloudFront 5XX 에러율이 임계값을 초과했습니다

#### Lambda 알람들
- **GenAI 함수 에러**: `petclinic-dev-lambda-genai-errors`
  - 임계값: 에러 수 > 5회/5분
  - 설명: GenAI Lambda 함수에서 에러가 발생했습니다

## 슬랙 알림 포맷

### 알람 발생 시 메시지 예시

```
🚨 알람 발생: petclinic-dev-api-4xx-error-rate

프로젝트: PETCLINIC-DEV
환경: DEV
리전: US West (Oregon)
상태 변화: INSUFFICIENT_DATA → ALARM
설명: API Gateway 4XX 에러율이 임계값을 초과했습니다
원인: Threshold Crossed: 1 out of the last 1 datapoints [25.0 (28/10/24 10:30:00)] was greater than the threshold (20.0)
발생 시간: 2025-11-02 08:42:14 UTC

[CloudWatch 콘솔 열기] 버튼
```

### 알람 복구 시 메시지 예시

```
✅ 정상 복구: petclinic-dev-api-4xx-error-rate

프로젝트: PETCLINIC-DEV
환경: DEV
리전: US West (Oregon)
상태 변화: ALARM → OK
설명: API Gateway 4XX 에러율이 정상으로 돌아왔습니다
원인: Threshold Crossed: 1 out of the last 1 datapoints [5.0 (28/10/24 10:35:00)] was less than or equal to the threshold (20.0)
발생 시간: 2025-11-02 08:45:14 UTC
```

## 테스트 방법

### 1. 기본 테스트 (권장)

```bash
# 테스트 알람을 ALARM 상태로 변경
aws cloudwatch set-alarm-state \
  --alarm-name "petclinic-dev-notification-test" \
  --state-value ALARM \
  --state-reason "Testing notification system" \
  --profile petclinic-dev \
  --region us-west-2
```

### 2. 실제 알람 테스트

```bash
# API 4XX 에러 알람을 ALARM 상태로 변경
aws cloudwatch set-alarm-state \
  --alarm-name "petclinic-dev-api-4xx-error-rate" \
  --state-value ALARM \
  --state-reason "Testing real alarm notification" \
  --profile petclinic-dev \
  --region us-west-2
```

### 3. 직접 SNS 메시지 전송

```bash
# CloudWatch 알람 포맷의 JSON 메시지 전송
aws sns publish \
  --topic-arn "arn:aws:sns:us-west-2:897722691159:petclinic-dev-alerts" \
  --message '{
    "AlarmName": "Test-Alarm",
    "AlarmDescription": "테스트 알람입니다",
    "NewStateValue": "ALARM",
    "OldStateValue": "OK",
    "NewStateReason": "Manual test",
    "StateChangeTime": "2025-11-02T08:00:00.000+0000",
    "Region": "us-west-2"
  }' \
  --profile petclinic-dev \
  --region us-west-2
```

## 로그 확인

### Lambda 함수 로그 확인

```bash
# 최신 로그 스트림 확인
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/petclinic-dev-slack-notifier" \
  --profile petclinic-dev \
  --region us-west-2

# 특정 로그 스트림 내용 확인
aws logs get-log-events \
  --log-group-name "/aws/lambda/petclinic-dev-slack-notifier" \
  --log-stream-name "2025/11/02/[$LATEST]xxxxx" \
  --profile petclinic-dev \
  --region us-west-2
```

### 실시간 로그 모니터링

```bash
# 실시간 로그 테일링
aws logs tail \
  "/aws/lambda/petclinic-dev-slack-notifier" \
  --follow \
  --profile petclinic-dev \
  --region us-west-2
```

## 추가 알람 연결하기

### Terraform에서 알람 추가하기

```hcl
# 새로운 알람 생성 예시
resource "aws_cloudwatch_metric_alarm" "custom_alarm" {
  alarm_name          = "${var.name_prefix}-custom-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CustomMetric"
  namespace           = "Custom/Namespace"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "커스텀 메트릭 알람"
  alarm_actions       = [module.notification.sns_topic_arn]

  tags = var.tags
}
```

### 기존 알람에 SNS 연결하기

```bash
# AWS CLI로 기존 알람에 SNS 액션 추가
aws cloudwatch put-metric-alarm \
  --alarm-name "existing-alarm-name" \
  --alarm-actions "arn:aws:sns:us-west-2:897722691159:petclinic-dev-alerts" \
  --profile petclinic-dev \
  --region us-west-2
```

## 환경 변수 설정

### 필수 환경 변수

- `SLACK_WEBHOOK_URL`: Slack Incoming Webhook URL
- `SLACK_CHANNEL`: Slack 채널 이름 (예: "#petclinic-alerts")
- `ENVIRONMENT`: 환경 이름 (예: "dev", "staging", "prod")
- `PROJECT_NAME`: 프로젝트 이름 (예: "petclinic")

### 선택 환경 변수

- `SLACK_USERNAME`: Slack 메시지 사용자 이름 (기본값: "AWS CloudWatch (환경명)")

## 보안 고려사항

1. **Webhook URL 보호**: Webhook URL을 환경 변수로 관리
2. **IAM 권한 최소화**: Lambda 함수에 필요한 최소 권한만 부여
3. **로그 암호화**: CloudWatch 로그 그룹 암호화 활성화
4. **채널 권한**: Slack 채널에 봇 권한이 있는지 확인

## 모니터링 및 유지보수

### CloudWatch 대시보드

- Lambda 함수 메트릭 모니터링
- SNS 토픽 메트릭 확인
- 알람 발생 빈도 분석

### 비용 최적화

- Lambda 함수 메모리 최적화 (현재 128MB)
- 로그 보관 기간 조정 (현재 14일)
- 불필요한 알람 정리

## 문제 해결

### 알림이 오지 않는 경우

1. **Webhook URL 확인**: Slack 앱 설정에서 URL 유효성 확인
2. **채널 권한 확인**: 봇이 채널에 메시지 보낼 권한 있는지 확인
3. **Lambda 함수 상태 확인**: 함수가 정상 실행되는지 로그 확인
4. **환경 변수 확인**: 모든 필수 환경 변수가 설정되었는지 확인

### JSON 파싱 에러

- CloudWatch 알람 메시지 포맷이 변경되었을 수 있음
- Lambda 함수 코드에서 JSON 파싱 로직 검토 필요

### 권한 에러

- Lambda IAM 역할에 CloudWatch Logs 쓰기 권한 있는지 확인
- SNS 토픽 정책에서 Lambda 호출 허용되었는지 확인

## 다음 단계

1. 실제 운영 알람들을 SNS 토픽에 연결
2. 알람 임계값 튜닝
3. 추가 알림 채널 설정 (이메일, SMS 등)
4. 알람 대시보드 구축
5. 자동 복구 워크플로우 구현