provider "aws" {
    region = var.aws_region
    profile = var.aws_profile
    version = "~> 2.49"
}

###############
## TF Version ##
###############
terraform {
  required_version = ">= 0.12.5"
}

# module "provider" {
#   source = "../../modules/provider"
# }

module "vpc" {
  source = "../../modules/vpc"
  stage = var.stage
}