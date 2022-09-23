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

    stage("Infrastructure Deploy") {
      when {
        expression {
          ACTION == "Deploy"
        }
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
        always {
          cleanWs()
        }
      }
    }
  }
}
