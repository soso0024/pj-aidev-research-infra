
# infrastructure/provider.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
  
  # LocalStack用の設定
  skip_credentials_validation = true
  skip_metadata_api_check    = true
  skip_requesting_account_id = true

  endpoints {
    apigateway = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    s3         = "http://localhost:4566"
    ses        = "http://localhost:4566"
  }
}
