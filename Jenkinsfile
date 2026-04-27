pipeline {
    agent any

    environment {
        SONAR_URL   = "http://100.31.147.77:9000"
        IMAGE_NAME  = "aupp-lms"
        SONAR_KEY   = "AUPP-LMS"
        GIT_REPO    = "https://github.com/vnak-3/final_project.git"
        GIT_BRANCH  = "main"
        DOCKER_USER = "vnak3"
        APP_IP      = "34.228.170.128"
        IMAGE_TAR   = "${WORKSPACE}/aupp-lms.tar"
    }

    stages {

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    script {
                        def scannerHome = tool 'SonarScanner'
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=${SONAR_KEY} \
                              -Dsonar.sources=. \
                              -Dsonar.host.url=${SONAR_URL}
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:latest 'Course Management/'"
            }
        }

        stage('Trivy Scan') {
            steps {
                sh """
                    trivy image \
                      --exit-code 1 \
                      --severity CRITICAL \
                      --no-progress \
                      ${IMAGE_NAME}:latest
                """
            }
      }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'DOCKER_HUB',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                        docker tag ${IMAGE_NAME}:latest $DOCKER_USERNAME/${IMAGE_NAME}:latest
                        docker push $DOCKER_USERNAME/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    sh "docker save ${IMAGE_NAME}:latest -o '${IMAGE_TAR}'"

                    sshagent(['EC2_SSH_KEY']) {
                        sh """
                            scp -o StrictHostKeyChecking=no '${IMAGE_TAR}' ubuntu@${APP_IP}:/home/ubuntu/

                            ssh -o StrictHostKeyChecking=no ubuntu@${APP_IP} '
                                docker load -i /home/ubuntu/aupp-lms.tar
                                docker stop ${IMAGE_NAME} || true
                                docker rm ${IMAGE_NAME} || true
                                docker run -d --name ${IMAGE_NAME} -p 3000:3000 ${IMAGE_NAME}:latest
                                docker ps
                            '
                        """
                    }

                    echo "App is live at http://${APP_IP}:3000"
                }
            }
        }
    }

    post {
        always {
            sh """
                rm -f "${IMAGE_TAR}" || true
                docker logout || true
            """
        }
        success {
            echo "Pipeline completed! App deployed successfully at http://${APP_IP}:3000"
        }
        failure {
            echo "Pipeline failed. Check the logs above."
        }
    }
}