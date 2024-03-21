resource "aws_vpc" "mastervpc" {
    cidr_block = var.cidr

    tags = {
        Name = "Master-VPC"
    }
}

resource "aws_subnet" "subnet1" {
    vpc_id = aws_vpc.mastervpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true

    tags = {
      Name = "Master-Subnet-1"
    }
}

resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.mastervpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Master-Subnet-2"
  }

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mastervpc.id

  tags = {
    Name = "Master-Internet-Gateway"
  }

}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.mastervpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Master-Public-RT"
  }

}

resource "aws_route_table_association" "rta1" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "master-sg" {
  name = "Master-SG"
  vpc_id = aws_vpc.mastervpc.id

  ingress {
    description = "HTTP Port"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH Port"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Master-SG"
  }

}

resource "aws_s3_bucket" "masters3" {
  bucket = "masters3bucket2024"
}

resource "aws_s3_bucket_public_access_block" "masters31" {
  bucket = aws_s3_bucket.masters3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "masters32" {
  bucket = aws_s3_bucket.masters3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "masters34" {
  depends_on = [aws_s3_bucket_ownership_controls.masters32]

  bucket = aws_s3_bucket.masters3.id
  acl    = "public-read"
}

resource "aws_instance" "web1" {
  ami = "ami-0a1b648e2cd533174"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.master-sg.id]
  subnet_id = aws_subnet.subnet1.id
  user_data = base64encode(file("userdata.sh"))
  key_name = "aws-secret"
  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "Web-Server-1"
  }

}

resource "aws_instance" "web2" {
  ami = "ami-0a1b648e2cd533174"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.master-sg.id]
  subnet_id = aws_subnet.subnet2.id
  user_data = base64encode(file("userdata1.sh"))
  key_name = "aws-secret"
  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "Web-Server-2"
  }

}

resource "aws_lb" "alb" {
  name = "Master-ALB"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.master-sg.id]
  subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "Master-ALB"
  }

}

resource "aws_lb_target_group" "alb-tg" {
  name = "Master-ALB-TG"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.mastervpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }

}

resource "aws_lb_target_group_attachment" "target1" {
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id = aws_instance.web1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "target2" {
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id = aws_instance.web2.id
  port = 80
}

resource "aws_lb_listener" "alb-listerner" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.alb-tg.arn
    type = "forward"
  }
}

resource "aws_eip" "eip1" {
  domain = "vpc"

  tags = {
    Name = "Web-Server1-EIP"
  }
}

resource "aws_eip" "eip2" {
  domain = "vpc"

  tags = {
    Name = "Web-Server2-EIP"
  }
}

resource "aws_eip_association" "eip1_alloc" {
  instance_id = aws_instance.web1.id
  allocation_id = aws_eip.eip1.id
}

resource "aws_eip_association" "eip2_alloc" {
  instance_id = aws_instance.web2.id
  allocation_id = aws_eip.eip2.id
}


output "lbdnsname" {
  value = aws_lb.alb.dns_name
}

output "web1-eip" {
  value = aws_instance.web1.public_ip
}

output "web2-eip" {
  value = aws_instance.web2.public_ip
}
