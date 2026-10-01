#!/bin/sh
set -eu
CONFIG=${1:-/root/codex-proxy.yaml}
BASE=/root/vpn
VERSION=v1.19.32
SHA256=8451100836c9eda194331c2babfad490b2faf30cebc1a04b0e76fd8ac2d35d10
[ -f "$CONFIG" ] || { echo "Missing $CONFIG" >&2; exit 1; }
mkdir -p "$BASE/bin" "$BASE/config" "$BASE/logs" "$BASE/run"
chmod 700 "$BASE" "$BASE/bin" "$BASE/config"
cp "$CONFIG" "$BASE/config/original.yaml"; chmod 600 "$BASE/config/original.yaml"
PYTHON=/root/code/dataset/openpi_training/openpi/.venv/bin/python
[ -x "$PYTHON" ] || PYTHON=python3
"$PYTHON" - "$BASE/config/original.yaml" "$BASE/config/config.yaml" <<'PY'
import os, sys
from pathlib import Path
import yaml
source, target = map(Path, sys.argv[1:])
data = yaml.safe_load(source.read_text())
if not isinstance(data, dict): raise SystemExit("Clash config must be a YAML mapping")
for key in ("port", "socks-port", "mixed-port", "redir-port", "tproxy-port", "listeners"): data.pop(key, None)
data.update({"mixed-port":17890,"allow-lan":False,"bind-address":"127.0.0.1","external-controller":"127.0.0.1:19090","mode":"rule","tun":{"enable":False}})
if isinstance(data.get("dns"), dict): data["dns"]["enable"] = False
data.pop("secret", None)
target.write_text(yaml.safe_dump(data, allow_unicode=True, sort_keys=False)); os.chmod(target, 0o600)
PY
ARCHIVE="$BASE/bin/mihomo-linux-amd64-$VERSION.gz"
if [ ! -x "$BASE/bin/mihomo" ]; then
  curl -fL --retry 2 --connect-timeout 10 --max-time 300 "https://github.com/MetaCubeX/mihomo/releases/download/$VERSION/mihomo-linux-amd64-$VERSION.gz" -o "$ARCHIVE"
  echo "$SHA256  $ARCHIVE" | sha256sum -c -
  gzip -dc "$ARCHIVE" > "$BASE/bin/mihomo"; chmod 700 "$BASE/bin/mihomo"
fi
if [ ! -f "$BASE/config/geoip.metadb" ]; then curl -fL --retry 2 --connect-timeout 10 --max-time 300 https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb -o "$BASE/config/geoip.metadb"; chmod 600 "$BASE/config/geoip.metadb"; fi
cat > "$BASE/start-codex-vpn.sh" <<'SH'
#!/bin/sh
set -eu
B=/root/vpn
if curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:19090/version >/dev/null 2>&1; then echo "Proxy is already running."; exit 0; fi
nohup "$B/bin/mihomo" -d "$B/config" -f "$B/config/config.yaml" >"$B/logs/mihomo.log" 2>&1 </dev/null & echo $! >"$B/run/mihomo.pid"
for i in $(seq 1 30); do curl --noproxy '*' -fsS --max-time 1 http://127.0.0.1:19090/version >/dev/null 2>&1 && { echo "Proxy ready"; exit 0; }; sleep 1; done
tail -30 "$B/logs/mihomo.log"; exit 1
SH
chmod 700 "$BASE/start-codex-vpn.sh"
sh "$BASE/start-codex-vpn.sh"
for D in /root/.vscode-server/extensions/openai.chatgpt-*/bin/linux-x86_64; do
  [ -x "$D/codex" ] || continue
  [ -e "$D/codex.real" ] || mv "$D/codex" "$D/codex.real"
  cat > "$D/codex" <<'SH'
#!/bin/sh
export HTTP_PROXY=http://127.0.0.1:17890 HTTPS_PROXY=http://127.0.0.1:17890 ALL_PROXY=http://127.0.0.1:17890
export http_proxy="$HTTP_PROXY" https_proxy="$HTTPS_PROXY" all_proxy="$ALL_PROXY"
export NO_PROXY=localhost,127.0.0.1,::1 no_proxy="$NO_PROXY"
exec "$(dirname "$0")/codex.real" "$@"
SH
  chmod 755 "$D/codex"
done
echo "Installed. Check: ss -lnt | grep -E ':17890|:19090'"
