# Nginx OpenVPN proxy role

This role configures nginx as a UDP proxy in front of the OpenVPN server. It
keeps the existing HTTP and ISPmanager configuration in `nginx.conf` and adds
only a managed include inside the top-level `stream` context.

Required variable:

```yaml
nginx_proxy_upstream_host: 157.180.39.82
```
