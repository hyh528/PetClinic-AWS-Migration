# Spring Boot 애플리케이션을 위한 다단계 빌드
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Maven 래퍼와 pom.xml 복사
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# 의존성 다운로드 (pom.xml이 변경되지 않은 경우 캐시됨)
RUN ./mvnw dependency:go-offline -B

# 소스 코드 복사
COPY src ./src

# 애플리케이션 빌드
RUN ./mvnw clean package -DskipTests

# 프로덕션 단계
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# 루트가 아닌 사용자 생성
RUN addgroup -S spring && adduser -S spring -G spring

# 빌더 단계에서 jar 파일 복사
COPY --from=builder /app/target/*.jar app.jar

# 소유권을 루트가 아닌 사용자로 변경
RUN chown spring:spring app.jar

# 루트가 아닌 사용자로 전환
USER spring

# 애플리케이션이 실행되는 포트 노출
EXPOSE 8080

# 헬스 체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "/app/app.jar"]