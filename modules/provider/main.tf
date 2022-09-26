variable "aws_region" {}
variable "aws_profile" {}

###############
## Provider ##
###############
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
