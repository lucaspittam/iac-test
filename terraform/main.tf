
# AWS Provider
provider "aws" {
  region     = var.aws_region
}

# data source for interpolation
data "aws_region" "current" {}

# VPC   
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
}

#Internet Gateway
resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.my_vpc.id

tags = {
    Name        = "ig-project"
  }
}

# Subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

tags = {
    Name = "public-1"
  }
}


resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${data.aws_region.current.name}b"
  map_public_ip_on_launch = true

tags = {
    Name = "public-2"
  }
}


resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = false

tags = {
    Name = "private-1"
  }
}


resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${data.aws_region.current.name}b"
  map_public_ip_on_launch = false

tags = {
    Name = "private-2"
  }
}

# Route Table

resource "aws_route_table" "route_table" {
 vpc_id = aws_vpc.my_vpc.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id

 }
    tags = {
    Name = "project-rt"
  }
}
 # Route Table Association 
resource "aws_route_table_association" "public_route_1" {
 subnet_id      = aws_subnet.public_subnet_1.id
 route_table_id = aws_route_table.route_table.id
}

# Route Table Association 
resource "aws_route_table_association" "public_route_2" {
 subnet_id      = aws_subnet.public_subnet_2.id
 route_table_id = aws_route_table.route_table.id
}


#  security groups
resource "aws_security_group" "public_security" {
  name        = "public-sg"
  description = "Allow web and ssh traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }
}

resource "aws_security_group" "private_security" {
  name        = "private-sg"
  description = "Allow web tier and ssh traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    security_groups = [ aws_security_group.public_security.id ]
  }
  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }
}

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "security group for alb"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ALB
resource "aws_lb" "project_alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

# Create ALB target group
resource "aws_lb_target_group" "project_tg" {
  name     = "project-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  depends_on = [aws_vpc.my_vpc]
}

# Create target attachments
resource "aws_lb_target_group_attachment" "tg_attach1" {
  target_group_arn = aws_lb_target_group.project_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80

  depends_on = [aws_instance.web1]
}

resource "aws_lb_target_group_attachment" "tg_attach2" {
  target_group_arn = aws_lb_target_group.project_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80

  depends_on = [aws_instance.web2]
}

# Create listener
resource "aws_lb_listener" "listener_lb" {
  load_balancer_arn = aws_lb.project_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project_tg.arn
  }
}

#  Data for Ami on EC2s
data "aws_ami" "ubuntu" {
 most_recent = true
 filter {
   name   = "name"
   values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
 }
 filter {
   name   = "virtualization-type"
   values = ["hvm"]
 }
 owners = ["099720109477"]
}

#Private Key
resource "tls_private_key" "key" {
 algorithm = "RSA"
 rsa_bits  = 4096
}

# AWS Key Pair for SSH
resource "aws_key_pair" "aws_key" {
 key_name   = "ssh-key"
 public_key = tls_private_key.key.public_key_openssh
}



# EC2 Instance
resource "aws_instance" "web1" {
  ami                          = data.aws_ami.ubuntu.id
  instance_type                = var.instance_type
  key_name                     = aws_key_pair.aws_key.key_name
  availability_zone            = "${data.aws_region.current.name}a"
  vpc_security_group_ids       = [aws_security_group.public_security.id]
  subnet_id                    = aws_subnet.public_subnet_1.id
  associate_public_ip_address  = true

  tags = {
    Name = "web1"
  }
}

resource "aws_instance" "web2" {
  ami                          = data.aws_ami.ubuntu.id
  instance_type                = var.instance_type
  key_name                     = aws_key_pair.aws_key.key_name
  availability_zone            = "${data.aws_region.current.name}b"
  vpc_security_group_ids       = [aws_security_group.public_security.id]
  subnet_id                    = aws_subnet.public_subnet_2.id
  associate_public_ip_address  = true

  tags = {
    Name = "web2"
  }
}

# Database subnet group
resource "aws_db_subnet_group" "db_subnet"  {
    name       = "db-subnet"
    subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

# Create database instance
resource "aws_db_instance" "project_db" {
  allocated_storage    = 5
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  identifier           = "db-instance"
  db_name              = "project_db"
  username             = "admin"
  password             = "password"
  db_subnet_group_name = aws_db_subnet_group.db_subnet.id
  vpc_security_group_ids = [aws_security_group.private_security.id]  
  publicly_accessible = false
  skip_final_snapshot  = true
}



