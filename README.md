# OpenVPN UDP through Cloudflare

The same Moscow host also provides a separate authenticated HTTPS proxy on
`proxy.nurshinov-vpn.com:8443`. Moscow terminates public TLS and performs TCP
proxying; like the VPN,
proxy traffic exits from Helsinki. See [Proxy through Moscow](#proxy-through-moscow).

## Active topology

```text
Existing OpenVPN clients
  -> 188.120.226.48:11999/UDP in Moscow
  -> GOST UDP-to-Relay frontend
  -> cloudflared access tcp on 127.0.0.1:12001
  -> Cloudflare transport for nurshinov-vpn.com
  -> named Cloudflare Tunnel in Helsinki
  -> nginx stream multiplexer on 127.0.0.1:12000/TCP
  -> GOST Relay-to-UDP backend on 127.0.0.1:12002/TCP
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
ansible-playbook install_benchmark.yml -i inventory
ansible-playbook install_proxy.yml -i inventory --vault-password-file .vault
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
ss -lntp | grep -E '12000|12002'
ss -lunp | grep 11999
iptables -t nat -S POSTROUTING | grep 10.0.0.0/24
```

## Speed benchmark

The managed iperf3 endpoint listens only inside the VPN on
`10.0.0.1:5201`. Connect with the existing OpenVPN profile, install `iperf3`
and `jq` on the client, then run:

```bash
scripts/benchmark-vpn.sh
```

The default benchmark performs three 10-second TCP tests in each direction
with four parallel streams and a two-second warm-up. Results are printed in
both Mbit/s and MB/s and saved under `benchmarks/results/<timestamp>/`.

Shorter smoke test:

```bash
scripts/benchmark-vpn.sh -r 1 -t 3 -P 1
```

## Monitoring

VictoriaMetrics, Grafana, and node_exporter run in Helsinki. Grafana remains
available at `https://grafana.157-180-39-82.sslip.io/`.

## Proxy through Moscow

The proxy uses GOST v3 rather than Squid: it is a smaller component already
used by this repository and supports an authenticated HTTP CONNECT proxy over
TLS. Its public endpoint is nginx TCP/8443 on Moscow. nginx uses a publicly
trusted Let's Encrypt certificate and re-encrypts the stream before passing it
stream through the existing Cloudflare TCP transport to an nginx stream
multiplexer and GOST backend on Helsinki, whose egress address is
`157.180.39.82`. The GOST proxy backend only listens on localhost.

Deploying it creates a stable random password in the ignored local file
`.proxy-password`. Certbot on Moscow manages the public certificate for
`proxy.nurshinov-vpn.com`; a separate pinned certificate protects and verifies
the Moscow-to-Helsinki leg.

```bash
ansible-playbook install_proxy.yml -i inventory --vault-password-file .vault

curl --proxy "https://vpnproxy:$(cat .proxy-password)@proxy.nurshinov-vpn.com:8443" \
  https://api.ipify.org
```

Expected output: `157.180.39.82`. Applications that only support a plain
local HTTP proxy can use the GOST client bridge documented in
`roles/secure_proxy/README.md`.

For a repeatable end-to-end health check, run
`scripts/verify-moscow-proxy.sh`.
