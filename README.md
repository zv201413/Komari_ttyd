# Komari_ttyd

All-in-one Docker image: **Komari + Nginx + Cloudflare Tunnel + TTYD**

---

## 架构

```
Agent → Cloudflare(443) → Tunnel → cloudflared → nginx:80 → komari:25774
                                                      └─ ttyd:7681 / 7682 ...
```

---

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `TUNNEL_TOKEN` | ✅ | Cloudflare Tunnel Token |
| `TTYD_P1` | ❌ | TTYD 实例，格式 `端口:用户名:密码` |
| `KOMARI_LISTEN` | ❌ | 监听地址，默认 `0.0.0.0:25774` |
| `KOMARI_ENABLE_CLOUDFLARED` | ❌ | 启用 Komari 内建隧道（`true`/`false`） |

### 示例

```bash
TUNNEL_TOKEN=eyJhIjoi...
TTYD_P1=7681:admin:pass123
KOMARI_ENABLE_CLOUDFLARED=false
```

---

## Cloudflare Zero Trust 配置

| 域名 | 服务 |
|------|------|
| `komari.你的域名.com` | `localhost:80` |
| `ttyd1.你的域名.com` | `localhost:7681` |

---

## 构建

```bash
docker build -t komari-ttyd .
```
