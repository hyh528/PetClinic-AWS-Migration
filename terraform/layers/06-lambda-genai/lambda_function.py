"""
GenAI Lambda 함수 - Amazon Bedrock과 RDS Data API 통합
기존 GenAI ECS 서비스를 대체하는 서버리스 구현
RDS Data API를 사용하여 Aurora MySQL에 연결
"""

import json
import logging
import os
import boto3
from typing import Dict, Any, Optional, List
import traceback
from datetime import datetime

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(os.getenv('LOG_LEVEL', 'INFO'))

# AWS 클라이언트 초기화 (전역 변수로 재사용)
bedrock_client = None
rds_data_client = None

def get_bedrock_client():
    """Bedrock 클라이언트 초기화"""
    global bedrock_client
    if bedrock_client is None:
        try:
            bedrock_client = boto3.client('bedrock-runtime', region_name='us-west-2')
            logger.info("Bedrock 클라이언트 초기화 성공")
        except Exception as e:
            logger.error(f"Bedrock 클라이언트 초기화 실패: {str(e)}")
            raise
    return bedrock_client

def get_rds_data_client():
    """RDS Data API 클라이언트 초기화"""
    global rds_data_client
    if rds_data_client is None:
        try:
            rds_data_client = boto3.client('rds-data', region_name='us-west-2')
            logger.info("RDS Data API 클라이언트 초기화 성공")
        except Exception as e:
            logger.error(f"RDS Data API 클라이언트 초기화 실패: {str(e)}")
            raise
    return rds_data_client

def execute_sql(database: str, sql: str, parameters: List = None) -> List[Dict]:
    """RDS Data API를 사용하여 SQL 실행"""
    try:
        client = get_rds_data_client()

        # 환경 변수에서 클러스터 ARN과 시크릿 ARN 가져오기
        cluster_arn = os.getenv('DB_CLUSTER_ARN')
        secret_arn = os.getenv('DB_SECRET_ARN')

        if not cluster_arn or not secret_arn:
            logger.error("DB_CLUSTER_ARN 또는 DB_SECRET_ARN 환경 변수가 설정되지 않았습니다")
            logger.error(f"DB_CLUSTER_ARN: {cluster_arn}")
            logger.error(f"DB_SECRET_ARN: {secret_arn}")
            return []

        # SQL 실행 파라미터 구성
        execute_params = {
            'resourceArn': cluster_arn,
            'secretArn': secret_arn,
            'database': database,
            'sql': sql,
            'includeResultMetadata': True
        }

        if parameters:
            execute_params['parameters'] = parameters

        logger.info(f"SQL 실행: {sql[:100]}...")
        logger.info(f"데이터베이스: {database}")
        logger.info(f"클러스터 ARN: {cluster_arn}")
        logger.info(f"시크릿 ARN: {secret_arn}")

        # SQL 실행
        response = client.execute_statement(**execute_params)

        # 결과 파싱
        if 'records' not in response:
            logger.info("쿼리 결과가 없습니다")
            return []

        records = response['records']
        column_metadata = response.get('columnMetadata', [])

        # 컬럼 이름 추출
        column_names = [col['name'] for col in column_metadata]
        logger.info(f"컬럼 메타데이터: {column_names}")

        # 결과를 딕셔너리 리스트로 변환
        results = []
        for record in records:
            row = {}
            for i, value in enumerate(record):
                column_name = column_names[i] if i < len(column_names) else f'col_{i}'

                # RDS Data API 응답 값 파싱
                if 'stringValue' in value:
                    row[column_name] = value['stringValue']
                elif 'longValue' in value:
                    row[column_name] = value['longValue']
                elif 'doubleValue' in value:
                    row[column_name] = value['doubleValue']
                elif 'booleanValue' in value:
                    row[column_name] = value['booleanValue']
                elif 'isNull' in value and value['isNull']:
                    row[column_name] = None
                else:
                    row[column_name] = str(value)

            results.append(row)

        logger.info(f"SQL 실행 성공: {len(results)}개 결과")
        logger.info(f"샘플 결과: {results[:2] if results else '없음'}")
        return results

    except Exception as e:
        logger.error(f"SQL 실행 오류: {str(e)}")
        logger.error(f"오류 타입: {type(e).__name__}")
        import traceback
        logger.error(f"스택 트레이스: {traceback.format_exc()}")
        return []

def analyze_question_type(question: str) -> Dict[str, Any]:
    """질문을 분석해서 데이터베이스 조회가 필요한지 판단"""
    try:
        client = get_bedrock_client()
        
        prompt = f"""
사용자 질문을 분석해서 다음 중 어떤 유형인지 판단해주세요:

1. DATABASE_QUERY: 특정 고객, 반려동물, 수의사, 방문 기록 등 데이터베이스에서 조회해야 하는 질문
2. GENERAL_ADVICE: 반려동물 건강, 수의학, 애완동물 관리에 대한 일반적인 상담

사용자 질문: "{question}"

다음 JSON 형식으로 응답해주세요:
{{
    "type": "DATABASE_QUERY 또는 GENERAL_ADVICE",
    "reason": "판단 근거"
}}

DATABASE_QUERY 예시:
- "10월에 건강검진 받은 개가 누구야?"
- "James Johnson이라는 고객이 있어?"
- "외과 전문 수의사는 누구야?"
- "Leo라는 이름의 반려동물 정보 알려줘"

GENERAL_ADVICE 예시:
- "강아지가 기침을 해요"
- "고양이 예방접종은 언제 해야 하나요?"
- "반려동물 건강관리 팁 알려주세요"
- "개가 먹으면 안 되는 음식은?"
"""

        messages = [{"role": "user", "content": prompt}]
        
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 500,
            "messages": messages,
            "temperature": 0.1
        }
        
        response = client.invoke_model(
            modelId="anthropic.claude-3-sonnet-20240229-v1:0",
            body=json.dumps(body),
            contentType='application/json'
        )
        
        response_body = json.loads(response['body'].read())
        ai_response = response_body['content'][0]['text']
        
        # JSON 응답 파싱
        try:
            json_start = ai_response.find('{')
            json_end = ai_response.rfind('}') + 1
            json_str = ai_response[json_start:json_end]
            
            analysis = json.loads(json_str)
            logger.info(f"질문 유형 분석: {analysis.get('type', 'UNKNOWN')}")
            return analysis
            
        except json.JSONDecodeError as e:
            logger.error(f"질문 분석 JSON 파싱 실패: {str(e)}")
            return {"type": "GENERAL_ADVICE", "reason": "파싱 실패로 기본값 사용"}
            
    except Exception as e:
        logger.error(f"질문 분석 실패: {str(e)}")
        return {"type": "GENERAL_ADVICE", "reason": "분석 실패로 기본값 사용"}

def generate_sql_from_question(question: str) -> Dict[str, Any]:
    """AI를 사용해서 질문을 분석하고 적절한 SQL 쿼리 생성"""
    try:
        client = get_bedrock_client()
        
        # 데이터베이스 스키마 정보
        schema_info = """
PetClinic 데이터베이스 스키마:

petclinic 데이터베이스 (단일 데이터베이스):
- owners 테이블: id, first_name, last_name, address, city, telephone
- pets 테이블: id, name, birth_date, type_id, owner_id
- types 테이블: id, name (예: dog, cat, bird 등)
- vets 테이블: id, first_name, last_name
- specialties 테이블: id, name (예: radiology, surgery, dentistry)
- vet_specialties 테이블: vet_id, specialty_id
- visits 테이블: id, pet_id, visit_date, description
"""

        prompt = f"""
다음 데이터베이스 스키마를 참고해서 사용자 질문에 맞는 SQL 쿼리를 생성해주세요:

{schema_info}

사용자 질문: "{question}"

다음 JSON 형식으로 응답해주세요:
{{
    "database": "사용할 데이터베이스 이름 (petclinic)",
    "sql": "실행할 SQL 쿼리",
    "description": "쿼리에 대한 간단한 설명"
}}

중요 지침:
- 반드시 아래 예시와 정확히 일치하는 패턴의 SQL 쿼리를 생성하세요
- WHERE 조건을 정확히 사용하세요
- 불필요한 JOIN은 피하세요

질문 유형별 SQL 예시 (반드시 이 패턴을 따르세요):

질문: "Coco라는 반려동물을 키우는 사람은 누구야?"
SQL: "SELECT o.first_name, o.last_name FROM owners o JOIN pets p ON o.id = p.owner_id WHERE p.name = 'Coco'"

질문: "Yeonghyeon Hwang의 펫 이름은 뭐야?"
SQL: "SELECT p.name as pet_name FROM pets p JOIN owners o ON p.owner_id = o.id WHERE o.first_name = 'Yeonghyeon' AND o.last_name = 'Hwang'"

질문: "고양이를 키우는 사람은 누구야?"
SQL: "SELECT DISTINCT o.first_name, o.last_name FROM owners o JOIN pets p ON o.id = p.owner_id JOIN types t ON p.type_id = t.id WHERE t.name = 'cat'"

주의사항:
- LIMIT 20을 추가해서 결과를 제한하세요
- 반려동물 이름을 물어보면 p.name (펫 이름)만 선택하세요
- 주인 이름을 물어보면 o.first_name, o.last_name를 선택하세요
"""

        messages = [{"role": "user", "content": prompt}]
        
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": messages,
            "temperature": 0.1
        }
        
        response = client.invoke_model(
            modelId="anthropic.claude-3-sonnet-20240229-v1:0",
            body=json.dumps(body),
            contentType='application/json'
        )
        
        response_body = json.loads(response['body'].read())
        ai_response = response_body['content'][0]['text']
        
        # JSON 응답 파싱
        try:
            # JSON 부분만 추출 (```json 태그 제거)
            json_start = ai_response.find('{')
            json_end = ai_response.rfind('}') + 1
            json_str = ai_response[json_start:json_end]
            
            sql_info = json.loads(json_str)
            logger.info(f"AI가 생성한 SQL: {sql_info.get('sql', '')[:100]}...")
            return sql_info
            
        except json.JSONDecodeError as e:
            logger.error(f"AI 응답 JSON 파싱 실패: {str(e)}")
            return get_fallback_query(question)
            
    except Exception as e:
        logger.error(f"AI SQL 생성 실패: {str(e)}")
        return get_fallback_query(question)

def get_fallback_query(question: str) -> Dict[str, Any]:
    """AI 실패 시 기본 쿼리 반환"""
    return {
        "database": "petclinic",
        "sql": """
            SELECT o.first_name, o.last_name, p.name as pet_name, t.name as pet_type
            FROM owners o
            JOIN pets p ON o.id = p.owner_id
            JOIN types t ON p.type_id = t.id
            ORDER BY o.last_name, o.first_name
            LIMIT 20
        """,
        "description": "전체 고객 및 반려동물 정보"
    }

def query_database_by_question(question: str) -> List[Dict]:
    """AI가 생성한 SQL로 데이터베이스 쿼리 실행"""
    try:
        logger.info(f"데이터베이스 쿼리 시작: {question}")

        # AI를 사용해서 SQL 생성
        sql_info = generate_sql_from_question(question)

        database = sql_info.get('database', 'petclinic_customers')
        sql = sql_info.get('sql', '')
        description = sql_info.get('description', '')

        logger.info(f"AI가 생성한 SQL 정보: {sql_info}")

        if not sql:
            logger.error("생성된 SQL이 없습니다")
            return []

        logger.info(f"실행할 쿼리: {description}")
        logger.info(f"실행할 SQL: {sql}")

        # SQL 실행
        results = execute_sql(database, sql)

        logger.info(f"데이터베이스 쿼리 성공: {len(results)}개 결과")
        return results

    except Exception as e:
        logger.error(f"데이터베이스 쿼리 실행 오류: {str(e)}")
        import traceback
        logger.error(f"스택 트레이스: {traceback.format_exc()}")
        return []



def call_bedrock_ai(prompt: str, context_data: str = "", is_general_advice: bool = False) -> str:
    """Bedrock AI 모델 호출"""
    try:
        client = get_bedrock_client()
        model_id = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        
        if is_general_advice:
            # 일반적인 반려동물 상담
            full_prompt = f"""당신은 PetClinic 애플리케이션의 AI 어시스턴트입니다. 반려동물 건강, 수의학, 애완동물 관리에 대한 도움을 제공합니다.

사용자 질문: {prompt}

친근하고 전문적인 톤으로 답변해주세요. 반려동물의 건강과 복지에 대한 유용한 정보를 제공하되, 응급상황이나 심각한 증상의 경우 반드시 수의사와 상담하도록 안내해주세요."""
        else:
            # 데이터베이스 기반 답변
            full_prompt = f"""다음은 데이터베이스 조회 결과입니다:

{context_data}

질문: {prompt}

이 데이터를 보고 질문에 직접 답변하세요. 간단하고 정확하게 답변하세요.

답변 예시:
- 데이터에 Yeonghyeon Hwang이 있으면: "Yeonghyeon Hwang님이 키우고 있습니다."
- 데이터에 Coco가 있으면: "Coco입니다."
- 데이터가 비어있으면: "해당 정보를 찾을 수 없습니다."

질문에 맞게 답변하세요:"""

        # Claude 3 모델용 메시지 형식
        messages = [
            {
                "role": "user",
                "content": full_prompt
            }
        ]
        
        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": messages,
            "temperature": 0.7
        }
        
        response = client.invoke_model(
            modelId=model_id,
            body=json.dumps(body),
            contentType='application/json'
        )
        
        response_body = json.loads(response['body'].read())
        
        if 'content' in response_body and len(response_body['content']) > 0:
            ai_response = response_body['content'][0]['text']
            logger.info("Bedrock AI 응답 생성 성공")
            return ai_response
        else:
            logger.error("Bedrock 응답에서 content를 찾을 수 없습니다")
            return "죄송합니다. AI 응답을 생성할 수 없습니다."
            
    except Exception as e:
        logger.error(f"Bedrock AI 호출 실패: {str(e)}")
        return f"AI 서비스 오류: {str(e)}"

def format_context_data(results: List[Dict], question: str) -> str:
    """데이터베이스 결과를 컨텍스트 문자열로 변환"""
    logger.info(f"컨텍스트 데이터 포맷팅 시작: {len(results)}개 결과")

    if not results:
        logger.warning("데이터베이스 결과가 없습니다")
        return "요청하신 정보를 데이터베이스에서 찾을 수 없습니다."

    context_data = "데이터베이스 조회 결과:\n"

    for i, row in enumerate(results):
        if i >= 50:  # 너무 많은 결과 방지
            context_data += f"... 그 외 {len(results) - i}개 더 있음\n"
            break

        # 동적으로 컬럼 정보 포맷팅
        row_info = []
        for key, value in row.items():
            if value is not None:
                if key == 'visit_date':
                    row_info.append(f"방문일: {value}")
                elif key == 'description':
                    row_info.append(f"내용: {value}")
                elif key in ['first_name', 'last_name']:
                    continue  # 이름은 따로 처리
                elif 'name' in key:
                    row_info.append(f"{key}: {value}")
                else:
                    row_info.append(f"{key}: {value}")

        # 이름 정보 우선 처리
        name_parts = []
        if 'first_name' in row and 'last_name' in row:
            name_parts.append(f"{row['first_name']} {row['last_name']}")
        elif 'owner_name' in row:
            name_parts.append(row['owner_name'])

        if name_parts:
            row_info.insert(0, name_parts[0])

        formatted_row = f"- {' | '.join(row_info)}\n"
        context_data += formatted_row
        logger.debug(f"포맷된 행: {formatted_row.strip()}")

    logger.info(f"컨텍스트 데이터 생성 완료: {len(context_data)}자")
    return context_data

def lambda_handler(event, context):
    """Lambda 함수 메인 핸들러"""
    try:
        logger.info(f"Lambda 함수 시작 - Request ID: {context.aws_request_id}")
        
        # HTTP 요청 처리
        if 'httpMethod' in event:
            method = event['httpMethod']
            path = event.get('path', '')
            
            if method == 'GET' and path == '/health':
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'status': 'healthy',
                        'service': 'genai-lambda',
                        'data_api_enabled': True,
                        'timestamp': context.aws_request_id
                    })
                }
            
            elif method == 'POST' and '/genai' in path:
                # POST 요청 본문 파싱
                body = event.get('body', '{}')
                
                # Base64 디코딩 처리
                if event.get('isBase64Encoded', False):
                    import base64
                    body = base64.b64decode(body).decode('utf-8')
                
                if isinstance(body, str):
                    try:
                        body = json.loads(body)
                    except json.JSONDecodeError as e:
                        logger.error(f"JSON 파싱 오류: {str(e)}")
                        body = {}
                
                question = body.get('question', '')
                
                if not question:
                    return {
                        'statusCode': 400,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({
                            'error': 'Bad Request',
                            'message': 'question 파라미터가 필요합니다.'
                        })
                    }
                
                # 질문 유형 분석
                question_analysis = analyze_question_type(question)
                question_type = question_analysis.get('type', 'GENERAL_ADVICE')
                
                if question_type == 'DATABASE_QUERY':
                    # 데이터베이스 조회가 필요한 질문
                    logger.info(f"데이터베이스 쿼리 유형으로 분류됨: {question}")
                    try:
                        db_results = query_database_by_question(question)
                        logger.info(f"데이터베이스 쿼리 결과: {len(db_results)}개")
                        context_data = format_context_data(db_results, question)
                        logger.info(f"컨텍스트 데이터 생성됨: {len(context_data)}자")
                        ai_response = call_bedrock_ai(question, context_data, is_general_advice=False)
                        data_source = 'aurora_rds_data_api'

                    except Exception as db_error:
                        logger.error(f"데이터베이스 조회 오류: {str(db_error)}")
                        logger.error(f"오류 타입: {type(db_error).__name__}")
                        import traceback
                        logger.error(f"스택 트레이스: {traceback.format_exc()}")
                        ai_response = call_bedrock_ai(question, "", is_general_advice=True)
                        data_source = 'general_advice_fallback'
                else:
                    # 일반적인 반려동물 상담
                    ai_response = call_bedrock_ai(question, "", is_general_advice=True)
                    data_source = 'general_advice'
                
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'question': question,
                        'answer': ai_response,
                        'data_source': data_source,
                        'question_type': question_type,
                        'timestamp': context.aws_request_id
                    }, ensure_ascii=False)
                }
        
        # 직접 호출 (테스트용)
        question = event.get('question', '')
        
        if not question:
            return {
                'statusCode': 400,
                'body': {
                    'error': 'Bad Request',
                    'message': 'question 파라미터가 필요합니다.',
                    'request_id': context.aws_request_id
                }
            }
        
        # 질문 유형 분석
        question_analysis = analyze_question_type(question)
        question_type = question_analysis.get('type', 'GENERAL_ADVICE')
        
        if question_type == 'DATABASE_QUERY':
            # 데이터베이스 조회가 필요한 질문
            try:
                db_results = query_database_by_question(question)
                context_data = format_context_data(db_results, question)
                ai_response = call_bedrock_ai(question, context_data, is_general_advice=False)
                data_source = 'aurora_rds_data_api'
                
            except Exception as db_error:
                logger.error(f"데이터베이스 조회 오류: {str(db_error)}")
                ai_response = call_bedrock_ai(question, "", is_general_advice=True)
                data_source = 'general_advice_fallback'
        else:
            # 일반적인 반려동물 상담
            ai_response = call_bedrock_ai(question, "", is_general_advice=True)
            data_source = 'general_advice'
        
        return {
            'statusCode': 200,
            'body': {
                'question': question,
                'answer': ai_response,
                'data_source': data_source,
                'question_type': question_type,
                'request_id': context.aws_request_id
            }
        }
        
    except Exception as e:
        logger.error(f"Lambda 함수 실행 오류: {str(e)}")
        logger.error(f"스택 트레이스: {traceback.format_exc()}")
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal Server Error',
                'message': str(e),
                'request_id': context.aws_request_id if context else 'unknown'
            })
        }