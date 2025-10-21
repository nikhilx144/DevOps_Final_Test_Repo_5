pipeline {
    agent any

    tools {
        terraform "terraform-latest"
    }

    environment {
        AWS_REGION = 'ap-south-2'
        AWS_ACCOUNT_ID = '661979762009'
        ECR_REPO_NAME = 'devops_ci_cd_final_prac_5'
        ECR_REPO_URI = '661979762009.dkr.ecr.ap-south-2.amazonaws.com/devops_ci_cd_final_prac_5'
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withAWS(credentials: 'aws_credentials', region: AWS_REGION) {
                        sh 'rm -rf .terraform .terraform.lock.hcl terraform.tfstate*'
                        sh 'terraform init -input=false -reconfigure'
                        sh 'terraform apply -auto-approve'
                        script {
                            env.EC2_PUBLIC_IP = sh(returnStdout: true, script: 'terraform output -raw ec2_public_ip').trim()
                        }
                    }
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                sh '''
                    apt-get update && apt-get install -y unzip
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -o awscliv2.zip
                    # The --update flag tells the installer to overwrite the existing installation
                    ./aws/install --update
                    # Clean up the installer files so the workspace is fresh for the next run
                    rm -rf aws awscliv2.zip
                '''

                sh 'docker system prune -a -f'

                withAWS(credentials: 'aws_credentials', region: AWS_REGION) {
                    sh "docker build -t ${ECR_REPO_URI}:${BUILD_NUMBER} ."
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URI}"
                    sh "docker push ${ECR_REPO_URI}:${BUILD_NUMBER}"
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i \${SSH_KEY} ec2-user@${env.EC2_PUBLIC_IP} '
                            echo "🚀 Starting deployment on EC2..."

                            # Wait for Docker to be ready (max 10 attempts, 10s apart)
                            for i in {1..10}; do
                                if sudo docker info > /dev/null 2>&1; then
                                    echo "✅ Docker is ready!"
                                    break
                                else
                                    echo "⏳ Waiting for Docker to start... attempt \$i"
                                    sleep 10
                                fi
                            done

                            # Confirm Docker is indeed running before proceeding
                            if ! sudo docker info > /dev/null 2>&1; then
                                echo "❌ Docker did not start after waiting. Exiting..."
                                exit 1
                            fi

                            # Log in to ECR (requires IAM Role on EC2 or credentials)
                            sudo aws ecr get-login-password --region ${AWS_REGION} | \
                                sudo docker login --username AWS --password-stdin ${ECR_REPO_URI}

                            # Pull the new image
                            sudo docker pull ${ECR_REPO_URI}:${BUILD_NUMBER}

                            # Stop and remove old container if it exists
                            sudo docker stop web-app || true
                            sudo docker rm web-app || true

                            # Run the new container
                            sudo docker run -d --name web-app -p 80:80 ${ECR_REPO_URI}:${BUILD_NUMBER}

                            echo "🎉 Deployment successful!"
                        '
                    """
                }
            }
        }
    }
}