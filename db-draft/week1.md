# 1주차 데이터 및 설정 분석 결과

담당자: 박준제 (Data & Migration Lead)

---

## ✅ 서비스별 DB 스키마 및 테이블 목록

### 1. `customers-service`
*   **`types`**: 반려동물의 종류 (e.g., cat, dog)
    *   `id`, `name`
*   **`owners`**: 반려동물 주인의 정보
    *   `id`, `first_name`, `last_name`, `address`, `city`, `telephone`
*   **`pets`**: 반려동물의 정보
    *   `id`, `name`, `birth_date`, `type_id`, `owner_id`

### 2. `vets-service`
*   **`vets`**: 수의사 정보
    *   `id`, `first_name`, `last_name`
*   **`specialties`**: 전문 분야 정보 (e.g., radiology, surgery)
    *   `id`, `name`
*   **`vet_specialties`**: 수의사와 전문 분야의 관계 (Many-to-Many)
    *   `vet_id`, `specialty_id`

### 3. `visits-service`
*   **`visits`**: 방문 기록
    *   `id`, `pet_id`, `visit_date`, `description`

---

## ✅ 데이터 관계도(ERD) 초안 분석

스키마의 `FOREIGN KEY`를 통해 다음과 같은 데이터 관계를 파악할 수 있습니다.

*   한 명의 `owner`는 여러 마리의 `pet`을 가질 수 있습니다. (`owners` 1:N `pets`)
*   하나의 `type`은 여러 `pet`에 적용될 수 있습니다. (`types` 1:N `pets`)
*   한 마리의 `pet`은 여러 번의 `visit` 기록을 가질 수 있습니다. (`pets` 1:N `visits`)
*   한 명의 `vet`은 여러 `specialty`를 가질 수 있으며, 하나의 `specialty`는 여러 `vet`에게 부여될 수 있습니다. (`vets` M:N `specialties`, `vet_specialties` 테이블을 통해 연결)

**주목할 점:**
`visits` 테이블은 `pets(id)`를 참조하지만, `pets` 테이블은 `customers-service`에 속해 있습니다. 이는 `visits-service`가 `customers-service`의 데이터에 의존하고 있음을 의미하며, 마이크로서비스 아키텍처에서 중요한 분석 포인트입니다.

---

## ✅ `Config Server` 분석 및 설정 정보 목록

### `Config Server` 분석

*   **저장소:** `Config Server`는 외부 GitHub 리포지토리(`https://github.com/spring-petclinic/spring-petclinic-microservices-config`)를 사용하여 설정 정보를 관리합니다.
*   **동작 방식:**
    1.  모든 서비스에 공통적으로 적용될 기본 설정을 `application.yml` 파일에 정의합니다.
    2.  각 서비스(예: `customers-service`)의 고유한 설정이나 기본 설정을 덮어써야 할 내용은 `[서비스이름].yml` 파일에 별도로 정의합니다.
    3.  `docker` 또는 `mysql` 같은 **Spring Profile**을 사용하여, 실행 환경(로컬, Docker 등)에 따라 다른 설정을 동적으로 적용합니다.

### 관리되고 있는 설정 정보 목록 (요약)

**1. 공통 설정 (`application.yml`)**

*   **DB 설정:** 기본적으로 HSQLDB(인메모리)를 사용하며, `mysql` 프로필 활성화 시 MySQL DB를 사용하도록 설정되어 있습니다.
*   **서버 포트:** 기본적으로 랜덤 포트를 사용하도록 설정되어 있습니다 (`port: 0`).
*   **모니터링:** Actuator, Prometheus(메트릭 수집), Zipkin(분산 추적) 등 대부분의 모니터링 기능이 기본적으로 활성화되어 있습니다.

**2. `customers-service` 전용 설정 (`customers-service.yml`)**

*   `docker` 프로필이 활성화되면(현재 `docker-compose` 환경), 공통 설정을 덮어쓰고 다음을 적용합니다.
    *   **서버 포트:** `8081`로 고정됩니다.
    *   **Discovery Server 주소:** `http://discovery-server:8761/eureka/`로 설정하여 Docker 네트워크 내의 다른 서비스를 찾을 수 있게 합니다.
    *   **Tracing Server 주소:** `http://tracing-server:9411/api/v2/spans`로 설정합니다.

---

## ✅ 아키텍처 설계 (Architecture Design)

### **산출물: As-Is 다이어그램의 데이터베이스 부분 초안**

현재 로컬 Docker 환경의 데이터베이스 아키텍처는 다음과 같이 분석할 수 있습니다. (다이어그램을 그리기 위한 텍스트 설명 초안입니다.)

*   **`customers-service`**
    *   **DB 종류:** 내장 HSQLDB (In-Memory)
    *   **테이블:** `types`, `owners`, `pets`
    *   **특징:** 자체적으로 데이터를 소유하고 관리합니다.

*   **`vets-service`**
    *   **DB 종류:** 내장 HSQLDB (In-Memory)
    *   **테이블:** `vets`, `specialties`, `vet_specialties`
    *   **특징:** 자체적으로 데이터를 소유하고 관리합니다.

*   **`visits-service`**
    *   **DB 종류:** 내장 HSQLDB (In-Memory)
    *   **테이블:** `visits`
    *   **특징:** `pet_id`를 통해 `customers-service`의 데이터에 논리적으로 의존하지만, DB가 직접 연결되어 있지는 않습니다.

> **핵심 요약:** 현재는 각 서비스가 독립적인 인메모리 DB를 사용하는, 전형적인 "Database-per-Service" 패턴의 초기 형태를 따르고 있습니다.

---

### **산출물: RDS 구성 방안 제안서**

클라우드로 이전할 때, 현재 아키텍처를 기반으로 다음과 같은 두 가지 RDS 구성 방안을 제안할 수 있습니다.

*   **방안 1: 서비스별 RDS 인스턴스 분리 (강력히 권장)**
    *   **구성:** `customers-db`, `vets-db`, `visits-db` 등 각 서비스마다 별도의 RDS 인스턴스를 생성합니다.
    *   **장점:**
        *   **높은 안정성:** 한 서비스의 DB 장애가 다른 서비스에 영향을 주지 않습니다.
        *   **독립적인 확장:** 특정 서비스(예: 방문 기록)에 부하가 몰릴 경우, 해당 DB만 독립적으로 확장할 수 있습니다.
        *   **느슨한 결합:** 마이크로서비스의 핵심 원칙을 준수하여 서비스 간 데이터 종속성을 제거합니다.
    *   **단점:**
        *   **비용:** 여러 개의 인스턴스를 유지해야 하므로 비용이 상대적으로 높습니다.
        *   **관리 복잡도:** 관리해야 할 DB 인스턴스 수가 늘어납니다.

*   **방안 2: 단일 RDS 인스턴스, 스키마 분리**
    *   **구성:** 하나의 큰 RDS 인스턴스를 생성하고, 그 안에 `customers_schema`, `vets_schema`처럼 서비스별로 논리적인 데이터베이스(스키마)를 분리합니다.
    *   **장점:**
        *   **비용 효율성:** 단일 인스턴스만 유지하므로 비용이 저렴합니다.
        *   **관리 용이성:** 관리 포인트가 하나로 줄어듭니다.
    *   **단점:**
        *   **강한 결합:** 서비스 간 데이터 격리가 깨져, 한 서비스의 변경이 다른 서비스에 영향을 줄 위험이 있습니다.
        *   **단일 장애점:** RDS 인스턴스에 장애가 발생하면 모든 서비스가 중단됩니다.

> **결론 및 제안:** 마이크로서비스의 장점을 최대한 활용하고 안정적인 운영을 위해 **방안 1: 서비스별 RDS 인스턴스 분리**를 채택하는 것을 권장합니다.

---

### **산출물: Parameter Store Key 구조 설계 문서**

`Config Server`의 설정을 AWS Parameter Store로 이전하기 위한 Key-Value 구조 초안을 제안합니다. 계층 구조를 활용하여 관리를 용이하게 합니다.

**Key 작명 규칙:** `/[프로젝트명]/[환경]/[서비스명]/[설정항목]`

*   `/petclinic/production/application/spring.datasource.username`: Production 환경의 모든 서비스에 공통으로 적용될 DB 사용자 이름
*   `/petclinic/production/application/spring.datasource.password`: DB 패스워드 (SecureString 타입으로 저장)
*   `/petclinic/production/customers-service/server.port`: Production 환경 `customers-service`의 서버 포트
*   `/petclinic/development/vets-service/spring.jpa.show-sql`: Development 환경 `vets-service`의 JPA SQL 로깅 여부

이 구조를 사용하면 환경별, 서비스별 설정을 명확하게 분리하고, IAM 정책을 통해 특정 Key에 대한 접근 제어를 쉽게 구현할 수 있습니다.






-----------------------------------------


현재의 인메모리 DB(H2)는 앱이 켜질 때 생성되고 꺼질 때 사라지기 때문에, 실제 운영 환경과는 거리가 멉니다. 말씀하신 대로 DB 서버와의 네트워크 통신, 디스크 I/O 등 실제 성능에 큰 영향을 미치는 요소들을 전혀 측정할수 없습니다.

따라서 로컬에 실제 MySQL 서버를 설치하고 애플리케이션이 그곳에 연결하도록 변경하는 것은, AWS로 이전하기 전 성능을 제대로 측정하고 문제를 미리 파악하기 위한 필수적인 과정입니다.



  ---

  ### 로컬 DB 환경 구축 및 연결 계획

  이 작업은 크게 4단계로 진행됩니다.


   1. 1단계: 로컬에 MySQL 서버 설치
   2. 2단계: 각 서비스를 위한 데이터베이스 생성
   3. 4단계: 재시작 및 확인
  1단계: MySQL 설치
   1. MySQL 공식 다운로드 페이지로 이동합니다.
   2. 설치가 완료되면 MySQL Workbench를 실행하고, 설치 시 설정한 Root 계정으로 접속합니다.
  `sql
      -- 각 서비스를 위한 데이터베이스(스키마) 생성
      CREATE DATABASE IF NOT EXISTS petclinic_customers;
      CREATE DATABASE IF NOT EXISTS petclinic_vets;
      CREATE DATABASE IF NOT EXISTS petclinic_visits;

      -- 애플리케이션이 사용할 공통 사용자 생성 및 권한 부여
      CREATE USER 'petclinic'@'%' IDENTIFIED BY 'petclinic';
      GRANT ALL PRIVILEGES ON petclinic_customers.* TO 'petclinic'@'%';
      GRANT ALL PRIVILEGES ON petclinic_vets.* TO 'petclinic'@'%';
      GRANT ALL PRIVILEGES ON petclinic_visits.* TO 'petclinic'@'%';
      FLUSH PRIVILEGES;
      `

  #### 3단계: Spring Boot 애플리케이션 설정 변경


  이제 각 서비스의 코드를 수정할 차례입니다. customers-service를 예시로 보여드리겠습니다. vets-service와
  visits-service도 동일하게 수정하시면 됩니다.

  3-1. `pom.xml` 파일에 MySQL 드라이버 의존성 추가


   * 파일 경로: spring-petclinic-customers-service/pom.xml
  `xml
      <dependency>
          <groupId>com.mysql</groupId>
          <artifactId>mysql-connector-j</artifactId>
          <scope>runtime</scope>
      </dependency>
      `

  3-2. `application.yml` 파일 수정


   * 파일 경로: spring-petclinic-customers-service/src/main/resources/application.yml
  `yaml
      spring:
        datasource:
          # 기존 H2 설정
          # url: jdbc:h2:mem:customers-db
          # username: sa
          # password:

          # 새로 추가할 MySQL 설정
          url: jdbc:mysql://host.docker.internal:3306/petclinic_customers?useSSL=false
          username: petclinic
          password: petclinic
          driver-class-name: com.mysql.cj.jdbc.Driver
        jpa:
          hibernate:
            ddl-auto: update
          database-platform: org.hibernate.dialect.MySQLDialect
      `
     중요:* url에 localhost 대신 host.docker.internal을 사용했습니다. 이것은 Docker 컨테이너 안에서 실행되는
   애플리케이션이 컨테이너를 실행하는 PC(호스트)의 localhost를 가리키는 특별한 주소입니다.

  3-3. 나머지 서비스(`vets-service`, `visits-service`)에도 위 과정 반복


   * 각 서비스의 pom.xml에 MySQL 의존성을 추가합니다.
  4단계: 재시작 및 확인
   1. 터미널에서 docker-compose down 명령으로 실행 중인 모든 컨테이너를 중지합니다.
  이 과정에서 막히는 부분이 있거나 질문이 생기면 언제든지 다시 물어보세요. 함께 해결해 나가겠습니다.