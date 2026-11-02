terraform {
  backend "s3" {
    bucket = "acme-terraform-state"
    key    = "fulfillment/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = "eu-north-1"
}

module "fulfillment" {
  source      = "../../../modules/fulfillment"
  environment = "prod"
}
