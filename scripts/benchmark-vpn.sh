#!/usr/bin/env bash
set -Eeuo pipefail

server="${VPN_BENCHMARK_SERVER:-10.0.0.1}"
port="${VPN_BENCHMARK_PORT:-5201}"
runs="${VPN_BENCHMARK_RUNS:-3}"
duration="${VPN_BENCHMARK_DURATION:-10}"
parallel="${VPN_BENCHMARK_PARALLEL:-4}"
omit="${VPN_BENCHMARK_OMIT:-2}"
output_root="${VPN_BENCHMARK_OUTPUT_DIR:-benchmarks/results}"

usage() {
  printf '%s\n' \
    'Usage: scripts/benchmark-vpn.sh [options]' \
    '' \
    'Options:' \
    '  -s ADDRESS  iperf3 server inside the VPN (default: 10.0.0.1)' \
    '  -p PORT     iperf3 server port (default: 5201)' \
    '  -r RUNS     upload/download pairs (default: 3)' \
    '  -t SECONDS  measured seconds per direction (default: 10)' \
    '  -P STREAMS  parallel TCP streams (default: 4)' \
    '  -O SECONDS  warm-up seconds omitted from results (default: 2)' \
    '  -o DIR      result directory root (default: benchmarks/results)' \
    '  -h          show this help'
}

while getopts ':s:p:r:t:P:O:o:h' option; do
  case "${option}" in
    s) server="${OPTARG}" ;;
    p) port="${OPTARG}" ;;
    r) runs="${OPTARG}" ;;
    t) duration="${OPTARG}" ;;
    P) parallel="${OPTARG}" ;;
    O) omit="${OPTARG}" ;;
    o) output_root="${OPTARG}" ;;
    h) usage; exit 0 ;;
    :) printf 'Option -%s requires a value.\n' "${OPTARG}" >&2; exit 2 ;;
    *) usage >&2; exit 2 ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command is missing: %s\n' "$1" >&2
    exit 1
  fi
}

validate_positive_integer() {
  local name="$1"
  local value="$2"
  if [[ ! "${value}" =~ ^[0-9]+$ ]] || (( value < 1 )); then
    printf '%s must be a positive integer, got: %s\n' "${name}" "${value}" >&2
    exit 2
  fi
}

require_command iperf3
require_command jq
require_command ping

validate_positive_integer port "${port}"
validate_positive_integer runs "${runs}"
validate_positive_integer duration "${duration}"
validate_positive_integer parallel "${parallel}"
if [[ ! "${omit}" =~ ^[0-9]+$ ]]; then
  printf 'omit must be a non-negative integer, got: %s\n' "${omit}" >&2
  exit 2
fi
if (( port > 65535 )); then
  printf 'port must not exceed 65535, got: %s\n' "${port}" >&2
  exit 2
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_dir="${output_root}/${timestamp}"
mkdir -p "${result_dir}"

printf 'VPN benchmark target: %s:%s\n' "${server}" "${port}"
printf 'Runs: %s, duration: %ss, warm-up: %ss, parallel streams: %s\n' \
  "${runs}" "${duration}" "${omit}" "${parallel}"

LC_ALL=C ping -c 10 "${server}" | tee "${result_dir}/ping.txt"

for ((run = 1; run <= runs; run++)); do
  printf '\n[%s/%s] Upload test\n' "${run}" "${runs}"
  iperf3 --client "${server}" --port "${port}" --version4 \
    --parallel "${parallel}" --time "${duration}" --omit "${omit}" --json \
    >"${result_dir}/run-${run}-upload.json"
  jq -e '.end.sum_received.bits_per_second | numbers' \
    "${result_dir}/run-${run}-upload.json" >/dev/null
  jq -r '(.end.sum_received.bits_per_second / 1000000) |
    "upload: \(. * 100 | round / 100) Mbit/s"' \
    "${result_dir}/run-${run}-upload.json"

  printf '[%s/%s] Download test\n' "${run}" "${runs}"
  iperf3 --client "${server}" --port "${port}" --version4 --reverse \
    --parallel "${parallel}" --time "${duration}" --omit "${omit}" --json \
    >"${result_dir}/run-${run}-download.json"
  jq -e '.end.sum_received.bits_per_second | numbers' \
    "${result_dir}/run-${run}-download.json" >/dev/null
  jq -r '(.end.sum_received.bits_per_second / 1000000) |
    "download: \(. * 100 | round / 100) Mbit/s"' \
    "${result_dir}/run-${run}-download.json"
done

packet_loss="$(awk -F', ' '/packets transmitted/ {
  for (i = 1; i <= NF; i++) if ($i ~ /packet loss/) {
    gsub(/% packet loss/, "", $i); print $i
  }
}' "${result_dir}/ping.txt")"
rtt_average="$(awk -F'= ' '/(round-trip|rtt) min\/avg\/max/ {
  split($2, values, "/"); print values[2]
}' "${result_dir}/ping.txt")"

upload_stats="$(jq -s '
  [.[].end.sum_received.bits_per_second] as $bps |
  {
    average_mbps: (($bps | add / length) / 1000000),
    minimum_mbps: (($bps | min) / 1000000),
    maximum_mbps: (($bps | max) / 1000000),
    average_MBps: (($bps | add / length) / 8000000)
  }' "${result_dir}"/run-*-upload.json)"

download_stats="$(jq -s '
  [.[].end.sum_received.bits_per_second] as $bps |
  {
    average_mbps: (($bps | add / length) / 1000000),
    minimum_mbps: (($bps | min) / 1000000),
    maximum_mbps: (($bps | max) / 1000000),
    average_MBps: (($bps | add / length) / 8000000)
  }' "${result_dir}"/run-*-download.json)"

jq -n \
  --arg timestamp "${timestamp}" \
  --arg server "${server}" \
  --argjson port "${port}" \
  --argjson runs "${runs}" \
  --argjson duration_seconds "${duration}" \
  --argjson parallel_streams "${parallel}" \
  --arg packet_loss_percent "${packet_loss}" \
  --arg rtt_average_ms "${rtt_average}" \
  --argjson upload "${upload_stats}" \
  --argjson download "${download_stats}" \
  '{
    schema_version: 1,
    timestamp_utc: $timestamp,
    target: {server: $server, port: $port},
    parameters: {
      runs: $runs,
      duration_seconds: $duration_seconds,
      parallel_streams: $parallel_streams
    },
    latency: {
      packet_loss_percent: ($packet_loss_percent | tonumber? // null),
      rtt_average_ms: ($rtt_average_ms | tonumber? // null)
    },
    upload: $upload,
    download: $download
  }' >"${result_dir}/summary.json"

jq -r '
  def rounded: . * 100 | round / 100;
  "# VPN benchmark \(.timestamp_utc)\n\n" +
  "Target: `\(.target.server):\(.target.port)`  \n" +
  "Runs: \(.parameters.runs), duration: \(.parameters.duration_seconds)s, " +
  "parallel streams: \(.parameters.parallel_streams)  \n" +
  "Average RTT: \(.latency.rtt_average_ms // "n/a") ms, " +
  "packet loss: \(.latency.packet_loss_percent // "n/a")%\n\n" +
  "| Direction | Average Mbit/s | Average MB/s | Min Mbit/s | Max Mbit/s |\n" +
  "|---|---:|---:|---:|---:|\n" +
  "| Upload | \(.upload.average_mbps | rounded) | " +
  "\(.upload.average_MBps | rounded) | \(.upload.minimum_mbps | rounded) | " +
  "\(.upload.maximum_mbps | rounded) |\n" +
  "| Download | \(.download.average_mbps | rounded) | " +
  "\(.download.average_MBps | rounded) | \(.download.minimum_mbps | rounded) | " +
  "\(.download.maximum_mbps | rounded) |"
' "${result_dir}/summary.json" >"${result_dir}/summary.md"

printf '\n'
sed -n '1,120p' "${result_dir}/summary.md"
printf '\nRaw results: %s\n' "${result_dir}"
