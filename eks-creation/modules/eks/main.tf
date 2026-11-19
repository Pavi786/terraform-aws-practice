# ==============================================================================
# 1. EKS CLUSTER CONTROL PLANE
# ==============================================================================
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = var.control_plane_subnet_ids
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = var.cluster_name
  }
}

# ==============================================================================
# 2. MANAGED WORKER NODE GROUP
# ==============================================================================
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "managed-worker-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.worker_subnet_ids

  capacity_type  = "ON_DEMAND"
  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [var.node_policy_dependencies]

  tags = {
    Name = "${var.cluster_name}-worker-node"
  }
}

# ==============================================================================
# 3. AWS EBS CSI DRIVER ADD-ON (Enables 100 GB Persistent Storage)
# ==============================================================================
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [
    aws_eks_node_group.this,
    var.node_policy_dependencies
  ]
}

# ==============================================================================
# 4. EKS ACCESS ENTRY & CLUSTER ADMIN POLICY (Grants Management EC2 Admin Rights)
# ==============================================================================
resource "aws_eks_access_entry" "management" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.management_role_arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_access_policy_association" "management_admin" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.management_role_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.management]
}
