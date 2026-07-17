# Lab 3.6 — Ubuntu Hardening Checklist

Complete after Lab 3.6 in [Chapter 3](../../../docs/part-i-foundations/03-linux.md).

## Server

- **Date hardened:**
- **Hostname:**
- **Ubuntu version:** (`cat /etc/os-release`)
- **Environment:** EC2 / Multipass / WSL2 / other

## Checklist

- [ ] `sudo apt update && sudo apt upgrade` completed
- [ ] SSH key authentication working from laptop
- [ ] `PasswordAuthentication no` in `/etc/ssh/sshd_config`
- [ ] `PermitRootLogin no` in `/etc/ssh/sshd_config`
- [ ] UFW enabled with OpenSSH allowed (skip on WSL if N/A)
- [ ] Baseline tools installed (`curl`, `jq`, `htop`)
- [ ] Verified login from second terminal before closing first

## UFW rules

```
(paste output of: sudo ufw status verbose)
```

## Notes
