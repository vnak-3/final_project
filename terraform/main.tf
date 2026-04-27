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
  key_name   = "jenkins-deploy"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCx3PpAjMF9UZuHPoPxvLmpu8e4DXW7mVMH13GoShGyAj9xM4oTf25yHgtl1vz0Syuxx8XKnqo4oe0nu3wPlpFSNlMpplhhl79DP/NIOobP0tdaQEfcQPXYooIeWnIUpxY8bTHd0Q25JUxnUyoNRGei3+ECivriAUNvgdQMBd3pZ6tOr7aT4poCMIlz86NMZF8YoBJcLVrWLkkLEAqgnyjtMgkDaypSXW9UJCiI9WsuWfYRewu84eSBXZBb6MBrH8O7bWxDDmLnWTEC26lJEQO+PlQH0ipbd9ZMa+bu1ZKu+/xtvTTI7DDRko297qAbH3ZJFSq37vbSDXBPty47eLvT"

  lifecycle {
    ignore_changes = [public_key]
  }
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