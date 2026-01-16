# Lab Index

This is the recommended order.

## Phase 1 – Foundations
- Networking + resolver behavior
- Storage + permissions basics
- systemd service management

## Phase 2 – Core Enterprise Dependencies
1. DNS (authoritative + client resolver behavior)
2. Time sync (chrony) and why it breaks auth
3. Identity (FreeIPA / SSSD) enrollment and sudo patterns

## Phase 3 – Security Hardening (Layered)
1. firewalld baseline
2. sshd hardening
3. auditd + rules
4. SELinux enforcing + tuning

## Phase 4 – Automation
- Ansible: baseline + security roles
- Drift control and repeatable builds

## Phase 5 – Fast Rebuilds
- Kickstart for workload nodes
- “Gold image → config management” workflow

