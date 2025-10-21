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
                script {
                    def ec2_ip = sh(script: "terraform -chdir=terraform output -raw ec2_public_ip", returnStdout: true).trim()

                    // Wait loop to ensure Docker is ready
                    sh """
                        echo 'Waiting for Docker to start on EC2...'
                        for i in {1..10}; do
                            if ssh -o StrictHostKeyChecking=no ec2-user@${ec2_ip} 'docker info > /dev/null 2>&1'; then
                                echo '✅ Docker is ready.'
                                break
                            else
                                echo '⏳ Docker not ready yet... retrying in 10 seconds.'
                                sleep 10
                            fi
                        done
                    """

                    // Proceed with deployment
                    sh """
                        ssh -o StrictHostKeyChecking=no ec2-user@${ec2_ip} \
                        'docker pull ${ECR_REPO_URI}:${BUILD_NUMBER} && docker run -d -p 80:80 ${ECR_REPO_URI}:${BUILD_NUMBER}'
                    """
                }
            }
        }

    }
}