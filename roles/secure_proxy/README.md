# secure_proxy

This role provides an authenticated HTTP CONNECT proxy with Helsinki egress
and a Moscow public entry point:

```text
client -> proxy.nurshinov-vpn.com:8443 (Moscow nginx, public TLS)
       -> re-encrypted stream -> existing Cloudflare TCP transport
       -> Helsinki nginx stream mux -> GOST TLS proxy -> Internet
```

The Moscow host terminates publicly trusted TLS in nginx and immediately
re-encrypts the connection toward Helsinki. Authentication and outbound proxy
connections happen on Helsinki. GOST binds only to localhost there. The
existing Cloudflare hostname and origin port are shared
with OpenVPN; nginx `ssl_preread` sends TLS proxy sessions to GOST and keeps
non-TLS GOST Relay sessions on the OpenVPN path.

Deployment generates a stable random password in the ignored controller file
`.proxy-password`. Certbot automatically renews the public nginx certificate
on Moscow. A separate self-signed certificate pins and verifies the encrypted
nginx-to-GOST connection.

```bash
ansible-playbook install_proxy.yml -i inventory --vault-password-file .vault

curl --proxy "https://vpnproxy:$(cat .proxy-password)@proxy.nurshinov-vpn.com:8443" \
  https://api.ipify.org
```

The expected response is the Helsinki public IP `157.180.39.82`.

The same end-to-end check is available as `scripts/verify-moscow-proxy.sh`.

For software without HTTPS-proxy support, expose a plain proxy on localhost:

```bash
gost -L http://127.0.0.1:8080 \
  -F "https://vpnproxy:$(cat .proxy-password)@proxy.nurshinov-vpn.com:8443?secure=true"
```
