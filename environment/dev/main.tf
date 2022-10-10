# provider "aws" {
#     region = var.aws_region
#     profile = var.aws_profile
#     version = "~> 2.49"
# }

###############
## TF Version ##
###############
# terraform {
#   required_version = ">= 0.12.5"
# }

# module内のvariableは空にする
# devなどに引数で宣言



module "provider" {
  source = "../../modules/provider"
  aws_profile = "mayblog"
  aws_region = "ap-northeast-1"
}

module "vpc" {
  source = "../../modules/network"
  # 各プロジェクトで変更
  project = "${local.name_prefix}"
}

module "wordpress_ecr"{
  source = "../../modules/ecr"
  name = "${local.name_prefix}-wordpress"
}

# module "codepipeline" {
#   source = "../../modules/codepipeline"
#   name_prefix = "${local.name_prefix}"
# }
