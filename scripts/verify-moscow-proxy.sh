#!/usr/bin/env bash

set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
password_file="${project_dir}/.proxy-password"
endpoint="proxy.nurshinov-vpn.com:8443"
expected_ip="157.180.39.82"

if [[ ! -r "${password_file}" ]]; then
  echo "Deploy install_proxy.yml first; proxy credentials are missing." >&2
  exit 1
fi

proxy_password=$(<"${password_file}")
actual_ip=$(
  curl --fail --silent --show-error --max-time 30 \
    --proxy "https://${endpoint}" \
    --proxy-user "vpnproxy:${proxy_password}" \
    https://api.ipify.org
)

if [[ "${actual_ip}" != "${expected_ip}" ]]; then
  echo "Unexpected proxy egress IP: ${actual_ip} (expected ${expected_ip})" >&2
  exit 1
fi

echo "Proxy endpoint ${endpoint} is healthy; egress IP is ${actual_ip}."
