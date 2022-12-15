variable project{}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = "true"
  enable_dns_support = "true"
  tags = {
    Name = "${var.project}_vpc"
  }
}

# Public Subnets
resource "aws_subnet" "publicsubnet1" {
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "ap-northeast-1c"
  cidr_block        = "192.168.1.0/24"
  tags = {
    Name = "${var.project}_publicsubnet1"
  }
}

resource "aws_subnet" "publicsubnet2" {
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "ap-northeast-1d"
  cidr_block        = "192.168.2.0/24"
  tags = {
    Name = "${var.project}_publicsubnet2"
  }
}

# Private Subnets
resource "aws_subnet" "privatesubnet1" {
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "ap-northeast-1c"
  cidr_block        = "192.168.3.0/24"
  tags = {
    Name = "${var.project}_privatesubnet1"
  }
}

resource "aws_subnet" "privatesubnet2" {
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "ap-northeast-1d"
  cidr_block        = "192.168.4.0/24"
  tags = {
    Name = "${var.project}_privatesubnet2"
  }
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name = "${var.project}_igw"
  }
}

# route table
## public
resource "aws_route_table" "rtbpub" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project}_rtbpub"
  }
}

resource "aws_route" "rtbpub-rt" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_route_table.rtbpub.id}"
  gateway_id             = "${aws_internet_gateway.igw.id}"  
}

resource "aws_route_table_association" "rtbpub_assoc" {
  count          = 2
  route_table_id = aws_route_table.rtbpub.id
  subnet_id      = element([aws_subnet.publicsubnet1.id, aws_subnet.publicsubnet2.id], count.index)
}

## private
resource "aws_route_table" "rtbpri" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block     = "0.0.0.0/0"
    network_interface_id = "${aws_instance.nat.primary_network_interface_id}"
  }
  tags = {
    Name = "${var.project}_rtbpri"
  }
}

resource "aws_route_table_association" "rtbpri_assoc" {
  count          = 2
  route_table_id = aws_route_table.rtbpri.id
  subnet_id      = element([aws_subnet.privatesubnet1.id, aws_subnet.privatesubnet2.id], count.index)
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

resource "aws_iam_role" "role" {
  name               = "MyInstanceProfile"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy" "systems_manager" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "iamattach" {
  role = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.systems_manager.arn
}

resource "aws_iam_instance_profile" "systems_manager" {
  name = "${var.project}-InstanceProfile"
  role = aws_iam_role.role.name
}

# NATインスタンス
data "aws_ssm_parameter" "amzn2_latest" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2"
}

 data "template_file" "install_nat" {
   template = file("${path.module}/natinstance.sh")
 }

resource "aws_instance" "nat" {
  ami                  = data.aws_ssm_parameter.amzn2_latest.value
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.publicsubnet1.id
  user_data            = data.template_file.install_nat.rendered
  vpc_security_group_ids = [aws_security_group.nat_sg.id]
  iam_instance_profile = aws_iam_instance_profile.systems_manager.name
  associate_public_ip_address = "true"
  source_dest_check = "false"
  tags = {
      Name = "${var.project}_nat"
    }
}

# NATインスタンス用SG
resource "aws_security_group" "nat_sg" {
  name        = "${var.project}-nat-sg"
  description = "nat-sg"
  vpc_id      = aws_vpc.vpc.id

  //HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16","172.16.0.0/12","10.0.0.0/8"]
  }
  egress {
    from_port = 80
    to_port   = 80
    #protocol    = "-1" は "all" と同等
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16","172.16.0.0/12","10.0.0.0/8"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    #protocol    = "-1" は "all" と同等
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 3306
    to_port     = 3306
    #protocol    = "-1" は "all" と同等
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"]
  }
  egress {
    from_port   = 22
    to_port     = 22
    #protocol    = "-1" は "all" と同等
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"]
  }

  //ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["175.177.42.32/32"]
  }

  tags = {
    Name = "${var.project}-nat-sg"
  }
}

output "EIP" {
  value = "${aws_instance.nat.public_ip}"
}

output "ssm_install_nginx_script" {
  value = data.template_file.install_nat.rendered # <----- syntaxは data.template_file.<LOCAL_FILE>.rendered
}
