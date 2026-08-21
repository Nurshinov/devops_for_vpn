# Hans ICMP tunnel role

This role builds the pinned Hans source revision and manages
`hans-tunnel.service`. Helsinki runs the server at `10.254.0.1`; Moscow runs the
client at `10.254.0.2`. Both endpoints must use the same MTU and password.

Helsinki is the source of truth for `/etc/hans-tunnel.env`. The role reuses the
existing server-side secret or generates a 64-character hex value when the file
is absent. The client play securely passes that value to Moscow. No tunnel
secret is stored in inventory, Git, or GitHub Actions.
