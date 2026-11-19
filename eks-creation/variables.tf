# ==============================================================================
# ROOT INPUT VARIABLES
# ==============================================================================
variable "aws_region" {
  description = "Target AWS region"
  type        = string
  default     = "ap-south-1" # Mumbai
}

variable "cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
  default     = "demo-eks-mumbai"
}

variable "environment" {
  description = "Deployment lifecycle stage"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ high availability"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version"
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "Instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}
