pipeline {
    agent any

    environment {
        SONAR_URL   = "http://100.31.147.77:9000"
        IMAGE_NAME  = "aupp-lms"
        SONAR_KEY   = "AUPP-LMS"
        GIT_REPO    = "https://github.com/vnak-3/final_project.git"
        GIT_BRANCH  = "main"
        DOCKER_USER = "vnak3"
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
                              -Dsonar.projectKey=AUPP-LMS \
                              -Dsonar.sources=. \
                              -Dsonar.host.url=http://100.31.147.77:9000 \
                              -Dsonar.exclusions=**/node_modules/**,**/.DS_Store,**/dist/**,**/.next/**,**/terraform/**
                        """
                    }
                }
            }
}

        stage('Checkout Code') {
            steps {
                git branch: "${GIT_BRANCH}", url: "${GIT_REPO}"
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
                sh "trivy image --exit-code 1 --severity CRITICAL --no-progress ${IMAGE_NAME}:latest"
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
                        echo "\$DOCKER_PASSWORD" | docker login -u "\$DOCKER_USERNAME" --password-stdin
                        docker tag ${IMAGE_NAME}:latest \$DOCKER_USERNAME/${IMAGE_NAME}:latest
                        docker push \$DOCKER_USERNAME/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Terraform Provision') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDS'
                ]]) {
                   sh """
                        chmod 600 \$KEY

                        echo "Testing SSH connection..."
                        ssh -i \$KEY -o StrictHostKeyChecking=no ubuntu@${appIp} "echo Connected"

                        echo "Copying image..."
                        scp -i \$KEY -o StrictHostKeyChecking=no ${IMAGE_TAR} ubuntu@${appIp}:/home/ubuntu/

                        echo "Deploying container..."
                        ssh -i \$KEY -o StrictHostKeyChecking=no ubuntu@${appIp} '
                            set -e

                            echo "Waiting for Docker..."
                            timeout 300 bash -c "until command -v docker >/dev/null 2>&1; do sleep 5; done"
                            timeout 300 bash -c "until systemctl is-active --quiet docker; do sleep 5; done"

                            echo "Loading image..."
                            docker load -i /home/ubuntu/aupp-lms.tar

                            echo "Restarting container..."
                            docker stop ${IMAGE_NAME} || true
                            docker rm ${IMAGE_NAME} || true

                            docker run -d --name ${IMAGE_NAME} -p 3000:3000 ${IMAGE_NAME}:latest

                            echo "Running containers:"
                            docker ps
                        '
                        """
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    def appIp = sh(script: "cat /tmp/app_ip.txt", returnStdout: true).trim()

                    sh "docker save ${IMAGE_NAME}:latest -o ${IMAGE_TAR}"

                    withCredentials([file(credentialsId: 'EC2_SSH_KEY', variable: 'KEY')]) {

                        sh """
                        chmod 600 \$KEY

                        echo "Testing SSH connection..."
                        ssh -i \$KEY -o StrictHostKeyChecking=no ubuntu@${appIp} "echo Connected"

                        echo "Copying image..."
                        scp -i \$KEY -o StrictHostKeyChecking=no ${IMAGE_TAR} ubuntu@${appIp}:/home/ubuntu/

                        echo "Deploying container..."
                        ssh -i \$KEY -o StrictHostKeyChecking=no ubuntu@${appIp} '
                            docker load -i /home/ubuntu/aupp-lms.tar
                            docker stop ${IMAGE_NAME} || true
                            docker rm ${IMAGE_NAME} || true
                            docker run -d --name ${IMAGE_NAME} -p 3000:3000 ${IMAGE_NAME}:latest
                            docker ps
                        '
                        """

                    }

                    // ✅ FIX: keep it inside script block
                    echo "App is live at http://${appIp}:3000"
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
            echo "Pipeline completed! App deployed successfully."
        }
        failure {
            echo "Pipeline failed. Check the logs above."
        }
    }
}