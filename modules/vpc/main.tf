# variable
variable "stage" {}

# VPC
resource "aws_vpc" "mayblog_vpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "mayblog_vpc_${var.stage}"
  }
}

# Public Subnets
resource "aws_subnet" "mayblog_publicsubnet1" {
  vpc_id = "${aws_vpc.mayblog_vpc.id}"
  availability_zone = "ap-northeast-1c"
  cidr_block        = "192.168.1.0/24"
  tags = {
    Name = "mayblog_publicsubnet1_${var.stage}"
  }
}

resource "aws_subnet" "mayblog_publicsubnet2" {
  vpc_id = "${aws_vpc.mayblog_vpc.id}"
  availability_zone = "ap-northeast-1d"
  cidr_block        = "192.168.2.0/24"
  tags = {
    Name = "mayblog_publicsubnet2_${var.stage}"
  }
}

# Private Subnets
resource "aws_subnet" "mayblog_privatesubnet1" {
  vpc_id = "${aws_vpc.mayblog_vpc.id}"
  availability_zone = "ap-northeast-1c"
  cidr_block        = "192.168.3.0/24"
  tags = {
    Name = "mayblog_privatesubnet1_${var.stage}"
  }
}

resource "aws_subnet" "mayblog_privatesubnet2" {
  vpc_id = "${aws_vpc.mayblog_vpc.id}"
  availability_zone = "ap-northeast-1d"
  cidr_block        = "192.168.4.0/24"
  tags = {
    Name = "mayblog_privatesubnet2_${var.stage}"
  }
}

# Internet gateway
resource "aws_internet_gateway" "mayblog_igw" {
  vpc_id = "${aws_vpc.mayblog_vpc.id}"
  tags = {
    Name = "mayblog_igw_${var.stage}"
  }
}

# route table
## public
resource "aws_route_table" "mayblog_rtbpub" {
  vpc_id = aws_vpc.mayblog_vpc.id
  tags = {
    Name = "mayblog_rtbpub_${var.stage}"
  }
}

resource "aws_route" "mayblog_rtbpub-rt" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_route_table.mayblog_rtbpub.id}"
  gateway_id             = "${aws_internet_gateway.mayblog_igw.id}"  
}

resource "aws_route_table_association" "mayblog_rtbpub_assoc" {
  count          = 2
  route_table_id = aws_route_table.mayblog_rtbpub.id
  subnet_id      = element([aws_subnet.mayblog_publicsubnet1.id, aws_subnet.mayblog_publicsubnet2.id], count.index)
}

## private
resource "aws_route_table" "mayblog_rtbpri" {
  vpc_id = "${aws_vpc.mayblog_vpc.id}"
  route {
    cidr_block     = "0.0.0.0/0"
    network_interface_id = "${aws_instance.mayblog_nat.primary_network_interface_id}"
  }
  tags = {
    Name = "mayblog_rtbpri_${var.stage}"
  }
}

resource "aws_route_table_association" "mayblog_rtbpri_assoc" {
  count          = 2
  route_table_id = aws_route_table.mayblog_rtbpri.id
  subnet_id      = element([aws_subnet.mayblog_privatesubnet1.id, aws_subnet.mayblog_privatesubnet2.id], count.index)
}

# IAMロール
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mayblog_role" {
  name               = "mayblog_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy" "systems_manager" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "mayblog_iamattach" {
  role = aws_iam_role.mayblog_role.name
  policy_arn = data.aws_iam_policy.systems_manager.arn
}

resource "aws_iam_instance_profile" "systems_manager" {
  name = "MyInstanceProfile"
  role = aws_iam_role.mayblog_role.name
}

# NATインスタンス
data "aws_ssm_parameter" "amzn2_latest" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2"
}

 data "template_file" "install_nat" {
   template = file("${path.module}/natinstance.sh")
 }

resource "aws_instance" "mayblog_nat" {
  ami                  = data.aws_ssm_parameter.amzn2_latest.value
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.mayblog_publicsubnet1.id
  user_data            = data.template_file.install_nat.rendered
  iam_instance_profile = aws_iam_instance_profile.systems_manager.name
  associate_public_ip_address = "true"
  source_dest_check = "false"
  tags = {
      Name = "mayblog_nat_${var.stage}"
    }
}

output "mayblog-EIP" {
  value = "${aws_instance.mayblog_nat.public_ip}"
}

output "ssm_install_nginx_script" {
  value = data.template_file.install_nat.rendered # <----- syntaxは data.template_file.<LOCAL_FILE>.rendered
}
