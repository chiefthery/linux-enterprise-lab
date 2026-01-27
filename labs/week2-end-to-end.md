# Week 2 End-to-End Lab: Secure Network + Automation Pipeline

## Overview

This lab demonstrates a complete infrastructure workflow:

1. Provisioning AWS network and compute resources with Terraform
2. Enforcing access controls using a bastion host
3. Accessing private instances through SSH ProxyJump
4. Configuring systems with Ansible
5. Deploying a production-style service (Nginx)
6. Validating system health and connectivity

The objective is to model a realistic enterprise environment where
application servers are isolated in private subnets and managed through
controlled entry points.

---

## Architecture Summary

- VPC with public and private subnets
- Internet Gateway + NAT Gateway
- Bastion host in public subnet
- Application host in private subnet
- SSH restricted to bastion
- Outbound access via NAT
- Centralized configuration via Ansible

---

## Prerequisites

- AWS account and credentials configured
- Terraform >= 1.5
- Ansible installed on control node
- SSH key pair available
- SSH config entries configured for bastion/private hosts

---

## Step 1 — Provision Infrastructure (Terraform)

From the Terraform directory:

```
cd terraform/week2-public-private-vpc
terraform init
terraform plan
terraform apply
```

Verify resources:

```
terraform output
aws ec2 describe-instances
```

Expected:
- Bastion with public IP
- Private app host with private IP
- VPC + subnets + routes created

---

## Step 2 — Validate Bastion Access

Confirm direct access to bastion:

`ssh week2-bastion`

Verify:

```
hostname
ip a
curl https://aws.amazon.com
```

Confirms internet + SSH access.

---

## Step 3 — Access Private Host via ProxyJump

Using SSH config:

`ssh week2-private`

Manual equivalent:

```
ssh -i ~/.ssh/<KEY>.pem \
  -J ec2-user@<BASTION_PUBLIC_IP> \
  ec2-user@<PRIVATE_IP>
```

Verify isolation:

`curl https://google.com`

Should work (via NAT), but direct inbound SSH is blocked.

---

## Step 4 — Run Ansible Baseline Configuration

From Ansible directory:

```
cd ~/linux-enterprise-lab/ansible
ansible -i inventory.ini all -m ping
```

Run baseline playbook:

`ansible-playbook site.yml`

Tasks include:
- Package updates
- User management
- SSH hardening
- Firewall configuration
- NTP configuration
- Security baselines

---

## Step 5 — Deploy Nginx Service

Run deployment role:

`ansible-playbook playbooks/deploy_nginx.yml`

Or via site.yml role inclusion.

Verify service:

```
ssh week2-private
systemctl status nginx
```

---

## Step 6 — Validate Application Access

From bastion:

`curl http://<PRIVATE_IP>`

From private host:

`curl localhost`

Expected:
- Default Nginx page returned
- Service enabled on boot

---

## Step 7 — Validate System Health

### Time Synchronization

```
chronyc tracking
chronyc sources -v
```

### Firewall

`sudo firewall-cmd --list-all`

### Services

`systemctl status sshd nginx chronyd`

---

## Step 8 — Tear Down (Cost Control)

When finished:

```
cd terraform/week2-public-private-vpc
terraform destroy
```
Confirms infrastructure is fully reproducible.

---

## Outcomes

This lab demonstrates:
- Secure cloud network segmentation
- Bastion-based access control
- Infrastructure-as-Code provisioning
- Configuration management automation
- Production-style service deployment
- Operational validation

The environment mirrors real-world cloud platform patterns.

---

## Lessons Learned

1. Private infrastructure requires controlled ingress.
2. Bastions simplify audit and security.
3. SSH config standardizes operator access.
4. Ansible depends on reliable SSH foundations.
5. DNS and NTP are critical dependencies.
6. Automation reduces configuration drift.

---

## Next Steps

- Add monitoring (CloudWatch / Prometheus)
- Introduce ALB
- Add autoscaling group
- Integrate CI/CD
- Implement patch automation
