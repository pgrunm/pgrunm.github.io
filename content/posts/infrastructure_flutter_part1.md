---
draft: false
date: 2021-04-21T21:12:43+01:00
title: "Developing Flutter apps with cloud infrastructure: Part 1"
description: "This post shows how create AWS architecture with Terraform for working Jenkins installation."
slug: ""
tags: [DevOps, Flutter, AWS, Jenkins, Terraform]
externalLink: ""
series: []
---

## Introduction

Hello again! It's been a while, because I finally finished my studied and I'm now Bachelor of Science :-). Anyway, I wanted to create a blog post of my bachelor thesis and this is going to be the one.

The topic of my thesis was how to speed up development performance when developing Flutter applications with cloud infrastructure. The infrastrcture was completely created with Terraform in AWS. The architecture itself is based on a sample [published by AWS itself](https://github.com/aws-samples/jenkins-on-aws). It consists of:

- an internet gateway (for access from public of course)
- an application loadbalancer (which I replaced by an Elastic Loadbalancer)
- NAT gateways for network address translation of public to private IP adresses and
- the Jenkins leader as well as the agents of course

As this is of course the current state of the architecture, this can be changed anytime, because everything was completely created using Terraform.

![This is an image](/images/infrastructure-flutter/aws_architektur_jenkins.png "Image of the AWS architecture")

This image shows a simplified view of the architecture itself. It's created over two AZs (eu-central-1a and eu-central-1b) in this example. The AZs can be configured within the Terraform config. It's even possible to distribute the infrastructure about more than only two AZs.

## Provisioning of the cloud infrastructure

Let's start with the provisioning of the AWS infrastructure. As I appreciate automation a lot I did not build any infrastructure by hand. Instead I used Terraform to create every necessary piece of infrastructure, from the VPC until the Jenkins leader. The most interesting parts as of now are the main file and the variables.

### Terraform main file

The content below is inside the `main.tf` file. It basically created all necessary security groups, subnets as well as the Elastic Container Service.

```terraform
provider "aws" {
  region = "eu-central-1"
}

# We need a cluster in which to put our service.
resource "aws_ecs_cluster" "JenkinsThesisAwsDev" {
  name = var.application_name
}

# Log groups hold logs from our app.
resource "aws_cloudwatch_log_group" "JenkinsThesisAwsDev" {
  name = "/ecs/${var.application_name}"
  # Delete Logs after 7 days
  retention_in_days = 7

  # Write the environment into tags
  tags = {
    "Environment" = var.environment
  }
}

# The main service.
resource "aws_ecs_service" "JenkinsThesisAwsDev" {
  name            = "ecs_service_${var.application_name}"
  task_definition = aws_ecs_task_definition.jenkins_master.arn
  cluster         = aws_ecs_cluster.JenkinsThesisAwsDev.id
  launch_type     = "FARGATE"

  # Require service version 1.4.0!
  platform_version = "1.4.0"

  desired_count = 1

  # Register the master and the port in dns
  service_registries {
    registry_arn = aws_service_discovery_service.jenkins_master.arn
    port         = 50000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jenkins.arn
    container_name   = "jenkins_master"
    container_port   = 8080
  }

  network_configuration {
    assign_public_ip = false

    security_groups = [
      aws_security_group.outbound.id,
      aws_security_group.efs_jenkins_security_group.id,
      aws_security_group.jenkins.id
    ]

    subnets = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id,
    ]
  }
}
```

The region is also configured within this file. As you can see, we run this on Fargate, because this is easier. The other option would be to use EC2 machines, but this is not necessary.

Some other important points are

- the configuration of the Fargate version 1.4.0, because otherwise you cannot mount storage into the containers
- the DNS registration of the master and the agent
- the configuration of the Elastic loadbalancer to redirect any incoming traffic to the Jenkins master container on TCP port 8080

### Configuration of variables

The tags and variables are populated inside the `variables.tf` file, as listed here:

```terraform
# Type of environment e. g. dev or prod
variable "environment" {
  description = "The name to use for the environment, used in Names etc."
  type        = string
  default     = "dev"
}

# Name of the Application
variable "application_name" {
  description = "The name of the application"
  type        = string
  default     = "jenkins_flutter_thesis"
}

# Output of the current region
data "aws_region" "current" {}

# Name of the Admin Account
variable "jenkins_accountname" {
  description = "The Jenkins Master Account"
  type        = string
  default     = "developer"
}

# Create a random password for the first login of the administrator account.
resource "random_string" "jenkins_pass" {
  length           = 20
  special          = true
  override_special = "/@\" "
}

variable "master_memory_amount" {
  default     = 1024
  description = "Soft RAM Limit for Jenkins Agent"
}

variable "master_cpu_amount" {
  default     = 512
  description = "Soft CPU Limit for Jenkins Agent"
}

variable "agent_memory_amount" {
  default     = 4096
  description = "Soft RAM Limit for Jenkins Agent"
}

variable "agent_cpu_amount" {
  default     = 2048
  description = "Soft CPU Limit for Jenkins Agent"
}

variable "s3_artifact_bucket_name" {
  default     = "jenkins-flutter-artifact-bucket"
  description = "Default Name for S3 Bucket where Jenkins stores artifacts"
}

variable "s3_folder_prefix_name" {
  default     = "jenkins_artifacts"
  description = "Default folder prefix for folder in the S3 Bucket where Jenkins stores artifacts"
}
```

<!-- What contains the variables file? -->
Just to mention the most important points:

- Any tags as well as application name comes from this file, it can be configured accordingly
- the administrator's username and password are configured inside this file. This is only for demo purposes, **never do this in a production environment**!
- CPU and memory limits are configured here
- Name and folder prefix for the S3 bucket, where artifacts are stored

<!-- How to host a gist: https://gohugo.io/content-management/shortcodes/#gist -->
<!-- {{< gist spf13 7896402 >}} -->

There are of course even more Terraform files, like the ones that create IAM policies, ECS task definitions for Jenkins master and agent or an S3 bucket for storing artifcats.

The most interesting file is probably the `network.tf` file, as it contains the most details about the network structure:

```terraform
# network.tf
resource "aws_vpc" "app-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.app-vpc.id
  count             = length(var.public_subnets)
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]
}

# Internet GW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.app-vpc.id

  tags = {
    Name        = var.application_name,
    Environment = var.environment
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.app-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "Gatewayroute for ${var.application_name}: ${var.environment} environment"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.route.id
  count          = length(var.public_subnets)
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.app-vpc.id
  count             = length(var.private_subnets)
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
}

# NAT Stuff

# Elastic IP for NAT
resource "aws_eip" "nat" {
  vpc   = true
  count = 2
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
  count         = length(var.public_subnets)
  depends_on    = [aws_internet_gateway.gw]
}

# Routing

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app-vpc.id
  count  = length(var.public_subnets)
  tags = {
    "Name" = "Route Table for Public Subnet ${count.index}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app-vpc.id
  count  = length(var.private_subnets)
  tags = {
    "Name" = "Route Table for Private Subnet ${count.index}"
  }
}

# Routing Table Association
resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public[count.index].id
  count          = length(var.public_subnets)
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private[count.index].id
  count          = length(var.private_subnets)
  route_table_id = aws_route_table.private[count.index].id
}

# Creating the Network Routes
resource "aws_route" "public_igw" {
  count                  = length(var.public_subnets)
  gateway_id             = aws_internet_gateway.gw.id
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_ngw" {
  count                  = length(var.private_subnets)
  nat_gateway_id         = aws_nat_gateway.ngw[count.index].id
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_security_group" "https" {
  name        = "Incoming HTTP"
  description = "HTTP and HTTPS traffic for ${var.environment} environment of ${var.application_name}"
  vpc_id      = aws_vpc.app-vpc.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound TCP Connections to Jenkins Master"
    from_port   = 8080
    protocol    = "TCP"
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jenkins" {
  name        = "Jenkins Master"
  description = "Allows traffic to Jenkins Master."
  vpc_id      = aws_vpc.app-vpc.id
  # HTTP Alternative
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "TCP"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.https.id]
  }
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jenkins_agent" {
  name        = "Jenkins Agents"
  description = "Allows traffic to Jenkins Agents."
  vpc_id      = aws_vpc.app-vpc.id

  # Allow Incoming Traffic on JLNP Port -> 50000
  ingress {
    description = "Allows JLNP Traffic"
    from_port   = 50000
    protocol    = "tcp"
    self        = true
    to_port     = 50000
  }

  tags = {
    "Environment" = var.environment
    "Application" = var.application_name
  }
}

resource "aws_security_group" "outbound" {
  name        = "Outbound Traffic"
  description = "Allow any outbound traffic for ${var.environment} environment of ${var.application_name}"
  vpc_id      = aws_vpc.app-vpc.id

  # Any Outbound connections allowing
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DNS Resolution for local zone
resource "aws_service_discovery_private_dns_namespace" "jenkins_zone" {
  name        = "jenkins.local"
  description = "DNS Resolution for ${var.application_name}: ${var.environment} environment"
  vpc         = aws_vpc.app-vpc.id
}

# Load Balancer
resource "aws_lb_target_group" "jenkins" {
  name                 = "Jenkins"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.app-vpc.id
  deregistration_delay = 10

  health_check {
    enabled = true
    path    = "/login"
    port    = "8080"
  }

  depends_on = [aws_alb.jenkins]
}

resource "aws_alb" "jenkins" {
  name               = "Jenkins"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public[0].id,
    aws_subnet.public[1].id,
  ]

  security_groups = [
    aws_security_group.https.id,
  ]
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_alb_listener" "jenkins_listener" {
  load_balancer_arn = aws_alb.jenkins.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

resource "aws_security_group" "jenkins_agent" {
  name        = "Jenkins Agents"
  description = "Allows traffic to Jenkins Agents."
  vpc_id      = aws_vpc.jenkins-vpc.id

  # Allow Incoming Traffic on JLNP Port -> TCP 50000
  ingress {
    description = "Allows JLNP Traffic"
    from_port   = 50000
    protocol    = "tcp"
    self        = true
    to_port     = 50000
  }

  # Add Tags to the security group, coming from variables.tf
  tags = {
    "Environment" = var.environment
    "Application" = var.application_name
  }
}
```

As you can see this file contains a lot of information, what is created by Terraform if you apply the configuration. Long story short:

- create a new VPC, new public and private subets (according to the variables) and assign them routing tables
- assign Elastic IPs to the NAT gateways
- create security groups for incoming and outgoing traffic
- create a DNS service for name resolution
- start an ELB with listener within the two public subnets with a healthcheck

Now there are still some files missing like the Jenkins master file.

### Jenkins Master

The Jenkins master controls every action done by the agents. If any task needs to be scheduled, the master will start a new ECS container agent. The master is configured like this:

```terraform
# The task definition the Jenkins Master Container
resource "aws_ecs_task_definition" "jenkins_master" {
  family = "JenkinsThesisAwsDev"

  container_definitions = <<EOF
[
    {
        "name": "jenkins_master",
        "image": "falconone/jenkins_thesis:latest",
        "portMappings": [
            {
                "containerPort": 8080,
                "hostPort": 8080
            },
            {
                "containerPort": 50000,
                "hostPort": 50000
            }
        ],
        "environment": [
            {
                "name": "EXECUTION_ROLE_ARN",
                "value": "${aws_iam_role.JenkinsThesisAwsDev-task-execution-role.arn}"
            },
            {
                "name": "SECURITY_GROUP_IDS",
                "value": "${aws_security_group.jenkins_agent.id},${aws_security_group.outbound.id},${aws_security_group.efs_jenkins_security_group.id}"
            },
            {
                "name": "AWS_REGION_NAME",
                "value": "${data.aws_region.current.name}"
            },
            {
                "name": "ECS_CLUSTER_NAME",
                "value": "${aws_ecs_cluster.JenkinsThesisAwsDev.name}"
            },
            {
                "name": "JENKINS_URL",
                "value": "http://${aws_service_discovery_service.jenkins_master.name}.${aws_service_discovery_private_dns_namespace.jenkins_zone.name}:8080"
            },
            {
                "name": "LOG_GROUP_NAME",
                "value": "/ecs/${var.application_name}"
            },
            {
                "name": "IMAGE_NAME",
                "value": "falconone/jenkins-flutter:latest"
            },
            {
                "name": "LOCAL_JENKINS_URL",
                "value": ""
            },
            {
                "name": "SUBNETS",
                "value": "${aws_subnet.public.id}"
            },
            {
                "name": "CPU_AMOUNT",
                "value": "${var.agent_cpu_amount}"
            },
            {
                "name": "MEMORY_AMOUNT",
                "value": "${var.agent_memory_amount}"
            },
            {
                "name": "PLATFORM_VERSION",
                "value": "1.4.0"
            },
            {
                "name": "BUCKET_NAME",
                "value": "${var.s3_artifact_bucket_name}"
            },
            {
                "name": "S3_FOLDER_PREFIX",
                "value": "${var.s3_folder_prefix_name}"
            },
            {
                "name": "JENKINS_ADMIN_USERNAME",
                "value": "${var.jenkins_accountname}"
            },
            {
                "name": "JENKINS_ADMIN_PASSWORD",
                "value": "${random_string.jenkins_pass.result}"
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-region": "eu-central-1",
                "awslogs-group": "/ecs/${var.application_name}",
                "awslogs-stream-prefix": "ecs"
            }
        }
    }
]
EOF
  # See here: https://stackoverflow.com/a/49947471
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
  execution_role_arn = aws_iam_role.JenkinsThesisAwsDev-task-execution-role.arn
  task_role_arn      = aws_iam_role.JenkinsThesisAwsDev-task-execution-role.arn

  # Memory and CPU values for Jenkins Master, can be adjusted in variables.tf
  cpu                      = var.master_memory_amount
  memory                   = var.master_cpu_amount
  requires_compatibilities = ["FARGATE"]

  # requirement for AWS ECS Fargate containers
  network_mode = "awsvpc"

  depends_on = [aws_efs_mount_target.jenkins_master_home]

  # Storage options for jenkins_home
  volume {
    name = "service-storage"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.jenkins_master_home.id
      root_directory          = "/var/jenkins_home"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.jenkins_master_home.id
        # Necessary for other resources like S3, EFS or AWS SSM!
        iam = "ENABLED"
      }
    }
  }
}

# DNS Resolution for Jenkins Master
resource "aws_service_discovery_service" "jenkins_master" {
  name = "master"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.jenkins_zone.id

    dns_records {
      ttl  = 60
      type = "A"
    }
    dns_records {
      ttl  = 60
      type = "SRV"
    }
    routing_policy = "MULTIVALUE"
  }
}
```

### Creating the storage with Terraform

There is also the `storage.tf` file, which creates all storage related stuff, like the S3 bucket or an EFS access point to mount storage inside the agents:

```terraform
resource "aws_security_group" "efs_jenkins_security_group" {
  name        = "efs_access"
  description = "Allows efs access from jenkins master to efs storage on port 2049 for ${var.environment} environment."
  vpc_id      = aws_vpc.jenkins-vpc.id

  #   EFS default port
  ingress {
    description = "EFS access"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    # security_groups = [aws_security_group.efs_jenkins_security_group.id]
    # Self is required to allow access for this group on EFS storage
    self = "true"
  }
}

# Create the EFS Storage
resource "aws_efs_file_system" "jenkins_master_home" {
  creation_token = "jenkins_master"

  tags = {
    Name        = "jenkins_master"
    environment = var.environment
  }
}

# Create the EFS Mount Target
resource "aws_efs_mount_target" "jenkins_master_home" {
  file_system_id  = aws_efs_file_system.jenkins_master_home.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs_jenkins_security_group.id]
}

resource "aws_efs_access_point" "jenkins_master_home" {
  file_system_id = aws_efs_file_system.jenkins_master_home.id
  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/jenkins-home"

    # Create the path with this rights, if it does not exist.
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 755
    }
  }
}

# S3 Bucket for Artifact Storage
resource "aws_s3_bucket" "jenkins_artifact_storage" {
  bucket = var.s3_artifact_bucket_name
  acl    = "private"

  tags = {
    Name        = var.s3_artifact_bucket_name
    Environment = var.environment
  }
}

```

### Necessary policies

As the master starts an agent if necessary, the master needs the right to run new ECS containers. This and even more is configured inside the `iam.tf` file.

```terraform
resource "aws_iam_role" "JenkinsThesisAwsDev-task-execution-role" {
  name               = "${var.application_name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-task-assume-role.json
}

data "aws_iam_policy_document" "ecs-task-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs-task-execution-role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach the above policy to the execution role.
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-default" {
  role       = aws_iam_role.JenkinsThesisAwsDev-task-execution-role.name
  policy_arn = data.aws_iam_policy.ecs-task-execution-role.arn
}


# Attach the required permissions to the Jenkins Task
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-jenkins" {
  role       = aws_iam_role.JenkinsThesisAwsDev-task-execution-role.name
  policy_arn = aws_iam_policy.jenkins_agents.arn
}

# Data Policy for Jenkins Master to start new Jenkins Agents
# https://stackoverflow.com/questions/62831874/terrafrom-aws-iam-policy-document-condition-correct-syntax
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document#condition
data "aws_iam_policy_document" "jenkins_master" {
  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:ListClusters",
      "ecs:DescribeContainerInstances",
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition",
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  # Listing of Container Instances
  statement {
    actions   = ["ecs:ListContainerInstances"]
    effect    = "Allow"
    resources = [aws_ecs_cluster.JenkinsThesisAwsDev.arn]
  }
  # Run Tasks in ECS
  statement {
    actions   = ["ecs:RunTask"]
    effect    = "Allow"
    resources = ["arn:aws:ecs:${data.aws_region.current.name}:526531137161:task-definition/*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values = [
        aws_ecs_cluster.JenkinsThesisAwsDev.arn
      ]
    }
  }

  statement {
    actions = ["ecs:StopTask"]
    effect  = "Allow"
    resources = [
      "arn:aws:ecs:*:*:task/*",
      "arn:aws:ecs:${data.aws_region.current.name}:526531137161:task/*"
    ]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values = [
        aws_ecs_cluster.JenkinsThesisAwsDev.arn
      ]
    }
  }
  statement {
    actions = ["ecs:DescribeTasks"]
    effect  = "Allow"
    resources = [
      "arn:aws:ecs:*:*:task/*",
      "arn:aws:ecs:${data.aws_region.current.name}:526531137161:task/*"
    ]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values = [
        aws_ecs_cluster.JenkinsThesisAwsDev.arn
      ]
    }
  }

  statement {
    actions   = ["iam:GetRole", "iam:PassRole"]
    effect    = "Allow"
    resources = [aws_iam_role.JenkinsThesisAwsDev-task-execution-role.arn]
  }

  # S3 Bucket Related policys for storing build artifacts
  statement {
    actions = [
      "s3:ListBucket"
    ]
    effect    = "Allow"
    sid       = "AllowListingOfFolder"
    resources = [aws_s3_bucket.jenkins_artifact_storage.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.s3_folder_prefix_name}/*"]
    }
  }

  # Allow the listing of bucket locations.
  statement {
    actions = [
      "s3:GetBucketLocation"
    ]
    effect    = "Allow"
    sid       = "AllowListingOfBuckets"
    resources = [aws_s3_bucket.jenkins_artifact_storage.arn]
  }

  statement {
    sid    = "AllowS3ActionsInFolder"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = ["${aws_s3_bucket.jenkins_artifact_storage.arn}/${var.s3_folder_prefix_name}/*"]
  }

}

# Policy for Jenkins Master to start new Jenkins Agents
# https://stackoverflow.com/questions/62831874/terrafrom-aws-iam-policy-document-condition-correct-syntax
resource "aws_iam_policy" "jenkins_agents" {

  description = "Allows the Jenkins master to start new agents."
  name        = "${var.application_name}_ecs_policy"

  # Policy
  # Hint: Curly braces may not be indented otherwise Terraform fails
  policy = data.aws_iam_policy_document.jenkins_master.json
}
```

## Conclusion

With everything of the files listed above the necessary AWS infrastructure is created within a few minutes. No need to click or anything else, you just have to run a `terraform apply` from the commandline. As it's hard to get all the code inside this document, I created a [new repository on Github](https://github.com/pgrunm/aws_jenkins_flutter), where I'll upload all the required code.

The cool thing about all the stuff above is, it created everthing and from now on we only have to worry about the container setup. The container setup I'm going to cover in part 2 of the series.

If you have any questions, do not hesitate to contact me! I hope you enjoyed reading this post and we will see each other in part 2, where we talk about how to configure the Jenkins master and agent.

See more in [part 2 of the series](/posts/infrastructure_flutter_part2).
