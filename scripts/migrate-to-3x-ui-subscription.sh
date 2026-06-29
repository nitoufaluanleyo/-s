#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_IP="${SERVER_IP:-}"
CLIENT_EMAIL="${CLIENT_EMAIL:-main-100g}"
LIMIT_GB="${LIMIT_GB:-100}"
LIMIT_BYTES="${LIMIT_BYTES:-}"
BACKUP_ROOT="${BACKUP_ROOT:-/root/xray-to-3x-ui-backup-$(date +%Y%m%d%H%M%S)}"
IMPORT_JSON="/root/3x-ui-vless-reality-import.json"
ROTATE_SCRIPT="/root/rotate-3x-ui-subscription.py"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

need_root() {
  [ "${EUID}" -eq 0 ] || die "Run as root first: sudo -i"
}

need_server_ip() {
  [ -n "$SERVER_IP" ] || die "Set SERVER_IP first, for example: SERVER_IP=203.0.113.10 bash $0"
}

compute_limit() {
  if [ -z "$LIMIT_BYTES" ]; then
    LIMIT_BYTES="$((LIMIT_GB * 1024 * 1024 * 1024))"
  fi
}

install_deps() {
  command -v apt-get >/dev/null 2>&1 || die "This script expects Ubuntu/Debian with apt-get."
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a
  apt-get update
  apt-get install -y curl ca-certificates openssl python3
}

backup_existing_xray() {
  mkdir -p "$BACKUP_ROOT"
  [ -f /usr/local/etc/xray/config.json ] && cp -a /usr/local/etc/xray/config.json "$BACKUP_ROOT/config.json"
  [ -f /root/vless-link.txt ] && cp -a /root/vless-link.txt "$BACKUP_ROOT/vless-link.txt"
  [ -f /root/vless-client.txt ] && cp -a /root/vless-client.txt "$BACKUP_ROOT/vless-client.txt"
  systemctl status xray --no-pager >"$BACKUP_ROOT/xray-status-before.txt" 2>&1 || true
  echo "Backup saved to: $BACKUP_ROOT"
}

install_3x_ui() {
  if command -v x-ui >/dev/null 2>&1 || [ -x /usr/bin/x-ui ] || [ -d /etc/x-ui ]; then
    echo "3x-ui appears to be installed; skipping installer."
    return
  fi

  echo "Installing 3x-ui from the official installer..."
  XUI_NONINTERACTIVE=1 XUI_SSL_MODE=none bash <(curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

write_import_generator() {
  cat >/root/create-3x-ui-import.py <<'PY'
#!/usr/bin/env python3
import json
import os
import secrets
import string
import subprocess
from pathlib import Path
from urllib.parse import parse_qs, urlparse

server_ip = os.environ["SERVER_IP"]
client_email = os.environ.get("CLIENT_EMAIL", "main-100g")
limit_bytes = int(os.environ["LIMIT_BYTES"])
out_path = Path(os.environ.get("IMPORT_JSON", "/root/3x-ui-vless-reality-import.json"))
config_path = Path("/usr/local/etc/xray/config.json")
link_candidates = [Path("/root/vless-link.txt"), Path("/root/vless-client.txt")]

def rand_sub_id(length=18):
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))

def first_reality_vless(config):
    for inbound in config.get("inbounds", []):
        if inbound.get("protocol") != "vless":
            continue
        stream = inbound.get("streamSettings") or {}
        if stream.get("security") == "reality":
            return inbound
    raise SystemExit("No VLESS + REALITY inbound found in /usr/local/etc/xray/config.json")

def parse_public_key_from_link():
    for link_path in link_candidates:
        if not link_path.exists():
            continue
        for line in link_path.read_text(encoding="utf-8", errors="ignore").splitlines():
            text = line.strip()
            if not text.startswith("vless://"):
                continue
            params = parse_qs(urlparse(text).query)
            pbk = (params.get("pbk") or [""])[0]
            if pbk:
                return pbk
    return ""

def public_key_from_private(private_key):
    for exe in ["xray", "/usr/local/bin/xray", "/usr/local/x-ui/bin/xray-linux-amd64"]:
        try:
            proc = subprocess.run(
                [exe, "x25519", "-i", private_key],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=10,
                check=False,
            )
        except Exception:
            continue
        for line in proc.stdout.splitlines():
            if "Public key:" in line:
                return line.split("Public key:", 1)[1].strip()
    return ""

with config_path.open("r", encoding="utf-8") as f:
    cfg = json.load(f)

old = first_reality_vless(cfg)
settings = old.get("settings") or {}
stream = old.get("streamSettings") or {}
reality = stream.get("realitySettings") or {}
clients = settings.get("clients") or []
if not clients:
    raise SystemExit("No client found in existing VLESS inbound")

uuid = clients[0].get("id")
server_names = reality.get("serverNames") or []
short_ids = reality.get("shortIds") or []
private_key = reality.get("privateKey", "")
public_key = parse_public_key_from_link() or public_key_from_private(private_key)
if not uuid or not private_key or not public_key or not server_names or not short_ids:
    raise SystemExit("Existing REALITY config is missing uuid/privateKey/publicKey/serverNames/shortIds")

sni = server_names[0]
short_id = short_ids[0]
dest = reality.get("dest") or f"{sni}:443"
sub_id = rand_sub_id()

inbound = {
    "up": 0,
    "down": 0,
    "total": 0,
    "remark": "VLESS-REALITY-100G",
    "enable": True,
    "expiryTime": 0,
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {
        "clients": [{
            "id": uuid,
            "flow": "",
            "email": client_email,
            "limitIp": 0,
            "totalGB": limit_bytes,
            "expiryTime": 0,
            "enable": True,
            "tgId": 0,
            "subId": sub_id,
            "reset": 0,
            "comment": "Monthly quota; subscription URL rotated monthly"
        }],
        "decryption": "none",
        "fallbacks": []
    },
    "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "tcpSettings": {"acceptProxyProtocol": False, "header": {"type": "none"}},
        "realitySettings": {
            "show": False,
            "dest": dest,
            "xver": 0,
            "serverNames": [sni],
            "privateKey": private_key,
            "shortIds": [short_id],
            "settings": {"publicKey": public_key, "fingerprint": "chrome", "spiderX": "/"}
        }
    },
    "sniffing": {"enabled": True, "destOverride": ["http", "tls", "quic"]},
    "tag": "in-443-vless-reality",
    "shareAddrStrategy": "custom",
    "shareAddr": server_ip,
    "clientStats": [{
        "enable": True,
        "email": client_email,
        "up": 0,
        "down": 0,
        "expiryTime": 0,
        "total": limit_bytes,
        "reset": 0
    }]
}

out_path.write_text(json.dumps(inbound, ensure_ascii=False, indent=2), encoding="utf-8")
Path("/root/3x-ui-subid.txt").write_text(sub_id + "\n", encoding="utf-8")
print(f"Wrote import JSON: {out_path}")
print(f"Client email: {client_email}")
print(f"Initial subId: {sub_id}")
print(f"SNI: {sni}")
PY
  chmod 700 /root/create-3x-ui-import.py
}

write_import_runner() {
  cat >/root/import-3x-ui-inbound.py <<'PY'
#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

env_path = Path("/etc/x-ui/install-result.env")
import_path = Path("/root/3x-ui-vless-reality-import.json")
if not env_path.exists():
    raise SystemExit("/etc/x-ui/install-result.env not found")

values = {}
for raw in env_path.read_text(encoding="utf-8", errors="ignore").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    try:
        parsed = shlex.split(line, comments=False, posix=True)
        line = parsed[0] if parsed else line
    except ValueError:
        pass
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip()

token = values.get("XUI_API_TOKEN", "")
port = values.get("XUI_PANEL_PORT", "2053")
base = values.get("XUI_WEB_BASE_PATH", "/")
if not base.startswith("/"):
    base = "/" + base
if not base.endswith("/"):
    base += "/"
if not token:
    raise SystemExit("XUI_API_TOKEN is empty; import manually from /root/3x-ui-vless-reality-import.json")

url = f"http://127.0.0.1:{port}{base}panel/api/inbounds/import"
payload = urllib.parse.urlencode({"data": import_path.read_text(encoding="utf-8")}).encode()

last = None
for _ in range(30):
    try:
        req = urllib.request.Request(url, data=payload, method="POST")
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("Content-Type", "application/x-www-form-urlencoded")
        with urllib.request.urlopen(req, timeout=8) as resp:
            body = resp.read().decode("utf-8", "replace")
            print(body)
            parsed = json.loads(body)
            if parsed.get("success") is False:
                raise SystemExit("3x-ui API returned failure; import manually from the JSON file")
            break
    except Exception as exc:
        last = exc
        time.sleep(2)
else:
    raise SystemExit(f"3x-ui API import failed: {last}")

sub_id = Path("/root/3x-ui-subid.txt").read_text(encoding="utf-8").strip()
server_ip = os.environ["SERVER_IP"]
sub_url = f"http://{server_ip}:2096/sub/{sub_id}"
Path("/root/current-subscription-url.txt").write_text(sub_url + "\n", encoding="utf-8")
print(f"Subscription URL: {sub_url}")
subprocess.run(["systemctl", "restart", "x-ui"], check=False)
PY
  chmod 700 /root/import-3x-ui-inbound.py
}

stop_standalone_xray() {
  if systemctl list-unit-files | grep -q '^xray\.service'; then
    systemctl disable --now xray || true
  fi
}

write_rotation_script() {
  cat >"$ROTATE_SCRIPT" <<'PY'
#!/usr/bin/env python3
import json
import os
import secrets
import shutil
import sqlite3
import string
import subprocess
import time
from pathlib import Path

DB = Path("/etc/x-ui/x-ui.db")
EMAIL = os.environ.get("CLIENT_EMAIL", "main-100g")
SERVER_IP = os.environ["SERVER_IP"]
LIMIT_BYTES = int(os.environ["LIMIT_BYTES"])

def rand_sub_id(length=18):
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))

def columns(cur, table):
    return {row[1] for row in cur.execute(f"PRAGMA table_info({table})").fetchall()}

def setting(cur, key, default):
    try:
        row = cur.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
    except sqlite3.Error:
        return default
    return row[0] if row and row[0] else default

def update_existing(cur, table, updates, where_sql, where_values):
    cols = columns(cur, table)
    filtered = {k: v for k, v in updates.items() if k in cols}
    if not filtered:
        return 0
    set_sql = ", ".join([f"{k} = ?" for k in filtered])
    cur.execute(f"UPDATE {table} SET {set_sql} WHERE {where_sql}", list(filtered.values()) + list(where_values))
    return cur.rowcount

def normalize_path(path):
    if not path.startswith("/"):
        path = "/" + path
    if not path.endswith("/"):
        path += "/"
    return path

if not DB.exists():
    raise SystemExit("/etc/x-ui/x-ui.db not found")

new_sub_id = rand_sub_id()
backup = Path(f"/etc/x-ui/x-ui.db.before-rotate-{time.strftime('%Y%m%d%H%M%S')}")
now_ms = int(time.time() * 1000)

subprocess.run(["systemctl", "stop", "x-ui"], check=False)
try:
    shutil.copy2(DB, backup)
    conn = sqlite3.connect(DB)
    try:
        cur = conn.cursor()
        cur.execute("BEGIN IMMEDIATE")
        row = cur.execute("SELECT id FROM clients WHERE email = ?", (EMAIL,)).fetchone()
        if not row:
            raise SystemExit(f"No client row found for {EMAIL}")

        update_existing(cur, "clients", {
            "sub_id": new_sub_id,
            "total_gb": LIMIT_BYTES,
            "expiry_time": 0,
            "enable": 1,
            "reset": 0,
            "updated_at": now_ms,
        }, "email = ?", [EMAIL])

        update_existing(cur, "client_traffics", {
            "enable": 1,
            "up": 0,
            "down": 0,
            "expiry_time": 0,
            "total": LIMIT_BYTES,
            "reset": 0,
        }, "email = ?", [EMAIL])

        changed = 0
        for inbound_id, settings_text in cur.execute("SELECT id, settings FROM inbounds").fetchall():
            try:
                settings = json.loads(settings_text or "{}")
            except Exception:
                continue
            touched = False
            for client in settings.get("clients") or []:
                if client.get("email") == EMAIL:
                    client["subId"] = new_sub_id
                    client["totalGB"] = LIMIT_BYTES
                    client["expiryTime"] = 0
                    client["enable"] = True
                    client["reset"] = 0
                    touched = True
            if touched:
                cur.execute("UPDATE inbounds SET settings = ? WHERE id = ?", (json.dumps(settings, ensure_ascii=False), inbound_id))
                changed += 1
        if changed == 0:
            raise SystemExit(f"No inbound settings client found for {EMAIL}")

        sub_port = setting(cur, "subPort", "2096")
        sub_path = normalize_path(setting(cur, "subPath", "/sub/"))
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    url = f"http://{SERVER_IP}:{sub_port}{sub_path}{new_sub_id}"
    Path("/root/3x-ui-subid.txt").write_text(new_sub_id + "\n", encoding="utf-8")
    Path("/root/current-subscription-url.txt").write_text(url + "\n", encoding="utf-8")
    print("Rotated subscription URL and reset traffic.")
    print(f"DB backup: {backup}")
    print(url)
finally:
    subprocess.run(["systemctl", "start", "x-ui"], check=False)
PY
  chmod 700 "$ROTATE_SCRIPT"

  cat >/etc/systemd/system/rotate-3x-ui-subscription.service <<EOF
[Unit]
Description=Rotate 3x-ui subscription URL and reset traffic

[Service]
Type=oneshot
Environment=SERVER_IP=$SERVER_IP
Environment=CLIENT_EMAIL=$CLIENT_EMAIL
Environment=LIMIT_BYTES=$LIMIT_BYTES
ExecStart=/usr/bin/python3 $ROTATE_SCRIPT
EOF

  cat >/etc/systemd/system/rotate-3x-ui-subscription.timer <<'EOF'
[Unit]
Description=Monthly rotate 3x-ui subscription URL

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now rotate-3x-ui-subscription.timer
}

print_next_steps() {
  echo
  echo "Done. Check these files and services:"
  echo "  /etc/x-ui/install-result.env"
  echo "  /root/current-subscription-url.txt"
  echo "  systemctl status x-ui --no-pager"
  echo "  systemctl status rotate-3x-ui-subscription.timer --no-pager"
  echo
  echo "Open firewall ports:"
  echo "  TCP 443 for VLESS"
  echo "  TCP 2096 for subscription updates"
  echo "  3x-ui panel port from /etc/x-ui/install-result.env, restricted to your IP"
}

main() {
  need_root
  need_server_ip
  compute_limit
  echo "SERVER_IP=$SERVER_IP CLIENT_EMAIL=$CLIENT_EMAIL LIMIT_BYTES=$LIMIT_BYTES"
  install_deps
  backup_existing_xray
  install_3x_ui
  write_import_generator
  write_import_runner
  SERVER_IP="$SERVER_IP" CLIENT_EMAIL="$CLIENT_EMAIL" LIMIT_BYTES="$LIMIT_BYTES" IMPORT_JSON="$IMPORT_JSON" /root/create-3x-ui-import.py
  stop_standalone_xray
  SERVER_IP="$SERVER_IP" /root/import-3x-ui-inbound.py || {
    echo "Automatic API import failed. Import manually from $IMPORT_JSON in the 3x-ui panel."
  }
  write_rotation_script
  print_next_steps
}

main "$@"
