# postman-ci-tests

## Запуск Postman collection

### 1. Локальний запуск через Newman

Встановіть Newman і HTML-репортер:

```bash
npm install -g newman newman-reporter-htmlextra
```

Запустіть колекцію:

```bash
newman run collection.json -e env.json -r cli,htmlextra -n 1
```

Після виконання HTML-звіт буде у директорії `newman/`.

### 2. Запуск через Docker

Збірка образу:

```bash
docker build -t postman-tests .
```

Запуск тестів:

```bash
docker run --name api-runner postman-tests || true
```

Копіювання звіту з контейнера:

```bash
docker cp api-runner:/etc/newman/newman .
docker rm api-runner
```

### 3. Запуск у Jenkins

У проєкті є `Jenkinsfile`, який виконує:
1. `docker build -t postman-tests .`
2. `docker run --name api-runner postman-tests || true`
3. Копіювання HTML-звіту і архівацію артефактів (`newman/*.html`)

---

## Golden Standard: Jenkins + Docker + ngrok (one-command setup)

Нижче наведений еталонний набір для розгортання всієї інфраструктури однією командою.

### 1. `Dockerfile.jenkins`

```Dockerfile
FROM jenkins/jenkins:lts

USER root

# Встановлюємо залежності для Docker
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Додаємо офіційний GPG ключ Docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Налаштовуємо репозиторій
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Встановлюємо Docker CLI
RUN apt-get update && apt-get install -y docker-ce-cli

USER jenkins
```

### 2. `docker-compose.yml`

```yaml
version: '3.8'

services:
  jenkins:
    build:
      context: .
      dockerfile: Dockerfile.jenkins
    container_name: jenkins_local
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      # Це магія: прокидаємо сокет Docker з вашого Mac всередину контейнера
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - jenkins-net

  ngrok:
    image: ngrok/ngrok:latest
    container_name: ngrok_tunnel
    command:
      - "http"
      - "jenkins:8080"
    environment:
      # Отримайте свій токен на ngrok.com (Dashboard -> Your Authtoken)
      - NGROK_AUTHTOKEN=ВАШ_ТОКЕН_ТУТ
    ports:
      - "4040:4040"
    depends_on:
      - jenkins
    networks:
      - jenkins-net

volumes:
  jenkins_home:

networks:
  jenkins-net:
    driver: bridge
```

### 3. `Jenkinsfile`

```groovy
pipeline {
    agent any

    tools {
        // Має збігатися з іменем, яке ви вказали в Manage Jenkins -> Tools
        dockerTool 'docker'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Run Postman Tests') {
            steps {
                script {
                    // Запускаємо Newman через офіційний образ Postman
                    // Файли мають бути у вашому репозиторії
                    sh "docker run --rm -v \\$(pwd):/etc/newman postman/newman run collection.json -e environment.json --reporters cli,html --reporter-html-export reports/report.html"
                }
            }
        }
    }

    post {
        always {
            // Зберігаємо звіт як артефакт
            archiveArtifacts artifacts: 'reports/*.html', fingerprint: true

            // Якщо встановлено плагін HTML Publisher, можна додати гарне відображення
            // publishHTML(target: [reportDir: 'reports', reportFiles: 'report.html', reportName: 'Postman Report'])
        }
    }
}
```

### Як цим користуватися (швидкий старт)

1. Створіть (або оновіть) у проєкті файли `Dockerfile.jenkins`, `docker-compose.yml`, `Jenkinsfile`.
2. У `docker-compose.yml` замініть `NGROK_AUTHTOKEN=ВАШ_ТОКЕН_ТУТ` на ваш реальний токен з ngrok.
3. Запустіть інфраструктуру:

```bash
docker compose up -d --build
```

4. Отримайте публічний URL Jenkins:
   - відкрийте `http://localhost:4040`
   - скопіюйте адресу виду `https://...ngrok-free.dev`
5. У Jenkins вставте цю адресу в `Manage Jenkins -> System -> Jenkins URL`.
6. У GitHub webhook використайте: `https://...ngrok-free.dev/github-webhook/`.

> Примітка для цього репозиторію: якщо у вас файл середовища називається `env.json`, оновіть у `Jenkinsfile` аргумент `-e environment.json` на `-e env.json`.
