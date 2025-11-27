# OpenVPN role

This role installs and configures OpenVPN server.

Supported OS:
- Ubuntu 22.04
- Ubuntu 24.04

# Connect schema
Moscow Nginx ---> Amazon VPC ---> OpenVPN ---> Client

# Usage
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ansible-playbook install_openvpn.yml -i inventory
```