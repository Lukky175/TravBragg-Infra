variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner" {
  type = string
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
  description = "Availability Zone for the subnet" #"ap-south-1a"
  type        = string
}