# Grafana ACME proxy role

Publishes the private Grafana backend through nginx, obtains a Let's Encrypt
certificate with the HTTP-01 webroot challenge, redirects HTTP to HTTPS, and
enables the Certbot renewal timer. The renewal deploy hook reloads nginx.
