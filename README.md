# Server Codex VPN

This repository installs a local-only Mihomo proxy for remote Codex. It does
not contain a Clash subscription or node credentials.

## Deploy after a container rebuild

Upload your private Clash YAML to the server, then clone this repository:

```bash
scp -P 33127 -i ~/.ssh/id_ed25519 /path/to/private-clash.yaml \
  root@115.191.61.28:/root/codex-proxy.yaml
ssh -p 33127 -i ~/.ssh/id_ed25519 root@115.191.61.28
git clone https://github.com/chen-ml-121/vpn.git /root/vpn-installer
cd /root/vpn-installer
bash install.sh /root/codex-proxy.yaml
```

The installer creates `/root/vpn`, installs Mihomo v1.19.32, restores the
GeoIP database, generates a proxy bound to `127.0.0.1:17890`, and wraps the
remote Codex binary so its process uses that proxy. It does not enable TUN or
alter system routes.

The uploaded Clash YAML contains credentials. Keep it outside this repository.
