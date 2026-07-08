# Komari_ttyd

> **Komari 生态**: [`komari_new`](https://github.com/zv201413/komari_new) (服务端) · [`komari-agent_new`](https://github.com/zv201413/komari-agent_new) (探针) · **`Komari_ttyd`** (本仓库, Docker 一体镜像) · [`komari-web_new`](https://github.com/zv201413/komari-web_new) (前端 UI 源码)

这是一个高度精简的 Docker 镜像，在极低资源占用的前提下，同时运行 **Komari 监控面板** 与 **网页终端（TTYD）**。

> **探针监控说明**：
> 为了保证容器在各大 PaaS 平台上的极致兼容性，本镜像**已剔除**内置的 Komari Agent。如需监控服务器：
> 1. **真实的 VPS / 虚拟机**：请直接使用官方后台复制的原始命令（`wget ... install.sh`）在宿主机运行，依赖 `systemd` 最稳定。
> 2. **PaaS 平台 / 纯容器环境**：脚本自动检测无 systemd 时切换为 nohup 后台模式，无需转换。
>
> > ⚠️ 如果 `wget` 下载失败，请将命令中的 `wget -qO-` 替换为 `curl -sL` 重试。

---

## 🚀 快速部署

### Northflank（最简单，自带 SSL）

Northflank 会自动为应用分配带 HTTPS 的专属域名。**不需要配置 Tunnel，也不需要搞证书**。

1. 创建 Service，选择 Docker image 模式：

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/komari_ttyd:latest` |
| **端口 1 (Port)** | `80` (访问 Komari 面板) |
| **端口 2 (Port)** | `7681` (TTYD 网页终端) |
| **持久化存储 (Volume)** | 挂载路径填 `/app/data`（必填，否则重启面板数据全丢） |

| 环境变量 | 值 | 说明 |
|--------|----|------|
| **`USER_PWD`** | **`用户名:你的复杂密码`** | 面板管理员账号密码。仅在首次部署、数据库为空时生效；后续可在后台改密码 |
| `ADMIN_USERNAME` + `ADMIN_PASSWORD` | 旧版兼容，已设 `USER_PWD` 则忽略 |
| `TTYD_P0` | `7681:admin:你的密码` | 网页终端 Basic Auth（`port:用户名:密码`） |
| `TTYD_P1` | `7682:user2:密码2` | 第二个 TTYD 终端（可继续 `TTYD_P2`、`TTYD_P3`...） |

2. 部署成功后，查看 Northflank 分配的域名：
   - **Komari 面板**：`https://xxx.northflank.app`
   - **TTYD 终端**：Northflank 在 Service → Ports 标签页为额外端口分配独立 URL

### ☁️ 其他 PaaS 平台（爪云 / Zeabur 等）

如果平台不提供 SSL 或不能暴露多端口，推荐配合 **Cloudflare Tunnel**。

**前置准备：获取 Tunnel Token**
1. 登录 [Cloudflare Zero Trust](https://one.dash.cloudflare.com) → **Networks** → **Tunnels** → **Add a tunnel** (选择 Cloudflared)
2. 在 Public Hostname 页面点击 **Save tunnel**
3. 回到列表，点击隧道 `...` 菜单 → **View tunnel token**，复制 `eyJ...` 开头的 Token

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/komari_ttyd:latest` |
| **持久化目录** | 挂载到 `/app/data` |
| **环境变量** | `TUNNEL_TOKEN=eyJh...`<br>`TTYD_P0=7681:admin:密码`<br>`USER_PWD=admin:密码` |

**配置域名解析**：在 Cloudflare Tunnel 面板的 Public Hostname 添加：
- `komari.你的域名.com` → `http://localhost:80`
- `ttyd.你的域名.com` → `http://localhost:7681`

### 💻 自建服务器 (Docker)

```bash
docker run -d --name komari \
  --restart unless-stopped \
  -p 8000:80 \
  -p 7681:7681 \
  -v /opt/komari/data:/app/data \
  -e USER_PWD=admin:你的复杂密码 \
  -e TTYD_P0=7681:admin:你的终端密码 \
  ghcr.io/zv201413/komari_ttyd:latest
```

*(访问 `http://你的IP:8000` 即可进入面板。)*

---

## 🔐 首次登录 & 密码管理

**必须设置管理员密码，不设密码不会启动。**

### 密码持久化逻辑
- `USER_PWD`（或旧版 `ADMIN_PASSWORD`）是**种子密码**，仅在数据库为空时生效（首次部署）。
- 一旦通过面板 UI **修改了密码**，数据库记录优先级最高，环境变量会被忽略。
- **必须挂载持久卷到 `/app/data`**，否则每次重启数据库重建，密码会丢失。
- **鉴权失败 ≠ 密码变了**：遇到登录问题，先确认持久卷是否挂载正确。

### 设置管理员账号（必填）
```bash
# 推荐（新版）
USER_PWD=admin:你的复杂密码

# 旧版兼容（同时设置）
ADMIN_USERNAME=admin
ADMIN_PASSWORD=你的复杂密码
```

> ⚠️ 不设置 `USER_PWD` 且数据库为空时，容器将启动失败并报错。

---

## 🛠 TTYD 多终端配置

每个 TTYD 实例自带 **Basic Auth 鉴权**（`-c user:pass`），必须输入用户名和密码才能进入终端。

```bash
TTYD_P0=7681:admin:密码1
TTYD_P1=7682:user2:密码2
TTYD_P2=7683:user3:密码3
```
*格式：`TTYD_P序号=端口:用户名:密码`。增加端口后，记得在部署平台或 Cloudflare Tunnel 中放行对应的端口号。*

> 🔒 **安全说明**：ttyd 未开启 HTTPS，建议通过 Nginx 反代或 Cloudflare Tunnel 暴露，避免明文传输密码。

---

## 🔔 Telegram 通知配置

Komari 内置通知系统，支持在服务器上下线时通过 Telegram 发送通知（包含 IP、OS、地区、CPU 等详细信息）。

### 方式一：内置 Telegram 发送器（推荐）

登录面板后 → **设置 (Settings)** → **通知 (Notifications)**：
1. 开启 **启用通知**
2. **通知方式** 选择 `telegram`
3. 点击 **编辑配置**，填入：

| 参数 | 值 |
|------|------|
| `bot_token` | `你的BOT_TOKEN` |
| `chat_id` | `你的CHAT_ID` |
| `endpoint` | `https://api.telegram.org/bot`（默认） |
| `message_thread_id` | 留空（仅超级群组话题需要） |

4. 保存后点击 **测试 (Test Send)** 验证

### 方式二：JavaScript 发送器（高级）

适用于自定义排版、多平台通知等场景，选择 `Javascript` 方式编写自定义脚本：

```javascript
async function sendMessage(message, title) {
  const url = `https://api.telegram.org/bot<你的BOT_TOKEN>/sendMessage`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      chat_id: '<你的CHAT_ID>',
      text: `<b>${title}</b>\n${message}`,
      parse_mode: 'HTML'
    })
  });
  return resp.ok;
}

async function sendEvent(event) {
  // event 对象: event, clients, message, time, emoji
  // clients[0]: name, ipv4, ipv6, os, arch, cpu_cores, region ...
  const client = event.clients[0];
  const text = `${event.emoji} ${client.name}\n`
    + `IP: ${client.ipv4}\n`
    + `OS: ${client.os}\n`
    + `Event: ${event.event}\n`
    + `Time: ${event.time}`;
  return await sendMessage(text, event.event);
}
```

### 通知模板

当使用非 JavaScript 发送器时，通知内容由 **通知模板** 控制（设置 → 通知中自定义）：

```
{{emoji}}{{emoji}}{{emoji}}
事件：{{event}}
服务器：{{client}}
消息：{{message}}
时间：{{time}}
```

可用变量：`{{emoji}}`（事件图标）、`{{event}}`（事件类型）、`{{client}}`（服务器名称）、`{{message}}`（详细消息）、`{{time}}`（事件时间）

---

## 🗑️ 探针卸载指南

### 场景一：真实 VPS（systemd 服务）

```bash
sudo systemctl stop komari-agent
sudo systemctl disable komari-agent
sudo rm /etc/systemd/system/komari-agent.service
sudo systemctl daemon-reload
sudo rm -rf /opt/komari
```

### 场景二：纯容器/PaaS（nohup 模式）

```bash
/opt/komari/agent.sh stop
rm -rf /opt/komari
```

---

## ✨ 相比原版的改进

| 改进项 | 原版表现 | 本仓库改进 |
| :--- | :--- | :--- |
| **NAT 类型检测** | 无此功能 | 客户端内置 STUN 探测，自动获取 NAT 类型并拼接到 OS 信息后方展示 |
| **离线通知宽限期** | 断连重连时高频误报 | 重写抢占锁同步机制，重连时宽限期定时器被完美清空 |
| **容器内 CPU 小数核心** | int 类型，0.25 核显示为 1 核 | float64 精度支持，正确展示 fractional CPU |
| **Cgroup 内存限制识别** | 读物理内存 | 支持读取 cgroup 真实内存限额与占用率 |
| **Telegram 通知增强** | 仅上下线名字 | 富文本：IP、OS+架构、Region、CPU、事件时间 |
| **非 Root 部署** | 强制 Root | 完善非 root 安装指导，脚本重定向至本 fork |
| **一体化 Docker** | 仅有面板 | 集成 ttyd + Nginx + Cloudflare Tunnel，专为 PaaS 设计 |
| **跨平台静态编译** | 需在线编译 | Zig 交叉编译 `linux/amd64` + `linux/arm64` |
| **图片直传** | 仅 URL | 支持直接上传图片文件（≤10MB），自动填入 URL |
| **签到目标日期** | 简单签到 | 支持签到目标日期、间隔、提醒天数/频率 |
| **点亮全球地图** | 无 | Dashboard 在线/离线节点颜色标记，统计卡片 |
| **主题管理增强** | 基础设置 | 上传主题包，动态渲染配置界面，select-with-custom 支持 |
| **Cookie 安全** | session token 明文 HTTP 传输 | Secure flag 动态判断 HTTPS（仅 HTTPS 下发），HttpOnly + SameSite=Lax |
| **SQLite 稳定性** | 无 busy timeout，并发写入易死锁 | `_busy_timeout=5000` + `_txlock=immediate` + `SetMaxOpenConns(1)` 防止 database is locked |
| **终端 2FA Sudo Token** | 无 | 终端入口可选 2FA 验证（`Sudo2FaRequired` 默认关闭，需要时在设置中开启）；验证一次后全站 1 小时免密 |
| **登录限速** | 无 | IP+用户名组合键限速，三档锁定期（5→5min / 10→30min / 15→2h） |

---

<img width="1815" height="896" alt="screenshot" src="https://github.com/user-attachments/assets/b4241e9f-1536-4d62-b643-587928c4f6a2" />
