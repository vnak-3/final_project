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
                sh '''
                    trivy image \
                      --exit-code 1 \
                      --severity CRITICAL \
                      --no-progress \
                      --format table \
                      -o trivy-report.txt \
                      aupp-lms:latest

                    echo "Trivy report generated:"
                    ls -lh trivy-report.txt
                    cat trivy-report.txt
                '''
                archiveArtifacts artifacts: 'trivy-report.txt', fingerprint: true
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
                    sh '''
                        cd terraform

                        terraform init -input=false
                        terraform apply -auto-approve

                        terraform output -raw app_ec2_public_ip > /tmp/app_ip.txt

                        echo "Waiting for EC2..."
                        sleep 10
                    '''
                }
            }
        }

       stage('Deploy to EC2') {
            steps {
                script {
                    def appIp = sh(script: "cat /tmp/app_ip.txt", returnStdout: true).trim()

                    sh "docker save ${IMAGE_NAME}:latest -o ${IMAGE_TAR}"

                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'EC2_SSH_KEY',
                        keyFileVariable: 'KEY',
                        usernameVariable: 'USER'
                    )]) {

                        sh """
                        chmod 600 \$KEY

                        echo "Testing SSH connection..."
                        ssh -i \$KEY -o StrictHostKeyChecking=no \$USER@${appIp} "echo Connected"

                        echo "Copying image..."
                        scp -i \$KEY -o StrictHostKeyChecking=no ${IMAGE_TAR} \$USER@${appIp}:/home/\$USER/

                        echo "Deploying container..."
                        ssh -i \$KEY -o StrictHostKeyChecking=no \$USER@${appIp} '
                            docker load -i /home/ubuntu/aupp-lms.tar
                            docker stop ${IMAGE_NAME} || true
                            docker rm ${IMAGE_NAME} || true
                            docker run -d --name ${IMAGE_NAME} -p 3000:3000 ${IMAGE_NAME}:latest
                            docker ps
                        '
                        """
                    }

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