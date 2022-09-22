pipeline {
  agent any
  environment {
    DEPLOYMENT_PARAM_INFRA_PATH = "infrastructure-vars"
    DEPLOYMENT_PARAM_TFVAR = "terraform.tfvars"
    TERRAFORM_STATE_S3_BUCKET = "hands-on-tf-state"
    TERRAFORM_STATE_S3_BUCKET_REGION = "us-east-1"
  }
  stages {
    stage('Setup Parameters') {
      steps {
        script {
          properties(
            [
              parameters(
                [
                  string(
                    name: 'InfraName',
                  ),
                  choice(
                    choices: ['Deploy', 'Destroy'],
                    name: 'Action',
                  ),
                ]
              )
            ]
          )
        }
      }
    }

    stage("Initialization") {
      steps {
        script {
          sh "mv $DEPLOYMENT_PARAM_INFRA_PATH/${params.InfraName}/$DEPLOYMENT_PARAM_TFVAR terraform-modules/infra_terraform.tfvars"
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
              sh "terraform init -no-color -backend-config='bucket=${TERRAFORM_STATE_S3_BUCKET}' -backend-config='key=${params.InfraName}' -backend-config='region=${TERRAFORM_STATE_S3_BUCKET_REGION}' "
            }
          }
        }
      }
    }

    stage("Infrastructure Deploy") {
      when {
        expression {
          params.Action == "Deploy"
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
          params.Action == "Destroy"
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
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
