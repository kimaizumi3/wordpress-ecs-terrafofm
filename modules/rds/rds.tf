##################
# sudo yum install mysql -y
# mysql -u admin -p -h RDSのエンドポイントを張り付け
# create database wordpress;
# CREATE USER 'wordpress'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
# grant all privileges on wordpress.* to wordpress@'%';
##################

variable "project"{}
variable "vpc_id"{}
variable "privatesubnet1" {}
variable "privatesubnet2" {}
#----------------------------------------
# RDSの構築
#----------------------------------------

# サブネットグループの作成
resource "aws_db_subnet_group" "dbsubnet" {
  name       = "${var.project}-dbsubnet"
  subnet_ids = [var.privatesubnet1, var.privatesubnet2]

  tags = {
    Name = "${var.project}-dbsubnet"
  }
}

#RDSの作成
resource "aws_db_instance" "rds" {
  identifier             = "${var.project}-rds"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0.31"
  instance_class         = "db.t4g.micro"
  username               = "admin"
  password               = "wordpress"
  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.dbsubnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  storage_encrypted = false
  #kms_key_id        = "arn:aws:kms:ap-southeast-1:アカウントID:key/e0b1110b-a12e-4a63-a87e-5b838d15ab4c"
  //バックアップを保持する日数
  backup_retention_period = 0

  //DB削除前にスナップショットを作成しない
  skip_final_snapshot = true

  tags = {
    name = "${var.project}-rds"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project}-rds-sg"
  description = "rds-sg"
  vpc_id      = var.vpc_id

  //MYSQL
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16","172.16.0.0/12","10.0.0.0/8"]
  }
  egress {
    from_port = 0
    to_port   = 0
    #protocol    = "-1" は "all" と同等
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-rds-sg"
  }
}

####################
# Parameter
####################
resource "aws_ssm_parameter" "wordpress_db_host" {
  name        = "WORDPRESS_DB_HOST"
  description = "WORDPRESS_DB_HOST"
  type        = "String"
  value       = aws_db_instance.rds.address
}