terraform {
  backend "s3" {
    bucket         = "simple-lambda-tfstate"
    key            = "simple-lambda/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "simple-lambda-tflock"
    encrypt        = true
  }
}
