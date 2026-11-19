output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "The Kubernetes API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "The security group automatically created by AWS EKS for the control plane"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_id" {
  description = "The ID of the managed node group"
  value       = aws_eks_node_group.this.id
}

output "node_group_status" {
  description = "Status of the managed node group"
  value       = aws_eks_node_group.this.status
}

output "access_policy_association_id" {
  description = "Ensures management EC2 only starts after Kubernetes admin authorization is active"
  value       = aws_eks_access_policy_association.management_admin.id
}
