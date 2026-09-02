# TODO

## Client observability exporter

Build a small exporter and Grafana dashboard for VPN client visibility without
changing the public endpoint or existing OpenVPN profiles.

- Export active OpenVPN sessions from Helsinki: certificate CN, VPN address,
  platform, OpenVPN/GUI version, cipher, connection time, RX/TX totals, and
  current transfer rate.
- Read device information from OpenVPN peer-info (`IV_PLAT`, `IV_VER`,
  `IV_GUI_VER`, and `IV_HWADDR` when a client provides it).
- Collect real client IP addresses and connection statistics from the Moscow
  GOST JSON logs or Observer API.
- Enrich public IP addresses locally with country, region, city, ASN, and ISP
  data; avoid external per-request GeoIP APIs.
- Expose Prometheus-compatible metrics to VictoriaMetrics and provision a
  Grafana client table, traffic panels, and a region map.
- Define retention and access rules because public IP and device identifiers
  are personal data.
- Find a reliable session-correlation mechanism between the Moscow GOST
  session and the Helsinki OpenVPN session. The current UDP-over-Relay path
  hides the original IP from OpenVPN, and GOST PROXY Protocol does not support
  UDP. Timestamp correlation is acceptable only as an initial approximation.
- Consider issuing a unique certificate per device. MAC/device ID cannot be
  guaranteed with the current shared client profile and must remain optional.
