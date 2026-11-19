# ==============================================================================
# ROOT MODULE ORCHESTRATION: EKS ARCHITECTURE
# ==============================================================================

# 1. NETWORKING MODULE (VPC, Multi-AZ Subnets, IGW, NAT Gateway, Routing)
module "vpc" {
  source = "./modules/vpc"

  cluster_name       = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# 2. IAM MODULE (EKS Cluster Role, Node Group Role, Management EC2 Profile)
module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
}

# 3. EKS MODULE (Control Plane, Managed Worker Nodes, EBS CSI Addon, Access Policy)
module "eks" {
  source = "./modules/eks"

  cluster_name             = var.cluster_name
  kubernetes_version       = var.kubernetes_version
  control_plane_subnet_ids = module.vpc.all_subnet_ids
  worker_subnet_ids        = module.vpc.private_subnet_ids
  cluster_role_arn         = module.iam.cluster_role_arn
  node_role_arn            = module.iam.node_role_arn
  management_role_arn      = module.iam.management_role_arn
  node_instance_types      = var.node_instance_types
  desired_size             = var.desired_nodes

  # Enforce that nodes only launch after IAM policies are attached
  node_policy_dependencies = module.iam.node_policy_attachments
}

# 4. MANAGEMENT EC2 MODULE (Ubuntu Bastion, Auto-configured kubectl, EKS Port 443 Rule)
module "management" {
  source = "./modules/management"

  cluster_name              = var.cluster_name
  vpc_id                    = module.vpc.vpc_id
  public_subnet_id          = module.vpc.public_subnet_ids[0]
  instance_profile_name     = module.iam.management_instance_profile_name
  cluster_security_group_id = module.eks.cluster_security_group_id

  # Ensure Management server only launches after EKS Admin permissions are active
  ready_dependencies = [
    module.eks.access_policy_association_id,
    module.eks.node_group_id
  ]
}
