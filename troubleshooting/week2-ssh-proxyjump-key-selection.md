# SSH ProxyJump + Key Selection Fix (and Ansible Through Bastion)

## Overview

Week 2 uses a standard enterprise pattern:
- **Bastion host** in a public subnet (has a public IP)
- **Private host(s)** in a private subnet (no public IP)
- Access to private hosts must go **through** the bastion

The end goal was a clean operator workflow:

- SSH: `ssh week2-private`
- Ansible: `ansible -m ping week2_private` (or `ansible-playbook ...`)

This doc captures the debugging process and the final “real fix”:
an SSH config entry that forces the correct identity and ProxyJump.

---

## Architecture Context

- Bastion: public subnet, reachable from the internet (SSH allowed from my IP)
- Private host: private subnet, SSH allowed **only from** the bastion security group

This is why direct access fails (by design).

---

## Symptoms

### SSH symptom

A ProxyJump attempt failed with:

`Permission denied (publickey,gssapi-keyex,gssapi-with-mic).`

Example failing command:

`ssh -i ~/.ssh/<KEY>.pem -J ec2-user@<BASTION_PUBLIC_IP> ec2-user@<PRIVATE_IP>`

### Ansible symptom

Ansible could not reach private hosts when executed from the control node because
SSH authentication through the bastion was not being applied consistently.

Typical failure modes:
- unreachable / timeout
- permission denied (wrong key)
- “it works in SSH but not in Ansible” (different SSH invocation)

---

## Root Cause Patterns (What Was Actually Going Wrong)

1) Two authentications happen with ProxyJump

ProxyJump requires two SSH handshakes:

    1. client → bastion

    2. bastion → private host

If the first hop fails (wrong key/user), the second never happens.

2) Wrong identity selection (agent/default keys)

Even when `-i` is provided, SSH may still offer multiple identities (agent + defaults), and some servers limit attempts — leading to confusing failures.

A reliable control is:

`-o IdentitiesOnly=yes`

3) Inconsistent config between interactive SSH and Ansible

Interactive SSH might succeed because you ran the “long form” command,
while Ansible might fail because it relies on inventory variables or defaults unless you explicitly configure ProxyJump + IdentityFile.

---

## Investigation Steps (Repeatable)

1) Prove the bastion works first

`ssh -i ~/.ssh/<KEY>.pem ec2-user@<BASTION_PUBLIC_IP>`

If this fails, ProxyJump cannot succeed.

2) Use verbose logging to confirm what key is offered

`ssh -vvv -i ~/.ssh/<KEY>.pem ec2-user@<BASTION_PUBLIC_IP>`

Look for `Offering public key:` lines.

3) Confirm security group intent
- Bastion: inbound SSH from my IP
- Private: inbound SSH from bastion SG only

Direct-to-private should fail and that is correct.

---

## The Real Fix: SSH Config Entry (Clean Operator Workflow)

Instead of long commands, define hosts in `~/.ssh/config.d/week2.conf`
(or `~/.ssh/config`).

Example:

```
Host week2-bastion
  HostName <BASTION_PUBLIC_IP>
  User ec2-user
  IdentityFile ~/.ssh/<KEY>.pem
  IdentitiesOnly yes

Host week2-private
  HostName <PRIVATE_IP>
  User ec2-user
  IdentityFile ~/.ssh/<KEY>.pem
  IdentitiesOnly yes
  ProxyJump week2-bastion
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

Then:

`ssh week2-private`

This forces:
- correct username
- correct identity
- correct ProxyJump hop
- stable keepalive behavior

---

## Ansible Fix: Use SSH Common Args (ProxyJump) + Identity

### Option A: inventory.ini with ansible_ssh_common_args

Example:

```
[week2_private]
week2-private ansible_host=<PRIVATE_IP> ansible_user=ec2-user

[week2_private:vars]
ansible_ssh_private_key_file=~/.ssh/<KEY>.pem
ansible_ssh_common_args=-o ProxyJump=ec2-user@<BASTION_PUBLIC_IP> -o IdentitiesOnly=yes
```

Test:

`ansible -i inventory.ini week2_private -m ping`

### Option B (cleaner): rely on SSH config hostnames

If ssh week2-private works, you can point Ansible at the SSH config host alias:

```
[week2_private]
week2-private ansible_user=ec2-user
```

And run:

`ansible -i inventory.ini week2_private -m ping`

Ansible will call SSH, and SSH will apply ProxyJump/Identity automatically.

## Validation

### SSH

`ssh week2-private 'hostname; whoami; ip a'`

### Ansible

```
ansible -i inventory.ini week2_private -m ping
ansible -i inventory.ini week2_private -a "uname -a"
```

---

## Lessons Learned

1. ProxyJump = two handshakes; debug hop #1 first.
2. `IdentitiesOnly=yes` prevents agent/default-key surprises.
3. The best fix is **codifying access** in SSH config.
4. If SSH config is correct, Ansible becomes dramatically simpler.
5. This pattern matches real enterprise “bastion → private subnet” operations.
