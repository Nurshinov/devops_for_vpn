# vpn_benchmark

Installs an iperf3 server bound only to the OpenVPN gateway address
`10.0.0.1:5201`. The endpoint is unreachable from the public network and is
used by `scripts/benchmark-vpn.sh` for repeatable end-to-end throughput tests.

Deploy it with:

```bash
ansible-playbook install_benchmark.yml -i inventory
```
