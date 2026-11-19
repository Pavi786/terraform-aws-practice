variable "cluster_name" {
  description = "The name of the EKS Cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS Cluster"
  type        = string
  default     = "1.31"
}

variable "control_plane_subnet_ids" {
  description = "List of subnet IDs for the EKS Control Plane ENIs (multi-AZ)"
  type        = list(string)
}

variable "worker_subnet_ids" {
  description = "List of private subnet IDs where worker nodes and pods will run"
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "IAM Role ARN for the EKS control plane"
  type        = string
}

variable "node_role_arn" {
  description = "IAM Role ARN for the managed worker node group"
  type        = string
}

variable "management_role_arn" {
  description = "IAM Role ARN of the management server to authorize in Kubernetes"
  type        = string
}

variable "node_instance_types" {
  description = "Instance types for the worker node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_policy_dependencies" {
  description = "Explicit dependency ensuring IAM policies attach before nodes launch"
  type        = any
  default     = []
}
