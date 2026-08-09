variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "terraform-monitoring"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "trusted_cidr" {
  description = "Public IP allowed to access Prometheus and Grafana"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.trusted_cidr))
    error_message = "Enter a valid CIDR, such as 203.0.113.10/32."
  }
}