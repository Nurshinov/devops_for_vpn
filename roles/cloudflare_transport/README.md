# cloudflare_transport

This role keeps the public OpenVPN endpoint at Moscow UDP/11999 while carrying
the blocked inter-server leg through a Cloudflare named tunnel.

- `frontend`: GOST listens on Moscow UDP/11999 and sends Relay protocol to
  `cloudflared access tcp` on localhost TCP/12001.
- `backend`: GOST accepts the Relay stream on Helsinki localhost TCP/12000 and
  forwards datagrams to OpenVPN on localhost UDP/11999.

The Cloudflare published application must be a `TCP` route for
`nurshinov-vpn.com` pointing to `localhost:12000`. The backend play requires
`cloudflare_tunnel_token`, stored encrypted in `vars/cloudflare_vault.yml`.

GOST and cloudflared are installed from pinned upstream releases with SHA-256
verification. Hans and its legacy service files are removed by this role.
