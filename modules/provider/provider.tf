variable "aws_region" {}
variable "aws_profile" {}

###############
## Provider ##
###############
provider "aws" {
    region = var.aws_region
    profile = var.aws_profile

  #  default_tags{
  #    tags = {
  #      Env = "prod"
  #      System = "mayblog"
  #    }
  #  }
}

###############
## TF Version ##
###############
terraform {
  required_providers{
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
