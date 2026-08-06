#!/bin/bash
set -e

CONF_DIR=/etc/supervisor/conf.d
mkdir -p "$CONF_DIR"

# ── nginx real_ip ──
# komari 只信任 127.0.0.1 并读 X-Real-IP（见 internal/server/runtime.go），
# 而 X-Real-IP 由本文件下方 nginx.conf 用 $remote_addr 生成，
# 所以「$remote_addr 有没有被还原成真实客户端 IP」直接决定 IP 白名单、
# 登录限速、审计日志是否可用。信任范围写窄是为了防伪造：只有 TCP 对端
# 落在可信网段时，nginx 才采信请求头里的 IP。
if [ -n "$TUNNEL_TOKEN" ]; then
    # cloudflared 与 nginx 同容器，隧道来的连接对端恒为回环地址
    DEFAULT_HEADER="CF-Connecting-IP"
    DEFAULT_CIDR="127.0.0.1/32,::1/128"
else
    # 平台 LB（Northflank / 爪云 / Zeabur 等）从私有网段发起连接
    DEFAULT_HEADER="X-Forwarded-For"
    DEFAULT_CIDR="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1/32"
fi

REAL_IP_HEADER="${REAL_IP_HEADER:-$DEFAULT_HEADER}"
TRUSTED_PROXY_CIDR="${TRUSTED_PROXY_CIDR:-$DEFAULT_CIDR}"

: > /etc/nginx/realip.inc
# 用 if 而非 `[ -n ] && echo`：后者在末项为空时（如 CIDR 串带尾随逗号）
# 返回非零，作为循环体最后一条语句会让管道子 shell 非零退出，撞上 set -e。
echo "$TRUSTED_PROXY_CIDR" | tr ',' '\n' | while read -r cidr; do
    if [ -n "$cidr" ]; then
        echo "set_real_ip_from $cidr;" >> /etc/nginx/realip.inc
    fi
done
cat >> /etc/nginx/realip.inc <<SUP
real_ip_header $REAL_IP_HEADER;
real_ip_recursive on;
SUP

echo "[INFO] real IP: header=$REAL_IP_HEADER trusted=$TRUSTED_PROXY_CIDR"

# ── nginx ──
cat > "$CONF_DIR/nginx.conf" << 'SUP'
[program:nginx]
command=nginx -g "daemon off;"
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP

# ── Komari Dashboard ──
# 如果用户设置了 KOMARI_LISTEN，传给 komari
LISTEN="${KOMARI_LISTEN:-0.0.0.0:25774}"

cat > "$CONF_DIR/komari.conf" << SUP
[program:komari]
command=/usr/local/bin/komari server -l $LISTEN
directory=/app
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
environment=
  KOMARI_DB_FILE="/app/data/komari.db",
  KOMARI_ENABLE_CLOUDFLARED="${KOMARI_ENABLE_CLOUDFLARED:-false}"
SUP


# ── Cloudflare Tunnel ──
if [ -z "$TUNNEL_TOKEN" ]; then
    echo "[WARN] TUNNEL_TOKEN not set. Cloudflare Tunnel will not start."
else
    cat > "$CONF_DIR/tunnel.conf" << SUP
[program:tunnel]
command=/usr/local/bin/cloudflared tunnel --no-autoupdate run --protocol http2 --http2-origin --token $TUNNEL_TOKEN
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP
fi

# ── TTYD instances ──
for var in $(compgen -A variable | grep -E '^TTYD_P[0-9]+$' | sort); do
    IFS=':' read -r port user pass <<< "${!var}"
    if [ -z "$port" ] || [ -z "$user" ] || [ -z "$pass" ]; then
        echo "[WARN] $var format invalid (expected port:user:pass), got: ${!var}"
        continue
    fi
    name="ttyd_${var#TTYD_P}"
    cat > "$CONF_DIR/${name}.conf" << SUP
[program:$name]
    command=/usr/local/bin/ttyd -c $user:$pass -p $port -W bash
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP
    echo "[INFO] TTYD instance '$name' -> port $port, user: $user"
done

exec supervisord -c /etc/supervisord.conf
