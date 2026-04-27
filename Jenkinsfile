pipeline {
    agent any

    environment {
        SONAR_URL   = "http://98.94.2.115:9000"
        IMAGE_NAME  = "foodapi"
        TF_DIR      = "${WORKSPACE}/terraform"
        SONAR_KEY   = "assignment7"
        GIT_REPO    = "https://github.com/vnak-3/assignment7.git"
        GIT_BRANCH  = "main"
        APP_IP_FILE = "${WORKSPACE}/app_ip.txt"
        IMAGE_TAR   = "${WORKSPACE}/foodapi.tar"
    }

    stages {

        stage('Clone') {
            steps {
                git url: "${GIT_REPO}", branch: "${GIT_BRANCH}"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    script {
                        def scannerHome = tool 'sonarqube-scanner'
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=${SONAR_KEY} \
                              -Dsonar.sources=./FoodAPI \
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
                sh "docker build -t ${IMAGE_NAME} ./FoodAPI/"
            }
        }

        stage('Trivy Scan') {
            steps {
                sh '''
                    export TRIVY_CACHE_DIR="$WORKSPACE/.trivy-cache"
                    rm -rf "$TRIVY_CACHE_DIR"
                    trivy image --exit-code 0 --severity HIGH,CRITICAL ${IMAGE_NAME}
                '''
            }
        }

        stage('Terraform Provision') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh '''
                        cd "${TF_DIR}"

                        rm -rf .terraform
                        terraform init

                        SG_ID=$(aws ec2 describe-security-groups \
                          --filters Name=vpc-id,Values=vpc-07e80d2f9c85ff873 Name=group-name,Values=foodexpress-app-sg \
                          --query 'SecurityGroups[0].GroupId' \
                          --output text)

                        echo "Found SG ID: $SG_ID"

                        if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
                            terraform state show aws_security_group.app_sg >/dev/null 2>&1 || \
                            terraform import aws_security_group.app_sg "$SG_ID"
                        fi

                        terraform plan -out=tfplan
                        terraform apply -auto-approve tfplan
                        terraform output -raw app_public_ip > "${APP_IP_FILE}"
                        echo "App EC2 IP: $(cat "${APP_IP_FILE}")"
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    def appIp = sh(script: "cat '${APP_IP_FILE}'", returnStdout: true).trim()

                    sh "docker save ${IMAGE_NAME} -o '${IMAGE_TAR}'"

                    sshagent(['app-ec2-ssh']) {
                        sh """
                            scp -o StrictHostKeyChecking=no '${IMAGE_TAR}' ubuntu@${appIp}:/home/ubuntu/

                            ssh -o StrictHostKeyChecking=no ubuntu@${appIp} '
                                timeout 300 bash -c "until command -v docker >/dev/null 2>&1; do sleep 5; done"
                                timeout 300 bash -c "until systemctl is-active --quiet docker; do sleep 5; done"
                                docker load -i /home/ubuntu/${IMAGE_NAME}.tar
                                docker stop ${IMAGE_NAME} || true
                                docker rm ${IMAGE_NAME} || true
                                docker run -d --name ${IMAGE_NAME} -p 3000:3000 ${IMAGE_NAME}
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
            sh '''
                rm -f "${IMAGE_TAR}" "${APP_IP_FILE}" || true
                rm -rf "$WORKSPACE/.trivy-cache" || true
            '''
        }
        success {
            echo "Pipeline completed! App deployed successfully."
        }
        failure {
            echo "Pipeline failed. Check the logs above."
        }
    }
}