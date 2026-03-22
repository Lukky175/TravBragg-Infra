variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  description = "Public Subnet ID"
  type = string
}

variable "private_subnet_id" {
  description = "Private Subnet ID"
  type = string
}