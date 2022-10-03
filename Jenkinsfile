def EC2_PUBLIC_IP
pipeline {
    agent any
    environment {
        DEPLOYMENT_PARAM_INFRA_PATH = "infrastructure-vars"
        DEPLOYMENT_PARAM_TFVAR = "terraform.tfvars"
        TERRAFORM_STATE_S3_BUCKET = "hands-on-tf-state"
        TERRAFORM_STATE_S3_BUCKET_REGION = "us-east-1"
        INFRA_NAME = "${params.InfraName}"
        ACTION = "${params.Action}" 
        PEM_KEY = "$INFRA_NAME" + ".pem"
    }
    stages {
        stage("Initialization") {
            steps {
                script {
                    sh "mv $DEPLOYMENT_PARAM_INFRA_PATH/$INFRA_NAME/$DEPLOYMENT_PARAM_TFVAR terraform-modules/b_terraform.auto.tfvars"
                    dir('terraform-modules') {
                        withCredentials(
                        [
                            [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'AWS Credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                            ]
                        ]
                        ) {
                            sh "terraform init -no-color -backend-config='bucket=${TERRAFORM_STATE_S3_BUCKET}' -backend-config='key=${INFRA_NAME}' -backend-config='region=${TERRAFORM_STATE_S3_BUCKET_REGION}' "
                        }
                    }
                }
            }
        }
        stage("Infrastructure Plan") {
            steps {
                script {
                    dir('terraform-modules') {
                        withCredentials(
                        [
                            [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'AWS Credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                            ]
                        ]
                        ) {
                            sh "terraform plan -no-color"
                        }
                    }
                }
            }
        }
        stage("Infrastructure Apply") {
            when {
                expression {
                    ACTION == "Deploy"
                }
            }
            input{
                message "Should we create infrastructure?"
                ok "Yes we should"
            }
            steps {
                script {
                    dir('terraform-modules') {
                        withCredentials(
                        [
                            [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'AWS Credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                            ]
                        ]
                        ) {
                            sh "terraform apply -auto-approve -no-color"
                            EC2_PUBLIC_IP=sh(returnStdout: true, script: "terraform output ec2_complete_public_ip").trim()
                            sh "chmod 400 test.pem"
                            sh "mv test.pem /var/lib/jenkins/pem/$PEM_KEY"
                            sh """
                            while true; do
                            if ssh -i /var/lib/jenkins/pem/$PEM_KEY -o StrictHostKeyChecking=no ec2-user@$EC2_PUBLIC_IP test -e /home/ec2-user/.kube/config; then
                                scp -i /var/lib/jenkins/pem/$PEM_KEY -o StrictHostKeyChecking=no ec2-user@$EC2_PUBLIC_IP:~/.kube/config .
                                mv config /var/lib/jenkins/kubeconfig/$INFRA_NAME
                                sleep 10
                                break;
                            else
                                echo "Not Found"
                                sleep 10
                            fi
                            done
                            """
                        }
                    }  
                }
            }
        }
        stage("Application Deploy") {
            when {
                expression {
                    ACTION == "Deploy"
                }
            }
            steps {
                script {
                    dir('k8s-deployments') {
                        withCredentials(
                        [
                            [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'AWS Credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                            ]
                        ]
                        ) {
                            withEnv(["KUBECONFIG=/var/lib/jenkins/kubeconfig/$INFRA_NAME"]) {
                                sh "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"
                                sh "kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
                                sh "helm upgrade -i hello helm-deployment"
                                sh "kubectl apply -f fluentd.yaml"
                                sh "kubectl apply -f php-apche.yaml"
                            } 
                        }
                    }
                }
            }
        }
        stage("Infrastructure Destroy") {
            when {
                expression {
                    ACTION == "Destroy"
                }
            }
            input{
                message "Should we destroy infrastructure?"
                ok "Yes we should"
            }
            steps {
                script {
                    dir('terraform-modules') {
                        withCredentials(
                        [
                            [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'AWS Credentials',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                            ]
                        ]
                        ) {
                            sh "terraform destroy -auto-approve -no-color"
                            sh "rm -rf /var/lib/jenkins/pem/$PEM_KEY"
                            sh "rm -rf /var/lib/jenkins/kubeconfig/$INFRA_NAME"
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}