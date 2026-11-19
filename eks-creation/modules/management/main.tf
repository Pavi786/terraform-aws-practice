# ==============================================================================
# 1. AUTOMATIC SSH KEY GENERATION
# ==============================================================================
resource "tls_private_key" "mgmt_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "mgmt_key_pem" {
  content         = tls_private_key.mgmt_key.private_key_pem
  filename        = "${path.root}/management_key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "mgmt_key" {
  key_name   = "${var.cluster_name}-mgmt-key"
  public_key = tls_private_key.mgmt_key.public_key_openssh
}

# ==============================================================================
# 2. SECURITY GROUP FOR MANAGEMENT EC2
# ==============================================================================
resource "aws_security_group" "management_sg" {
  name        = "${var.cluster_name}-management-sg"
  description = "Allow SSH access to management EC2"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-management-sg"
  }
}

# Allow Management EC2 to communicate with the EKS Control Plane API on Port 443
resource "aws_security_group_rule" "cluster_inbound_from_management" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.management_sg.id
  security_group_id        = var.cluster_security_group_id
  description              = "Allow management EC2 to communicate with EKS API server"
}

# ==============================================================================
# 3. DYNAMIC UBUNTU AMI & MANAGEMENT EC2 INSTANCE
# ==============================================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "management_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.management_sg.id]
  key_name                    = aws_key_pair.mgmt_key.key_name
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true

  # Automatically installs AWS CLI v2 + kubectl + configures kubeconfig & aliases
  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y curl unzip git

              # 1. Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
              unzip -q /tmp/awscliv2.zip -d /tmp
              /tmp/aws/install

              # 2. Install kubectl (Kubernetes 1.31)
              curl -LO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/

              # 3. Configure kubeconfig for the ubuntu user
              mkdir -p /home/ubuntu/.kube
              aws eks update-kubeconfig --region ap-south-1 --name ${var.cluster_name} --kubeconfig /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube

              # 4. Add aliases for comfortable Kubernetes management
              echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
              echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
              echo 'complete -o default -F __start_kubectl k' >> /home/ubuntu/.bashrc

              echo "SETUP_COMPLETE" > /tmp/ready.txt
              EOF

  depends_on = [
    aws_security_group_rule.cluster_inbound_from_management,
    var.ready_dependencies
  ]

  tags = {
    Name = "${var.cluster_name}-management-server"
  }
}
