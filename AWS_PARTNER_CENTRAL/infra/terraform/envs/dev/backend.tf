terraform {
  backend "s3" {
    bucket         = "pcw-tfstate-dev"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pcw-tflock-dev"
    encrypt        = true
  }
}
