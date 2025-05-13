resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = local.env

  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.env}-igw"
  }
}

resource "aws_subnet" "public-zone1" {
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/19"
  availability_zone       = local.zone1
  tags = {
    Name = "${local.env}-public-${local.zone1}"
  }
}


resource "aws_subnet" "public-zone2" {
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.32.0/19"
  availability_zone       = local.zone2
  tags = {
    Name = "${local.env}-public-subnet-2"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${local.env}-public"
    Environment = local.env
  }
}


resource "aws_route_table_association" "public_zone1" {
  subnet_id      = aws_subnet.public-zone1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_zone2" {
  subnet_id      = aws_subnet.public-zone2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "ec2-security-group"
    Environment = local.env
  }
}


resource "aws_key_pair" "monitoring-server-key-pair" {
  provider   = aws
  key_name   = "monitoring-key-pair"
  public_key = file("./id_rsa.pub")

}
###############################RDS########################################


resource "aws_db_subnet_group" "postgres-rds" {
  name       = "postgres-rds"
  subnet_ids = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]
  tags = {
    Name        = "postgres-rds"
    Environment = local.env
  }
}

resource "aws_db_instance" "postgres-accounts" {
  identifier             = "postgres-accounts"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16.3"
  username               = "postgres"
  password               = "postgres"
  db_subnet_group_name   = aws_db_subnet_group.postgres-rds.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  #   parameter_group_name   = aws_db_parameter_group.db_parameter_group.name
  publicly_accessible     = false
  skip_final_snapshot     = false
  backup_retention_period = 7
  tags = {
    Name        = "postgres-instance"
    Environment = local.env
  }
}

resource "aws_db_instance" "postgres-orders" {
  identifier             = "postgres-orders"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16.3"
  username               = "postgres"
  password               = "postgres"
  db_subnet_group_name   = aws_db_subnet_group.postgres-rds.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  #parameter_group_name   = aws_db_parameter_group.db_parameter_group.name
  publicly_accessible     = false
  skip_final_snapshot     = false
  backup_retention_period = 7
  tags = {
    Name        = "postgres-instance"
    Environment = local.env
  }
}

resource "aws_route53_zone" "backend_postgres_accounts" {
  name = "backend.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_record" "postgres_rds_accounts" {
  zone_id = aws_route53_zone.backend_postgres_accounts.zone_id
  name    = "postgres.accounts" # Using a subdomain
  type    = "CNAME"
  ttl     = 300
  records = [replace(aws_db_instance.postgres-accounts.endpoint, ":5432", "")] # Remove the port number from endpoint
}

resource "aws_route53_zone" "backend_postgres_orders" {
  name = "backend.in"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_record" "postgres_rds_orders" {
  zone_id = aws_route53_zone.backend_postgres_orders.zone_id
  name    = "postgres.orders" # Using a subdomain
  type    = "CNAME"
  ttl     = 300
  records = [replace(aws_db_instance.postgres-orders.endpoint, ":5432", "")] # Remove the port number from endpoint
}




#################################_EKS_#####################################################

resource "aws_iam_role" "ecommerce_cluster_role" {
  name = "ecommerce_cluster_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecommerce_cluster_role_policy" {
  role       = aws_iam_role.ecommerce_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "ecommerce_node_group_role" {
  name = "ecommerce-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecommerce_node_group_role_policy" {
  role       = aws_iam_role.ecommerce_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecommerce_node_group_cni_policy" {
  role       = aws_iam_role.ecommerce_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecommerce_node_group_registry_policy" {
  role       = aws_iam_role.ecommerce_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


resource "aws_eks_cluster" "ecommerce-prod-cluster" {
  name     = local.eks_name
  role_arn = aws_iam_role.ecommerce_cluster_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]
    security_group_ids = [aws_security_group.ec2_sg.id]
  }
}

resource "aws_eks_node_group" "ecommerce" {
  cluster_name    = aws_eks_cluster.ecommerce-prod-cluster.name
  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.ecommerce_node_group_role.arn
  subnet_ids      = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key               = aws_key_pair.monitoring-server-key-pair.key_name
    source_security_group_ids = [aws_security_group.ec2_sg.id]
  }
}



resource "aws_eks_addon" "eks_ebs_csi_driver" {
  cluster_name  = local.eks_name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.38.1-eksbuild.1" # Update this based on available versions for your Kubernetes version.

  depends_on = [aws_eks_cluster.ecommerce-prod-cluster]
}



