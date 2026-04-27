provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "jenkins_deploy" {
  key_name   = "jenkins-deploy"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAEbm0DNhACrtCE0TT99xxaREgvZ+bt9bveKhXsWcoZB jenkins-deploy"
}

resource "aws_security_group" "app_sg" {
  name        = "foodexpress-app-sg"
  description = "Allow SSH and app port"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FoodExpress-App-SG"
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

  tags = {
    Name = "FoodExpress-App"
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
    chmod 666 /var/run/docker.sock || true

    until docker info >/dev/null 2>&1; do
      sleep 2
    done

    touch /home/ubuntu/docker-ready.flag
    chown ubuntu:ubuntu /home/ubuntu/docker-ready.flag
  EOF
}