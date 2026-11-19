# ==============================================================================
# 1. TERRAFORM & AWS PROVIDER CONFIGURATION
# ==============================================================================
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Mumbai
}

locals {
  cluster_name = "demo-eks-mumbai"
}

# ==============================================================================
# 2. VPC NETWORKING (EKS requires at least 2 Availability Zones)
# ==============================================================================
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                                          = "${local.cluster_name}-vpc"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "${local.cluster_name}-igw"
  }
}

# --- PUBLIC SUBNETS (For Load Balancers, NAT Gateway & Management EC2) ---
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${local.cluster_name}-public-ap-south-1a"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1" # Required tag for AWS Public Load Balancers
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${local.cluster_name}-public-ap-south-1b"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

# --- PRIVATE SUBNETS (Where Worker Nodes & Pods live securely) ---
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name                                          = "${local.cluster_name}-private-ap-south-1a"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1" # Required tag for Internal Load Balancers
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name                                          = "${local.cluster_name}-private-ap-south-1b"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# --- NAT GATEWAY (Allows private worker nodes to download container images) ---
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${local.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${local.cluster_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

# --- ROUTE TABLES ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${local.cluster_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# 3. EKS CLUSTER IAM ROLE (Permissions for the Kubernetes Control Plane)
# ==============================================================================
resource "aws_iam_role" "cluster" {
  name = "${local.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ==============================================================================
# 4. EKS CLUSTER (Control Plane)
# ==============================================================================
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]
  }

  # Modern EKS Access Management (Enables EKS Access Entries for EC2 Management Host)
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = {
    Name = local.cluster_name
  }
}

# ==============================================================================
# 5. EKS NODE GROUP IAM ROLE (Permissions for Worker Node EC2s)
# ==============================================================================
resource "aws_iam_role" "nodes" {
  name = "${local.cluster_name}-node-group-role"

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

resource "aws_iam_role_policy_attachment" "nodes_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.nodes.name
}

# ==============================================================================
# 6. EKS MANAGED NODE GROUP (The Worker Nodes where Pods run)
# ==============================================================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "managed-worker-nodes"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_policy
  ]

  tags = {
    Name = "${local.cluster_name}-worker-node"
  }
}

# ==============================================================================
# 6.1 AWS EBS CSI DRIVER ADDON (Enables 100 GB Persistent Storage PVCs)
# ==============================================================================
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.nodes_ebs_csi_policy
  ]
}

# ==============================================================================
# 7. IAM ROLE & INSTANCE PROFILE FOR UBUNTU MANAGEMENT EC2 (BASTION)
# ==============================================================================
resource "aws_iam_role" "management_node" {
  name = "${local.cluster_name}-management-role"

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

# Grants the EC2 instance permission to call EKS and AWS APIs
resource "aws_iam_role_policy_attachment" "management_admin" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.management_node.name
}

resource "aws_iam_instance_profile" "management_profile" {
  name = "${local.cluster_name}-management-profile"
  role = aws_iam_role.management_node.name
}

# ==============================================================================
# 8. EKS ACCESS ENTRY: AUTHORIZE MANAGEMENT EC2 AS CLUSTER ADMIN IN KUBERNETES
# ==============================================================================
resource "aws_eks_access_entry" "management" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.management_node.arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_access_policy_association" "management_admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.management_node.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.management]
}

# ==============================================================================
# 9. AUTOMATIC SSH KEY GENERATION FOR MANAGEMENT EC2
# ==============================================================================
resource "tls_private_key" "mgmt_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "mgmt_key_pem" {
  content         = tls_private_key.mgmt_key.private_key_pem
  filename        = "${path.module}/management_key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "mgmt_key" {
  key_name   = "${local.cluster_name}-mgmt-key"
  public_key = tls_private_key.mgmt_key.public_key_openssh
}

# ==============================================================================
# 10. SECURITY GROUP FOR MANAGEMENT EC2
# ==============================================================================
resource "aws_security_group" "management_sg" {
  name        = "${local.cluster_name}-management-sg"
  description = "Allow SSH access to management EC2"
  vpc_id      = aws_vpc.eks_vpc.id

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
    Name = "${local.cluster_name}-management-sg"
  }
}

# Allow Management EC2 to communicate with the EKS Control Plane API on Port 443
resource "aws_security_group_rule" "cluster_inbound_from_management" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.management_sg.id
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description              = "Allow management EC2 to communicate with EKS API server"
}

# ==============================================================================
# 11. UBUNTU MANAGEMENT EC2 INSTANCE (Automates AWS CLI + kubectl + kubeconfig)
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
  instance_type = "t3.micro" # Free-tier eligible size

  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.management_sg.id]
  key_name                    = aws_key_pair.mgmt_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.management_profile.name
  associate_public_ip_address = true

  # USER DATA: Installs AWS CLI v2 + kubectl + runs update-kubeconfig automatically
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
              aws eks update-kubeconfig --region ap-south-1 --name ${aws_eks_cluster.main.name} --kubeconfig /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube

              # 4. Add aliases for comfortable Kubernetes management
              echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
              echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
              echo 'complete -o default -F __start_kubectl k' >> /home/ubuntu/.bashrc

              echo "SETUP_COMPLETE" > /tmp/ready.txt
              EOF

  # Guarantees the EKS Cluster, Node Group, and Admin permissions exist BEFORE configuring kubeconfig
  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    aws_eks_access_policy_association.management_admin
  ]

  tags = {
    Name = "${local.cluster_name}-management-server"
  }
}

# ==============================================================================
# 12. OUTPUTS
# ==============================================================================
output "cluster_name" {
  description = "The name of the EKS Cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "management_server_public_ip" {
  description = "Public IP address of the Ubuntu Management EC2"
  value       = aws_instance.management_server.public_ip
}

output "ssh_to_management_server" {
  description = "Command to SSH into the Management EC2 server"
  value       = "ssh -i ${path.module}/management_key.pem ubuntu@${aws_instance.management_server.public_ip}"
}

output "instant_k8s_test_command" {
  description = "Command to test Kubernetes directly from your local terminal"
  value       = "ssh -i ${path.module}/management_key.pem ubuntu@${aws_instance.management_server.public_ip} 'kubectl get nodes'"
}
