module "networking" {
  source = "../../modules/networking"

  project_name      = var.project_name
  environment       = var.environment
  owner             = var.owner
  instance_tenancy  = var.instance_tenancy
  cidr_block        = var.cidr_block
  availability_zone = var.availability_zone
  subnet_public_cidr_block = var.subnet_public_cidr_block
  subnet_private_cidr_block = var.subnet_private_cidr_block
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  owner        = var.owner

  instance_type = var.instance_type
  vpc_id    = module.networking.vpc_id
  public_subnet_id   = module.networking.public_subnet_id
  private_subnet_id  = module.networking.private_subnet_id
}