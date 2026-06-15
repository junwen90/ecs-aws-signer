# ECS Cluster and Service for Signature Verification Testing

# VPC (using default VPC - adjust if needed)
resource "aws_default_vpc" "default" {
  tags = {
    Name = "default-vpc"
  }
}

# Default subnets in AZs
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "default-subnet-az1"
  }
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "default-subnet-az2"
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Security group for Fargate tasks
resource "aws_security_group" "fargate_sg" {
  name        = "fargate-signing-test-sg-${var.environment}"
  description = "Security group for Fargate tasks"
  vpc_id      = aws_default_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fargate-signing-test-sg-${var.environment}"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "signing_test" {
  name = "signing-test-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "signing-test-cluster-${var.environment}"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/signing-test-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "ecs-signing-test-logs-${var.environment}"
  }
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-execution-role-${var.environment}"
  }
}

# Attach the default ECS task execution policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM role for ECS task (application permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-role-${var.environment}"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "signing_test" {
  family                   = "signing-test-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "signing-test-app"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "signing-test-task-${var.environment}"
  }
}

# Auto Scaling Group for ECS Capacity Provider
resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ecs-signing-test-asg-${var.environment}"
  vpc_zone_identifier = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.ecs_instance.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ecs-signing-test-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = false
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Launch Template for ECS instances (not used with Fargate, but can be added later for EC2)
resource "aws_launch_template" "ecs_instance" {
  name_prefix   = "ecs-signing-test-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = aws_ecs_cluster.signing_test.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs-signing-test-instance-${var.environment}"
    }
  }
}

# Get ECS-optimized AMI
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# IAM instance profile for ECS instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile-${var.environment}"
  role = aws_iam_role.ecs_instance_role.name
}

# ECS Service - using Fargate launch type
resource "aws_ecs_service" "signing_test" {
  name            = "signing-test-service-${var.environment}"
  cluster         = aws_ecs_cluster.signing_test.id
  task_definition = aws_ecs_task_definition.signing_test.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = true
  }

  # Enable service registries if needed for service discovery
  enable_execute_command = true

  depends_on = [aws_ecs_cluster.signing_test]

  tags = {
    Name = "signing-test-service-${var.environment}"
  }
}
