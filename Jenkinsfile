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
                            # Log in to ECR on the EC2 instance (requires AWS CLI and IAM Role on EC2)
                            # NOTE: For this to work, you must attach an IAM Role to your EC2 instance that allows ECR access.
                            # Or you would need to configure AWS credentials on the instance itself.
                            
                            sudo aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${ECR_REPO_URI}
                            
                            # Pull the new image
                            sudo docker pull ${ECR_REPO_URI}:${BUILD_NUMBER}
                            
                            # Stop and remove the old container if it exists
                            sudo docker stop web-app || true
                            sudo docker rm web-app || true
                            
                            # Run the new container
                            sudo docker run -d --name web-app -p 80:80 ${ECR_REPO_URI}:${BUILD_NUMBER}
                        '
                    """
                }
            }
        }
    }
}