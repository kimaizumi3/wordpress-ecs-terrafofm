variable "project"{}
variable "vpc_id" {}
variable "privatesubnet1" {}
variable "privatesubnet2" {}
variable "publicsubnet1" {}
variable "publicsubnet2" {}
variable "domain" {}

variable "enable_alb" {
  type = bool
  default = true
}
data "aws_route53_zone" "this" {
    name = ".com"
}

#acm
# acm
resource "aws_acm_certificate" "root" {
  domain_name = data.aws_route53_zone.this.name
  validation_method = "DNS"

  tags = {
    Name = "${var.project}-acm"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "root" {
  certificate_arn = aws_acm_certificate.root.arn
}

# route53にACM書き込み
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.root.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      type = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  name = each.value.name
  records = [ each.value.record ]
  ttl = 60
  type = each.value.type
  zone_id = data.aws_route53_zone.this.id
}

resource "aws_route53_record" "root_a" {
  name = data.aws_route53_zone.this.name
  type = "A"
  zone_id = data.aws_route53_zone.this.zone_id

  alias {
    evaluate_target_health = true
    name = aws_lb.alb.dns_name
    zone_id = aws_lb.alb.zone_id
  }
}

####################
# ALB
####################
resource "aws_lb" "alb" {
  name = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]

  subnets = [
    var.publicsubnet1,
    var.publicsubnet2
  ]

  tags = {
    Name = "${var.project}-alb"
  }
}

####################
# Target Group
####################
resource "aws_lb_target_group" "alb" {
  name                 = "${var.project}-alb-tg"
  port                 = "80"
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = "60"
  depends_on = [aws_lb.alb]
 
  health_check {
    interval            = "10"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "4"
    healthy_threshold   = "2"
    unhealthy_threshold = "10"
    matcher             = "200-302"
  }
}

####################
# Listener
####################
resource "aws_lb_listener" "https" {
  certificate_arn = aws_acm_certificate.root.arn
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  depends_on = [ aws_lb.alb ]
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
}

resource "aws_alb_listener_rule" "https" {
  listener_arn = aws_lb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
  condition {
    host_header {
      values = [
        var.domain 
      ]
    }
  }
}

###############
# efs
###############
resource "aws_efs_file_system" "efs" {
  creation_token                  = "fargate-efs"
  throughput_mode                 = "bursting"
 
  tags = {
    Name = "fargate-efs"
  }
}
 
# Mount Target
resource "aws_efs_mount_target" "privatesubnet1" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = var.privatesubnet1
  security_groups = [
    aws_security_group.efs.id
  ]
}
 
resource "aws_efs_mount_target" "privatesubnet2" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = var.privatesubnet2
  security_groups = [
    aws_security_group.efs.id
  ]
}

####################
# Cluster
####################
resource "aws_ecs_cluster" "cluster" {
  name = "${var.project}-ecs"

  capacity_providers = [ "FARGATE_SPOT" ]
 
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
  
  tags = {
    Name = "${var.project}-ecs"
  }
}
 
####################
# Task Definition
####################
resource "aws_ecs_task_definition" "task" {
  family                   = "${var.project}-task-wordpress"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  execution_role_arn       = aws_iam_role.ecs_task.arn
 
  volume {
    name = "fargate-efs"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode(
    [{
          "name": "wordpress",
          "image": "wordpress:latest",
          "essential": true,
          "portMappings": [
              {
                  "containerPort": 80,
                  "hostPort": 80
              }
          ],
          "mountPoints": [
              {
                  "containerPath": "/var/www/html",
                  "sourceVolume": "fargate-efs"
              }
          ],
          "secrets": [
              {
                  "name": "WORDPRESS_DB_HOST",
                  "valueFrom": "WORDPRESS_DB_HOST"
              },
              {
                  "name": "WORDPRESS_DB_USER",
                  "valueFrom": "WORDPRESS_DB_USER"
              },
              {
                  "name": "WORDPRESS_DB_PASSWORD",
                  "valueFrom": "WORDPRESS_DB_PASSWORD"
              },
              {
                  "name": "WORDPRESS_DB_NAME",
                  "valueFrom": "WORDPRESS_DB_NAME"
              }
          ]
    }]
  )
}
 
####################
# Service
####################
resource "aws_ecs_service" "service" {
  name             = "${var.project}-efs-service"
  cluster          = aws_ecs_cluster.cluster.arn
  task_definition  = aws_ecs_task_definition.task.arn
  desired_count    = 1
  platform_version = "1.4.0"
  depends_on       = [ aws_lb_target_group.alb, aws_efs_file_system.efs]
 
  load_balancer {
    target_group_arn = aws_lb_target_group.alb.arn
    container_name   = "wordpress"
    container_port   = "80"
  }
 
  network_configuration {
    subnets = [
      var.privatesubnet2,
      var.privatesubnet1
    ]
    security_groups = [
      aws_security_group.fargate.id
    ]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base = 1
    weight = 1
  }
}

# iam
resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-ecs-task"
  assume_role_policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": {
                  "Service": "ecs-tasks.amazonaws.com"
              },
              "Action": "sts:AssumeRole"
          }
      ]
    }
  )

  tags = {
    Name = "${var.project}-ecs-task"
  }
}

resource "aws_iam_role_policy" "aws_ecs_task_execution" {
  name = "${var.project}-execution-policy"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode(
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ssm:GetParameters",
            "Resource": "*"
        }
      ]
    }
  )
}

# SG
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "for ALB"
  vpc_id      = var.vpc_id
}
 
resource "aws_security_group" "fargate" {
  name        = "fargate-sg"
  description = "for Fargate"
  vpc_id      = var.vpc_id
}
 
resource "aws_security_group" "efs" {
  name        = "efs-sg"
  description = "for EFS"
  vpc_id      = var.vpc_id
}

# SG rule
resource "aws_security_group_rule" "allow_http_for_alb" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow_http_for_alb"
}
 
resource "aws_security_group_rule" "from_alb_to_fargate" {
  security_group_id        = aws_security_group.fargate.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  # source_security_group_id = aws_security_group.alb.id
  cidr_blocks              = ["192.168.0.0/16","172.16.0.0/12","10.0.0.0/8"]
  description              = "from_alb_to_fargate"
}
 
resource "aws_security_group_rule" "from_fargate_to_efs" {
  security_group_id        = aws_security_group.efs.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2049
  to_port                  = 2049
  source_security_group_id = aws_security_group.fargate.id
  description              = "from_fargate_to_efs"
}
 
resource "aws_security_group_rule" "egress_alb" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound ALL"
}
 
resource "aws_security_group_rule" "egress_fargate" {
  security_group_id = aws_security_group.fargate.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound ALL"
}
 
resource "aws_security_group_rule" "egress_efs" {
  security_group_id = aws_security_group.efs.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound ALL"
}

####################
# Parameter
####################
resource "aws_ssm_parameter" "wordpress_db_user" {
  name        = "WORDPRESS_DB_USER"
  description = "WORDPRESS_DB_USER"
  type        = "String"
  value       = "wordpress"
}
 
resource "aws_ssm_parameter" "wordpress_db_password" {
  name        = "WORDPRESS_DB_PASSWORD"
  description = "WORDPRESS_DB_PASSWORD"
  type        = "String"
  value       = "password"
}
 
resource "aws_ssm_parameter" "wordpress_db_name" {
  name        = "WORDPRESS_DB_NAME"
  description = "WORDPRESS_DB_NAME"
  type        = "String"
  value       = "wordpress"
}