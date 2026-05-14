#!/bin/bash
set -e

CONF_DIR=/etc/supervisor/conf.d
mkdir -p "$CONF_DIR"

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
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
environment=
  KOMARI_DB_FILE="/app/data/komari.db",
  KOMARI_ENABLE_CLOUDFLARED="${KOMARI_ENABLE_CLOUDFLARED:-false}"
SUP

# ── Komari Agent（自我监控）──
if [ -n "$KOMARI_AGENT_SERVER" ] && [ -n "$KOMARI_AGENT_TOKEN" ]; then
    AGENT_DIR="/app/data"
    AGENT_BIN="${AGENT_DIR}/komari-agent"

    if [ ! -f "$AGENT_BIN" ]; then
        echo "[INFO] Downloading komari-agent to ${AGENT_DIR}..."
        # 检测架构
        case "$(uname -m)" in
            x86_64|amd64) ARCH="amd64" ;;
            aarch64|arm64) ARCH="arm64" ;;
            *) echo "[WARN] Unknown arch, agent not downloaded"; AGENT_BIN="" ;;
        esac
        if [ -n "$AGENT_BIN" ]; then
            curl -sL "https://github.com/komari-monitor/komari-agent/releases/latest/download/komari-agent-linux-${ARCH}" \
                -o "$AGENT_BIN" && chmod +x "$AGENT_BIN"
        fi
    fi

    if [ -f "$AGENT_BIN" ]; then
        TLS_FLAG=""
        [ -n "$KOMARI_AGENT_TLS" ] && TLS_FLAG="--tls"
        cat > "$CONF_DIR/agent.conf" << SUP
[program:komari-agent]
command=${AGENT_BIN} -e ${KOMARI_AGENT_SERVER} -t ${KOMARI_AGENT_TOKEN} ${TLS_FLAG} --disable-auto-update
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP
        echo "[INFO] Komari Agent enabled -> ${KOMARI_AGENT_SERVER}"
    fi
fi

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
