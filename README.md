## Terraform Configuration for Kubernetes Cluster 

This Terraform configuration sets up a Kubernetes cluster on AWS using EC2 instances. It utilizes Terraform to manage infrastructure as code, ensuring consistency and repeatability in deployments. 

# Variable Declarations 

Variables such as ami, region, instance_type, mykey, etc., have been consolidated into auto.tfvars. This file now serves as the single source for specifying variable values, ensuring easier management and separation of sensitive data. 

# Provider Configuration 

The AWS provider configuration in main.tf now correctly references variables declared within the same file. For example, var.region is used to specify the AWS region where resources will be provisioned.

# Resource Definitions
Resource definitions (e.g., aws_instance, aws_security_group, aws_iam_role) remain unchanged except for referencing variables from var. namespace. This modular approach allows for flexibility in configuration and easier maintenance. 

# Files Included 
- **main.tf:** Contains the Terraform configuration for provisioning AWS resources. It references variables from var. namespace and defines resource blocks for EC2 instances, security groups, IAM roles, etc.

- **auto.tfvars:** This file contains variable definitions such as mykey, ami, region, instance_type, as well as additional variables specific to security groups and other configurations. It overrides default values and provides customizable inputs for your deployment. 
