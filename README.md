# Connect schema
Moscow Nginx [11999] ---> Amazon VPC [11999] ---> OpenVPN ---> Client


# Usage 

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ansible-playbook install_openvpn.yml -i inventory
```