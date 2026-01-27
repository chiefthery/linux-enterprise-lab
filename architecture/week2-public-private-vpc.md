# Week 2 Architecture: Public + Private VPC with Bastion and NAT

## Overview

This document describes the network and security architecture used in
Week 2 of the Linux Enterprise Lab. The environment models a common enterprise cloud pattern:

- Internet-facing access is restricted to a bastion host
- Application servers reside in private subnets
- Outbound access is provided through a NAT gateway
- All infrastructure is provisioned via Terraform

The design prioritizes isolation, auditability, and least privilege.

---

## High-Level Design

The architecture follows a segmented network model.

```
Internet
     |
[ Internet Gateway ]
     |
[ Public Subnet ]
     |
[ Bastion ] [ NAT Gateway ]
     |
[ Private Subnet ]
     |
[ App / IPA / Infra Hosts ]
```

---

## Core Components

### Virtual Private Cloud (VPC)

- Provides an isolated network boundary
- Defines private IP addressing
- Enables internal routing

Example CIDR:

10.20.0.0/16

### Public Subnet

Purpose:
- Hosts internet-facing resources
- Contains controlled entry points

Resources:
- Bastion host
- NAT Gateway

Characteristics:
- Route to Internet Gateway
- Public IP assignment enabled

### Private Subnet

Purpose:
- Hosts application and infrastructure services
- Prevents direct internet exposure

Resources:
- Application server
- IPA server
- Infrastructure services

Characteristics:
- No direct route to Internet Gateway
- Outbound traffic via NAT only

### Internet Gateway (IGW)

Role:
- Enables inbound and outbound internet connectivity
- Attached at the VPC level

Used only by public subnet routes.

### NAT Gateway

Role:
- Allows private instances to reach the internet
- Blocks inbound connections

Use cases:
- Package updates
- API access
- Certificate validation
- NTP synchronization

### Bastion Host

Role:
- Centralized access point
- Enforces controlled SSH entry

Security benefits:
- Single audit point
- Reduced attack surface
- Easier logging

---

## Routing Design

### Public Route Table

0.0.0.0/0 → IGW

Used by:
- Bastion
- NAT Gateway

### Private Route Table

0.0.0.0/0 → NAT Gateway

Used by:
- Application and infrastructure hosts

---

## Security Group Model

### Bastion Security Group

Inbound:
- SSH (22) from operator IP

Outbound:
- All (or restricted as needed)

### Private Host Security Group

Inbound:
- SSH (22) from Bastion SG only
- HTTP (80) from internal sources

Outbound:
- All via NAT

---

## Access Flow (SSH)

### Operator → Bastion → Private Host

1. Operator connects to bastion
2. Bastion forwards traffic to private host
3. Private host accepts only bastion-originated SSH

Example:

`ssh week2-private`

Enforced via:
- Security groups
- SSH ProxyJump
- SSH config entries

---

## Management and Automation Flow

### Configuration Management

- Ansible runs from vm4/control node
- Uses SSH over bastion
- Applies consistent configuration

Flow:
Ansible → Bastion → Private Hosts

### Infrastructure Provisioning

- Terraform defines all resources
- State tracks dependencies
- Outputs feed automation

Flow:
Terraform → AWS → Ansible

---

## Dependency Relationships

Several services depend on network and name resolution.

| Service | Depends On     |
| ------- | -------------- |
| NTP     | DNS, Routing   |
| Ansible | SSH, Routing   |
| IPA     | Time Sync, DNS |
| TLS     | Time Sync, DNS |

Misconfigurations propagate quickly.

---

## Failure Domains

### Bastion Failure

Impact:
- No administrative access
- App continues running

Mitigation:
- Rebuild via Terraform
- Stateless design

### NAT Failure

Impact:
- No outbound access
- Updates fail
- NTP may degrade

Mitigation:
- Monitoring
- Multi-AZ NAT (future)

---

## Design Rationale

### Why Not Public App Servers?

Public-facing app servers:
- Increase attack surface
- Complicate firewalling
- Require additional monitoring

Private placement enforces zero-trust principles.

### Why Bastion Instead of Direct VPN?

Bastion advantages:
- Simpler setup
- Easier auditing
- Lower cost

VPN may be added later.

### Why NAT Instead of Public IPs?

Public IPs:
- Expose hosts
- Require firewall hardening
- Increase compliance burden

NAT preserves isolation.

---

## Scalability Considerations

Future improvements:
- Auto Scaling Groups
- Load Balancers
- Multiple private subnets
- Multi-AZ NAT
- Private endpoints (VPC endpoints)

---

## Observability Considerations

Recommended additions:
- VPC Flow Logs
- CloudWatch metrics
- Centralized logging
- Bastion audit logs

---

## Lessons Learned

1. Network segmentation simplifies security.
2. Bastions centralize access control.
3. NAT enables controlled outbound access.
4. Automation depends on stable networking.
5. Bootstrap dependencies must be planned.

---

## References

- AWS Well-Architected Framework
- Zero Trust Architecture
- CIS AWS Foundations Benchmark
