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

                        terraform init -migrate-state -force-copy -input=false

                        # Check if EC2 already exists in state
                        if terraform state show aws_instance.app_ec2 > /dev/null 2>&1; then
                            echo "EC2 already exists in state, skipping create"
                        else
                            # Check if EC2 already exists in AWS by tag
                            EXISTING_ID=$(aws ec2 describe-instances \
                                --filters "Name=tag:Name,Values=Course-Management-App" \
                                          "Name=instance-state-name,Values=running" \
                                --query "Reservations[0].Instances[0].InstanceId" \
                                --output text)

                            if [ "$EXISTING_ID" != "None" ] && [ -n "$EXISTING_ID" ]; then
                                echo "EC2 exists in AWS but not in state, importing..."
                                terraform import aws_instance.app_ec2 $EXISTING_ID
                            fi
                        fi

                        terraform apply -auto-approve
                        terraform output -raw app_ec2_public_ip > /tmp/app_ip.txt
                        echo "App EC2 IP: $(cat /tmp/app_ip.txt)"
                        echo "Waiting 60s for EC2 to boot..."
                        sleep 30
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    def appIp = sh(script: "cat /tmp/app_ip.txt", returnStdout: true).trim()

                    sh "docker save ${IMAGE_NAME}:latest -o '${IMAGE_TAR}'"

                    withCredentials([file(credentialsId: 'EC2_SSH_KEY', variable: 'KEY')]) {

                                sh """
                        scp -i \$KEY -o StrictHostKeyChecking=no '${IMAGE_TAR}' ubuntu@${appIp}:/home/ubuntu/

                        ssh -i \$KEY -o StrictHostKeyChecking=no ubuntu@${appIp} '
                            timeout 300 bash -c "until command -v docker >/dev/null 2>&1; do sleep 5; done"
                            timeout 300 bash -c "until systemctl is-active --quiet docker; do sleep 5; done"
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