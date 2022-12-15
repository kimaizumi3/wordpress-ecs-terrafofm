variable "name"{
    type = string
}

variable "holding_count"{
    type = number
    default = 10
}
resource "aws_ecr_repository" "this"{
    name = var.name
    tags = {
        Name = var.name
    }
}

resource "aws_ecr_lifecycle_policy" "this"{
    policy = jsonencode(
        {
            "rules": [
                {
                    "rulePriority": 1,
                    "description": "Hold only 10 images, expire all others",
                    "selection": {
                        "tagStatus": "any",
                        "countType": "imageCountMoreThan",
                        "countNumber": var.holding_count
                    },
                    "action": {
                        "type": "expire"
                    }
                }
            ]
        }
    )
    
    repository = aws_ecr_repository.this.name
}
