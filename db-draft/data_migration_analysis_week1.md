### **데이터 및 설정 분석 보고서 (초안)**

**작성자:** (본인 성함)
**역할:** Data & Migration Lead
**작성일:** 2025년 9월 23일
**목표:** PetClinic Microservices의 AS-IS 데이터 및 설정 구조를 분석하고, AWS 마이그레이션을 위한 기반 정보를 확보한다.

---

### **1. 데이터베이스 스키마 및 테이블 분석**

로컬 환경에서 `docker-compose`로 전체 서비스를 실행한 후, 각 서비스의 소스코드 및 API 응답을 분석하여 사용하는 데이터베이스 테이블 구조를 파악함.

-   **`customers-service` (고객 서비스)**
    -   **주요 테이블:** `owners`, `pets`, `types`
    -   **역할:** 소유주 정보, 소유주에 속한 반려동물의 정보, 반려동물의 종류(개, 고양이 등)를 관리.

-   **`vets-service` (수의사 서비스)**
    -   **주요 테이블:** `vets`, `specialties`, `vet_specialties`
    -   **역할:** 수의사 정보, 전문 분야(방사선, 외과 등), 그리고 수의사와 전문 분야 간의 다대다(N:M) 관계를 관리.

-   **`visits-service` (방문 기록 서비스)**
    -   **주요 테이블:** `visits`
    -   **역할:** 특정 반려동물(`pet_id`로 연결)의 방문 일자 및 진료 내용을 관리.

---

### **2. DB 종류 및 초기화 스크립트 분석**

#### **산출물: DB 초기화 스크립트 분석 자료**

-   **현재(AS-IS) DB 종류:** **HSQLDB (In-memory)**
    -   각 서비스의 `pom.xml`에 `h2` 의존성이 포함되어 있으며, 별도의 외부 DB 설정이 없어 Spring Boot의 기본 동작에 따라 앱 실행 시 메모리에 DB가 생성되고 앱 종료 시 사라지는 구조임.
    -   **문제점:** 이 방식으로는 DB와의 네트워크 지연, 디스크 I/O 등 실제 운영 환경에서 발생할 성능 부하를 측정할 수 없음. **(→ 로컬 MySQL 전환 작업의 당위성)**

-   **초기화 스크립트 위치 및 내용:**
    -   **`schema.sql` (테이블 구조 정의: `CREATE TABLE ...`)**
        -   `customers-service/src/main/resources/db/mysql/schema.sql`
        -   `vets-service/src/main/resources/db/mysql/schema.sql`
        -   `visits-service/src/main/resources/db/mysql/schema.sql`
    -   **`data.sql` (초기 데이터 삽입: `INSERT INTO ...`)**
        -   `customers-service/src/main/resources/db/mysql/data.sql`
        -   `vets-service/src/main/resources/db/mysql/data.sql`
        -   `visits-service/src/main/resources/db/mysql/data.sql`
    -   **분석:** 각 서비스는 시작 시 자신의 `schema.sql`을 참조하여 테이블 구조를 만들고, `data.sql`을 참조하여 기본 데이터(예: 수의사 목록, 반려동물 종류)를 삽입함.

---

### **3. `Config Server` 분석**

#### **산출물: `Config Server` 분석 및 설정 정보 목록 문서**

-   **Git 연동 방식 분석:**
    -   `spring-petclinic-config-server`의 `application.yml` 파일에 Git 리포지토리 주소가 명시되어 있음.
    -   **연동 Git 주소:** `https://github.com/spring-petclinic/spring-petclinic-microservices-config`
    -   **동작 방식:** 모든 마이크로서비스는 시작 시 `Config Server`에 자신의 설정 정보를 요청하고, `Config Server`는 위 Git 리포지토리에서 해당 서비스의 설정 파일(예: `customers-service.yml`)을 읽어 제공함. 이를 통해 설정을 중앙에서 관리.

-   **관리되고 있는 주요 설정 정보:**
    -   `server.port`: 각 서비스의 실행 포트
    -   `eureka.client.serviceUrl.defaultZone`: 서비스 등록 및 검색을 위한 Eureka 서버 주소
    -   `spring.datasource.url` 등 데이터베이스 연결 정보 (현재는 HSQLDB로 설정됨)
    -   각종 타임아웃, 로깅 레벨 등 서비스 운영에 필요한 대부분의 설정

---

### **4. 데이터 관계 및 중요도 식별**

#### **산출물: 데이터 관계도(ERD) 초안**

-   **주요 데이터 관계:**
    -   `owners` (1) → `pets` (N) : 한 명의 소유주는 여러 반려동물을 가질 수 있다.
    -   `pets` (1) → `visits` (N) : 한 마리의 반려동물은 여러 방문 기록을 가질 수 있다.
    -   `pets` (N) → `types` (1) : 여러 반려동물은 하나의 타입(종류)에 속한다.
    -   `vets` (N) ↔ `specialties` (M) : 수의사와 전문 분야는 다대다 관계이며, `vet_specialties` 테이블로 연결된다.

-   **데이터 중요도 식별:**
    -   **상 (High):** `owners`, `pets`, `visits`
        -   **사유:** 고객의 핵심 정보이자 서비스의 근간이 되는 데이터. 유실 시 비즈니스에 직접적인 타격을 줌. 마이그레이션 시 데이터 정합성과 무결성을 최우선으로 보장해야 함.
    -   **중 (Medium):** `vets`, `specialties`, `vet_specialties`
        -   **사유:** 서비스 운영에 필수적인 데이터지만, 상대적으로 정적이며 최악의 경우 수동으로 재입력이 가능한 데이터.
    -   **하 (Low):** `types`
        -   **사유:** 거의 변경되지 않는 단순 분류 데이터(Master Data).

---

이 분석을 바탕으로, 현재 진행 중인 **로컬 DB 환경을 HSQLDB에서 MySQL로 전환하는 작업**은 실제 운영 환경과 유사한 성능 테스트를 위해 반드시 필요한 과정임을 재확인했습니다. 3단계 작업을 계속 진행하겠습니다.
