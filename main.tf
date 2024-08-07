# Provider configuration
provider "aws" {
  region = "us-east-2"  # Change this to your preferred region
}

# Variables
variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# EC2 Instance for BuildKit
resource "aws_instance" "buildkit" {
  ami               = "ami-05c3dc660cb6907f0"
  instance_type     = "c5a.4xlarge"
  availability_zone = "us-east-2a"

  vpc_security_group_ids = [aws_security_group.buildkit.id]
  iam_instance_profile   = aws_iam_instance_profile.buildkit_instance_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update and install dependencies
    yum update -y
    yum install -y docker git

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    # Add ec2-user to the docker group
    usermod -aG docker ec2-user

    # Download and install BuildKit
    export BUILDKIT_VERSION=0.12.0
    curl -sSL "https://github.com/moby/buildkit/releases/download/v$${BUILDKIT_VERSION}/buildkit-v$${BUILDKIT_VERSION}.linux-amd64.tar.gz" -o buildkit.tar.gz
    tar -xzf buildkit.tar.gz -C /usr/local/bin --strip-components=1

    # Create buildkitd systemd service
    cat <<EOT > /etc/systemd/system/buildkitd.service
    [Unit]
    Description=BuildKit daemon
    After=network.target

    [Service]
    ExecStart=/usr/local/bin/buildkitd --addr tcp://0.0.0.0:9999 --addr unix:///run/buildkit/buildkitd.sock --debug
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOT

    # Enable and start buildkitd service
    systemctl daemon-reload
    systemctl enable buildkitd
    systemctl start buildkitd
  EOF
}

# Security Group for BuildKit Instance
resource "aws_security_group" "buildkit" {
  name        = "buildkit-sg"
  description = "Security group for BuildKit instance"

  ingress {
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to GA runners range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "buildkit_instance_role" {
  name = "BuildKitInstanceRole"

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

# IAM Role Policy Attachment
# This is not required for our example but will be useful if you're pushing to ECR
# resource "aws_iam_role_policy_attachment" "buildkit_instance_policy" {
  # policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  # role       = aws_iam_role.buildkit_instance_role.name
# }

# IAM Instance Profile
resource "aws_iam_instance_profile" "buildkit_instance_profile" {
  name = "BuildKitInstanceProfile"
  role = aws_iam_role.buildkit_instance_role.name
}

# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_role" {
  name = "GithubActionsBuildKitRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# IAM Policy for GitHub Actions Role
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "GithubActionsBuildKitPolicy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      }
    ]
  })
}

# Output
output "buildkit_instance_public_ip" {
  value       = aws_instance.buildkit.public_ip
  description = "The public IP address of the BuildKit instance"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "The ARN of the IAM role for GitHub Actions"
}