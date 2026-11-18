terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Mumbai
}

# 1. Fetch Latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# 2. Security Group (Firewall)
resource "aws_security_group" "HelloWorld" {
  name        = "my-ec2-security-group"
  description = "Allow inbound SSH and HTTP traffic, allow all outbound"

  # Standard SSH on port 22
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP Web traffic on port 80
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: Required for downloading Git/Docker/Nginx
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-web-ssh-sg"
  }
}

# 3. The Single EC2 Instance with User Data Tools
resource "aws_instance" "my_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Attach the Security Group
  vpc_security_group_ids = [aws_security_group.HelloWorld.id]

  # User Data: Automatically installs Git, Docker, and Nginx
  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y git curl unzip nginx docker.io

              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              systemctl start nginx
              systemctl enable nginx

              echo "<h1>🚀 Server Deployed via Terraform!</h1><p>Git, Docker, and Nginx are installed.</p>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "My-Ubuntu-Web-Server"
  }
}

# 4. Outputs
output "public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.my_server.public_ip
}

output "website_url" {
  description = "Clickable website URL"
  value       = "http://${aws_instance.my_server.public_ip}"
}
