# Komari_ttyd

一个 Docker 镜像，同时运行 **Komari 监控面板 + 网页终端（TTYD）** 本项目多个平台均可部署
---

## 准备工作

拿到 Tunnel Token（一串以 eyJ... 开头的字符）


## 环境变量（配置参数）

### 方式 A：使用 Cloudflare Tunnel（默认）

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

如果你的 PaaS 平台支持直接暴露 TCP 端口（比如给你分配了一个域名+端口），可以**不填 `TUNNEL_TOKEN`**，cloudflared 不会启动。

| 变量 | 必填 | 说明 |
|------|------|------|
| `TTYD_P1` | ❌ | 网页终端，格式 `端口:用户名:密码` |
| `ADMIN_USERNAME` | ❌ | Komari 管理员用户名，默认自动生成 |
| `ADMIN_PASSWORD` | ❌ | Komari 管理员密码，不设则自动生成（看日志） |

```bash
# 不需要 TUNNEL_TOKEN
TTYD_P1=7681:admin:123456
```

| 跟 Tunnel 方案的区别 | |
|-------------------|---|
| ✅ 更简单，少一个配置项 | |
| ❌ 服务器 IP/端口公开暴露 | |
| ❌ Agent 连接地址用平台分配的域名，不是你能控制的 | |

---

## 部署

### 方式一：在 PaaS 平台部署（推荐新手）

适用：爪云、justrunmy.app、Zeabur 等。

#### 方案 A：走 Cloudflare Tunnel（需 TUNNEL_TOKEN）

1. **创建应用**，填入：

   | 设置项 | 填什么 |
   |--------|--------|
   | 镜像地址 | `ghcr.io/zv201413/komari_ttyd:latest` |
   | 端口 | `80` |
   | 持久化目录 | `/app/data` ← 关键，否则重启面板配置全丢 |
   | 环境变量 | `TUNNEL_TOKEN=你拿到的token` |
   | | `TTYD_P1=7681:admin:你的密码` |

2. **添加域名映射**（Cloudflare Zero Trust 面板）：

    打开 [https://one.dash.cloudflare.com](https://one.dash.cloudflare.com) → Networks → Tunnels → 点你的隧道 → **Add a public hostname**：

   | 域名 | 服务 |
   |------|------|
   | `komari.你的域名.com` | `localhost:80` |
   | `ttyd.你的域名.com` | `localhost:7681` |

3. **访问**：

   | 用途 | 地址 |
   |------|------|
   | Komari 面板 | `https://komari.你的域名.com` |
   | 网页终端 | `https://ttyd.你的域名.com` |

#### 方案 B：直接开 TCP 端口（不需要 Tunnel）

如果平台支持直接暴露 TCP 端口（比如给你一个 `xxxx.paas.com` 域名），可以不用 Tunnel：

1. **创建应用**，填入：

   | 设置项 | 填什么 |
   |--------|--------|
   | 镜像地址 | `ghcr.io/zv201413/komari_ttyd:latest` |
   | 端口 | `80` |
   | 持久化目录 | `/app/data` ← 关键，否则重启面板配置全丢 |
   | 环境变量 | `TTYD_P1=7681:admin:你的密码` |
   | | **不填 TUNNEL_TOKEN** |

2. 平台会给你一个域名，比如 `komari-xxxx.paas.com`

3. **访问**：

   | 用途 | 地址 |
   |------|------|
   | Komari 面板 | `https://komari-xxxx.paas.com` |
   | 网页终端 | `https://komari-xxxx.paas.com:7681` |

   > **TTYD 怎么用？** 方式 B 下平台默认只暴露了 80 端口，TTYD（7681）外面连不到。如果你用的平台**支持暴露多个端口**（如爪云支持自定义端口映射），在创建应用时把 80 和 7681 都暴露出来即可。不支持的话，TTYD 就用不了，改用 Tunnel 方式（方式 A）。
   >
   > **Agent 怎么连？** 在 Komari 面板设置里，对接地址填平台给你的域名，端口填 80（或 443，看平台是否支持 HTTPS）。

### 方式二：在自己的服务器上运行

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

Komari **没有固定默认密码**，首次启动自动生成。

### 方式 A：从日志查看
部署完成后去平台看容器日志，搜索 `admin` 或 `password`，找到类似：
```
Admin username: admin
Admin password: xxxxxx
```

### 方式 B：环境变量指定密码（推荐）
部署时加上以下环境变量，密码就是你指定的，不用翻日志：

| 变量 | 示例 |
|------|------|
| `ADMIN_USERNAME` | `admin` |
| `ADMIN_PASSWORD` | `你设的密码` |

1. 打开 `https://komari.你的域名.com`
2. 用你设置的用户名密码登录
3. 登录后**立即修改密码**（点右上角头像 → 设置）
4. 接下来可以添加服务器（Agent）进行监控了

---

## 添加更多 TTYD（网页终端）

想开多个终端窗口？加环境变量就行：

```bash
TTYD_P1=7681:admin:密码1
TTYD_P2=7682:user2:密码2
```

每加一个，Cloudflare 面板里加一条 Public Hostname：

| 域名 | 服务 |
|------|------|
| `ttyd1.你的域名.com` | `localhost:7681` |
| `ttyd2.你的域名.com` | `localhost:7682` |

