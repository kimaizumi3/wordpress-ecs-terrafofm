# EIP
resource "aws_eip" "nat_gateway" {
  vpc = true
  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name : "my-eip-001"
  }
}

resource "aws_instance" "example" {
  ami           = lookup(var.amis, var.aws_region)
  instance_type = "t2.micro"
  subnet_id = var.subnet_id

  tags = {
    terraform = "true"
  }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.amzn2_latest.value
  associate_public_ip_address = var.associate_public_ip_address
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  iam_instance_profile        = var.iam_instance_profile
  vpc_security_group_ids      = var.vpc_security_group_ids
  user_data                   = var.user_data
  tags                        = merge(tomap({ Name = "${var.name}-ec2" }), var.tags)

  capacity_reservation_specification {
    capacity_reservation_preference = "none"
  }
}

data "aws_ssm_parameter" "amzn2_latest" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2"
}