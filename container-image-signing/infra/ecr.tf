# ECR Repository Configuration with Managed Signing

resource "aws_ecr_repository" "signing_enabled" {
  for_each = { for svc in var.services : svc.name => svc }

  name                 = "${var.prefix}-${each.value.name}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Service = each.value.name
  }
}

# Enable ECR repository policy to block unsigned images
resource "aws_ecr_repository_policy" "block_unsigned" {
  for_each = { for svc in var.services : svc.name => svc }

  repository = aws_ecr_repository.signing_enabled[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnsignedImages"
        Effect    = "Deny"
        Principal = "*"
        Action    = "ecr:PutImage"
        Condition = {
          StringNotEquals = {
            "ecr:ResourceTag/SigningStatus" = "signed"
          }
        }
      }
    ]
  })
}

# ECR lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each = { for svc in var.services : svc.name => svc }

  repository = aws_ecr_repository.signing_enabled[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last N signed images"
        selection = {
          tagStatus     = "any"
          countNumber   = 10
          countType     = "imageCountMoreThan"
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
