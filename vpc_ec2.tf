provider "aws" {

region = "ap-south-1" #AWS provider

}

#creting the vpc
resource "aws_vpc" "vpc" { 
cidr_block = "10.0.0.0/16"
                }

#creating two subnet with public access

resource "aws_subnet" "subnet1" {        #CREATING SUBNET
        vpc_id                          = aws_vpc.vpc.id
        cidr_block                      = "10.0.1.0/24"
        availability_zone               = "ap-south-1a"
        map_public_ip_on_launch         = true 
    }
resource "aws_subnet" "subnet2" {        #CREATING SUBNET
        vpc_id                          = aws_vpc.vpc.id        
	cidr_block                      = "10.0.2.0/24"
        availability_zone               = "ap-south-1b"
        map_public_ip_on_launch         = true
}

#Creating the Internet gatewya and adding it to VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main"
  }
}
#Creating the routing tabel and allow the connection to Internet Gateway AS WELL SUBNETS
resource "aws_route_table" "way"{
	vpc_id = aws_vpc.vpc.id
	route{
			cidr_block = "0.0.0.0/0"
			gateway_id = aws_internet_gateway.gw.id
		}
}
resource "aws_route_table_association" "route1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.way.id
}
resource "aws_route_table_association" "route2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.way.id
}
#Created the security gourp and allowed the port 80 and 22 
resource "aws_security_group" "sgvpc" {
name = "web"  
vpc_id = aws_vpc.vpc.id
ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
#Created the two Instance and install ngixn and apache on the two server 
resource "aws_instance" "node1" {
  ami                    = "ami-0522ab6e1ddcc7055"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sgvpc.id]
  subnet_id              = aws_subnet.subnet1.id
  user_data              = <<-EOF
#!/bind/bash
sudo apt update
sudo apt install nginx -y
sudo systemctl start nginx
sudo sytemctl enable nginx
EOF
}

resource "aws_instance" "node2" {
  ami                    = "ami-0522ab6e1ddcc7055"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sgvpc.id]
  subnet_id              = aws_subnet.subnet2.id
  user_data              = <<-EOF
#!/bind/bash
sudo apt update
sudo apt install nginx -y
sudo systemctl start nginx
sudo sytemctl enable nginx
EOF
}
#Created the lb and added the traget groups to load balancer
resource "aws_lb" "lb" {
  name               = "marklb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.sgvpc.id]
  subnets         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "web"
  }
}
resource "aws_lb_target_group" "lbtg" {
  name     = "lbtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}
resource "aws_lb_target_group_attachment" "binding" {
  target_group_arn = aws_lb_target_group.lbtg.arn
  target_id        = aws_instance.node1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "binding2" {
  target_group_arn = aws_lb_target_group.lbtg.arn
  target_id        = aws_instance.node2.id
  port             = 80
}
resource "aws_lb_listener" "checking" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lbtg.arn
    type             = "forward"
  }
}
output "loadbalancerdns" {
  value = aws_lb.lb.dns_name
}
