# H2 인메모리에서 MySQL로 마이그레이션 가이드

## 개요

Spring Petclinic 마이크로서비스 아키텍처에서 H2 인메모리 데이터베이스에서 로컬 MySQL 데이터베이스로 마이그레이션하는 완전 가이드입니다.

### 마이그레이션 목표
- H2 인메모리 → MySQL 데이터베이스
- 단일 JVM → Docker 컨테이너 기반 마이크로서비스
- 모니터링 스택 (Prometheus, Grafana, Zipkin) 통합
- Clean Code: YAML Anchors로 설정 중복 제거 (20% 코드 감소)

### 예상 소요 시간
- 2-3시간 (환경 설정 포함)
- 난이도: 중간

---

## 사전 준비사항

### 1. 필수 소프트웨어 설치
```bash
# Docker & Docker Compose
# MySQL 8.0+
# JDK 17+
# Maven 3.6+
```

### 2. MySQL 설치 및 설정
```sql
-- MySQL에 접속하여 데이터베이스 생성
CREATE DATABASE petclinic;
CREATE USER 'petclinic'@'%' IDENTIFIED BY 'petclinic';
GRANT ALL PRIVILEGES ON petclinic.* TO 'petclinic'@'%';
FLUSH PRIVILEGES;
```

### 3. 환경 변수 설정
```bash
# .env 파일 생성 또는 환경 변수 설정
DB_USER=petclinic
DB_PASSWORD=petclinic
```

---

## 단계별 마이그레이션

### 단계 1: 프로젝트 구조 확인

```
PetClinic-AWS-Migration/
├── docker-compose.yml          # Docker 서비스 정의
├── config/                     # 각 서비스 설정 파일
│   ├── customers-service.yml
│   ├── visits-service.yml
│   ├── vets-service.yml
│   └── api-gateway.yml
├── spring-petclinic-*-service/ # 각 마이크로서비스
└── docker/                     # Docker 설정
```

### 단계 2: MySQL 데이터베이스 설정

#### 2.1 Docker Compose에 MySQL 서비스 추가
```yaml
# docker-compose.yml에 추가
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: petclinic
      MYSQL_USER: ${DB_USER:-petclinic}
      MYSQL_PASSWORD: ${DB_PASSWORD:-petclinic}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-root}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

volumes:
  mysql_data:
```

#### 2.2 환경 변수 파일 생성
```bash
# .env.example을 .env로 복사
cp .env.example .env

# .env 파일 편집 (실제 비밀번호로 변경)
DB_USER=petclinic
DB_PASSWORD=your_secure_password
DB_ROOT_PASSWORD=your_root_password
```

#### 2.2 각 서비스의 데이터베이스 설정
```yaml
# config/customers-service.yml
spring:
  datasource:
    url: jdbc:mysql://host.docker.internal:3306/petclinic?useUnicode=true
    username: ${DB_USER}
    password: ${DB_PASSWORD}
```

**모든 서비스에 동일하게 적용:**
- customers-service.yml
- visits-service.yml
- vets-service.yml

### 단계 3: Docker 포트 설정

#### 3.1 서비스 포트 매핑 (Clean Code 적용)
```yaml
# docker-compose.yml (YAML Anchors로 중복 제거)
x-service-base: &service-base
  deploy:
    resources:
      limits:
        memory: 512M
  depends_on:
    config-server:
      condition: service_healthy
    discovery-server:
      condition: service_healthy

x-database-env: &database-env
  - SPRING_PROFILES_ACTIVE=mysql,docker
  - SPRING_DATASOURCE_URL=jdbc:mysql://host.docker.internal:3306/petclinic?useUnicode=true
  - SPRING_DATASOURCE_USERNAME=${DB_USER}
  - SPRING_DATASOURCE_PASSWORD=${DB_PASSWORD}
  - EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://discovery-server:8761/eureka/

x-eureka-env: &eureka-env
  - SPRING_PROFILES_ACTIVE=docker
  - EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://discovery-server:8761/eureka/

services:
  customers-service:
    <<: *service-base
    image: springcommunity/spring-petclinic-customers-service
    container_name: customers-service
    ports:
    - 8081:8080
    environment:
      <<: *database-env

  visits-service:
    <<: *service-base
    image: springcommunity/spring-petclinic-visits-service
    container_name: visits-service
    ports:
    - 8082:8080
    environment:
      <<: *database-env

  vets-service:
    <<: *service-base
    image: springcommunity/spring-petclinic-vets-service
    container_name: vets-service
    ports:
    - 8083:8080
    environment:
      <<: *database-env

  api-gateway:
    <<: *service-base
    image: springcommunity/spring-petclinic-api-gateway
    container_name: api-gateway
    ports:
    - 8080:8080
    environment:
      <<: *eureka-env
```

#### 3.2 Admin Server 포트 설정
```yaml
admin-server:
  ports:
    - "9090:8080"  # 외부 9090 → 내부 8080
```

### 단계 4: 모니터링 스택 설정

#### 4.1 Prometheus 설정
```yaml
# docker/prometheus/prometheus.yml
scrape_configs:
- job_name: customers-service
  metrics_path: /actuator/prometheus
  static_configs:
  - targets: ['customers-service:8080']

- job_name: visits-service
  metrics_path: /actuator/prometheus
  static_configs:
  - targets: ['visits-service:8080']

- job_name: vets-service
  metrics_path: /actuator/prometheus
  static_configs:
  - targets: ['vets-service:8080']
```

#### 4.2 Zipkin 설정
```yaml
# 각 서비스 config에 추가
management:
  zipkin:
    tracing:
      endpoint: http://tracing-server:9411/api/v2/spans
```

### 단계 5: Docker Compose 실행

#### 5.1 서비스 시작
```bash
# 프로젝트 루트에서 실행
cd PetClinic-AWS-Migration
docker-compose up -d
```

#### 5.2 시작 순서 확인
```bash
# MySQL이 완전히 시작될 때까지 대기
docker-compose logs mysql | grep "ready for connections"
```

---

## 검증 단계

### 1. 서비스 상태 확인
```bash
# 각 서비스 헬스체크
curl http://localhost:8081/actuator/health  # CUSTOMERS
curl http://localhost:8082/actuator/health  # VISITS
curl http://localhost:8083/actuator/health  # VETS
curl http://localhost:8080/actuator/health  # API GATEWAY
curl http://localhost:9090/actuator/health  # ADMIN SERVER
```

### 2. 데이터베이스 연결 확인
```bash
# MySQL 접속 (두 가지 방식 모두 가능)
mysql -h localhost -P 3306 -u petclinic -p petclinic
# 또는
mysql -h localhost -P 3306 -u petclinic -ppetclinic petclinic

# 테이블 확인
SHOW TABLES;
```

### 3. API 기능 테스트
```bash
# 데이터 조회
curl http://localhost:8081/owners
curl http://localhost:8083/vets

# API Gateway를 통한 접근
curl http://localhost:8080/api/customer/owners
```

### 4. 모니터링 확인
```bash
# Prometheus 타겟 상태
curl http://localhost:9091/api/v1/targets

# Grafana 접근
open http://localhost:3030

# Zipkin 접근
open http://localhost:9411
```

### 5. Eureka 서비스 등록 확인
```bash
# Eureka 대시보드
open http://localhost:8761
```

---

## 문제 해결

### 일반적인 문제들

#### 1. MySQL 연결 실패
```bash
# MySQL 로그 확인
docker-compose logs mysql

# 데이터베이스 재생성
docker-compose down -v
docker-compose up -d mysql
```

#### 2. 서비스 시작 실패
```bash
# 서비스별 로그 확인
docker-compose logs customers-service
docker-compose logs visits-service
```

#### 3. 포트 충돌
```bash
# 사용 중인 포트 확인
netstat -tulpn | grep :808

# Docker 포트 변경
docker-compose down
# docker-compose.yml에서 포트 변경 후 재시작
```

#### 4. 메트릭 수집 안됨
```bash
# Prometheus 설정 재적재
docker-compose restart prometheus-server

# 메트릭 엔드포인트 확인
curl http://localhost:8081/actuator/prometheus
```

### 데이터 마이그레이션

#### H2에서 MySQL로 데이터 이전
```bash
# 1. H2 데이터베이스 백업 (필요시)
# 2. MySQL 스키마 생성
# 3. 데이터 마이그레이션 스크립트 실행

# 각 서비스의 resources/db/mysql/schema.sql 실행
mysql -u petclinic -ppetclinic petclinic < schema.sql
mysql -u petclinic -ppetclinic petclinic < data.sql
```

---

## 추가 리소스

### 유용한 명령어들
```bash
# 전체 서비스 상태
docker-compose ps

# 로그 모니터링
docker-compose logs -f

# 특정 서비스 재시작
docker-compose restart customers-service

# 전체 재빌드
docker-compose down
docker-compose up --build
```

### 설정 파일 위치
- `config/*.yml`: 서비스별 설정
- `docker-compose.yml`: Docker 서비스 정의
- `docker/prometheus/prometheus.yml`: 모니터링 설정

### 포트 정리
| 서비스 | 외부 포트 | 내부 포트 | 용도 |
|--------|----------|----------|------|
| API Gateway | 8080 | 8080 | 메인 API |
| Customers | 8081 | 8080 | 고객 서비스 |
| Visits | 8082 | 8080 | 방문 서비스 |
| Vets | 8083 | 8080 | 수의사 서비스 |
| Admin | 9090 | 8080 | 관리 인터페이스 |
| Prometheus | 9091 | 9090 | 메트릭 수집 |
| Grafana | 3030 | 3000 | 대시보드 |
| Zipkin | 9411 | 9411 | 트레이싱 |
| Eureka | 8761 | 8761 | 서비스 디스커버리 |
| Config | 8888 | 8888 | 설정 서버 |

---

## ✅ 완료 체크리스트

- [ ] MySQL 데이터베이스 생성 및 권한 설정
- [ ] docker-compose.yml에 MySQL 서비스 추가
- [ ] 각 서비스 config에 MySQL 연결 설정
- [ ] Docker 포트 매핑 설정
- [ ] 모니터링 스택 설정 (Prometheus, Grafana, Zipkin)
- [ ] 서비스 정상 시작 확인
- [ ] API 기능 테스트
- [ ] 모니터링 대시보드 확인
- [ ] Eureka 서비스 등록 확인

---

## 🎉 마이그레이션 완료!

축하합니다! H2 인메모리에서 MySQL 기반의 완전한 마이크로서비스 아키텍처로 성공적으로 마이그레이션했습니다.

이제 프로덕션 환경 배포를 위한 기반이 구축되었습니다.