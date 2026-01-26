# Lab: Terraform Week 1 — Spawn Internet-Accessible EC2

## Summary

This lab demonstrates how to use Terraform to provision a minimal, production-style AWS environment consisting of:
- A dedicated VPC
- Public subnet with Internet Gateway
- Route table + association
- Locked-down SSH security group
- Amazon Linux 2023 EC2 instance

The goal is to establish a repeatable “infrastructure baseline” that mirrors how entry-level cloud environments are built in enterprise teams.

This stack is intentionally simple and correct — before introducing private subnets, NAT, and multi-tier architectures in later labs.

## What This Lab Builds

A single internet-reachable EC2 instance managed fully through Terraform.

Architecture:

```
Internet
   |
  IGW
   |
Public Subnet
   |
EC2 (SSH restricted)
```

Components:
- VPC (custom CIDR)
- Internet Gateway
- Public subnet
- Public route table
- SSH security group
- EC2 instance (Amazon Linux 2023)
All resources are tagged using enterprise-style conventions.

## Goal

Establish the full lifecycle:

`terraform apply`

→ verify SSH access
→ consume outputs
→ `terraform destroy`

No manual provisioning. No click-ops. Everything reproducible.

---

## Repo Location
terraform/week1-single-ec2/

Files:
- main.tf
- variables.tf
- outputs.tf
- terraform.tfvars.example

---

## Prerequisites

Before running this lab, you should have:
- AWS credentials configured:

`aws configure`

- Terraform ≥ 1.5 installed
- An existing EC2 key pair in AWS
- Your public IP address (for SSH restriction)

To get your IP:

`curl ifconfig.me`

---

## Terraform Files

### main.tf

Defines:
- Provider and version constraints
- AMI lookup (Amazon Linux 2023)
- VPC + subnet + routing
- Security group
- EC2 instance

Key design choice: AMI is dynamically queried instead of hardcoded. This avoids stale AMI issues and reflects enterprise best practice.

### variables.tf

Centralizes all environment inputs:

| Variable           | Purpose              |
| ------------------ | -------------------- |
| project_name       | Resource name prefix |
| aws_region         | Deployment region    |
| aws_az             | Availability zone    |
| vpc_cidr           | VPC address space    |
| public_subnet_cidr | Subnet range         |
| allowed_ssh_cidr   | Trusted IP           |
| instance_type      | EC2 size             |
| key_name           | SSH key pair         |

No hardcoding inside main.tf. All environment variance lives here.

### outputs.tf

Exports values for downstream automation:
- Public IP
- SSH example command
- Ansible inventory line

This is the “bridge” between Terraform and Ansible.

Infrastructure → Configuration → Hardening.

---

## Variables and tfvars

Create:

terraform.tfvars

Based on:

terraform.tfvars.example

Example:

project_name     = "week1-iac"
allowed_ssh_cidr = "x.x.x.x/32"
key_name         = "my-ec2-key"


**Important:**
- Never commit real tfvars
- Keep secrets local
- Treat tfvars like credentials

Add to .gitignore:

`*.tfvars`

`*.tfstate*`

---

## Enterprise Tagging

All resources use standardized tags:

Owner       = "Name"
Project     = var.project_name
ManagedBy   = "terraform"
Environment = "lab"

**Why this matters:**

In real environments, tags drive:
- Billing
- Access policies
- Auditing
- Asset management
- Compliance reporting

Learning this early = major advantage.

---

## Run the Stack

From:

`terraform/week1-single-ec2/`

Initialize:

`terraform init`

Format:

`terraform fmt`

Validate:

`terraform validate`

Plan:

`terraform plan -var-file=terraform.tfvars`

or just

'terraform plan`

Apply:

`terraform apply -var-file=terraform.tfvars`

or just

`terraform apply`

Confirm with `yes`.

---

## Verify

After apply completes, Terraform prints outputs.

### SSH Access

Example output:

`ssh -i ~/.ssh/mykey.pem ec2-user@18.xxx.xxx.xxx`

Connect:

`ssh -i ~/.ssh/mykey.pem ec2-user@<PUBLIC_IP>`

Successful login confirms:
- Routing works
- IGW works
- Security group works
- Key auth works

### Expected Success State

Inside EC2:

`cat /etc/os-release`

Should show:

Amazon Linux 2023

And:

`ping google.com`

Should resolve and return. This verifies outbound routing.

---

## Outputs for Ansible

Example:

instance_public_ip = "18.xxx.xxx.xxx"

ansible_inventory_line =
"week1 ansible_host=18.xxx.xxx.xxx ansible_user=ec2-user"

Usage:

Copy directly into:

ansible/inventory/hosts

Terraform provisions. Ansible configures. No manual IP copying.

This models real infra pipelines.

---

## Destroy

When finished running the instance:

`terraform destroy -var-file=terraform.tfvars`

Confirm that all resources are removed. No orphaned infra. No cost leaks.

---

## Lessons Learned

### 1. Terraform State Is Critical

State is local by default.

Do NOT commit:

terraform.tfstate
terraform.tfstate.backup

Future labs will introduce remote state (S3 + DynamoDB).

### 2. Variables = Environment Contracts

All environment changes happen through:

terraform.tfvars

Not through editing code. This is how enterprises promote:

dev → staging → prod.

### 3. Outputs Enable Automation

Outputs are APIs. They allow:
- Ansible
- CI pipelines
- Monitoring systems

to consume infrastructure data programmatically. This is foundational DevOps design.

### 4. Minimal ≠ Toy

This stack looks simple, but it includes:
- Proper routing
- CIDR planning
- SSH restriction
- Tag governance
- AMI management
- This is the real baseline.
