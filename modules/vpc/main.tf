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

resource "aws_route" "mayblog_rtbpri" {
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
  tags = {
    Name = "mayblog_rtbpri_${var.stage}"
  }
}

resource "aws_route_table_association" "mayblog_rtbpri_assoc" {
  count          = 2
  route_table_id = aws_route_table.mayblog_rtbpri.id
  subnet_id      = element([aws_subnet.mayblog_privatesubnet1.id, aws_subnet.mayblog_privatesubnet2.id], count.index)
}

