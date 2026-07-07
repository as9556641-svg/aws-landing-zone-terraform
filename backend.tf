# Configure Terraform Remote Backend

terraform {

  backend "s3" {

    bucket         = "ajeet-terraform-state-2026"
    key            = "aws-landing-zone/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true

  }

}