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
                            sh "echo $EC2_PUBLIC_IP"
                            sh '''
                            ip="${EC2_PUBLIC_IP}"
                            while true; do
                            if ssh -i test.pem -o StrictHostKeyChecking=no ubuntu@"${ip}" test -e /home/ubuntu/.kube/config; then
                                scp -i test.pem host:~/.kube/config .
                                break;
                            else
                                echo "Not Found"
                                sleep 5
                            fi
                            done
                            '''
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
                            def kubeconfig = new File(env.WORKSPACE, "terraform-modules").getParent() + "/config"
                            withEnv(["KUBECONFIG=${kubeconfig}"]) {
                                sh "kubectl apply -f deployment-hello.yaml"
                                sh "kubectl apply -f fluentd.yaml"
                                sh "kubectl apply -f php-apche.yaml"
                                sh "kubectl apply -f kube-state-metrics-configs/"
                                sh "kubectl apply -f prometheus/"
                                sh "kubectl apply -f grafana/"
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
                        }
                    }
                }
                cleanWs()
            }
        }
    }
}