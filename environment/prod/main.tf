module "provider" {
  source = "../../modules/provider"
  aws_profile = ""
  aws_region = "ap-northeast-1"
}

module "network" {
  source = "../../modules/network"
  # 各プロジェクトで変更
  project = "${local.name_prefix}"
}

module "wordpress_ecr"{
  source = "../../modules/ecr"
  name = "${local.name_prefix}-wordpress"
}

module "mayblog_rds" {
  source = "../../modules/rds"
  project = "${local.name_prefix}"
  # module.module名.引き出したい変数
  vpc_id = module.network.vpc_id
  privatesubnet1 = module.network.privatesubnet1
  privatesubnet2 = module.network.privatesubnet2
}

module "mayblog_cicd" {
  source = "../../modules/iam"
  project = "${local.name_prefix}"
}


module "mayblog_ecs" {
  source = "../../modules/ecs"
  project = "${local.name_prefix}"
  vpc_id = module.network.vpc_id
  privatesubnet1 = module.network.privatesubnet1
  privatesubnet2 = module.network.privatesubnet2
  publicsubnet1 = module.network.publicsubnet1
  publicsubnet2 = module.network.publicsubnet2
  domain = "${local.domain}"
}