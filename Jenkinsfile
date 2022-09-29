pipeline {
    agent any
    environment {
        DEPLOYMENT_PARAM_INFRA_PATH = "infrastructure-vars"
        DEPLOYMENT_PARAM_TFVAR = "terraform.tfvars"
        TERRAFORM_STATE_S3_BUCKET = "hands-on-tf-state"
        TERRAFORM_STATE_S3_BUCKET_REGION = "us-east-1"
        INFRA_NAME = "${params.InfraName}"
        ACTION = "${params.Action}"
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
                            def EC2_PUBLIC_IP=sh(returnStdout: true, script: "terraform output ec2_complete_public_ip").trim()
                            sh "chmod 400 test.pem"
                            sh "mv test.pem ./../test_$INFRA_NAME.pem"
                            sh """
                            while true; do
                            if ssh -i ./../test_$INFRA_NAME.pem -o StrictHostKeyChecking=no ubuntu@$EC2_PUBLIC_IP test -e /home/ubuntu/.kube/config; then
                                scp -i ./../test_$INFRA_NAME.pem -o StrictHostKeyChecking=no ubuntu@$EC2_PUBLIC_IP:~/.kube/config
                                mv config ./../config_$INFRA_NAME
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
                            sh "export KUBECONFIG=./../config_$INFRA_NAME"
                            // withEnv(["KUBECONFIG=${kubeconfig}"]) {
                            sh "kubectl apply -f deployment-hello.yaml"
                            sh "kubectl apply -f fluentd.yaml"
                            sh "kubectl apply -f php-apche.yaml"
                            sh "kubectl apply -f kube-state-metrics-configs/"
                            sh "kubectl apply -f prometheus/"
                            sh "kubectl apply -f grafana/"
                            // }
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
                            sh "rm -rf ./../test_$INFRA_NAME.pem"
                            sh "rm -rf ./../config_$INFRA_NAME"
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