# ==============================================================================
# 1. TERRAFORM & PROVIDER CONFIGURATION
# ==============================================================================
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
  }
}

# Target Region: Mumbai
provider "aws" {
  region = "ap-south-1"
}

# ==============================================================================
# 2. VIRTUAL PRIVATE CLOUD (VPC)
# The isolated private network datacenter in AWS
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # Provides 65,536 private IP addresses
  enable_dns_support   = true          # Enables AWS internal DNS resolution
  enable_dns_hostnames = true          # Gives public DNS hostnames to instances with public IPs

  tags = {
    Name        = "my-custom-vpc"
    Environment = "Dev"
  }
}

# ==============================================================================
# 3. INTERNET GATEWAY (IGW)
# The door that connects your VPC to the outside internet
# ==============================================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id # Attaches the gateway to our VPC

  tags = {
    Name = "my-internet-gateway"
  }
}

# ==============================================================================
# 4. PUBLIC SUBNET
# For servers that need direct access from the internet (Web servers, Bastion, NAT)
# ==============================================================================
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24" # 256 IPs (10.0.1.0 to 10.0.1.255)
  availability_zone       = "ap-south-1a" # Placed in Mumbai AZ-1a
  map_public_ip_on_launch = true          # Automatically assigns a public IP to instances here

  tags = {
    Name = "my-public-subnet"
  }
}

# ==============================================================================
# 5. PRIVATE SUBNET
# For secure backend servers (Databases, Backend APIs) hidden from the internet
# ==============================================================================
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24" # 256 IPs (10.0.2.0 to 10.0.2.255)
  availability_zone       = "ap-south-1a" # Placed in Mumbai AZ-1a
  map_public_ip_on_launch = false         # Never assigns a public IP (keeps it private)

  tags = {
    Name = "my-private-subnet"
  }
}

# ==============================================================================
# 6. ELASTIC IP (EIP) FOR NAT GATEWAY
# A static, dedicated public IP required by the NAT Gateway
# ==============================================================================
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw] # Standard best practice: ensure IGW exists before allocating EIP

  tags = {
    Name = "my-nat-elastic-ip"
  }
}

# ==============================================================================
# 7. NAT GATEWAY
# Enables private subnet instances to reach internet (for OS updates) without being exposed
# Note: NAT Gateway MUST be deployed inside the PUBLIC subnet
# ==============================================================================
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id # Lives in the public subnet to talk to the internet

  tags = {
    Name = "my-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ==============================================================================
# 8. PUBLIC ROUTE TABLE & ASSOCIATION
# Routes all outbound traffic (0.0.0.0/0) to the Internet Gateway
# ==============================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id # Destination: Internet Gateway
  }

  tags = {
    Name = "my-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# 9. PRIVATE ROUTE TABLE & ASSOCIATION
# Routes all outbound traffic (0.0.0.0/0) through the NAT Gateway
# ==============================================================================
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id # Destination: NAT Gateway
  }

  tags = {
    Name = "my-private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# 10. OUTPUTS
# ==============================================================================
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The ID of the Public Subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "The ID of the Private Subnet"
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_public_ip" {
  description = "Static Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# ==============================================================================
# 10. INPUT VARIABLES (Zero Hardcoded values)
# ==============================================================================
variable "instance_type" {
  description = "EC2 instance sizing"
  type        = string
  default     = "t3.micro"
}

# ==============================================================================
# 11. DYNAMIC AMI QUERY (Queries Canonical for latest Ubuntu 22.04 in Mumbai)
# ==============================================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS Account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# 12. SECURITY GROUP IN CUSTOM VPC (Bound to aws_vpc.main.id)
# ==============================================================================
resource "aws_security_group" "ec2_web_sg" {
  name        = "custom-vpc-web-sg"
  description = "Allow HTTP and SSH traffic into custom VPC"
  vpc_id      = aws_vpc.main.id # DYNAMIC: Attaches to our custom VPC, NOT default VPC

  # Inbound HTTP (port 80)
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound SSH (port 22)
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: Allow all outbound traffic (so user_data can download packages)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "custom-vpc-web-sg"
  }
}

# ==============================================================================
# 13. EC2 INSTANCE IN CUSTOM PUBLIC SUBNET (100% Dynamic References)
# ==============================================================================
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id # DYNAMIC: AMI from data source
  instance_type = var.instance_type      # DYNAMIC: Size from input variable

  # DYNAMIC NETWORK BINDING:
  subnet_id                   = aws_subnet.public.id               # Placed in our custom public subnet
  vpc_security_group_ids      = [aws_security_group.ec2_web_sg.id] # Attached to custom security group
  associate_public_ip_address = true                               # Public IP for direct internet access
  user_data_replace_on_change = true                               # Recreates instance automatically if user_data changes

  # Explicit dependency ensures Internet Gateway and Routes are 100% active before instance boots
  depends_on = [aws_route_table_association.public, aws_internet_gateway.igw]

  # USER DATA: Installs Git, Docker, and Nginx with a Super Modern UI Dashboard
  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive

              # 1. Update OS and install tools
              apt-get update -y
              apt-get install -y git curl unzip htop nginx docker.io

              # 2. Start and enable Docker
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              # 3. Start and enable Nginx
              systemctl start nginx
              systemctl enable nginx

              # 4. Fetch dynamic AWS instance metadata using IMDSv2
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "i-instance")
              AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "ap-south-1a")
              PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 || echo "10.0.1.x")

              # 5. Create a Super Modern Glassmorphism Dashboard
              cat <<HTML > /var/www/html/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>AWS Cloud Architecture Dashboard</title>
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
                <style>
                  * { margin: 0; padding: 0; box-sizing: border-box; }
                  body {
                    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
                    background: radial-gradient(circle at 20% 20%, #1e1b4b 0%, #0f172a 40%, #020617 100%);
                    color: #f8fafc;
                    min-height: 100vh;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    padding: 2rem 1rem;
                  }
                  .container {
                    width: 100%;
                    max-width: 900px;
                  }
                  .glass-card {
                    background: rgba(30, 41, 59, 0.7);
                    backdrop-filter: blur(16px);
                    -webkit-backdrop-filter: blur(16px);
                    border: 1px solid rgba(255, 255, 255, 0.1);
                    border-radius: 24px;
                    padding: 2.5rem;
                    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.6), 0 0 40px rgba(99, 102, 241, 0.15);
                  }
                  .header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
                    padding-bottom: 1.5rem;
                    margin-bottom: 2rem;
                    flex-wrap: wrap;
                    gap: 1rem;
                  }
                  .title-group h1 {
                    font-size: 1.85rem;
                    font-weight: 800;
                    background: linear-gradient(135deg, #38bdf8 0%, #818cf8 50%, #c084fc 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                    letter-spacing: -0.02em;
                  }
                  .title-group p {
                    color: #94a3b8;
                    font-size: 0.95rem;
                    margin-top: 0.35rem;
                  }
                  .status-pill {
                    display: inline-flex;
                    align-items: center;
                    gap: 0.5rem;
                    background: rgba(16, 185, 129, 0.12);
                    border: 1px solid rgba(16, 185, 129, 0.3);
                    color: #34d399;
                    padding: 0.5rem 1rem;
                    border-radius: 9999px;
                    font-weight: 600;
                    font-size: 0.85rem;
                  }
                  .pulse {
                    width: 8px;
                    height: 8px;
                    background: #10b981;
                    border-radius: 50%;
                    box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
                    animation: pulse 2s infinite;
                  }
                  @keyframes pulse {
                    0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
                    70% { box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
                    100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
                  }
                  .grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
                    gap: 1.25rem;
                    margin-bottom: 2rem;
                  }
                  .panel {
                    background: rgba(15, 23, 42, 0.6);
                    border: 1px solid rgba(255, 255, 255, 0.05);
                    border-radius: 16px;
                    padding: 1.25rem;
                    transition: transform 0.2s ease, border-color 0.2s ease;
                  }
                  .panel:hover {
                    transform: translateY(-2px);
                    border-color: rgba(99, 102, 241, 0.3);
                  }
                  .panel-title {
                    font-size: 0.8rem;
                    text-transform: uppercase;
                    letter-spacing: 0.08em;
                    color: #64748b;
                    font-weight: 700;
                    margin-bottom: 1rem;
                    display: flex;
                    align-items: center;
                    gap: 0.5rem;
                  }
                  .item {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 0.45rem 0;
                    font-size: 0.9rem;
                    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
                  }
                  .item:last-child { border-bottom: none; }
                  .item-key { color: #94a3b8; }
                  .item-val {
                    font-family: 'JetBrains Mono', monospace;
                    color: #e2e8f0;
                    font-weight: 600;
                    font-size: 0.85rem;
                  }
                  .badge-val {
                    background: rgba(99, 102, 241, 0.15);
                    color: #a5b4fc;
                    border: 1px solid rgba(99, 102, 241, 0.3);
                    padding: 0.2rem 0.55rem;
                    border-radius: 6px;
                  }
                  .tool-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
                    gap: 1rem;
                    margin-top: 1rem;
                  }
                  .tool-card {
                    background: rgba(15, 23, 42, 0.6);
                    border: 1px solid rgba(255, 255, 255, 0.05);
                    border-radius: 14px;
                    padding: 1rem;
                    display: flex;
                    align-items: center;
                    gap: 0.85rem;
                  }
                  .tool-icon {
                    font-size: 1.75rem;
                  }
                  .tool-info h4 {
                    font-size: 0.95rem;
                    font-weight: 700;
                    color: #f1f5f9;
                  }
                  .tool-info span {
                    font-size: 0.75rem;
                    color: #34d399;
                    font-weight: 600;
                  }
                  .footer {
                    margin-top: 2rem;
                    text-align: center;
                    font-size: 0.85rem;
                    color: #64748b;
                    border-top: 1px solid rgba(255, 255, 255, 0.06);
                    padding-top: 1.5rem;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    flex-wrap: wrap;
                    gap: 0.5rem;
                  }
                  .tech-tag {
                    font-family: 'JetBrains Mono', monospace;
                    background: rgba(14, 165, 233, 0.1);
                    color: #38bdf8;
                    padding: 0.25rem 0.65rem;
                    border-radius: 6px;
                    font-size: 0.8rem;
                  }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="glass-card">
                    <div class="header">
                      <div class="title-group">
                        <h1>AWS Cloud Infrastructure</h1>
                        <p>End-to-End Custom VPC & Automated EC2 Provisioning</p>
                      </div>
                      <div class="status-pill">
                        <div class="pulse"></div>
                        SYSTEM HEALTHY
                      </div>
                    </div>

                    <div class="grid">
                      <div class="panel">
                        <div class="panel-title">🌐 Network Architecture</div>
                        <div class="item"><span class="item-key">VPC CIDR</span><span class="item-val badge-val">10.0.0.0/16</span></div>
                        <div class="item"><span class="item-key">Subnet Type</span><span class="item-val">Public (10.0.1.0/24)</span></div>
                        <div class="item"><span class="item-key">Region</span><span class="item-val">Mumbai (ap-south-1)</span></div>
                        <div class="item"><span class="item-key">Internet Gateway</span><span class="item-val" style="color: #34d399;">Attached & Active</span></div>
                        <div class="item"><span class="item-key">NAT Gateway</span><span class="item-val" style="color: #38bdf8;">Configured</span></div>
                      </div>

                      <div class="panel">
                        <div class="panel-title">⚡ Live Server Metadata</div>
                        <div class="item"><span class="item-key">Instance ID</span><span class="item-val badge-val">$INSTANCE_ID</span></div>
                        <div class="item"><span class="item-key">Availability Zone</span><span class="item-val">$AZ</span></div>
                        <div class="item"><span class="item-key">Private IP</span><span class="item-val">$PRIVATE_IP</span></div>
                        <div class="item"><span class="item-key">Web Server</span><span class="item-val">Nginx / Port 80</span></div>
                        <div class="item"><span class="item-key">OS Release</span><span class="item-val">Ubuntu 22.04 LTS</span></div>
                      </div>
                    </div>

                    <div class="panel-title">🚀 Installed DevOps Toolchain</div>
                    <div class="tool-grid">
                      <div class="tool-card">
                        <div class="tool-icon">🐳</div>
                        <div class="tool-info">
                          <h4>Docker Engine</h4>
                          <span>● Active & Running</span>
                        </div>
                      </div>
                      <div class="tool-card">
                        <div class="tool-icon">🌐</div>
                        <div class="tool-info">
                          <h4>Nginx</h4>
                          <span>● Serving Traffic</span>
                        </div>
                      </div>
                      <div class="tool-card">
                        <div class="tool-icon">🐙</div>
                        <div class="tool-info">
                          <h4>Git</h4>
                          <span>● Installed</span>
                        </div>
                      </div>
                      <div class="tool-card">
                        <div class="tool-icon">⚡</div>
                        <div class="tool-info">
                          <h4>Curl & Unzip</h4>
                          <span>● Ready to use</span>
                        </div>
                      </div>
                    </div>

                    <div class="footer">
                      <div>Managed by <strong>HashiCorp Terraform</strong></div>
                      <div class="tech-tag">Zero Hardcoding • Dynamic Architecture</div>
                    </div>
                  </div>
                </div>
              </body>
              </html>
              HTML
              EOF

  tags = {
    Name        = "custom-vpc-web-server"
    Environment = "Dev"
  }
}

# ==============================================================================
# 14. EC2 OUTPUTS
# ==============================================================================
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance inside the Custom VPC"
  value       = aws_instance.web_server.public_ip
}

output "website_url" {
  description = "Clickable HTTP URL for the web server"
  value       = "http://${aws_instance.web_server.public_ip}"
}
