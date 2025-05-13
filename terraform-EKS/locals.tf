locals {
  env             = "prod"
  region          = "us-east-1"
  zone1           = "us-east-1a"
  zone2           = "us-east-1b"
  eks_name        = "ecommerce-prod-cluster"
  eks_version     = "1.31"
  node_group_name = "ecommerce-prod-node-group"
}
