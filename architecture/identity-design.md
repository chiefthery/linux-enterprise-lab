# Identity Design (FreeIPA)

## Purpose

FreeIPA is the central identity authority for the lab. It provides:
- **Single source of truth** for users/groups
- **Kerberos-based SSO** (where applicable)
- **SSSD-backed identity + authorization** on Linux hosts
- Policy control for:
    - SSH access (via groups / HBAC)
    - Sudo access (via sudo rules)
    - Optional: host-based access, service principals, keytabs

This mirrors an enterprise pattern: **IdP (IPA/AD) → enrolled hosts → centrally-managed access.**

---

## Components and Responsibilities

IPA Server (identity node)
- Stores and serves:
    - Users, groups
    - Hosts and host groups
    - HBAC rules (who can log into what)
    - Sudo rules (who can elevate where)
    - Kerberos realm + KDC (tickets)
    - Certificate authority (if you enable it)

IPA Client (enrolled hosts)
- Runs:
    - `sssd` (identity/authz cache + NSS/PAM integration)
    - `krb5` client (Kerberos tickets)
    - `oddjobd` / `pam_mkhomedir` (optional: auto-create local home directories on first login)
    - Uses IPA as the upstream identity provider

---

## Enrollment Flow (Host Join)

**Goal:** A new Linux host becomes “known” to IPA and can authenticate users centrally.

High-level flow
1) Prereqs on the host
    - Correct hostname / FQDN
    - DNS resolution works both ways (forward + reverse if possible)
    - Time sync (chrony/NTP) — Kerberos is time-sensitive
2) Enroll
    - `ipa-client-install` joins the host to the realm
    - Creates the host entry in IPA (or uses a pre-created one)
    - Configures SSSD + Kerberos + PAM
3) Validate
    - Confirm the host appears in IPA
    - Confirm SSSD can resolve users and groups
    - Confirm login + sudo policies apply as expected

**Why this matters:** This is your “gold image → join to identity → policies apply” enterprise loop.

---

## Authentication Path (SSSD + Kerberos)

When a domain user logs in (SSH/console), the path is:
1) User attempts login on a client host
2) PAM hands auth to SSSD
3) SSSD talks to IPA:
    - Identity lookup (user, group membership)
    - Auth:
        - Often Kerberos (preferred)
        - Can fall back to other mechanisms depending config
4) If allowed, user session starts
5) SSSD caches identity/auth data locally (offline-friendly)

Key concept:
- Kerberos proves who you are (authentication)
- HBAC/groups/sudo rules decide what you can do (authorization)

---

## Authorization Model (How Access Is Controlled)

1) SSH / Login Control

You should treat “can the user log in?” as policy, not a local config hack.

**Recommended approach (enterprise-like):**
- Use IPA groups to represent access intent:
    - `ssh-login`
    - `ssh-admins`

- Optionally enforce via:
    - HBAC rules in IPA (best)
    - and/or `sshd_config` `AllowGroups` (works, but must reference groups that actually exist in IPA)

2) Sudo / Privilege Control
Use IPA sudo rules rather than local /etc/sudoers edits.

Pattern:
- IPA group: `lab-admins`
- Sudo rule: allow `lab-admins` to run sudo on approved hosts (or all lab hosts)
- Optional: restrict commands (later), require tty, logging defaults, etc.

---

## SSH Public Key Strategy (Important)

You have two options—document the one you’re using.

Option A (centralized keys via IPA + SSSD)
- Store user public keys in IPA
- On clients, SSH pulls keys from SSSD:
    - `AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys`
- Benefit: keys are managed centrally like enterprise

Option B (local keys in `~/.ssh/authorized_keys`)
- Simple but not centralized (less “enterprise”)

**Reality check:**
If you use Option A, then:
- Users don’t need local authorized_keys on every host
- Group membership + HBAC become the “real” access control plane

---

## Operational Standards (Lab Rules)

- **No local users for humans on servers** (except break-glass if you choose)
- All access is via:
    - IPA user + IPA group + (HBAC/sudo rule)
- Every new host must:
    1) Have working DNS + time sync
    2) Enroll via `ipa-client-install`
    3) Pass verification checklist (below)

---

## Verification Checklist (Quick Tests)

On an enrolled client host, confirm:
- Identity resolution:
    - `id <user>`
    - `getent passwd <user>`
- SSSD health:
    - `systemctl status sssd`
    - `sssctl domain-status`
- Kerberos:
    - `kinit <user>` then `klist`
- SSH key retrieval (if using centralized keys):
    - `/usr/bin/sss_ssh_authorizedkeys <user>`
- Sudo policy:
    - `sudo -l` (as the user)

---

## Known Gotchas (What Breaks Most Often)

- **Time drift** → Kerberos failures
- **DNS misconfig** → enrollment issues, reverse lookup weirdness
- **SSHD AllowGroups** references a group that doesn’t exist in IPA
- SELinux/firewall blocking IPA services (if you tighten too early)
- SSSD cache confusion after changes (needs cache clear/restart occasionally)

---

## Future Enhancements (Roadmap)

- HBAC rules per host group (e.g., “admins can log into infra nodes only”)
- Host groups and role-based access:
    - `infra-nodes`, `workload-nodes`, `automation-nodes`
- Service principals + keytabs for automation (Ansible/Terraform workflows)
- Internal CA + host cert issuance (mTLS groundwork)
