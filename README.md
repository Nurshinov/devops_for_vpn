# OpenVPN UDP through Cloudflare

## Active topology

```text
Existing OpenVPN clients
  -> 188.120.226.48:11999/UDP in Moscow
  -> GOST UDP-to-Relay frontend
  -> cloudflared access tcp on 127.0.0.1:12001
  -> Cloudflare transport for nurshinov-vpn.com
  -> named Cloudflare Tunnel in Helsinki
  -> GOST Relay-to-UDP backend on 127.0.0.1:12000/TCP
  -> OpenVPN on 127.0.0.1:11999/UDP (10.0.0.0/24)
  -> Internet through 157.180.39.82
```

The public client endpoint and `config.ovpn` remain unchanged. GOST preserves
the UDP sessions while the Moscow-to-Helsinki leg is transported through the
Cloudflare TCP/WebSocket path. Hans is not installed or used.

In Cloudflare Zero Trust, the published application route for
`nurshinov-vpn.com` remains service type `TCP` with URL `localhost:12000`.

## Deployment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

ansible-playbook install_cloudflare_transport.yml -i inventory --vault-password-file .vault
ansible-playbook install_monitoring.yml -i inventory
```

The tunnel token is encrypted in `vars/cloudflare_vault.yml`. The local Vault
password file `.vault` must remain mode `0600`.

## Client

Use the existing `config.ovpn` with:

```text
proto udp
remote 188.120.226.48 11999
```

The expected public IPv4 after connection is `157.180.39.82`.

## Verification

On Moscow:

```bash
systemctl is-active gost-cloudflare-frontend cloudflared-access-tcp
ss -lunp | grep 11999
ss -lntp | grep 12001
```

On Helsinki:

```bash
systemctl is-active cloudflared-tunnel gost-cloudflare-backend openvpn-server@server-cf openvpn-cf-iptables
ss -lntp | grep 12000
ss -lunp | grep 11999
iptables -t nat -S POSTROUTING | grep 10.0.0.0/24
```

## Monitoring

VictoriaMetrics, Grafana, and node_exporter run in Helsinki. Grafana remains
available at `https://grafana.157-180-39-82.sslip.io/`.
