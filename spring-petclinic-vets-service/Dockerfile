# Spring Boot 애플리케이션을 위한 간단한 빌드
FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app

# Maven 래퍼 실행 권한 부여
RUN chmod +x mvnw

# Maven 래퍼와 pom.xml 복사
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# 의존성 다운로드
RUN ./mvnw dependency:go-offline -B

# 소스 코드 복사
COPY src ./src

# 애플리케이션 빌드 (테스트 포함)
RUN ./mvnw clean package

# 애플리케이션이 실행되는 포트 노출
EXPOSE 8080

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "/app/target/*.jar"]