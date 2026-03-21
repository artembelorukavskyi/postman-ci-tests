pipeline {
    agent any

    options {
        ansiColor('xterm')
        timeout(time: 10, unit: 'MINUTES')
    }

    environment {
        DOCKER_IMAGE = "postman-tests-app"
        CONTAINER_NAME = "api-runner-${BUILD_NUMBER}"
    }

    stages {
        stage('Cleanup Workspace') {
            steps {
                deleteDir()
                // Видаляємо старі звіти, якщо вони залишились
                sh "rm -rf allure-results results.xml report.html || true"
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                // Збираємо образ з твого Dockerfile
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        stage('Run API Tests') {
            steps {
                script {
                    try {
                        // Запускаємо тест.
                        // --rm автоматично видалить контейнер після завершення,
                        // але ми даємо ім'я, щоб встигнути скопіювати файли у разі потреби
                        sh "docker run --name ${CONTAINER_NAME} ${DOCKER_IMAGE}"
                    } catch (Exception e) {
                        echo "Tests failed, but we continue to collect reports..."
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }

        stage('Archive Results') {
            steps {
                script {
                    // Перевіряємо, чи існує контейнер перед копіюванням
                    def containerExists = sh(script: "docker ps -a --format '{{.Names}}' | grep '^${CONTAINER_NAME}\$' ", returnStatus: true) == 0

                    if (containerExists) {
                        echo "Extracting reports from container..."
                        // Копіюємо звіти з контейнера в папку Jenkins
                        sh "docker cp ${CONTAINER_NAME}:/etc/newman/newman/ . || true"
                        // Видаляємо контейнер вручну
                        sh "docker rm -f ${CONTAINER_NAME}"
                    }
                }
            }
        }
    }

    post {
        always {
            // Публікуємо результати JUnit (якщо Newman генерує xml)
            junit testResults: '**/results.xml', allowEmptyResults: true

            // Якщо у тебе є HTML звіт, він буде доступний в Artifacts
            archiveArtifacts artifacts: '*.html', allowEmptyArchive: true

            echo "Pipeline finished. Check artifacts for HTML report."
        }
        cleanup {
            // Видаляємо образ, щоб не забивати пам'ять на MacBook
            sh "docker rmi ${DOCKER_IMAGE} || true"
        }
    }
}