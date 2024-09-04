# Provider Block: Configures AWS as the cloud provider and sets the region
provider "aws" { 
  region = var.region
}

# Variables: Define configurable values used throughout the configuration

variable "ami" {
  description = "AMI ID for the EC2 instances"
  default     = "ami-08a0d1e16fc3f61ea"  # The default AMI ID for the instances
}

variable "region" {
  description = "AWS region where resources will be provisioned"
  default     = "us-east-1"  # Default AWS region
}

variable "instance_type" {
  description = "Instance type for the EC2 instances"
  default     = "t3a.medium"  # Default instance type for EC2
}

variable "mykey" {
  description = "Name of your AWS key pair"
  default     = "kadir"  # Default name for the AWS key pair
}

variable "sec-gr-mutual" {
  description = "Name of the mutual security group"
  default     = "K8S-cluster-mutual-sec-group"  # Default name for mutual security group
}

variable "sec-gr-k8s-master" {
  description = "Name of the Kubernetes master security group"
  default     = "K8S-cluster-master-sec-group"  # Default name for Kubernetes master security group
}

variable "sec-gr-k8s-worker" {
  description = "Name of the Kubernetes worker security group"
  default     = "K8S-cluster-worker-sec-group"  # Default name for Kubernetes worker security group
}

# Data Source: Retrieves information about the default VPC
data "aws_vpc" "name" {
  default = true  # Retrieves the default VPC
}

# Security Group for mutual communication within the Kubernetes cluster
resource "aws_security_group" "K8S-cluster-mutual-sg" {
  name   = var.sec-gr-mutual
  vpc_id = data.aws_vpc.name.id

  # Ingress rules for communication within the Kubernetes cluster
  ingress {
    protocol  = "tcp"
    from_port = 10250
    to_port   = 10250
    self      = true  # Allows communication within the security group
  }

  ingress {
    protocol  = "udp"
    from_port = 8472
    to_port   = 8472
    self      = true  # Allows communication within the security group
  }

  ingress {
    protocol  = "tcp"
    from_port = 2379
    to_port   = 2380
    self      = true  # Allows communication within the security group
  }
}

# Security Group for Kubernetes master nodes
resource "aws_security_group" "K8S-cluster-kube-master-sg" {
  name   = var.sec-gr-k8s-master
  vpc_id = data.aws_vpc.name.id

  # Ingress rules for Kubernetes master security group
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from any IP
  }

  ingress {
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]  # Allow access to Kubernetes API server from any IP
  }

  ingress {
    protocol  = "tcp"
    from_port = 10257
    to_port   = 10257
    self      = true  # Allows communication within the security group
  }

  ingress {
    protocol  = "tcp"
    from_port = 10259
    to_port   = 10259
    self      = true  # Allows communication within the security group
  }

  ingress {
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]  # Allow NodePort service access from any IP
  }

  # Egress rule allowing all outbound traffic
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

# Security Group for Kubernetes worker nodes
resource "aws_security_group" "K8S-cluster-kube-worker-sg" {
  name   = var.sec-gr-k8s-worker
  vpc_id = data.aws_vpc.name.id

  # Ingress rules for Kubernetes worker security group
  ingress {
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]  # Allow NodePort service access from any IP
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from any IP
  }

  ingress {
    protocol  = "tcp"
    from_port = 10256
    to_port   = 10256
    self      = true  # Allows communication within the security group
  }

  # Egress rule allowing all outbound traffic
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

# IAM Role for the Kubernetes master server to access S3
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

  # Attach the managed policy for read-only access to S3
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
}

# IAM Instance Profile for the Kubernetes master server
resource "aws_iam_instance_profile" "K8S-cluster-master-server-profile" {
  name = "K8S-cluster-master-server-profile"
  role = aws_iam_role.K8S-master-server-s3-role.name
}

# EC2 Instance for the Kubernetes master node
resource "aws_instance" "kube-master" {
  count             = 1  # Only one master node
  ami               = var.ami
  instance_type     = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.K8S-cluster-master-server-profile.name
  key_name          = var.mykey
  subnet_id         = "subnet-079ed9643fe7323db"  # Replace with your subnet ID
  availability_zone = "us-east-1a"  # Availability zone for the instance
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

# EC2 Instances for Kubernetes worker nodes
resource "aws_instance" "kube-worker" {
  count               = 2  # Two worker nodes
  ami                 = var.ami
  instance_type       = var.instance_type
  key_name            = var.mykey
  subnet_id           = "subnet-079ed9643fe7323db"  # Replace with your subnet ID
  availability_zone   = "us-east-1a"
  security_groups     = [
    aws_security_group.K8S-cluster-kube-worker-sg.id,
    aws_security_group.K8S-cluster-mutual-sg.id
  ]
  tags = {
    Name        = "kube-worker-${count.index}"
    Project     = "tera-kube-ans"
    Role        = "worker"
    Id          = "${count.index + 1}"
    Environment = "dev"
  }
}
