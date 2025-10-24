# Spring Boot 애플리케이션을 위한 간단한 빌드
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# 빌드된 JAR 파일 복사 (와일드카드 사용으로 버전 독립적)
COPY target/*.jar app.jar

# 애플리케이션이 실행되는 포트 노출
EXPOSE 8082

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "/app/app.jar"]