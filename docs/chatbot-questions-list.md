# PetClinic 챗봇 질문 리스트
## 학교 경진대회 시연용 질문 모음

이 문서는 PetClinic 애플리케이션의 AI 챗봇이 답변할 수 있는 모든 질문들을 정리한 것입니다.
실제 데이터베이스에 존재하는 정보를 기반으로 하며, 각 질문은 챗봇이 정확한 답변을 제공할 수 있도록 구성되었습니다.

## 데이터베이스 개요

### 반려동물 타입 (Pet Types)
- cat (고양이)
- dog (강아지)
- lizard (도마뱀)
- snake (뱀)
- bird (새)
- hamster (햄스터)

### 고객 (Owners)
1. George Franklin - 110 W. Liberty St., Madison - 전화: 6085551023
2. Betty Davis - 638 Cardinal Ave., Sun Prairie - 전화: 6085551749
3. Eduardo Rodriquez - 2693 Commerce St., McFarland - 전화: 6085558763
4. Harold Davis - 563 Friendly St., Windsor - 전화: 6085553198
5. Peter McTavish - 2387 S. Fair Way, Madison - 전화: 6085552765
6. Jean Coleman - 105 N. Lake St., Monona - 전화: 6085552654
7. Jeff Black - 1450 Oak Blvd., Monona - 전화: 6085555387
8. Maria Escobito - 345 Maple St., Madison - 전화: 6085557683
9. David Schroeder - 2749 Blackhawk Trail, Madison - 전화: 6085559435
10. Carlos Estaban - 2335 Independence La., Waunakee - 전화: 6085555487

### 반려동물 (Pets)
1. Leo (고양이) - 주인: George Franklin - 생년월일: 2000-09-07
2. Basil (햄스터) - 주인: Betty Davis - 생년월일: 2002-08-06
3. Rosy (강아지) - 주인: Eduardo Rodriquez - 생년월일: 2001-04-17
4. Jewel (강아지) - 주인: Eduardo Rodriquez - 생년월일: 2000-03-07
5. Iggy (도마뱀) - 주인: Harold Davis - 생년월일: 2000-11-30
6. George (뱀) - 주인: Peter McTavish - 생년월일: 2000-01-20
7. Samantha (고양이) - 주인: Jean Coleman - 생년월일: 1995-09-04
8. Max (고양이) - 주인: Jean Coleman - 생년월일: 1995-09-04
9. Lucky (새) - 주인: Jeff Black - 생년월일: 1999-08-06
10. Mulligan (강아지) - 주인: Maria Escobito - 생년월일: 1997-02-24
11. Freddy (새) - 주인: David Schroeder - 생년월일: 2000-03-09
12. Lucky (강아지) - 주인: Carlos Estaban - 생년월일: 2000-06-24
13. Sly (고양이) - 주인: Carlos Estaban - 생년월일: 2002-06-08

### 수의사 (Vets)
1. James Carter
2. Helen Leary - 전문분야: radiology
3. Linda Douglas - 전문분야: surgery, dentistry
4. Rafael Ortega - 전문분야: surgery
5. Henry Stevens - 전문분야: radiology
6. Sharon Jenkins

### 방문 기록 (Visits)
- Samantha (Jean Coleman): 2010-03-04 - rabies shot
- Max (Jean Coleman): 2011-03-04 - rabies shot
- Max (Jean Coleman): 2009-06-04 - neutered
- Samantha (Jean Coleman): 2008-09-04 - spayed

---

## 1. 고객 정보 조회 질문

### 기본 정보 조회
- "George Franklin의 주소는 뭐야?"
- "Betty Davis의 전화번호 알려줘"
- "Eduardo Rodriquez는 어디에 살아?"
- "Carlos Estaban의 주소와 전화번호를 알려줘"

### 존재 여부 확인
- "George Franklin이라는 고객이 있어?"
- "Maria Escobito 고객이 등록되어 있어?"
- "Kim이라는 성을 가진 고객이 있어?"

---

## 2. 반려동물 정보 조회 질문

### 특정 반려동물 정보
- "Leo의 주인은 누구야?"
- "Basil은 어떤 동물이야?"
- "Rosy의 생년월일은 언제야?"
- "Samantha의 주인 이름이 뭐야?"

### 주인별 반려동물 조회
- "George Franklin의 반려동물 이름이 뭐야?"
- "Jean Coleman이 키우는 반려동물들은 뭐야?"
- "Carlos Estaban의 펫들은 어떤 동물들이 있어?"

### 동물 종류별 조회
- "고양이를 키우는 사람은 누구야?"
- "강아지를 키우는 고객들은 누구야?"
- "새를 키우는 주인들은 누구인가?"

### 반려동물 존재 확인
- "Leo라는 반려동물이 있어?"
- "Max라는 이름의 반려동물이 몇 마리 있어?"

---

## 3. 방문 기록 조회 질문

### 특정 반려동물 방문 기록
- "Samantha의 검진기록 알려줘"
- "Max의 방문 기록을 보여줘"

### 가장 최근 방문
- "Samantha의 가장 최근 검진일은 언제야?"
- "Max가 가장 최근에 언제 병원을 방문했어?"

### 방문 내용 조회
- "Samantha가 언제 예방접종을 맞았어?"
- "Max의 중성화 수술은 언제 했어?"

---

## 4. 수의사 정보 조회 질문

### 기본 정보 조회
- "Helen Leary의 전문 분야는 뭐야?"
- "Linda Douglas는 어떤 분야의 전문의야?"
- "Rafael Ortega의 전문 분야를 알려줘"

### 전문 분야별 조회
- "외과 전문 수의사는 누구야?"
- "치과 전문 수의사는 누구인가?"
- "영상 진단 전문 수의사들은 누구야?"

---

## 5. 통계 및 집계 질문

### 반려동물 수 통계
- "Jean Coleman은 몇 마리의 반려동물을 키워?"
- "총 몇 마리의 반려동물이 등록되어 있어?"

### 동물 종류별 통계
- "고양이는 몇 마리 등록되어 있어?"
- "강아지를 키우는 사람은 몇 명이야?"

### 방문 통계
- "지난 1년 동안 몇 번의 방문이 있었어?"

---

## 6. 복합 질문 (여러 정보 결합)

### 주인 + 반려동물 + 방문
- "Jean Coleman의 Samantha가 언제 마지막으로 병원을 방문했어?"
- "Carlos Estaban의 Lucky는 어떤 동물이고 언제 태어났어?"

### 지역별 조회
- "Madison에 사는 고객들은 누구야?"
- "Monona 지역 고객들의 반려동물들은 뭐야?"

---

## 7. 존재하지 않는 데이터에 대한 질문 (부정 응답 테스트)

### 존재하지 않는 고객
- "김철수라는 고객이 있어?"
- "박영희의 주소는 어디야?"
- "이민수 고객의 전화번호 알려줘"

### 존재하지 않는 반려동물
- "뽀삐라는 반려동물이 있어?"
- "망고의 주인은 누구야?"
- "초코의 검진 기록을 알려줘"

### 존재하지 않는 수의사
- "김의사 선생님의 전문 분야는 뭐야?"
- "박수의사의 진료 분야를 알려줘"

---

## 8. 일반적인 반려동물 상담 질문 (AI 일반 지식)

### 건강 관리
- "강아지가 기침을 해요. 어떡하죠?"
- "고양이 예방접종은 언제 맞혀야 하나요?"
- "반려동물 건강관리 팁을 알려주세요"

### 식단 및 관리
- "강아지가 먹으면 안 되는 음식은 뭐가 있어?"
- "고양이 사료는 어떻게 골라야 해?"
- "반려동물 털 관리 방법 알려주세요"

### 행동 및 훈련
- "강아지 분리불안 어떻게 해결할까?"
- "고양이가 밤에 울면 어떻게 해야 해?"

---

## 9. 경계 테스트 질문 (한계 확인)

### 너무 복잡한 질문
- "Madison에 사는 모든 고객의 모든 반려동물과 방문 기록을 알려줘"
- "모든 수의사의 전문 분야와 진료 가능한 동물들을 알려줘"

### 모호한 질문
- "Leo에 대해 알려줘" (고객 Leo인지 반려동물 Leo인지 불명확)
- "Davis에 대해 알려줘" (Betty Davis인지 Harold Davis인지 불명확)

### 지원하지 않는 질문
- "병원 예약을 하고 싶어"
- "진료비가 얼마야?"
- "약을 어떻게 복용시켜?"

---

## 시연 시나리오 제안

### 기본 시연 (5분)
1. "George Franklin의 주소는 뭐야?" → 고객 정보 조회
2. "Leo의 주인은 누구야?" → 반려동물 정보 조회
3. "고양이를 키우는 사람은 누구야?" → 동물 종류별 조회
4. "Samantha의 검진기록 알려줘" → 방문 기록 조회
5. "외과 전문 수의사는 누구야?" → 수의사 정보 조회

### 심화 시연 (10분)
1. 고객 정보 조회 시리즈
2. 반려동물 정보 조회 시리즈
3. 방문 기록 조회 시리즈
4. 수의사 정보 조회 시리즈
5. 존재하지 않는 데이터에 대한 질문 (부정 응답)
6. 일반 반려동물 상담 질문

### 전문가 시연 (15분)
- 모든 카테고리의 질문을 커버
- 경계 테스트로 시스템 한계 설명
- 데이터베이스 기반 답변 vs 일반 AI 답변 차이점 설명

---

## 기술적 특징 설명 포인트

### 데이터베이스 기반 답변
- 실제 MySQL Aurora 데이터베이스의 정보를 실시간으로 조회
- RDS Data API를 사용하여 서버리스로 데이터 접근
- 정확한 정보만 제공 (hallucination 방지)

### AI 자연어 처리
- Amazon Bedrock Claude 3 모델 사용
- 한국어 자연어 이해 및 답변
- SQL 쿼리 자동 생성

### 실시간 응답
- Lambda 함수로 서버리스 구현
- 평균 응답 시간 2-3초
- API Gateway를 통한 RESTful API 제공

### 보안 및 확장성
- VPC 내에서 실행
- IAM 역할 기반 접근 제어
- CloudWatch로 모니터링 및 로깅