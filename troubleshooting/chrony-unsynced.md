# Incident: Chrony Not Syncing (Time Drift Causing Auth Failures)

## Summary

Multiple authentication and service issues were traced back to system time drift.
Although chronyd was running, the system clock was **not synchronized**, causing
Kerberos-based authentication and IPA-related operations to fail intermittently.

---

## Symptoms Observed

- `timedatectl` showed:
System clock synchronized: no

- SSH key-based auth behaved inconsistently
- IPA enrollment and sudo rules behaved unexpectedly
- DNS and Kerberos failures appeared unrelated at first

## Evidence (sanitized)

`timedatectl` (before):
```text
System clock synchronized: no
NTP service: active```

`chronyc sources -v` (before):
```text
(no reachable sources selected)```

---

## Initial Assumptions (Incorrect)

- DNS was misconfigured
- SSHD configuration was broken
- IPA/SSSD was malfunctioning

These assumptions delayed root cause identification.

---

## Investigation

1) Checked chrony status:

```bash
systemctl status chronyd

Service was running, but time was not synced.

2) Checked time status:

timedatectl

3) Confirmed:

- NTP service active

- System clock not synchronized

4) Verified chrony sources:

chronyc sources -v


Found no reachable or selected time sources.

## Root Cause

Chrony was configured but not successfully synchronizing with any valid time source.

In an identity-based environment (FreeIPA / Kerberos), even small time drift breaks:

- Ticket validation

- Auth requests

- Sudo policy evaluation

## Fix

1) Ensured correct chrony configuration

2) Verified network reachability to time sources

3) Restarted chronyd:

systemctl restart chronyd

4) Forced sync and verified:

chronyc tracking
timedatectl

Confirmed:

System clock synchronized: yes

## Lessons Learned

- Time is a hard dependency, not a background service

- Identity, DNS, and time form a triangle — if one fails, others behave unpredictably

- Always verify time sync early when debugging auth-related issues

## Prevention

- Validate chrony immediately after OS install

- Confirm sync before enrolling systems into identity domains

- Treat time drift as a first-class incident in authentication failures
