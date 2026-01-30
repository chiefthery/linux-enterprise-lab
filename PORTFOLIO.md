# Portfolio — Infra Reliability Lab

This repo documents enterprise-style infrastructure work focused on identity, core Linux dependencies, security hardening, observability, and recovery.

## Best starting points
- Architecture:
  - architecture/vm-topology.md
  - architecture/week2-public-private-vpc.md
  - architecture/week3-observability.md

- Labs:
  - labs/00-index.md
  - labs/week2-end-to-end.md
  - labs/lab-week3-observability.md

- Troubleshooting (real incident writeups):
  - troubleshooting/week2-ntp-dns-bootstrap-failure.md
  - troubleshooting/week2-ssh-proxyjump-key-selection.md
  - troubleshooting/chrony-unsynced.md

## What this proves
- Multi-host systems thinking (dependencies: DNS/NTP/identity/SSH/sudo)
- Secure access patterns (bastion, private subnets, least privilege)
- Observability: metrics + alerting + automation (self-heal)
- Failure-driven learning: reproduce → break → debug → harden → document

