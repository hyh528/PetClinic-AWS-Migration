#!/bin/bash

# =============================================================================
# 알림 시스템 테스트 스크립트
# =============================================================================
# 목적: SNS + Lambda Slack 알림 시스템이 정상 작동하는지 테스트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 기본 설정
REGION="us-west-2"
ENVIRONMENT="dev"
PROJECT_NAME="petclinic"

# 함수 정의
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# 메인 함수
main() {
    print_header "PetClinic 알림 시스템 테스트"
    
    # 1. AWS CLI 설정 확인
    check_aws_cli
    
    # 2. SNS 토픽 확인
    check_sns_topic
    
    # 3. Lambda 함수 확인
    check_lambda_function
    
    # 4. 테스트 알람 발생
    test_alarm_notification
    
    # 5. CloudWatch 알람 상태 확인
    check_cloudwatch_alarms
    
    print_header "테스트 완료"
    print_success "모든 테스트가 완료되었습니다."
    print_info "Slack 채널에서 알림 메시지를 확인하세요."
}

# AWS CLI 설정 확인
check_aws_cli() {
    print_info "AWS CLI 설정 확인 중..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # AWS 계정 정보 확인
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    if [ -z "$ACCOUNT_ID" ]; then
        print_error "AWS 자격 증명이 설정되지 않았습니다."
        exit 1
    fi
    
    print_success "AWS CLI 설정 완료 (계정: $ACCOUNT_ID, 리전: $REGION)"
}

# SNS 토픽 확인
check_sns_topic() {
    print_info "SNS 토픽 확인 중..."
    
    TOPIC_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alerts"
    TOPIC_ARN=$(aws sns list-topics --region $REGION --query "Topics[?contains(TopicArn, '$TOPIC_NAME')].TopicArn" --output text)
    
    if [ -z "$TOPIC_ARN" ]; then
        print_error "SNS 토픽을 찾을 수 없습니다: $TOPIC_NAME"
        print_info "12-notification 레이어를 먼저 배포하세요."
        exit 1
    fi
    
    print_success "SNS 토픽 확인 완료: $TOPIC_ARN"
    
    # 구독 확인
    SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region $REGION --query "Subscriptions[].Protocol" --output text)
    if [[ "$SUBSCRIPTIONS" == *"lambda"* ]]; then
        print_success "Lambda 구독 확인 완료"
    else
        print_warning "Lambda 구독이 설정되지 않았습니다."
    fi
}

# Lambda 함수 확인
check_lambda_function() {
    print_info "Lambda 함수 확인 중..."
    
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-slack-notifier"
    
    # Lambda 함수 존재 확인
    if aws lambda get-function --function-name "$FUNCTION_NAME" --region $REGION &>/dev/null; then
        print_success "Lambda 함수 확인 완료: $FUNCTION_NAME"
        
        # 환경 변수 확인
        ENV_VARS=$(aws lambda get-function-configuration --function-name "$FUNCTION_NAME" --region $REGION --query "Environment.Variables" --output json)
        
        if echo "$ENV_VARS" | grep -q "SLACK_WEBHOOK_URL"; then
            print_success "Slack Webhook URL 설정 확인 완료"
        else
            print_warning "Slack Webhook URL이 설정되지 않았습니다."
        fi
        
        # 최근 로그 확인
        LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
        if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region $REGION &>/dev/null; then
            print_success "Lambda 로그 그룹 확인 완료"
        else
            print_warning "Lambda 로그 그룹을 찾을 수 없습니다."
        fi
    else
        print_error "Lambda 함수를 찾을 수 없습니다: $FUNCTION_NAME"
        exit 1
    fi
}

# 테스트 알람 발생
test_alarm_notification() {
    print_info "테스트 알람 발생 중..."
    
    # 테스트 메트릭 전송
    aws cloudwatch put-metric-data \
        --namespace "Custom/Test" \
        --metric-data MetricName=TestMetric,Value=1,Unit=Count \
        --region $REGION
    
    print_success "테스트 메트릭 전송 완료"
    
    # 잠시 대기
    print_info "알람 발생 대기 중... (30초)"
    sleep 30
    
    # 테스트 알람 상태 확인
    TEST_ALARM_NAME="${PROJECT_NAME}-${ENVIRONMENT}-notification-test"
    ALARM_STATE=$(aws cloudwatch describe-alarms --alarm-names "$TEST_ALARM_NAME" --region $REGION --query "MetricAlarms[0].StateValue" --output text 2>/dev/null || echo "")
    
    if [ "$ALARM_STATE" = "ALARM" ]; then
        print_success "테스트 알람 발생 확인 완료"
        print_info "Slack 채널에서 알림 메시지를 확인하세요."
    elif [ "$ALARM_STATE" = "OK" ]; then
        print_warning "테스트 알람이 아직 발생하지 않았습니다."
    else
        print_warning "테스트 알람을 찾을 수 없습니다. create_test_alarm = true로 설정하세요."
    fi
}

# CloudWatch 알람 상태 확인
check_cloudwatch_alarms() {
    print_info "CloudWatch 알람 상태 확인 중..."
    
    # 프로젝트 관련 알람 목록 조회
    ALARMS=$(aws cloudwatch describe-alarms --region $REGION --query "MetricAlarms[?starts_with(AlarmName, '${PROJECT_NAME}-${ENVIRONMENT}')].[AlarmName,StateValue]" --output table)
    
    if [ -n "$ALARMS" ]; then
        print_success "CloudWatch 알람 목록:"
        echo "$ALARMS"
        
        # ALARM 상태인 알람 개수 확인
        ALARM_COUNT=$(aws cloudwatch describe-alarms --region $REGION --state-value ALARM --query "MetricAlarms[?starts_with(AlarmName, '${PROJECT_NAME}-${ENVIRONMENT}')]" --output json | jq length)
        
        if [ "$ALARM_COUNT" -gt 0 ]; then
            print_warning "$ALARM_COUNT 개의 알람이 현재 ALARM 상태입니다."
        else
            print_success "모든 알람이 정상 상태입니다."
        fi
    else
        print_warning "CloudWatch 알람을 찾을 수 없습니다."
    fi
}

# Lambda 함수 로그 확인 (선택사항)
check_lambda_logs() {
    print_info "Lambda 함수 로그 확인 중..."
    
    FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-slack-notifier"
    LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
    
    # 최근 1시간 로그 확인
    RECENT_LOGS=$(aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --start-time $(date -d '1 hour ago' +%s)000 \
        --region $REGION \
        --query "events[].message" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$RECENT_LOGS" ]; then
        print_success "최근 Lambda 실행 로그:"
        echo "$RECENT_LOGS" | tail -10
    else
        print_info "최근 Lambda 실행 로그가 없습니다."
    fi
}

# 도움말 표시
show_help() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -r, --region REGION    AWS 리전 설정 (기본값: us-west-2)"
    echo "  -e, --env ENVIRONMENT  환경 설정 (기본값: dev)"
    echo "  -p, --project PROJECT  프로젝트 이름 (기본값: petclinic)"
    echo "  -l, --logs            Lambda 함수 로그도 확인"
    echo "  -h, --help            이 도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0                     # 기본 설정으로 테스트"
    echo "  $0 -r ap-northeast-2   # 서울 리전에서 테스트"
    echo "  $0 -e prod -l          # 프로덕션 환경에서 로그와 함께 테스트"
}

# 명령행 인수 처리
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -l|--logs)
            CHECK_LOGS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "알 수 없는 옵션: $1"
            show_help
            exit 1
            ;;
    esac
done

# 메인 함수 실행
main

# 로그 확인 (옵션)
if [ "$CHECK_LOGS" = true ]; then
    check_lambda_logs
fi

print_header "테스트 스크립트 완료"
print_info "추가 정보:"
print_info "- Slack 채널: #${PROJECT_NAME}-alerts"
print_info "- CloudWatch 콘솔: https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#alarmsV2:"
print_info "- Lambda 콘솔: https://${REGION}.console.aws.amazon.com/lambda/home?region=${REGION}#/functions/${PROJECT_NAME}-${ENVIRONMENT}-slack-notifier"