pipeline {
    agent any

    options {
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        DOCKER_IMAGE = "postman-tests-app"
        CONTAINER_NAME = "api-runner-${BUILD_NUMBER}"
    }

    stages {
        stage('Prepare & Cleanup') {
            steps {
                script {
                    echo "🧹 Очищення старих контейнерів..."
                    sh "docker rm -f ${CONTAINER_NAME} || true"
                }
            }
        }

        stage('Build Image') {
            steps {
                script {
                    echo "🏗️ Збірка Docker образу з Newman..."
                    sh "docker build -t ${DOCKER_IMAGE} ."
                }
            }
        }

        stage('Run API Tests') {
            steps {
                script {
                    echo "🚀 Запуск тестів у контейнері..."
                    sh """
                        docker create --name ${CONTAINER_NAME} ${DOCKER_IMAGE} \
                        run collection.json \
                        -e env.json \
                        -r cli,junit,htmlextra \
                        --reporter-junit-export results.xml \
                        --reporter-htmlextra-export report.html
                    """
                    sh "docker cp collection.json ${CONTAINER_NAME}:/etc/newman/collection.json"
                    sh "docker cp env.json ${CONTAINER_NAME}:/etc/newman/env.json"
                    try {
                        sh "docker start -a ${CONTAINER_NAME}"
                    } catch (Exception e) {
                        echo "⚠️ Деякі тести не пройшли (це нормально, перевірте звіти)"
                    }
                }
            }
        }

        stage('Extract Reports') {
            steps {
                script {
                    echo "📥 Копіювання звітів з контейнера..."
                    sh "docker cp ${CONTAINER_NAME}:/etc/newman/results.xml . || true"
                    sh "docker cp ${CONTAINER_NAME}:/etc/newman/report.html . || true"
                    sh "docker rm -f ${CONTAINER_NAME} || true"
                }
            }
        }
    }

    post {
        always {
            echo "📊 Публікація звітів..."
            junit 'results.xml'
            archiveArtifacts artifacts: 'report.html', allowEmptyArchive: true
        }

        success {
            echo "✅ Тести пройшли успішно!"
        }

        failure {
            echo "❌ Помилка в пайплайні!"
        }

        cleanup {
            script {
                echo "♻️ Видалення тимчасового образу..."
                sh "docker rmi ${DOCKER_IMAGE} || true"
            }
        }
    }
}