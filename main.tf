provider "aws" {
  region = var.region
}

variable "ami" {
  description = "AMI ID for the EC2 instances"
  default     = "ami-08a0d1e16fc3f61ea"
}

variable "region" {
  description = "AWS region where resources will be provisioned"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Instance type for the EC2 instances"
  default     = "t3a.medium"
}

variable "mykey" {
  description = "Name of your AWS key pair"
  default     = "kadir"
}

variable "sec-gr-mutual" {
  description = "Name of the mutual security group"
  default     = "K8S-cluster-mutual-sec-group"
}

variable "sec-gr-k8s-master" {
  description = "Name of the Kubernetes master security group"
  default     = "K8S-cluster-master-sec-group"
}

variable "sec-gr-k8s-worker" {
  description = "Name of the Kubernetes worker security group"
  default     = "K8S-cluster-worker-sec-group"
}

data "aws_vpc" "name" {
  default = true
}

resource "aws_security_group" "K8S-cluster-mutual-sg" {
  name   = var.sec-gr-mutual
  vpc_id = data.aws_vpc.name.id

  ingress {
    protocol  = "tcp"
    from_port = 10250
    to_port   = 10250
    self      = true
  }

  ingress {
    protocol  = "udp"
    from_port = 8472
    to_port   = 8472
    self      = true
  }

  ingress {
    protocol  = "tcp"
    from_port = 2379
    to_port   = 2380
    self      = true
  }
}

resource "aws_security_group" "K8S-cluster-kube-master-sg" {
  name   = var.sec-gr-k8s-master
  vpc_id = data.aws_vpc.name.id

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 6443
    to_port   = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 10257
    to_port   = 10257
    self      = true
  }

  ingress {
    protocol  = "tcp"
    from_port = 10259
    to_port   = 10259
    self      = true
  }

  ingress {
    protocol  = "tcp"
    from_port = 30000
    to_port   = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "K8S-cluster-kube-worker-sg" {
  name   = var.sec-gr-k8s-worker
  vpc_id = data.aws_vpc.name.id

  ingress {
    protocol  = "tcp"
    from_port = 30000
    to_port   = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 10256
    to_port   = 10256
    self      = true
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "K8S-master-server-s3-role" {
  name               = "K8S-cluster-master-server-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
}

resource "aws_iam_instance_profile" "K8S-cluster-master-server-profile" {
  name = "K8S-cluster-master-server-profile"
  role = aws_iam_role.K8S-master-server-s3-role.name
}

resource "aws_instance" "kube-master" {
  count             = 1
  ami               = var.ami
  instance_type     = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.K8S-cluster-master-server-profile.name
  key_name          = var.mykey
  subnet_id         = "subnet-079ed9643fe7323db"  # Replace with your subnet ID in us-east-1a
  availability_zone = "us-east-1a"
  security_groups   = [
    aws_security_group.K8S-cluster-kube-master-sg.id,
    aws_security_group.K8S-cluster-mutual-sg.id
  ]
  tags = {
    Name        = "kube-master"
    Project     = "tera-kube-ans"
    Role        = "master"
    Id          = "1"
    Environment = "dev"
  }
}

resource "aws_instance" "kube-worker" {
  count             = 2  # Create 2 worker nodes
  ami               = var.ami
  instance_type     = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.K8S-cluster-master-server-profile.name
  key_name          = var.mykey
  subnet_id         = "subnet-079ed9643fe7323db"  # Replace with your subnet ID in us-east-1a
  availability_zone = "us-east-1a"
  security_groups   = [
    aws_security_group.K8S-cluster-kube-worker-sg.id,
    aws_security_group.K8S-cluster-mutual-sg.id
  ]
  tags = {
    Name        = "worker-${count.index + 1}"
    Project     = "tera-kube-ans"
    Role        = "worker"
    Id          = "${count.index + 1}"
    Environment = "dev"
  }
}

output "kube-master-ip" {
  value     = aws_instance.kube-master[*].public_ip
  sensitive = false
  description = "Public IP addresses of the kube-master instances"
}

output "kube-worker-ips" {
  value     = aws_instance.kube-worker[*].public_ip
  sensitive = false
  description = "Public IP addresses of the kube-worker instances"
}
