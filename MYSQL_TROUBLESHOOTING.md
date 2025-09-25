# Spring PetClinic MySQL 연동 문제 해결 기록

이 문서는 Spring PetClinic 마이크로서비스 애플리케이션을 MySQL 데이터베이스에 연동하는 과정에서 발생했던 문제점들과 그 해결 과정을 정리한 것입니다.

---

## 1. 문제: MySQL 연결 - 접근 거부 (Access denied for user 'root'@'localhost' (using password: NO))

### 발생 상황
`customers-service`, `vets-service`, `visits-service` 등 데이터베이스에 연결해야 하는 서비스 컨테이너들이 시작 직후 중지되며 "Access denied for user 'root'@'localhost' (using password: NO)" 오류를 발생시켰습니다. 이는 `root` 사용자로 접속 시 비밀번호가 올바르게 전달되지 않았음을 의미합니다.

### 원인
`docker-compose.yml` 파일에서 데이터베이스 접속 정보(`SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`)를 환경 변수 `${DB_USER}`와 `${DB_PASSWORD}`를 통해 주입하도록 설정되어 있었습니다. 하지만 사용자 환경에 이 변수들이 설정되어 있지 않아, 컨테이너 내부에서는 빈 문자열(empty string)이 비밀번호로 사용되어 접속이 거부되었습니다.

### 해결
`docker-compose.yml` 파일의 `x-database-env` 섹션에 `SPRING_DATASOURCE_USERNAME: root`와 `SPRING_DATASOURCE_PASSWORD: 1234`를 직접 명시하여, 환경 변수 대신 고정된 값을 사용하도록 수정했습니다.

---

## 2. 문제: MySQL 연결 - 알 수 없는 데이터베이스 ('Unknown database 'petclinic'')

### 발생 상황
접속 자격 증명 문제를 해결한 후, 서비스 컨테이너들이 "Unknown database 'petclinic'" 오류와 함께 중지되었습니다.

### 원인
Spring Boot 애플리케이션은 연결하려는 데이터베이스가 이미 존재한다고 가정합니다. `petclinic`이라는 이름의 데이터베이스가 MySQL 서버에 생성되어 있지 않았기 때문에, 애플리케이션이 연결을 시도할 때 해당 데이터베이스를 찾지 못해 오류가 발생했습니다.

### 해결
사용자에게 MySQL 클라이언트(예: MySQL Workbench 또는 CLI)에서 `CREATE DATABASE petclinic;` 명령어를 실행하여 `petclinic` 데이터베이스를 수동으로 생성하도록 안내했습니다.

---

## 3. 문제: 테이블 미생성 (`SHOW TABLES;` 결과가 비어있음)

### 발생 상황
데이터베이스 연결 및 `petclinic` 데이터베이스 생성 후에도, MySQL 클라이언트에서 `SHOW TABLES;` 명령어를 실행했을 때 테이블 목록이 비어있었습니다.

### 원인
Spring Boot의 자동 스키마 초기화(`schema.sql`)가 실행되지 않았습니다.
*   **초기화 모드:** `spring.sql.init.mode` 속성이 명시적으로 설정되지 않아 기본값(`embedded` - 내장형 데이터베이스에만 적용)이 사용되었고, 외부 MySQL 데이터베이스에서는 `schema.sql`이 실행되지 않았습니다.
*   **파일 위치:** `schema.sql` 파일들이 `src/main/resources/db/mysql/schema.sql` 경로에 있었지만, Spring Boot는 기본적으로 클래스패스(classpath)의 최상위 경로(`src/main/resources`)에서 `schema.sql`을 찾으므로 파일을 발견하지 못했습니다.

### 해결
*   각 서비스의 설정 파일(`config/*.yml`)에 `spring.sql.init.mode: always`를 추가하여 SQL 스크립트가 항상 실행되도록 강제했습니다.
*   각 서비스의 설정 파일에 `spring.sql.init.schema-locations: classpath:db/mysql/schema.sql`을 추가하여 `schema.sql` 파일의 정확한 위치를 Spring Boot에 알려주었습니다.

---

## 4. 문제: `visits-service`의 외래 키 제약 조건 오류 (`Failed to open the referenced table 'pets'`)

### 발생 상황
테이블 생성 문제를 해결한 후, `visits-service`만 "Failed to open the referenced table 'pets'" 오류와 함께 중지되었습니다.

### 원인
`visits-service`의 `schema.sql` 파일에 있는 `visits` 테이블은 `pets` 테이블을 참조하는 외래 키를 가지고 있습니다. `pets` 테이블은 `customers-service`가 생성합니다. `docker-compose up` 명령으로 모든 서비스가 동시에 시작될 때, `visits-service`가 `pets` 테이블이 아직 생성되지 않은 상태에서 `visits` 테이블을 생성하려고 시도하여 외래 키 제약 조건 오류가 발생했습니다. 이는 서비스 간의 시작 순서 문제였습니다.

### 해결
`docker-compose.yml` 파일의 `visits-service` 정의에 `depends_on` 조건을 추가하여 `visits-service`가 `customers-service`가 시작된 후에 실행되도록 설정했습니다.
```yaml
    depends_on:
      customers-service:
        condition: service_started
```

---

## 5. 문제: 프론트엔드에서 Pet Type이 보이지 않음 (드롭다운 목록이 비어있음)

### 발생 상황
모든 서비스가 정상적으로 실행되고 테이블도 생성되었지만, 웹 애플리케이션의 반려동물 추가 화면에서 "Pet Type" 드롭다운 목록이 비어있었습니다.

### 원인
`types` 테이블에 초기 데이터(예: 'cat', 'dog')가 채워져 있지 않았기 때문입니다. 이 초기 데이터는 `data.sql` 스크립트에 정의되어 있었지만, `schema.sql`과 동일한 이유로 Spring Boot가 `data.sql` 파일을 찾아서 실행하지 못했습니다. `data.sql` 파일도 `src/main/resources/db/mysql/data.sql` 경로에 위치해 있었습니다.

### 해결
각 서비스의 설정 파일(`config/*.yml`)에 `spring.sql.init.data-locations: classpath:db/mysql/data.sql`을 추가하여 `data.sql` 파일의 정확한 위치를 Spring Boot에 알려주었습니다. 이로 인해 애플리케이션 시작 시 `data.sql`이 실행되어 `types` 테이블에 초기 데이터가 채워졌고, 프론트엔드에서 Pet Type 목록을 정상적으로 표시할 수 있게 되었습니다.

---

이러한 문제 해결 과정을 통해 Spring PetClinic 애플리케이션이 MySQL 데이터베이스와 완전히 연동되어 정상적으로 작동하게 되었습니다.