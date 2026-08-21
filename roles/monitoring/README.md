# Monitoring role

Installs a pinned VictoriaMetrics single-node binary and Grafana OSS on
Helsinki. VictoriaMetrics and Grafana bind to localhost; the `grafana_acme`
role publishes Grafana through an nginx HTTPS reverse proxy. VictoriaMetrics
scrapes the two node exporters over the Hans tunnel, and Grafana provisions the
VictoriaMetrics datasource and a VPN performance dashboard automatically.
