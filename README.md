# postman-ci-tests

Репозиторій для запуску Postman collection у CI через Newman, Docker і Jenkins.

## Файли проєкту

- `collection.json` - Postman collection.
- `env.json` - Postman environment (`baseUrl`, `notesUrl`).
- `Dockerfile` - образ для запуску `newman` з репортерами.
- `Jenkinsfile` - Jenkins pipeline для запуску тестів і збереження звітів.
- `Dockerfile.jenkins` - кастомний Jenkins image з Docker CLI.
- `docker-compose.yml` - локальний Jenkins у Docker.

## 1. Локальний запуск через Newman

```bash
npm install -g newman newman-reporter-htmlextra
newman run collection.json -e env.json -r cli,junit,htmlextra \
  --reporter-junit-export results.xml \
  --reporter-htmlextra-export report.html
```

Після виконання у корені проєкту зʼявляться:
- `results.xml` (JUnit для CI)
- `report.html` (детальний HTML-звіт)

## 2. Запуск через Docker

```bash
docker build -t postman-tests-app .
docker run --rm -v "$PWD:/etc/newman" postman-tests-app run collection.json -e env.json -r cli,junit,htmlextra \
  --reporter-junit-export results.xml \
  --reporter-htmlextra-export report.html
```

Команда монтує поточну папку в контейнер, тому звіти залишаються локально.

## 3. Запуск Jenkins локально (Docker Compose)

```bash
docker compose up -d --build
```

- Jenkins UI: `http://localhost:8081`
- Agent порт: `50001`
- Контейнер: `jenkins_postman`

Перший пароль адміністратора:

```bash
docker exec jenkins_postman cat /var/jenkins_home/secrets/initialAdminPassword
```

Далі створіть `Pipeline` job, підключіть репозиторій і використовуйте `Jenkinsfile` з кореня.

## Що робить Jenkinsfile

- Будує Docker image `postman-tests-app`.
- Створює контейнер `api-runner-${BUILD_NUMBER}` для запуску Newman.
- Копіює `collection.json` та `env.json` в `/etc/newman`.
- Запускає тести з репортерами `cli,junit,htmlextra`.
- Завантажує назад `results.xml` і `report.html`.
- Публікує `results.xml` як JUnit, `report.html` як artifact.
- Очищає контейнер і Docker image після виконання.
