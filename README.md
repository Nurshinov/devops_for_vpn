# Connect schema

```text
Unchanged client config
  -> Moscow nginx UDP/11999
  -> Hans IPv4-over-ICMP tunnel (10.254.0.2 -> 10.254.0.1)
  -> Helsinki OpenVPN UDP/11999
  -> Internet
```


# Usage 

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ansible-playbook install_icmp_tunnel.yml -i inventory
ansible-playbook install_openvpn.yml -i inventory
ansible-playbook install_nginx.yml -i inventory
ansible-playbook install_monitoring.yml -i inventory
```

The external firewall attached to the Hetzner server must allow inbound ICMP
from the Moscow proxy (`188.120.226.48/32`). The client continues to use
`188.120.226.48:11999/udp`; UDP/11999 does not need to pass directly between
Moscow and Helsinki.

The first ICMP tunnel deployment generates `/etc/hans-tunnel.env` on Helsinki
and synchronizes it to Moscow with mode `0600`. Later deployments reuse the
secret already stored on Helsinki, so no CI secret is required.

VictoriaMetrics and the Grafana backend listen on localhost only. Grafana is
published by nginx with an automatically renewed Let's Encrypt certificate:

```bash
https://grafana.157-180-39-82.sslip.io/
```

The Hetzner Cloud Firewall only needs public TCP/80 and TCP/443 for this route.
Keep Grafana port 3000 and VictoriaMetrics port 8428 private.
