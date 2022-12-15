variable project{}

# OIDC 
data "http" "github_actions_openid_configuration" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

data "tls_certificate" "github_actions" {
  url = jsondecode(data.http.github_actions_openid_configuration.body).jwks_uri
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = data.tls_certificate.github_actions.certificates[*].sha1_fingerprint
}

# role
resource "aws_iam_role" "deployer" {
  name = "${var.project}-iamrole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.github_actions.arn
        },
        "Action" : [
            "sts:AssumeRoleWithWebIdentity",
            "sts:TagSession"
        ],
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:sub" : "repo:kimaizumi3/wordpress-docker:*"
          },
        }
      }
    ]
  })
}

# ecr権限付与
data "aws_iam_policy" "ecr_poweruser" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "role_deployer_policy" {
    role = aws_iam_role.deployer.name
    policy_arn = data.aws_iam_policy.ecr_poweruser.arn
}

