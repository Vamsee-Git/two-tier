provider "aws" {
  region = "ap-south-1"  # Replace with your desired region.
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "custom-vpc"
  }
}

# Subnets
resource "aws_subnet" "web_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "web-subnet-1"
  }
}

resource "aws_subnet" "web_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "web-subnet-2"
  }
}

resource "aws_subnet" "db_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "db-subnet-1"
  }
}

resource "aws_subnet" "db_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "db-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route Table for Web Subnets
resource "aws_route_table" "web_route_table" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_route" {
  route_table_id         = aws_route_table.web_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "web_subnet_1_association" {
  subnet_id      = aws_subnet.web_subnet_1.id
  route_table_id = aws_route_table.web_route_table.id
}

resource "aws_route_table_association" "web_subnet_2_association" {
  subnet_id      = aws_subnet.web_subnet_2.id
  route_table_id = aws_route_table.web_route_table.id
}

# Route Table for DB Subnets (No Internet Access)
resource "aws_route_table" "db_route_table" {
  vpc_id = aws_vpc.main.id
}

# EC2 Security Group (Web Servers)
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Security Group (Database)
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow DB traffic from web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instances (Web Servers)
resource "aws_instance" "web_server_1" {
  ami                    = "ami-0ddfba243cbee3768"  # Replace with a valid Apache or Nginx AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web_subnet_1.id
  vpc_security_group_ids     = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "web-server-1"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Welcome to Instance 1</h1>" > /var/www/html/index.html
              EOF
}

resource "aws_instance" "web_server_2" {
  ami                    = "ami-0ddfba243cbee3768"  # Replace with a valid Apache or Nginx AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web_subnet_2.id
  vpc_security_group_ids     = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "web-server-2"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Welcome to Instance 2</h1>" > /var/www/html/index.html

              EOF
}
# Application Load Balancer Configuration
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]  # ALB security group
  subnets            = [aws_subnet.web_subnet_1.id, aws_subnet.web_subnet_2.id]
  enable_deletion_protection = false
 
  tags = {
    Name = "Web ALB"
  }
}
 
# Target Group for Web Servers (both EC2 instances)
resource "aws_lb_target_group" "web_target_group" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
 
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
 
  tags = {
    Name = "Web Target Group"
  }
}
 
# Listener for the ALB (HTTP Listener on Port 80)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn  # Reference the target group ARN directly
  }
}
 
# Register EC2 Instances with the ALB Target Group
resource "aws_lb_target_group_attachment" "web_server_1_attachment" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id       = aws_instance.web_server_1.id
  port            = 80
}
 
resource "aws_lb_target_group_attachment" "web_server_2_attachment" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id       = aws_instance.web_server_2.id
  port            = 80
}
# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"  # Replaces the deprecated 'vpc = true'
}
 
# NAT Gateway in Public Subnet 1
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.web_subnet_1.id
 
  tags = {
    Name = "NAT Gateway"
  }
}
 
# Route Table for Private Subnet 1
resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.main.id
 
  tags = {
    Name = "Private Route Table 1"
  }
}
 
# Route Table for Private Subnet 2
resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.main.id
 
  tags = {
    Name = "Private Route Table 2"
  }
}
 
# Route for Private Subnet 1 through NAT Gateway
resource "aws_route" "private_route_1" {
  route_table_id         = aws_route_table.private_route_table_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}
 
# Route for Private Subnet 2 through NAT Gateway
resource "aws_route" "private_route_2" {
  route_table_id         = aws_route_table.private_route_table_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}
# RDS MySQL Configuration
resource "aws_db_instance" "mysql_db" {
  allocated_storage    = 20   # Minimum storage size in GB
  storage_type         = "gp2"  # General Purpose SSD storage
  instance_class       = "db.t3.micro"  # Instance type (choose based on requirements)
  engine               = "mysql"
  engine_version       = "8.0"  # MySQL version
  db_name              = "mydatabase"  # Database name
  username             = "admin"  # Master username
  password             = "your-password"  # Master password
  multi_az             = false  # Multi-AZ deployment for high availability (set to true for production)
  publicly_accessible  = false  # Don't make the DB publicly accessible
  db_subnet_group_name  = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]  # Attach security group
  backup_retention_period = 7  # Retain backups for 7 days
  availability_zone     = "ap-south-1a"  # Set to match your region/availability zone
  skip_final_snapshot = true
  tags = {
    Name = "MySQL-Database"
  }
}
# DB Subnet Group (Required for RDS)
resource "aws_db_subnet_group" "main" {
  name        = "mysql-db-subnet-group"
  subnet_ids  = [aws_subnet.db_subnet_1.id, aws_subnet.db_subnet_2.id]
  tags = {
    Name = "MySQL DB Subnet Group"
  }
}
# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-state-lock"  # Unique table name
  billing_mode = "PAY_PER_REQUEST"  # No need to manage capacity manually
 
  hash_key     = "LockID"  # The primary key for DynamoDB, which Terraform uses for state locking
 
  attribute {
    name = "LockID"
    type = "S"  # String type
  }
 
  tags = {
    Name = "Terraform State Lock"
  }
}
