# Komari_ttyd

一个 Docker 镜像，同时运行 **Komari 监控面板 + 网页终端（TTYD）**，多个平台均可部署。

---

## 🚀 Northflank 部署（最简单，自带 SSL）

Northflank 自动分配 HTTPS 域名，无需 Tunnel、无需证书配置。

### 1. 创建应用

| 设置项 | 填什么 |
|--------|--------|
| 镜像地址 | `ghcr.io/zv201413/komari_ttyd:latest` |
| 端口 1 | `80` → Komari 面板 |
| 端口 2 | `7681` → TTYD 网页终端（可选） |
| 持久化目录 | `/app/data` ← 不设的话重启面板数据全丢 |
| 环境变量 | `TTYD_P1=7681:admin:你的密码` |
| | `ADMIN_USERNAME=admin` |
| | `ADMIN_PASSWORD=你的密码` |

### 2. 访问

| 用途 | 地址 |
|------|------|
| Komari 面板 | `https://xxx.northflank.app`（平台分配） |
| TTYD 终端 | `https://xxx.northflank.app`（平台分配） |

> **无需填 `TUNNEL_TOKEN`**，这是最简单的方式。

---

## 准备工作（Tunnel 方式需要）

拿到 Tunnel Token（一串以 eyJ... 开头的字符）：

1. 打开 [https://one.dash.cloudflare.com](https://one.dash.cloudflare.com)
2. **Networks** → **Tunnels** → **Add a tunnel** → 选 Cloudflared → 起个名字
3. 到 **Public Hostname** 页面点 **Save tunnel**
4. 回到隧道列表，点隧道 → `...` → **View tunnel token**
5. 复制那串 `eyJ...` 开头的字符

> 这串 token 不要泄露给别人。

---

## 环境变量

### 方式 A：使用 Cloudflare Tunnel

| 变量 | 必填 | 说明 |
|------|------|------|
| `TUNNEL_TOKEN` | ✅ | Cloudflare Tunnel Token |
| `TTYD_P1` | ❌ | 网页终端，格式 `端口:用户名:密码` |
| `TTYD_P2` | ❌ | 第二个网页终端（支持 P3、P4...） |
| `ADMIN_USERNAME` | ❌ | Komari 管理员用户名，默认自动生成 |
| `ADMIN_PASSWORD` | ❌ | Komari 管理员密码，不设则自动生成（看日志） |


```bash
TUNNEL_TOKEN=eyJhIjoi...
TTYD_P1=7681:admin:123456
ADMIN_USERNAME=admin
ADMIN_PASSWORD=你的密码
```

### 方式 B：直接开 TCP 端口（不需要 Tunnel）

| 变量 | 必填 | 说明 |
|------|------|------|
| `TTYD_P1` | ❌ | 网页终端，格式 `端口:用户名:密码` |
| `ADMIN_USERNAME` | ❌ | Komari 管理员用户名，默认自动生成 |
| `ADMIN_PASSWORD` | ❌ | Komari 管理员密码，不设则自动生成（看日志） |


```bash
TTYD_P1=7681:admin:123456
```

---

## 部署

### 无SSL证书等 PaaS 平台（爪云、justrunmy.app、Zeabur 等）

#### 方案 A：走 Cloudflare Tunnel

| 设置项 | 填什么 |
|--------|--------|
| 镜像地址 | `ghcr.io/zv201413/komari_ttyd:latest` |
| 端口 | `80` |
| 持久化目录 | `/app/data` |
| 环境变量 | `TUNNEL_TOKEN=你的token` `TTYD_P1=7681:admin:你的密码` |

Cloudflare 面板加 Public Hostname：

| 域名 | 服务 |
|------|------|
| `komari.你的域名.com` | `localhost:80` |
| `ttyd.你的域名.com` | `localhost:7681` |

#### 方案 B：直接开 TCP 端口

| 设置项 | 填什么 |
|--------|--------|
| 镜像地址 | `ghcr.io/zv201413/komari_ttyd:latest` |
| 端口 | `80`（+ `7681` 如果需要 TTYD）|
| 持久化目录 | `/app/data` |
| 环境变量 | `TTYD_P1=7681:admin:你的密码` **不填 TUNNEL_TOKEN** |

> TTYD 需要平台支持暴露多个端口。

### 自建服务器

```bash
docker run -d --name komari \
  -p 80:80 \
  -v /app/data:/app/data \
  -e TUNNEL_TOKEN=eyJhIjoi... \
  -e TTYD_P1=7681:admin:123456 \
  ghcr.io/zv201413/komari_ttyd:latest
```

---

## 首次登录

Komari **没有固定默认密码**。

### 从日志查看
去平台看容器日志，搜索 `admin` 或 `password`：
```
Admin username: admin
Admin password: xxxxxx
```

### 环境变量指定（推荐）
部署时加上 `ADMIN_USERNAME` 和 `ADMIN_PASSWORD`，用你设的密码直接登录。

---



## 添加更多 TTYD

```bash
TTYD_P1=7681:admin:密码1
TTYD_P2=7682:user2:密码2
```

每加一个，Cloudflare 面板加一条 Public Hostname 指向对应端口。

---
