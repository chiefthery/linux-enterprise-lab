# Linux Enterprise Lab (Rocky/RHEL-style)

This repo documents an enterprise-style Linux lab designed to practice **identity, DNS/NTP dependencies, security hardening, and automation** across multiple hosts.

It’s written like a runbook: **what I built, how to reproduce it, what broke, and how I fixed it**.

---

## Goals

- Build a realistic multi-host environment (not a single-VM tutorial)
- Practice core sysadmin dependencies: **DNS, time sync, identity, SSH, sudo**
- Layer security controls in a deliberate order (firewall → SSH → auditd → SELinux)
- Apply automation *after* understanding the underlying system behavior

---

## Environment Overview

- Hypervisor: (VMware / cloud)  
- OS family: Rocky Linux 9 / RHEL-like
- Core pattern: “Known-good base OS” → “Enroll to identity” → “Apply config via Ansible”

---

## Architecture

### Host Roles (example)
- `ipa` (Identity): FreeIPA (IdM), DNS (authoritative for lab domain)
- `infra1` (Infra services): supporting services and test workloads
- `client1` (Client): domain-enrolled workload node
- `vm4` (Automation): Ansible control node

### Diagram

```mermaid
flowchart LR
  A["Ansible Control Node (vm4)"]
  B["infra1"]
  C["client1"]
  D["FreeIPA / IdM (ipa)"]

  A -->|SSH + Ansible| B
  A -->|SSH + Ansible| C

  B -->|SSSD / Kerberos| D
  C -->|SSSD / Kerberos| D

  B -->|DNS queries| D
  C -->|DNS queries| D

  B -->|NTP (chrony)| D
  C -->|NTP (chrony)| D```

## How to Use This Repo
1) Read the lab index

See labs/00-index.md for the recommended path and prerequisites.

2) Reproduce the environment (high level)

1. Provision VMs (names + IPs)

2. Configure networking + resolvers

3. Install/configure FreeIPA + DNS

4. Enroll clients (SSSD)

5. Apply baseline hardening

6. Apply Ansible roles for consistency

## Security Hardening (layered)

This lab applies controls in layers so failures are debuggable:

1. firewalld baseline

2. sshd hardening (keys only, no root, explicit allowed groups)

3. auditd + rules (make changes observable)

4. SELinux enforcing (then tune based on audit logs)

5. patch policy (manual cadence + documentation)

See labs/ and troubleshooting/ for details.

## Automation (Ansible)

Ansible contents live under ansible/.

- ansible/playbooks/ – entry playbooks

- ansible/roles/ – reusable roles (common/security/etc.)

- ansible/inventory/ – inventory (sanitized example files will be provided)

## What Broke (and Fixes)

This is intentional: debugging is the point.

- DNS recursion / root hints issues → troubleshooting/dns-root-hints.md

- Chrony time not synced → troubleshooting/chrony-unsynced.md

- SSH key auth still prompting for password → troubleshooting/ssh-auth-gotchas.md

## Roadmap (Next)

- Kickstart-based rebuilds (“nuke & pave” workload node)

- Centralized logging (rsyslog/journald forwarding)

- Vulnerability scanning workflow + remediation notes

- Jenkins/Terraform integration (later phase)

## Disclaimer

This repo is for learning. Sensitive values (real IPs, passwords, private keys, tokens) are excluded or redacted.
