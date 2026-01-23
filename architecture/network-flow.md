# Network Flow


## Purpose

This doc explains how traffic moves through the lab: **who talks to who, why, on what ports, and how to verify it**.  
Goal: make troubleshooting fast and make hardening decisions obvious.

---

## Topology at a glance

**Nodes (roles)**

- **VM1 — identity server**: FreeIPA (IdM), DNS, Kerberos, LDAP, CA
- **VM2 — infra services node**: “boring stable infra” (optional: repos, NFS, web, etc.)
- **VM3 — client/workload node**: domain-enrolled host that runs workloads + users log into
- **VM4 — automation control node**: Ansible control node (push configuration to VM1–VM3)

**Mental model**

- **VM1 is “City Hall”**: identity + certificates + DNS truth
- **VM4 is “Dispatcher”**: it doesn’t serve clients; it pushes changes to servers
- **VM3 is “A building downtown”**: where people actually enter/SSH and run workloads
- **VM2 is “Utilities”**: stable shared services (when needed)

---

## Trust boundaries & assumptions

**Trust boundaries**

- **Admin plane**: VM4 → (VM1/VM2/VM3) via SSH for automation
- **Identity plane**: (VM2/VM3/VM4) ↔ VM1 for auth, DNS, Kerberos, certs
- **App plane**: user/client traffic ↔ VM3 (and VM2 if it hosts services)

**Core assumptions**

- DNS is centralized on **VM1 (IPA DNS)** for the lab domain (e.g., `lab.local`)
- Hosts use **Kerberos/SSSD** for auth after enrollment
- Firewall defaults to **deny-by-default** with explicit allow rules
- SSH is **key-based** (and in enterprise reality, group-based access is enforced)

---

## Critical flows (the “why”)

### A) Name resolution (DNS)
**Who:** VM2/VM3/VM4 → VM1  
**Why:** Everything else depends on clean DNS (Kerberos especially)

- Query type: UDP 53 (and TCP 53 for larger responses / zone transfers)

**Verify**
`dig VM2 @VM1`
- What it does: asks the IPA DNS server directly for the A record.
`getent hosts infra1.lab.local`
- What it does: checks the system’s name service switch path (DNS/SSSD/etc.) the same way apps do.

### B) Time sync (NTP / Chrony)
**Who:** VM2/VM3/VM4 → time source (often VM1 or external)
**Why:** Kerberos breaks if clocks drift (auth “fails” even when credentials are correct)

**Verify**
`chronyc sources -v`
- What it does: shows which NTP sources you’re using and whether sync is healthy.
`timedatectl`
- What it does: confirms local time, NTP status, and sync state.

### C) Identity, auth, and access (SSSD + Kerberos + LDAP)
**Who:** VM3/VM2/VM4 ↔ VM1
**Why:** logins, sudo rules, SSH access, group membership, service tickets

**Core components**
- **LDAP**: identity + group info (directory lookups)
- **Kerberos**: authentication (tickets)
- **SSSD**: the “translator/cache” on clients (talks to IPA, provides identity to Linux)

**Verify**
`ipa user-show <username>`
- What it does: confirms the user exists in IPA (run on the IPA server or from a host with ipa client tools configured).
`id <username>`
- What it does: resolves user + groups through NSS/SSSD (this is what SSH + sudo depend on).
`klist`
- What it does: shows whether you have a valid Kerberos ticket (auth layer).

### D) SSH access (interactive and automation)

**Interactive SSH (humans)**
- Typical flow: laptop → VM3 (workload) OR laptop → VM1 (admin only)
- Identity-backed key retrieval (if configured): VM3 asks SSSD/IPA for keys

**Automation SSH (Ansible)**
- Typical flow: VM4 → VM1/VM2/VM3 over SSH
- VM4 should have a clean, predictable path: DNS works → SSH works → sudo works

**Verify**
`ssh -vvv <user>@VM3
- What it does: verbose SSH handshake; shows which key was offered, what auth method was used, and why it failed.
`sssctl user-checks <username>`
- What it does: checks SSSD health for the user (identity resolution, cache, policy). Great for “why can’t this user log in?” cases.
`/usr/bin/sss_ssh_authorizedkeys <username>`
- What it does: prints the SSH public keys SSSD believes are valid for that user (if you’re using IPA/SSSD to source keys).

### E) Certificate trust (IPA CA)
**Who:** clients trust the IPA CA; services can present certs issued by IPA
**Why:** TLS between internal services, secure LDAP, internal HTTPS, etc.
**Verify**
`trust list | head`
- What it does: shows certificate trust stores and anchors (quick sanity check).`
`openssl s_client -connect <host>:443 -servername <host> </dev/null`
- What it does: inspects a live TLS endpoint and prints the cert chain.

---

## Port map (what must be allowed)

Exact ports can vary by configuration, but these are the usual “make the lab work” flows.

### A) Minimum: IPA server (VM1)

| From        | To  | Protocol | Port | Purpose                                   |
| ----------- | --- | -------- | ---- | ----------------------------------------- |
| VM2/VM3/VM4 | VM1 | TCP/UDP  | 53   | DNS                                       |
| VM2/VM3/VM4 | VM1 | UDP/TCP  | 88   | Kerberos (auth tickets)                   |
| VM2/VM3/VM4 | VM1 | TCP      | 389  | LDAP (directory lookups)                  |
| VM2/VM3/VM4 | VM1 | TCP      | 636  | LDAPS (optional but common)               |
| VM2/VM3/VM4 | VM1 | TCP      | 443  | IPA Web UI / API                          |
| VM2/VM3/VM4 | VM1 | UDP/TCP  | 464  | Kerberos password change (common in IPA)  |
| VM2/VM3/VM4 | VM1 | TCP      | 80   | HTTP redirect / ACME-ish flows (optional) |
| VM4         | VM1 | TCP      | 22   | SSH (admin/automation)                    |
| VM2/VM3/VM4 | VM1 | UDP      | 123  | NTP/Chrony (if VM1 is NTP server)         |

### B) Workload node (VM3)

| From                     | To  | Protocol | Port   | Purpose             |
| ------------------------ | --- | -------- | ------ | ------------------- |
| VM4                      | VM3 | TCP      | 22     | Ansible / admin SSH |
| Your laptop              | VM3 | TCP      | 22     | Interactive SSH     |
| (optional) users/clients | VM3 | TCP      | 80/443 | Hosted apps         |

### C) Infra services node (VM2) (optional)

| From | To  | Protocol | Port    | Purpose                     |
| ---- | --- | -------- | ------- | --------------------------- |
| VM4  | VM2 | TCP      | 22      | Ansible / admin SSH         |
| VM3  | VM2 | TCP/UDP  | depends | NFS, repo mirror, web, etc. |

---

## “If X breaks, what else breaks?” (dependency chain)

- **DNS breaks** → Kerberos breaks → SSH via AllowGroups/SSSD feels “random” → Ansible becomes unreliable
- **Time sync breaks** → Kerberos breaks (even with perfect DNS)
- **SSSD breaks** → id user fails → group-based SSH and sudo rules fail
- **Firewall too strict** → looks like “auth issues” but is really blocked ports
- **IPA CA trust missing** → LDAPS/TLS services fail and look like “cert errors” everywhere

--- 

## Quick health checklist (5-minute triage)

Run these in order:

1) DNS
`getent hosts VM1`
- What it does: confirms the host resolves using system config.

2) Time
`chronyc tracking`
- What it does: confirms the system is actually synced.

3) SSSD
`systemctl status sssd --no-pager`
- What it does: confirms the identity broker is running.

4) Identity resolution
`id <username>`
- What it does: confirms user + groups resolve correctly.

5) SSH
`ssh -vvv <username>@VM3`
- What it does: shows the exact auth path and failure reason.

---

## Hardening philosophy (practical + enterprise-aligned)

Default stance: deny by default, then allow only the flows above.
- VM1 (IPA) is sensitive: expose only required identity ports to enrolled hosts + admin SSH from VM4
- VM3 (workload) is the main entry point: SSH locked down by keys + group policy + minimal open services
- VM4 (Ansible) should be highly trusted: protect keys, restrict outbound to only managed nodes

---

## Notes / lab gotchas

- **AllowGroups + IPA:** if SSH is restricted to groups, those groups must exist in IPA and resolve via SSSD — local groups won’t satisfy domain-based policy.
- **Kerberos is fragile to time drift:** if something “suddenly” fails across the domain, check NTP before anything else.
- **DNS must match hostnames:** mismatched forward/reverse records can create confusing auth behavior.

---

## Diagram (ASCII)

                  (Admin Plane)
                 SSH (22) / Ansible
        +----------------------------------+
        |                                  |
      [VM4] ---------------------------> [VM1]
   Ansible Control                       IPA/DNS/CA
        |                                  ^
        |                                  |
        |                                  | (Identity Plane)
        |                                  | DNS 53, Kerberos 88/464
        v                                  | LDAP 389/636, HTTPS 443
      [VM3] <------------------------------+
  Workload/Client Node
        ^
        |
        | (Human access)
      Laptop
       SSH 22 (and 80/443 if apps)

