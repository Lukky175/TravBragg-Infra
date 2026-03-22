data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

locals {
  security_groups = {
    master = {
      ingress = [
        { from_port = 8080,  to_port = 8080,  desc = "Jenkins UI" },
        { from_port = 22,    to_port = 22,    desc = "SSH" },

        # Kubernetes NodePort range
        { from_port = 30000, to_port = 32767, desc = "K8s NodePort" },

        # Redis
        { from_port = 6379,  to_port = 6379,  desc = "Redis" },

        # Kubernetes API Server
        { from_port = 6443,  to_port = 6443,  desc = "K8s API" },

        # SMTP
        { from_port = 25,    to_port = 25,    desc = "SMTP" },
        { from_port = 465,   to_port = 465,   desc = "SMTPS" }
      ]
    }

    slave = {
      ingress = [
        { port = 22, desc = "SSH" }
      ]
    }

    app = {
      ingress = [
        { port = 80, desc = "HTTP" },
        { port = 443, desc = "HTTPS" }
      ]
    }
  }
}


# tfsec:ignore:aws-ec2-no-public-ingress-sgr
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group" "ec2_sg" {
  for_each = local.security_groups

  name        = "${var.project_name}-${var.environment}-${each.key}-sg"
  description = "Security group for EC2"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # later restrict
      description = ingress.value.desc
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

locals {
  instances = {
    app = {
      user_data = "app_server.sh"
      subnet_id = var.private_subnet_id
      public_ip = false
    }
    master = {
      user_data = "jenkins_master.sh"
      subnet_id = var.public_subnet_id
      public_ip = true
    }
    slave = {
      user_data = "jenkins_slave.sh"
      subnet_id = var.private_subnet_id
      public_ip = false
    }
  }
}

resource "aws_instance" "ec2" {
  for_each = local.instances
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = each.value.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg[each.key].id]
  associate_public_ip_address = each.value.public_ip

  metadata_options {
    http_tokens   = "required" #Prevents SSRF (Server-Side Request Forgery) Attacks by requiring IMDSv2 for metadata access.
    http_endpoint = "enabled"
  }
  root_block_device {
    volume_size = 29
    volume_type = "gp3"
    encrypted   = true
  }
  user_data                   = file("${path.module}/${each.value.user_data}")
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}-ec2"

  }
}