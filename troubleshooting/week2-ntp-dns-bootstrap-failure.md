# Debugging Chrony Silent Failure Due to DNS Bootstrap Issues

## Overview

During Week 2 infrastructure labs, the vm4 management node experienced persistent NTP
synchronization failures despite correct chrony configuration and network connectivity. Chronyd appeared to run normally but never registered any time sources. No errors were logged.

This document describes the investigation process, root cause, and resolution.

---

## Environment

- Platform: AWS EC2 (Amazon Linux / Rocky Linux)
- Role: Management / Ansible Control Node (vm4)
- NTP Service: chrony
- Upstream Servers:
  - ipa.lab.local
  - infra1.lab.local
- Network: Private subnet via NAT + Bastion

---

## Problem Statement

The system clock failed to synchronize. Observed behavior:

- `chronyd` service running
- No time sources registered
- System clock drifting
- No visible errors

Example:

```
systemctl status chronyd
chronyc sources
chronyc tracking
```

Output showed no active sources.

---

## Initial Symptoms

Manual debugging showed:

`sudo /usr/sbin/chronyd -d -f /etc/chrony.conf`

Output:
- Service started
- Drift file loaded
- No "Added source" messages

This indicated that chrony was not activating any configured servers.

---

## Investigation Process

**1. Verify Configuration Parsing**

`chronyd -d -f /etc/chrony.conf -p`

Result:

```
server ipa.lab.local iburst prefer
server infra1.lab.local iburst
```

Confirmed that the configuration file was being parsed correctly.

**2. Check Name Resolution**

`getent hosts ipa.lab.local`

`getent hosts infra1.lab.local`

Result:
No output.

This showed that the system could not resolve internal hostnames.

**3. Verify DNS Configuration**

`cat /etc/resolv.conf`

Result:

```
nameserver 1.1.1.1
nameserver 8.8.8.8
```

The system was using public DNS resolvers, which cannot resolve .lab.local domains.

**4. Eliminate DNS as a Variable**

`sudo /usr/sbin/chronyd -d 'server 129.6.15.28 iburst'`

Result:

```
Selected source 129.6.15.28
System clock wrong by XXXX seconds
```

This confirmed that:
- Network connectivity was functional
- Chrony was working correctly
- DNS resolution was the failure point

---

## Root Cause

Chrony uses asynchronous DNS resolution. When hostname resolution fails, chronyd:
- Does not log an error
- Does not timeout
- Does not register sources
- Continues running silently

Because vm4 was configured with public DNS servers, it could not resolve internal
`.lab.local` hostnames. As a result, chronyd never activated its upstream sources.

## Resolution

### Option 1 — Static Host Mapping (Applied)

`sudo nano /etc/hosts`

Add:

```
10.x.x.x ipa.lab.local
10.x.x.y infra1.lab.local
```

Then restart:

`sudo systemctl restart chronyd`

### Option 2 — Use IP Addresses in chrony.conf

```
server 10.x.x.x iburst prefer
server 10.x.x.y iburst
```
Removes DNS dependency during bootstrap.

### Option 3 — Configure Internal DNS

Update DHCP / NetworkManager to use internal resolvers:

```
nameserver <internal-dns-ip>
search lab.local
```

---

## Validation

After applying the fix:

```
chronyc sources -v
chronyc tracking
timedatectl
```

Expected:
- Reachable sources
- Valid stratum
- Stable offset

---

## Lessons Learned

1. NTP depends on DNS during startup.
2. Bootstrap ordering matters.
3. Chrony fails silently on DNS resolution issues.
4. Public resolvers cannot resolve internal domains.
5. IP-based NTP is safer during early boot.

Time synchronization should be treated as critical infrastructure.

---

## Best Practices Going Forward

- Use IP-based NTP during bootstrap
- Switch to DNS after internal resolution is stable
- Always allow stepping on fresh installs
- Monitor chrony status
- Document time dependencies

---

## Related Topics
- DNS bootstrapping
- Kerberos time sensitivity
- TLS certificate validation
- Distributed system clock skew
