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
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = local.zone1
  tags = {
    Name = "${local.env}-public-${local.zone1}"
  }
}

resource "aws_subnet" "public-zone2" {
   map_public_ip_on_launch = true
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = local.zone2
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

resource "aws_iam_role" "devopsshack_cluster_role" {
  name = "devopsshack-cluster-role"

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

resource "aws_iam_role_policy_attachment" "devopsshack_cluster_role_policy" {
  role       = aws_iam_role.devopsshack_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "devopsshack_node_group_role" {
  name = "devopsshack-node-group-role"

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

resource "aws_iam_role_policy_attachment" "devopsshack_node_group_role_policy" {
  role       = aws_iam_role.devopsshack_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "devopsshack_node_group_cni_policy" {
  role       = aws_iam_role.devopsshack_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "devopsshack_node_group_registry_policy" {
  role       = aws_iam_role.devopsshack_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}






###########################################################################################################################

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

##############################################EC2##############################################################


resource "aws_launch_template" "accounts_launch_template" {
  name_prefix   = "accounts-launch-template"
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t3.medium"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  block_device_mappings {
     device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  user_data = base64encode(file("./accounts-userdata.sh"))

  tags = {
    Name        = "Accounts Launch Template"
    Environment = local.env
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [aws_db_instance.postgres-accounts]
}

resource "aws_lb_target_group" "accounts_service_tg" {
  name     = "accounts-service-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name        = "accounts-target-group"
    Environment = local.env
  }
}

resource "aws_lb" "accounts_load-balancer" {
  name               = "accounts-load-balancer"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]
  tags = {
    Name        = "accounts-load-balancer"
    Environment = local.env
  }
}

resource "aws_lb_listener" "http_accounts" {
  load_balancer_arn = aws_lb.accounts_load-balancer.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.accounts_service_tg.arn
  }
  tags = {
    Name        = "TCP-listener"
    Environment = local.env
  }
}

resource "aws_autoscaling_group" "accounts_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.accounts_service_tg.arn]
  vpc_zone_identifier = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]

  launch_template {
    id      = aws_launch_template.accounts_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "accounts ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.env
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [ aws_launch_template.accounts_launch_template ]
}

resource "aws_route53_zone" "accounts_zone" {
  name = "backend.accounts.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}
resource "aws_route53_record" "accounts_record" {
  zone_id = aws_route53_zone.accounts_zone.zone_id
  name    = "backend.accounts.com"
  type    = "A"
  alias {
    name                   = aws_lb.accounts_load-balancer.dns_name
    zone_id                = aws_lb.accounts_load-balancer.zone_id
    evaluate_target_health = false
  }
}

#######################################elasticSearch#####################

resource "aws_launch_template" "ElasticSearch_launch_template" {
  name_prefix   = "ElasticSearch-launch-template"
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t3.medium"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  block_device_mappings {
     device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  user_data = base64encode(file("./ElasticSearch-userdata.sh"))

  tags = {
    Name        = "ElasticSearch Launch Template"
    Environment = local.env
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [aws_db_instance.postgres-accounts]
}

resource "aws_lb_target_group" "ElasticSearch_service_tg" {
  name     = "ElasticSearch-service-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name        = "ElasticSearch-target-group"
    Environment = local.env
  }
}

resource "aws_lb" "ElasticSearch_load-balancer" {
  name               = "ElasticSearch-load-balancer"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]
  tags = {
    Name        = "ElasticSearch-load-balancer"
    Environment = local.env
  }
}

resource "aws_lb_listener" "http_ElasticSearch" {
  load_balancer_arn = aws_lb.ElasticSearch_load-balancer.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ElasticSearch_service_tg.arn
  }
  tags = {
    Name        = "http-listener"
    Environment = local.env
  }
}

resource "aws_autoscaling_group" "ElasticSearch_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.ElasticSearch_service_tg.arn]
  vpc_zone_identifier = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]

  launch_template {
    id      = aws_launch_template.ElasticSearch_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "elasticSearch ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.env
    propagate_at_launch = true
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [ aws_launch_template.ElasticSearch_launch_template ]
}

resource "aws_route53_zone" "elasticSearch_zone" {
  name = "backend.elasticSearch.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}
resource "aws_route53_record" "ElasticSearch_records" {
  zone_id = aws_route53_zone.elasticSearch_zone.id
  name    = "backend.elasticSearch.com"
  type    = "A"
  alias {
    name                   = aws_lb.ElasticSearch_load-balancer.dns_name
    zone_id                = aws_lb.ElasticSearch_load-balancer.zone_id
    evaluate_target_health = false
  }
}

#######################################catalog#################################

resource "aws_launch_template" "catalog_launch_template" {
  name_prefix   = "catalog-launch-template"
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t3.medium"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  block_device_mappings {
     device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  user_data = base64encode(file("./catalog-userdata.sh"))

  tags = {
    Name        = "catalog Launch Template"
    Environment = local.env
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [aws_db_instance.postgres-accounts]
}

resource "aws_lb_target_group" "catalog_service_tg" {
  name     = "catalog-service-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name        = "catalog-target-group"
    Environment = local.env
  }
}

resource "aws_lb" "catalog_load-balancer" {
  name               = "catalog-load-balancer"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]
  tags = {
    Name        = "catalog-load-balancer"
    Environment = local.env
  }
}

resource "aws_lb_listener" "http_catalog" {
  load_balancer_arn = aws_lb.catalog_load-balancer.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalog_service_tg.arn
  }
  tags = {
    Name        = "http-listener"
    Environment = local.env
  }
}

resource "aws_autoscaling_group" "catalog_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.catalog_service_tg.arn]
  vpc_zone_identifier = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]

  launch_template {
    id      = aws_launch_template.catalog_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "catalog ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.env
    propagate_at_launch = true
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [ aws_launch_template.catalog_launch_template ]
}

resource "aws_route53_zone" "catalog_zone" {
  name = "backend.catalog.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}
resource "aws_route53_record" "catalog_records" {
  zone_id = aws_route53_zone.catalog_zone.id
  name    = "backend.catalog.com"
  type    = "A"
  alias {
    name                   = aws_lb.catalog_load-balancer.dns_name
    zone_id                = aws_lb.catalog_load-balancer.zone_id
    evaluate_target_health = false
  }
}

########################################orders##############################

resource "aws_launch_template" "orders_launch_template" {
  name_prefix   = "orders-launch-template"
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t3.medium"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  user_data = base64encode(file("./orders-userdata.sh"))

  tags = {
    Name        = "orders Launch Template"
    Environment = local.env
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [aws_db_instance.postgres-accounts]
}

resource "aws_lb_target_group" "orders_service_tg" {
  name     = "orders-service-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name        = "orders-target-group"
    Environment = local.env
  }
}

resource "aws_lb" "orders_load-balancer" {
  name               = "orders-load-balancer"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]
  tags = {
    Name        = "orders-load-balancer"
    Environment = local.env
  }
}

resource "aws_lb_listener" "http_orders" {
  load_balancer_arn = aws_lb.orders_load-balancer.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.orders_service_tg.arn
  }
  tags = {
    Name        = "http-listener"
    Environment = local.env
  }
}

resource "aws_autoscaling_group" "orders_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.orders_service_tg.arn]
  vpc_zone_identifier = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]

  launch_template {
    id      = aws_launch_template.orders_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "orders ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.env
    propagate_at_launch = true
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [ aws_launch_template.orders_launch_template ]
}

resource "aws_route53_zone" "orders_zone" {
  name = "backend.orders.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}
resource "aws_route53_record" "orders_records" {
  zone_id = aws_route53_zone.orders_zone.id
  name    = "backend.orders.com"
  type    = "A"
  alias {
    name                   = aws_lb.orders_load-balancer.dns_name
    zone_id                = aws_lb.orders_load-balancer.zone_id
    evaluate_target_health = false
  }
}

#########################################graphql##############################################

resource "aws_launch_template" "graphql_launch_template" {
  name_prefix   = "graphql-launch-template"
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t3.medium"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  block_device_mappings {
     device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  user_data = base64encode(file("./graphql-userdata.sh"))

  tags = {
    Name        = "graphql Launch Template"
    Environment = local.env
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [aws_db_instance.postgres-accounts]
}

resource "aws_lb_target_group" "graphql_service_tg" {
  name     = "graphql-service-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name        = "graphql-target-group"
    Environment = local.env
  }
}

resource "aws_lb" "graphql_load-balancer" {
  name               = "graphql-load-balancer"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]
  tags = {
    Name        = "graphql-load-balancer"
    Environment = local.env
  }
}

resource "aws_lb_listener" "http_graphql" {
  load_balancer_arn = aws_lb.graphql_load-balancer.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.graphql_service_tg.arn
  }
  tags = {
    Name        = "http-listener"
    Environment = local.env
  }
}

resource "aws_autoscaling_group" "graphql_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.graphql_service_tg.arn]
  vpc_zone_identifier = [aws_subnet.public-zone1.id, aws_subnet.public-zone2.id]

  launch_template {
    id      = aws_launch_template.graphql_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "graphql ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.env
    propagate_at_launch = true
  }
  lifecycle {
    # create_before_destroy = true
  }
  depends_on = [ aws_launch_template.graphql_launch_template ]
}

output "ip_address_graphql" {
  value = aws_lb.graphql_load-balancer.dns_name
  depends_on = [ aws_lb.graphql_load-balancer ]
}


#########################################################################################





