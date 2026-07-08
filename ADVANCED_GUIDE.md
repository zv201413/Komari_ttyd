# Komari_ttyd 高级用法与原理指南

本指南包含 `Komari_ttyd` 的进阶配置选项、自定义脚本编写以及系统底层的持久化逻辑等内容。如果你只是想快速部署并使用基本功能，请参阅主页的 [README.md](./README.md)。

---

## ☁️ Cloudflare Tunnel 详细配置指南

如果你的部署平台（如爪云、Zeabur 等）不提供 SSL，或者不能暴露多个端口，推荐使用 Cloudflare Tunnel 将面板和 TTYD 安全地暴露到公网。

### 前置准备：获取 Tunnel Token
1. 登录 [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. 导航到 **Networks** → **Tunnels** → 点击 **Add a tunnel** (选择 Cloudflared)
3. 命名隧道并在 Public Hostname 页面点击 **Save tunnel**
4. 回到隧道列表，点击对应隧道的 `...` 菜单 → **View tunnel token**
5. 复制弹窗中 `eyJ...` 开头的 Token 字符串。

### 部署配置
在你的平台上部署镜像 `ghcr.io/zv201413/komari_ttyd:latest`，并设置以下环境变量：
- `TUNNEL_TOKEN=eyJh...` （刚才复制的 Token）
- `TTYD_P0=7681:admin:你的终端密码`
- `USER_PWD=admin:你的面板密码`

（务必记得将 `/app/data` 挂载为持久化目录）

### 配置域名解析规则
回到 Cloudflare Tunnel 的 **Public Hostname** 标签页，添加以下路由规则：
- **Komari 面板**：`komari.你的域名.com` → `http://localhost:80`
- **TTYD 终端**：`ttyd.你的域名.com` → `http://localhost:7681`

通过以上配置，你的流量将经过 Cloudflare 加密网络，安全且无需自行申请证书。

---

## 🧠 密码持久化深度逻辑

在配置管理员账号时，理解系统如何处理密码优先级非常重要：

1. **种子密码阶段**：环境变量 `USER_PWD`（或旧版 `ADMIN_PASSWORD`）被视为**种子密码**。它**仅仅**在数据库为空时（即第一次启动且未初始化过用户）生效。
2. **数据库接管阶段**：一旦系统启动，种子密码将被加密并写入 SQLite 数据库。此后，如果你通过面板 UI 修改了密码，**数据库记录的优先级将永远高于环境变量**。即使你重启容器并更改了 `USER_PWD`，只要挂载了数据库文件，系统也会忽略环境变量，继续使用你在后台修改的密码。
3. **数据丢失警告**：如果你没有将 `/app/data` 挂载为持久化目录，每次容器重启时，系统都会发现数据库为空，从而重新读取 `USER_PWD` 并重建数据库。这将导致你丢失所有历史数据和用户配置。
4. **鉴权排障**：如果你遇到了“鉴权失败”且确定环境变量没写错，通常是因为你在未挂载持久卷的情况下修改了密码，或者环境变量中包含了导致解析错误的特殊字符。

---

## 💻 JavaScript 自定义通知发送器 (高级)

除了内置的 Telegram 通知外，系统允许使用 `Javascript` 编写自定义脚本，适用于更复杂的排版、通知路由或是推送到钉钉/飞书等其他平台。

在 **设置 (Settings)** → **通知 (Notifications)** 中选择 `Javascript` 方式，并参考以下代码编写你的网关：

```javascript
// 发送消息到底层 API 的封装函数
async function sendMessage(message, title) {
  // 以 Telegram 为例，替换为你需要的任何 API 端点
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

// 系统触发的主入口函数，必须命名为 sendEvent
async function sendEvent(event) {
  /*
   * event 对象包含以下属性:
   * event: 事件类型字符串 (如 'login', 'offline')
   * time: 事件发生的时间戳
   * emoji: 事件对应的图标
   * message: 系统内置的简短消息说明
   * clients: 受影响的客户端数组
   */
  
  // 提取首个客户端信息
  // client 包含: name, ipv4, ipv6, os, arch, cpu_cores, region 等丰富属性
  const client = event.clients[0];
  
  // 组装自定义富文本
  const text = `${event.emoji} ${client.name}\n`
    + `IP: ${client.ipv4}\n`
    + `系统: ${client.os} (${client.arch})\n`
    + `触发事件: ${event.event}\n`
    + `时间: ${event.time}`;
    
  // 提交发送
  return await sendMessage(text, event.event);
}
```

---

## 📝 静态通知模板自定义指南

当你使用非 JavaScript 发送器（如原生 Telegram、Email）时，你依然可以通过修改**通知模板**来调整消息的格式。这位于设置页面的通知面板中。

**系统默认模板**：
```
{{emoji}}{{emoji}}{{emoji}}
事件：{{event}}
服务器：{{client}}
消息：{{message}}
时间：{{time}}
```

**可用插值变量**：
- `{{emoji}}`：事件图标（离线通常是 🔴，上线是 🟢）
- `{{event}}`：事件类型文本
- `{{client}}`：触发该事件的服务器名称（支持多个时逗号分隔）
- `{{message}}`：详细消息附带说明
- `{{time}}`：格式化后的本地事件时间

你可以随意调整这些变量的顺序或添加 Markdown / HTML 标签（具体取决于你的发送方通道是否支持富文本解析）。
