# Week 2 — Public + Private VPC (Enterprise Upgrade)

## Goal

Move from “a server” to “a network” by building a real-world AWS VPC layout:
- Public subnet: bastion + NAT Gateway
- Private subnet: app instance (no public IP)
- Internet ingress: only to bastion (SSH from my IP)
- Private access: SSH to app only via bastion security group
- Private egress: app reaches internet via NAT (outbound only)

---

## Architecture (traffic story)

Admins:
Internet → Bastion (public subnet) → SSH → App (private subnet)

Outbound updates:
App (private) → NAT Gateway (public) → IGW → Internet

---

## What Terraform builds

- VPC (+ DNS hostnames/support)
- 1 public subnet + 1 private subnet (single AZ for simplicity; expand to multi-AZ later)
- Internet Gateway
- Public route table: `0.0.0.0/0 → IGW`
- NAT Gateway (public subnet + EIP)
- Private route table: `0.0.0.0/0 → NAT`
- Security groups:
  - Bastion: SSH only from `my_ip_cidr`

  - App: SSH only from bastion SG
- EC2:
  - Bastion (public IP)
  - App (private IP only)

---

## How to run

```
terraform fmt
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

## SSH into the private instance

Use ProxyJump:

`ssh -i <PATH_TO_KEY> -J ec2-user@<BASTION_PUBLIC_IP> ec2-user@<APP_PRIVATE_IP>`

### Note (See Troubleshooting)

If SSH to bastion works but ProxyJump doesn't:

1) Add identity files to .ssh/config

```
Host <NAME_FOR_BASTION>
  HostName <BASTION_PUBLIC_IP>
  User ec2-user
  IdentityFile <PATH_TO_KEY>
  IdentitiesOnly yes

Host <NAME_FOR_APP>
  HostName <APP_PRIVATE_IP>
  User ec2-user
  IdentityFile <PATH_TO_KEY>
  IdentitiesOnly yes
  ProxyJump <NAME_FOR_BASTION>
```

2) Edit permissions

`chmod 600 ~/.ssh/config`

3) SSH again

`ssh <NAME_FOR_APP>`

---

## Clean up (avoid NAT costs)

`terraform destroy -var-file=terraform.tfvars`

