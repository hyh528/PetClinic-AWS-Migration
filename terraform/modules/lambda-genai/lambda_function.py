"""
GenAI Lambda 함수 - Amazon Bedrock과 통합하여 AI 기능 제공
기존 GenAI ECS 서비스를 대체하는 서버리스 구현
"""

import json
import logging
import os
import boto3
from typing import Dict, Any, Optional
import traceback

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(os.getenv('LOG_LEVEL', 'INFO'))

# Bedrock 클라이언트 초기화 (전역 변수로 재사용)
bedrock_client = None

def get_bedrock_client():
    """Bedrock 클라이언트 싱글톤 패턴으로 초기화"""
    global bedrock_client
    if bedrock_client is None:
        try:
            bedrock_client = boto3.client(
                'bedrock-runtime',
                region_name=os.getenv('AWS_REGION', '${aws_region}')
            )
            logger.info("Bedrock 클라이언트 초기화 완료")
        except Exception as e:
            logger.error(f"Bedrock 클라이언트 초기화 실패: {str(e)}")
            raise
    return bedrock_client

def create_response(status_code: int, body: Dict[str, Any], headers: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    """API Gateway 응답 형식 생성"""
    default_headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
    
    if headers:
        default_headers.update(headers)
    
    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body, ensure_ascii=False)
    }

def invoke_bedrock_model(prompt: str, model_id: str = None) -> Dict[str, Any]:
    """Bedrock 모델 호출"""
    if model_id is None:
        model_id = os.getenv('BEDROCK_MODEL_ID', '${bedrock_model_id}')
    
    try:
        client = get_bedrock_client()
        
        # Claude 3 Sonnet 모델용 요청 페이로드
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "temperature": 0.7,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }
        
        logger.info(f"Bedrock 모델 호출: {model_id}")
        logger.debug(f"요청 페이로드: {json.dumps(request_body, ensure_ascii=False)}")
        
        response = client.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body),
            contentType='application/json',
            accept='application/json'
        )
        
        # 응답 파싱
        response_body = json.loads(response['body'].read())
        logger.info("Bedrock 모델 호출 성공")
        logger.debug(f"응답: {json.dumps(response_body, ensure_ascii=False)}")
        
        return {
            'success': True,
            'content': response_body.get('content', [{}])[0].get('text', ''),
            'usage': response_body.get('usage', {}),
            'model_id': model_id
        }
        
    except Exception as e:
        logger.error(f"Bedrock 모델 호출 실패: {str(e)}")
        logger.error(f"스택 트레이스: {traceback.format_exc()}")
        return {
            'success': False,
            'error': str(e),
            'model_id': model_id
        }

def handle_chat_request(event_body: Dict[str, Any]) -> Dict[str, Any]:
    """채팅 요청 처리"""
    try:
        message = event_body.get('message', '')
        if not message:
            return create_response(400, {
                'error': 'message 필드가 필요합니다',
                'code': 'MISSING_MESSAGE'
            })
        
        # 시스템 프롬프트 추가 (PetClinic 컨텍스트)
        system_prompt = """당신은 PetClinic 애플리케이션의 AI 어시스턴트입니다. 
반려동물 건강, 수의학, 애완동물 관리에 대한 도움을 제공합니다.
친근하고 전문적인 톤으로 답변해주세요."""
        
        full_prompt = f"{system_prompt}\n\n사용자 질문: {message}"
        
        # Bedrock 모델 호출
        result = invoke_bedrock_model(full_prompt)
        
        if result['success']:
            return create_response(200, {
                'response': result['content'],
                'model_id': result['model_id'],
                'usage': result.get('usage', {}),
                'timestamp': event_body.get('timestamp')
            })
        else:
            return create_response(500, {
                'error': 'AI 모델 호출 중 오류가 발생했습니다',
                'code': 'MODEL_INVOCATION_ERROR',
                'details': result['error']
            })
            
    except Exception as e:
        logger.error(f"채팅 요청 처리 실패: {str(e)}")
        return create_response(500, {
            'error': '내부 서버 오류가 발생했습니다',
            'code': 'INTERNAL_SERVER_ERROR'
        })

def handle_health_check() -> Dict[str, Any]:
    """헬스체크 처리"""
    try:
        # Bedrock 클라이언트 연결 테스트
        client = get_bedrock_client()
        
        return create_response(200, {
            'status': 'healthy',
            'service': 'genai-lambda',
            'version': '1.0.0',
            'bedrock_model': os.getenv('BEDROCK_MODEL_ID', '${bedrock_model_id}'),
            'timestamp': None  # 실제 구현에서는 현재 시간 추가
        })
    except Exception as e:
        logger.error(f"헬스체크 실패: {str(e)}")
        return create_response(503, {
            'status': 'unhealthy',
            'error': str(e),
            'code': 'HEALTH_CHECK_FAILED'
        })

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda 함수 메인 핸들러"""
    try:
        logger.info(f"Lambda 함수 호출: {json.dumps(event, ensure_ascii=False)}")
        
        # HTTP 메서드 확인
        http_method = event.get('httpMethod', 'GET')
        path = event.get('path', '/')
        
        # CORS preflight 요청 처리
        if http_method == 'OPTIONS':
            return create_response(200, {'message': 'CORS preflight'})
        
        # 헬스체크 요청 처리
        if path.endswith('/health') or path.endswith('/actuator/health'):
            return handle_health_check()
        
        # POST 요청만 처리 (채팅)
        if http_method != 'POST':
            return create_response(405, {
                'error': 'POST 메서드만 지원됩니다',
                'code': 'METHOD_NOT_ALLOWED'
            })
        
        # 요청 본문 파싱
        try:
            if event.get('body'):
                if event.get('isBase64Encoded', False):
                    import base64
                    body = json.loads(base64.b64decode(event['body']).decode('utf-8'))
                else:
                    body = json.loads(event['body'])
            else:
                body = {}
        except json.JSONDecodeError as e:
            logger.error(f"JSON 파싱 오류: {str(e)}")
            return create_response(400, {
                'error': '잘못된 JSON 형식입니다',
                'code': 'INVALID_JSON'
            })
        
        # 채팅 요청 처리
        return handle_chat_request(body)
        
    except Exception as e:
        logger.error(f"Lambda 함수 실행 중 예상치 못한 오류: {str(e)}")
        logger.error(f"스택 트레이스: {traceback.format_exc()}")
        
        return create_response(500, {
            'error': '내부 서버 오류가 발생했습니다',
            'code': 'INTERNAL_SERVER_ERROR',
            'request_id': context.aws_request_id if context else None
        })