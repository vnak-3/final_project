terraform {
  backend "s3" {
    bucket = "final-project-vnak3"
    key    = "aupp-lms/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "jenkins_deploy" {
  key_name   = "jenkins-deploy-v2"
  public_key = file("/home/ubuntu/.ssh/jenkins-deploy.pub")
}

resource "aws_security_group" "app_sg" {
  name        = "course-management-app-sg"
  description = "Allow SSH and app port"

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Application port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Course-Management-App-SG"
  }
}

resource "aws_instance" "app_ec2" {
  ami                         = var.ami_id
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.jenkins_deploy.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }

  tags = {
    Name = "Course-Management-App"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release

    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh

    systemctl enable docker
    systemctl start docker

    usermod -aG docker ubuntu

    until docker info >/dev/null 2>&1; do
      sleep 2
    done

    touch /home/ubuntu/docker-ready.flag
    chown ubuntu:ubuntu /home/ubuntu/docker-ready.flag
  EOF
}