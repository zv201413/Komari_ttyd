# Komari_ttyd

> **Komari 生态**: [`komari_new`](https://github.com/zv201413/komari_new) (服务端) · [`komari-agent_new`](https://github.com/zv201413/komari-agent_new) (探针) · **`Komari_ttyd`** (本仓库, Docker 一体镜像) · [`komari-web_new`](https://github.com/zv201413/komari-web_new) (前端 UI 源码)

这是一个高度精简的 Docker 镜像，在极低资源占用的前提下，同时运行 **Komari 监控面板** 与 **网页终端（TTYD）**。

> **探针监控说明**：
> 为了保证容器在各大 PaaS 平台上的极致兼容性，本镜像**已剔除**内置的 Komari Agent。如需监控服务器：
> 1. **真实的 VPS / 虚拟机**：请直接使用官方后台复制的原始命令（`wget ... install.sh`）在宿主机运行，依赖 `systemd` 最稳定。
> 2. **PaaS 平台 / 纯容器环境**：脚本自动检测无 systemd 时切换为 nohup 后台模式，无需转换。

<img width="1940" height="643" alt="image" src="https://github.com/user-attachments/assets/0b7b301b-c35a-4551-a628-17667712c88d" />


---

## 🚀 推荐部署方案：Northflank（最简单，自带 SSL）

Northflank 会自动为应用分配带 HTTPS 的专属域名。**不需要配置 Tunnel，也不需要搞证书**，这是最推荐的部署方式。

### 1. 创建应用 (Service)

在 Northflank 创建一个 Service，选择 Docker image 模式，并按以下参数配置：

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/komari_ttyd:latest` |
| **端口 1 (Port)** | `80` (用于访问 Komari 面板) |
| **端口 2 (Port)** | `7681` (如果需要用到 TTYD 网页终端) |
| **持久化存储 (Volume)** | 挂载路径填 `/app/data`（必填，否则容器重启面板数据全丢） |

**环境变量 (Variables)**：

| 变量名 | 值 | 说明 |
|--------|----|------|
| `ADMIN_USERNAME` | `admin` | 面板登录账号（可选，不设默认随机生成） |
| `ADMIN_PASSWORD` | `你的复杂密码` | 面板登录密码（可选，不设默认随机生成） |
| `TTYD_P1` | `7681:admin:你的密码` | 网页终端账号密码（需要 TTYD 时填写） |

### 2. 访问面板

部署成功后，查看 Northflank 分配的域名（通常在右上角）：
- **Komari 面板**：`https://xxx.northflank.app`
- **TTYD 终端**：`https://xxx.northflank.app:7681` （如果启用了端口 2）

---

## ☁️ 其他 PaaS 平台（如 爪云, Zeabur 等）

如果平台不自动提供 SSL 域名，或者不支持暴露多个端口，推荐使用 **Cloudflare Tunnel** 进行内网穿透。

### 前置准备：获取 Tunnel Token
1. 登录 Cloudflare Zero Trust 面板。
2. 导航到 **Networks** → **Tunnels** → **Add a tunnel** (选择 Cloudflared)。
3. 在 Public Hostname 页面点击 **Save tunnel**。
4. 回到列表，点击该隧道对应的 `...` 菜单 → **View tunnel token**。
5. 复制那串 `eyJ...` 开头的极长字符。**切记保密**。

### 平台配置

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/komari_ttyd:latest` |
| **持久化目录** | 挂载到 `/app/data` |
| **环境变量** | `TUNNEL_TOKEN=eyJh...` (你的 Token)<br>`TTYD_P1=7681:admin:密码`<br>`ADMIN_USERNAME=admin`<br>`ADMIN_PASSWORD=密码` |

**配置域名解析**：
去 Cloudflare Tunnel 面板的 Public Hostname 里，添加两条记录：
- `komari.你的域名.com` → 指向 `http://localhost:80`
- `ttyd.你的域名.com` → 指向 `http://localhost:7681`

---

## 💻 自建服务器部署 (Docker)

如果你有自己的 VPS，直接一条命令跑起来即可（也可搭配 Tunnel 使用）：

```bash
docker run -d --name komari \
  --restart unless-stopped \
  -p 8000:80 \
  -p 7681:7681 \
  -v /opt/komari/data:/app/data \
  -e ADMIN_USERNAME=admin \
  -e ADMIN_PASSWORD=你的复杂密码 \
  -e TTYD_P1=7681:admin:你的终端密码 \
  ghcr.io/zv201413/komari_ttyd:latest
```

*(访问 `http://你的IP:8000` 即可进入面板。)*

---

## 🔐 首次登录必看

Komari 强调安全性，**没有固定的默认密码**。

### 方式一：指定环境变量（推荐）
在部署时直接通过环境变量写死账号密码：
- `ADMIN_USERNAME=admin`
- `ADMIN_PASSWORD=你的复杂密码`

### 方式二：查看随机生成的密码
如果你部署时没填环境变量，Komari 会在初次启动时随机生成密码。去你的部署平台查看 **容器日志 (Logs)**，寻找以下字样：
```text
Admin username: admin
Admin password: xxxxxx
```

---

## 🔔 配置 Telegram 通知

Komari 内置通知系统，支持在服务器上下线时通过 Telegram 发送通知消息（v1.3.0+ 消息包含 IP、OS、地区、CPU 等详细信息）。

### 方式一：内置 Telegram 发送器（推荐）

登录 Komari 面板后：

1. 进入 **设置 (Settings)** → **通知 (Notifications)**
2. 开启 **启用通知 (Enable Notifications)**
3. **通知方式 (Notification Method)** 选择 `telegram`
4. 点击 **编辑配置 (Edit Configuration)**，填入：

| 参数 | 值 |
|------|------|
| `bot_token` | `你的BOT_TOKEN` |
| `chat_id` | `你的CHAT_ID` |
| `endpoint` | `https://api.telegram.org/bot`（默认，无需修改） |
| `message_thread_id` | 留空（仅超级群组话题需要） |

5. 保存配置后，点击 **测试 (Test Send)** 验证是否收到消息

### 方式二：JavaScript 发送器（高级）

如果需要更灵活的消息格式（自定义排版、多平台通知等），可选择 `Javascript` 通知方式，编写自定义 JS 脚本：

```javascript
async function sendMessage(message, title) {
  // 发送普通文本消息
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
  // event 对象包含: event, clients, message, time, emoji
  // clients[0] 包含完整客户端信息: name, ipv4, ipv6, os, arch, cpu_cores, region 等
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

当使用非 JavaScript 发送器（如内置 telegram）时，通知内容由 **通知模板 (Notification Template)** 控制。可在面板 **设置 → 通知** 中找到并自定义。

默认模板格式示例：
```
{{emoji}}{{emoji}}{{emoji}}
事件：{{event}}
服务器：{{client}}
消息：{{message}}
时间：{{time}}
```

可用变量：

- `{{emoji}}` — 事件图标（🔴 🟢 🆕）
- `{{event}}` — 事件类型（offline / online / registered）
- `{{client}}` — 服务器名称
- `{{message}}` — 详细消息（含 IP、OS、地区、CPU 等信息，v1.3.0+）
- `{{time}}` — 事件时间

---

## 🛠 高级设置：多个 TTYD 终端

如果需要开多个相互独立的网页终端供不同用户使用，可以继续添加环境变量：

```bash
TTYD_P1=7681:admin:密码1
TTYD_P2=7682:user2:密码2
TTYD_P3=7683:user3:密码3
```
*注意：增加端口后，记得在部署平台或 Cloudflare Tunnel 中放行对应的端口号。*

---

## 🗑️ 探针卸载指南

如果你按照本说明在宿主机或容器中安装了探针（Komari Agent），请根据你的**安装方式**选择卸载步骤：

### 场景一：真实 VPS（使用官方脚本安装的 systemd 服务）
如果你在 VPS 上运行了官方安装脚本，探针已经注册为系统服务。

**彻底卸载步骤**：
```bash
# 1. 停止并禁用服务
sudo systemctl stop komari-agent
sudo systemctl disable komari-agent

# 2. 删除服务配置文件
sudo rm /etc/systemd/system/komari-agent.service
sudo systemctl daemon-reload

# 3. 删除探针老巢（极其重要）
sudo rm -rf /opt/komari
```

### 场景二：纯容器/PaaS（使用通用安装命令或 nohup 模式）
如果你是在无 systemd 的容器/PaaS 中使用通用安装脚本安装的，Agent 以 nohup 后台模式运行。

**彻底卸载步骤**：
```bash
# 1. 使用管理脚本停止（推荐）
/opt/komari/agent.sh stop

# 2. 删除整个安装目录
rm -rf /opt/komari
```
