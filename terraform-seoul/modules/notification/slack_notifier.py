#!/usr/bin/env python3
"""
Slack 알림 Lambda 함수
CloudWatch 알람을 Slack으로 전송
"""

import json
import urllib3
import os
from datetime import datetime

# 환경 변수
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL')
SLACK_CHANNEL = os.environ.get('SLACK_CHANNEL', '#alerts')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'petclinic')

def lambda_handler(event, context):
    """
    Lambda 함수 메인 핸들러
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # SNS 메시지 파싱
        for record in event['Records']:
            if record['EventSource'] == 'aws:sns':
                message = json.loads(record['Sns']['Message'])
                send_slack_notification(message)
        
        return {
            'statusCode': 200,
            'body': json.dumps('알림 전송 완료')
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'알림 전송 실패: {str(e)}')
        }

def send_slack_notification(alarm_data):
    """
    Slack으로 알람 메시지 전송
    """
    if not SLACK_WEBHOOK_URL:
        print("SLACK_WEBHOOK_URL이 설정되지 않았습니다.")
        return
    
    # 알람 정보 추출
    alarm_name = alarm_data.get('AlarmName', 'Unknown Alarm')
    alarm_description = alarm_data.get('AlarmDescription', '')
    new_state = alarm_data.get('NewStateValue', 'UNKNOWN')
    old_state = alarm_data.get('OldStateValue', 'UNKNOWN')
    reason = alarm_data.get('NewStateReason', '')
    timestamp = alarm_data.get('StateChangeTime', '')
    region = alarm_data.get('Region', 'us-west-2')
    
    # 알람 상태에 따른 색상 및 이모지 설정
    if new_state == 'ALARM':
        color = '#FF0000'  # 빨간색
        emoji = '🚨'
        state_text = '알람 발생'
    elif new_state == 'OK':
        color = '#00FF00'  # 초록색
        emoji = '✅'
        state_text = '정상 복구'
    else:
        color = '#FFA500'  # 주황색
        emoji = '⚠️'
        state_text = '데이터 부족'
    
    # 타임스탬프 포맷팅
    try:
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        formatted_time = dt.strftime('%Y-%m-%d %H:%M:%S UTC')
    except:
        formatted_time = timestamp
    
    # Slack 메시지 구성
    slack_message = {
        "channel": SLACK_CHANNEL,
        "username": f"AWS CloudWatch ({ENVIRONMENT.upper()})",
        "icon_emoji": ":warning:",
        "attachments": [
            {
                "color": color,
                "title": f"{emoji} {state_text}: {alarm_name}",
                "fields": [
                    {
                        "title": "프로젝트",
                        "value": PROJECT_NAME.upper(),
                        "short": True
                    },
                    {
                        "title": "환경",
                        "value": ENVIRONMENT.upper(),
                        "short": True
                    },
                    {
                        "title": "리전",
                        "value": region,
                        "short": True
                    },
                    {
                        "title": "상태 변화",
                        "value": f"{old_state} → {new_state}",
                        "short": True
                    },
                    {
                        "title": "설명",
                        "value": alarm_description or "설명 없음",
                        "short": False
                    },
                    {
                        "title": "원인",
                        "value": reason,
                        "short": False
                    },
                    {
                        "title": "발생 시간",
                        "value": formatted_time,
                        "short": False
                    }
                ],
                "footer": "AWS CloudWatch",
                "footer_icon": "https://aws.amazon.com/favicon.ico",
                "ts": int(datetime.now().timestamp())
            }
        ]
    }
    
    # 추가 액션 버튼 (선택사항)
    if new_state == 'ALARM':
        slack_message["attachments"][0]["actions"] = [
            {
                "type": "button",
                "text": "CloudWatch 콘솔 열기",
                "url": f"https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#alarmsV2:alarm/{alarm_name}"
            }
        ]
    
    # Slack으로 메시지 전송
    http = urllib3.PoolManager()
    
    try:
        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=json.dumps(slack_message),
            headers={'Content-Type': 'application/json'}
        )
        
        if response.status == 200:
            print(f"Slack 알림 전송 성공: {alarm_name}")
        else:
            print(f"Slack 알림 전송 실패: {response.status} - {response.data}")
    
    except Exception as e:
        print(f"Slack 전송 중 오류: {str(e)}")

def format_metric_data(alarm_data):
    """
    메트릭 데이터 포맷팅 (추가 정보 표시용)
    """
    trigger = alarm_data.get('Trigger', {})
    
    if not trigger:
        return "메트릭 정보 없음"
    
    metric_name = trigger.get('MetricName', 'Unknown')
    namespace = trigger.get('Namespace', 'Unknown')
    threshold = trigger.get('Threshold', 'Unknown')
    comparison = trigger.get('ComparisonOperator', 'Unknown')
    
    return f"메트릭: {namespace}/{metric_name}\n임계값: {comparison} {threshold}"

# 테스트용 함수
if __name__ == "__main__":
    # 로컬 테스트용 샘플 이벤트
    test_event = {
        "Records": [
            {
                "EventSource": "aws:sns",
                "Sns": {
                    "Message": json.dumps({
                        "AlarmName": "petclinic-dev-api-4xx-error-rate",
                        "AlarmDescription": "API Gateway 4XX 에러율이 임계값을 초과했습니다",
                        "NewStateValue": "ALARM",
                        "OldStateValue": "OK",
                        "NewStateReason": "Threshold Crossed: 1 out of the last 1 datapoints [25.0 (28/10/24 10:30:00)] was greater than the threshold (20.0) (minimum 1 datapoint for OK -> ALARM transition).",
                        "StateChangeTime": "2024-10-28T10:30:00.000+0000",
                        "Region": "us-west-2"
                    })
                }
            }
        ]
    }
    
    # 환경 변수 설정 (테스트용 - 실제 값은 환경 변수에서 로드)
    os.environ['SLACK_WEBHOOK_URL'] = os.environ.get('SLACK_WEBHOOK_URL', 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL')
    os.environ['SLACK_CHANNEL'] = os.environ.get('SLACK_CHANNEL', '#petclinic-alerts')
    os.environ['ENVIRONMENT'] = 'dev'
    os.environ['PROJECT_NAME'] = 'petclinic'
    
    # 테스트 실행
    result = lambda_handler(test_event, None)
    print(f"Test result: {result}")