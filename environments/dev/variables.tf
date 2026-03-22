variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, staging, prod)"
}

variable "owner" {
  type        = string
  description = "Owner of the project"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "instance_tenancy" {
  description = "VPC instance tenancy"
  type        = string
  default     = "default"
}

variable "subnet_public_cidr_block" {
  description = "Subnet CIDR block" #"10.0.1.0/24"
  type        = string
}

variable "subnet_private_cidr_block" {
  description = "Subnet CIDR block" #"10.0.2.0/24"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone for the subnet"
  type        = string
}