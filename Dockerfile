# OpenJDK를 기반 이미지로 사용
FROM openjdk:17-jdk-alpine

# 빌드된 jar 파일을 컨테이너에 복사
ARG JAR_FILE=target/my-spring-app.jar
COPY ${JAR_FILE} app.jar

# jar 파일 실행
ENTRYPOINT ["java","-jar","/app.jar"]
