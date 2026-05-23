# OpenVPN role

This role installs and configures OpenVPN server.

Supported OS:
- Ubuntu 22.04
- Ubuntu 24.04

# Usage
```yaml
- hosts: hetzner
  become: true
  roles:
    - openvpn
```