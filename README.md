# Kubernetes에서 Spring 애플리케이션 NGINX와 함께 배포하기

이 저장소는 Spring Boot 애플리케이션을 컨테이너화하고, Kubernetes에 3개의 복제본으로 배포한 후, NGINX를 외부 통신을 위한 리버스 프록시로 설정하는 방법을 보여줍니다.

## 사용 기술
![Spring](https://img.shields.io/badge/Spring-6DB33F?style=for-the-badge&logo=spring&logoColor=white) ![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![k8s](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white) ![]()

## 사전 준비 사항

- Docker
- Kubernetes 클러스터 (예: Minikube, GKE, EKS)
- Kubectl
- DockerHub 계정 (이미지 푸시를 원할 경우)

---

## 1단계: Spring 애플리케이션 도커화

1. Spring Boot 애플리케이션을 위한 `Dockerfile`을 생성합니다:
    ```dockerfile
    # OpenJDK를 기반 이미지로 사용
    FROM openjdk:17-jdk-alpine

    # 빌드된 jar 파일을 컨테이너에 복사
    ARG JAR_FILE=target/my-spring-app.jar
    COPY ${JAR_FILE} app.jar

    # jar 파일 실행
    ENTRYPOINT ["java","-jar","/app.jar"]
    ```

2. Docker 이미지를 빌드합니다:
    ```bash
    mvn clean package
    docker build -t my-spring-app:latest .
    ```

3. (선택) 이미지를 DockerHub에 푸시합니다:
    ```bash
    docker login
    docker tag my-spring-app:latest <your-dockerhub-username>/my-spring-app:latest
    docker push <your-dockerhub-username>/my-spring-app:latest
    ```

---

## 2단계: Spring 애플리케이션의 Kubernetes 배포

1. Kubernetes에서 Spring 애플리케이션을 배포하기 위한 `deployment.yaml` 파일을 생성합니다:
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: spring-app-deployment
    spec:
      replicas: 3  # 3개의 애플리케이션 Pod
      selector:
        matchLabels:
          app: spring-app
      template:
        metadata:
          labels:
            app: spring-app
        spec:
          containers:
          - name: spring-app-container
            image: <your-dockerhub-username>/my-spring-app:latest  # Docker 이미지 사용
            ports:
            - containerPort: 8080  # 8080 포트 노출
    ```

2. Spring 애플리케이션을 외부에 노출하기 위한 `service.yaml` 파일을 생성합니다:
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: spring-app-service
    spec:
      selector:
        app: spring-app
      ports:
      - protocol: TCP
        port: 80  # 외부 포트
        targetPort: 8080  # Spring 컨테이너 포트
      type: LoadBalancer  # 외부 트래픽을 허용하기 위한 타입
    ```

3. 설정을 적용합니다:
    ```bash
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    ```

---

## 3단계: NGINX를 리버스 프록시로 설정

1. NGINX를 리버스 프록시로 설정하기 위한 `nginx.conf` 파일을 작성합니다:
    ```nginx
    events {}

    http {
        upstream spring_app {
            server spring-app-service:8080;  # Spring 서비스와 연결
        }

        server {
            listen 80;

            location / {
                proxy_pass http://spring_app;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }
        }
    }
    ```

2. NGINX 구성을 로드할 `ConfigMap`을 생성합니다:
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: nginx-config
    data:
      nginx.conf: |
        events {}
        http {
            upstream spring_app {
                server spring-app-service:8080;
            }

            server {
                listen 80;

                location / {
                    proxy_pass http://spring_app;
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                }
            }
        }
    ```

3. NGINX를 Kubernetes에 배포하기 위한 `deployment.yaml`을 작성합니다:
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: nginx:latest
            ports:
            - containerPort: 80
            volumeMounts:
            - name: nginx-config-volume
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
          volumes:
          - name: nginx-config-volume
            configMap:
              name: nginx-config
    ```

4. NGINX 외부 접속을 위한 `service.yaml` 파일을 생성합니다:
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: nginx-service
    spec:
      selector:
        app: nginx
      ports:
      - protocol: TCP
        port: 80  # 외부 포트
        targetPort: 80  # NGINX 컨테이너 포트
      type: LoadBalancer
    ```

5. NGINX 설정을 적용합니다:
    ```bash
    kubectl apply -f nginx-configmap.yaml
    kubectl apply -f nginx-deployment.yaml
    kubectl apply -f nginx-service.yaml
    ```

---

## 4단계: 배포 확인

1. Pod 상태를 확인합니다:
    ```bash
    kubectl get pods
    ```

2. NGINX 서비스에 할당된 외부 IP를 확인합니다:
    ```bash
    kubectl get svc
    ```

3. 브라우저 또는 `curl` 명령어를 통해 할당된 `EXTERNAL-IP`로 접속하여 NGINX가 Spring 애플리케이션으로 트래픽을 제대로 전달하는지 확인합니다.

4. Log를 확인하여 관리한다
    ```bash
    kubectl logs <pod name>
    ```

5. Dashboard 를 활용하여 모니터링

![image (2)](https://github.com/user-attachments/assets/69b875d0-dd87-48ae-a271-1b800e7c313b)

---

### 결론

이 과정은 Spring 애플리케이션을 컨테이너화하고, Kubernetes에 NGINX 리버스 프록시를 통해 배포하는 방법을 다룹니다. 이 단계를 따라하면 클라우드 네이티브 환경에서 애플리케이션을 효율적으로 관리하고 확장할 수 있습니다.

### 트러블 슈팅

#### Spring App, Nginx `deployment.yaml`파일 작성 중 다음과 같은 경고 발생
`One or more containers do not have resource limits - this could starve other processes`


변경 이전
```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: spring-app-service
    spec:
      selector:
        app: spring-app
      ports:
      - protocol: TCP
        port: 80  # 외부 포트
        targetPort: 8080  # Spring 컨테이너 포트
      type: LoadBalancer  # 외부 트래픽을 허용하기 위한 타입
```
변경 이후
```yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app-deployment
spec:
  replicas: 3  # 3개의 애플리케이션 Pod
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
      - name: spring-app-container
        image: gato46/my-spring-app:latest  # Docker 이미지 사용
        ports:
        - containerPort: 8080  # 8080 포트 노출
        resources:
          requests:
            memory: "512Mi"  # 최소 512Mi 메모리 요청
            cpu: "500m"      # 최소 0.5 CPU 코어 요청
          limits:
            memory: "1Gi"    # 최대 1Gi 메모리 사용 제한
            cpu: "1"         # 최대 1 CPU 코어 사용 제한
```
##### 설명
- `resources` 섹션 추가:
  - `requests`: Kubernetes는 이 값을 기반으로 Pod를 스케줄링하고, 최소한으로 보장되는 리소스 양입니다.
  - `limits`: 이 값을 초과하면 컨테이너가 강제로 제한됩니다. 예를 들어, 메모리 제한을 넘으면 컨테이너가 종료될 수 있습니다.

이 설정을 통해 Pod가 너무 많은 자원을 사용하는 것을 방지하고, 다른 Pod 및 프로세스들이 안정적으로 자원을 사용할 수 있게 됩니다.
