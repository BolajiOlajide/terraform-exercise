variable "aws_access_key" {
  description = "Access key gotten from AWS"
  type = string
}

variable "aws_secret_key" {
  description = "Secret key gotten from AWS"
  type = string
}

provider "aws" {
  region = "eu-central-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# resource "<provider>_<resource_type>" "name" {
#   config options ...
#   key = "value"
#   key2 = "value 2"
# }

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  # default = "10.0.66.0/24"
  # type = string
}

resource "aws_vpc" "first_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

# 2. Create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.first_vpc.id}"
}

# 3. Create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = "${aws_vpc.first_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# 4. Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.first_vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = "eu-central-1a"

  tags = {
    "Name" = var.subnet_prefix[0].name
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.first_vpc.id
  cidr_block = var.subnet_prefix[1].cidr_block
  availability_zone = "eu-central-1a"

  tags = {
    "Name" = var.subnet_prefix[1].name
  }
}

# 5. Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create security group to allow traffic on ports 22, 80 and 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.first_vpc.id

  ingress = [
    {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"],
      "ipv6_cidr_blocks": null,
      "prefix_list_ids": null,
      "security_groups": null,
      "self": null,
    },
    {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"],
      "ipv6_cidr_blocks": null,
      "prefix_list_ids": null,
      "security_groups": null,
      "self": null,
    },
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"],
      "ipv6_cidr_blocks": null,
      "prefix_list_ids": null,
      "security_groups": null,
      "self": null,
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"],
      "description": "egress",
      "ipv6_cidr_blocks": null,
      "prefix_list_ids": null,
      "security_groups": null,
      "self": null,
    }
  ]

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step. 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  # attachment {
  #   instance     = aws_instance.web_server.id
  #   device_index = 1
  # }
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  # because the eip needs the internet gateway to exist before it creates it
  # we need to use the `depends_on` attribute to specify that it's dependent
  # on another resource
  depends_on = [
    aws_internet_gateway.gw
  ]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# 9. Create ubuntu server and install/enable apache2
resource "aws_instance" "web_server" {
  ami = "ami-05f7491af5eef733a"
  instance_type = "t2.micro"
  availability_zone = "eu-central-1a"
  key_name = "Bolaji MBP 16"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c 'echo your very first web server > /var/www/html/index.html'
  EOF

  tags = {
    Name = "ubuntu_server"
  }
}

output "server_private_ip" {
  value = aws_instance.web_server.private_ip
}

output "server_id" {
  value = aws_instance.web_server.id
}