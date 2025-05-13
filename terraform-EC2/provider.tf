provider "aws" {
  region = "us-east-1"
}

terraform {
    backend "s3" {
  bucket         = "ecommerce-prod-s3-125"
  region         = "us-east-1"
  key            = "go-grpc-graphql-microservices/terraform-EC2/terraform.tfstate"
  dynamodb_table = "Lock-Files"
  encrypt        = true
}
  required_version = ">=1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.49"
    }
    random = {
      source  = "hashicorp/Random"
      version = "~>3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "> 1.2.0,<2.0.0, != 1.4.0"
    }
  }
}
