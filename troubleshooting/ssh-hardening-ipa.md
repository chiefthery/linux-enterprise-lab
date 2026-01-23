# Incident: SSH Key Authentication Blocked by Misconfigured AllowGroups (FreeIPA / OpenSSH Hardening)

## Summary

After hardening SSH to enforce key-only authentication and group-based access controls, legitimate users were unable to log in. Access failures were caused by referencing local Unix groups in `sshd_config` that had not been created in FreeIPA.

This resulted in all non-root users being denied SSH access.

---

## Expected behavior:

- Users authenticate using SSH keys
- User identity and groups resolved via FreeIPA/SSSD
- `AllowGroups` permits authorized users
- Login succeeds

`Authentication succeeded (publickey).`

---

## Symptoms Observed

- SSH connections were rejected after key authentication
- Users received access denied errors
- Password authentication was disabled
- No fallback authentication was available

Example:

`Permission denied (publickey).`

Or immediate disconnect after key acceptance.

---

## Evidence (sanitized)

Client-side debug output:

`ssh -vvv user@host`

Showed:
- Public key accepted
- Authentication halted during authorization phase

Server logs:

`journalctl -u sshd`

Example:

`User user not allowed because none of user's groups are listed in AllowGroups`

Group resolution:

`id user`

Showed:
User not a member of any permitted groups

---

## Initial Assumptions (Incorrect)

Initial hypotheses included:

- SSH key misconfiguration
- Incorrect file permissions
- SSSD authentication failure
- SELinux interference

The access policy itself was assumed to be correct.

---

## Investigation

1) SSH Access Controls

Reviewed sshd_config:

`AllowGroups lab-admins ssh-users`

Confirmed password auth was disabled:

`PasswordAuthentication no`

2) Group Resolution

Checked group membership:

`id user`
`getent group lab-admins`

Returned no results for expected groups.

3) FreeIPA Directory

Verified group existence:

`ipa group-find`
`ipa group-show lab-admins`

Confirmed groups had not been created in IPA.

4) SSSD Verification

Validated identity integration:

`sssctl user-checks user`

Confirmed SSSD was functioning correctly.

5) Recovery Access

Maintained root/console access to prevent lockout while debugging.

---

## Root Cause

SSH access controls were enforced using `AllowGroups`, but the referenced groups existed only conceptually and had not been created in FreeIPA.

Because SSSD could not resolve these groups:

- Users were not recognized as authorized
- sshd denied access
- No password fallback existed

This created a full access lockout for standard users.

---

## Fix

1) Create Groups in FreeIPA

`ipa group-add lab-admins`
`ipa group-add ssh-users`

2) Add Users to Groups

`ipa group-add-member lab-admins --users=user`

3) Refresh SSSD Cache

`sss_cache -E`
`systemctl restart sssd`

4) Validate Resolution

`getent group lab-admins`
`id user`

5) Test SSH Access

`ssh user@host`

Result:

`Authentication succeeded (publickey).`

---

## Lessons Learned

- Identity objects must exist before policy enforcement
- Access controls depend on directory services
- Security hardening must follow IAM setup
- Misconfigured AllowGroups can cause full lockout
- Centralized identity requires coordinated changes
- Always preserve emergency access paths

---

## Prevention

To prevent recurrence:

- Create IPA groups before referencing them in sshd
- Validate group resolution before deploying policies
- Use Ansible pre-checks for IAM dependencies
- Test hardening in staging environments
- Maintain documented rollback procedures
- Implement automated access validation

Example check:

`getent group lab-admins || exit 1`
