# Komari_ttyd

> **Komari 生态**: [`komari_new`](https://github.com/zv201413/komari_new) (服务端) · [`komari-agent_new`](https://github.com/zv201413/komari-agent_new) (探针) · **`Komari_ttyd`** (本仓库, Docker 一体镜像) · [`komari-web_new`](https://github.com/zv201413/komari-web_new) (前端 UI 源码)

这是一个高度精简的 Docker 镜像，在极低资源占用的前提下，同时运行 **Komari 监控面板** 与 **网页终端（TTYD）**。

## 相比上游 komari-monitor 的差异

本镜像由 fork 仓库构建：服务端 [komari_new](https://github.com/zv201413/komari_new) · 探针 [komari-agent_new](https://github.com/zv201413/komari-agent_new) · 前端 [komari-web_new](https://github.com/zv201413/komari-web_new)（radix 分支）。

**服务端增强**
- 节点签到系统：target/interval 两种模式，到期提醒联动
- 登录限速器：IP|用户名组合键三阶梯锁定，信任代理 + X-Real-IP 防伪造
- 终端 sudo-2FA：登录时验过 2FA 即下发 sudo_token，开终端免重复输码（可开关）
- 流量校正：面板可直接设置真实已用流量（换算偏移量存储），上传/下载独立
- 动态月份续费（月末日期夹取）、节点前台隐藏（仅管理员可见）
- TCP 拥塞算法（tcp_cc）展示、图片上传接口

**探针增强**
- NAT 类型检测（--check-nat-type）、TCP 拥塞算法上报
- cgroup 感知的容器 CPU 配额核数
- 安装脚本：curl/wget 双通道下载、无 systemd 环境自动 nohup 兜底、--run-in-background；默认从本 fork 拉取

**前端（radix 分支）**
- PurCarte 前台布局与玻璃 UI/背景系统（多背景图、焦点/缩放、移动端独立背景、预览比例编辑器）
- 隐藏节点徽章、签到界面、sudo-2FA 对话框

**已同步的上游更新（2026-07）**
- metric store 存储引擎、REST→JSON-RPC 重构、安装向导与数据库恢复页
- xterm 6 与终端设置、每图表时间范围选择、非 root 安装（systemd user service）


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
| `TTYD_P0` | `7681:admin:你的密码` | 网页终端 Basic Auth（`port:用户名:密码`） |
| `TTYD_P1` | `7682:user2:密码2` | 第二个 TTYD 终端（可继续 `TTYD_P2`、`TTYD_P3`...） |

2. 部署成功后，查看 Northflank 分配的域名：
   - **Komari 面板**：`https://xxx.northflank.app`
   - **TTYD 终端**：Northflank 在 Service → Ports 标签页为额外端口分配独立 URL

### ☁️ 其他 PaaS 平台（爪云 / Zeabur 等）

如果平台不提供 SSL 或不能暴露多端口，推荐配合 **Cloudflare Tunnel**。
详细的 Tunnel 配置步骤，请参阅：[**高级用法与原理指南：Cloudflare Tunnel 配置**](./ADVANCED_GUIDE.md#☁️-cloudflare-tunnel-详细配置指南)

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

**必须设置管理员密码，不设密码不会启动。** 密码的环境变量仅在**首次部署**时生效，后续优先级以数据库内你修改的为准。
详细的密码持久化与覆盖逻辑，请参阅：[**高级用法与原理指南：密码持久化深度逻辑**](./ADVANCED_GUIDE.md#🧠-密码持久化深度逻辑)

### 设置管理员账号（必填）
```bash
USER_PWD=admin:你的复杂密码
```
> ⚠️ 必须挂载持久卷到 `/app/data`，否则每次重启数据库重建，密码会丢失。

---

## 🛠 TTYD 多终端配置

每个 TTYD 实例自带 **Basic Auth 鉴权**（`-c user:pass`），必须输入用户名和密码才能进入终端。

```bash
TTYD_P0=7681:admin:密码1
TTYD_P1=7682:user2:密码2
TTYD_P2=7683:user3:密码3
```
*格式：`TTYD_P序号=端口:用户名:密码`。增加端口后，记得在部署平台放行对应的端口号。*

> 🔒 **安全说明**：ttyd 未开启 HTTPS，建议通过 Nginx 反代或 Cloudflare Tunnel 暴露，避免明文传输密码。

---

## 🔔 Telegram 通知配置

Komari 内置通知系统，支持在服务器上下线时通过 Telegram 发送通知。
如需使用更高级的自定义 JS 通知网关或自定义排版模板，请参阅：[**高级用法与原理指南：自定义通知配置**](./ADVANCED_GUIDE.md#💻-javascript-自定义通知发送器-高级)

登录面板后 → **设置 (Settings)** → **通知 (Notifications)**：
1. 开启 **启用通知**
2. **通知方式** 选择 `telegram`
3. 点击 **编辑配置**，填入：

| 参数 | 值 |
|------|------|
| `bot_token` | `你的BOT_TOKEN` |
| `chat_id` | `你的CHAT_ID` |
| `endpoint` | `https://api.telegram.org/bot`（默认） |

4. 保存后点击 **测试 (Test Send)** 验证

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
| **一体化 Docker** | 仅有面板 | 集成 ttyd + Nginx + Cloudflare Tunnel，专为 PaaS 设计 |
| **跨平台静态编译** | 需在线编译 | Zig 交叉编译 `linux/amd64` + `linux/arm64` |
| **Cookie 安全** | session token 明文传输 | Secure flag 动态判断 HTTPS，HttpOnly + SameSite=Lax |
| **SQLite 稳定性** | 并发写入易死锁 | 注入 `_busy_timeout` 与单连接池防止 database is locked |
| **终端 2FA Sudo Token** | 无 | 终端入口可选 2FA 验证；验证一次后全站 1 小时免密 |
| **登录限速** | 无 | IP+用户名组合键限速，三档锁定期（5→5min / 10→30min / 15→2h） |

---

<img width="1815" height="896" alt="screenshot" src="https://github.com/user-attachments/assets/b4241e9f-1536-4d62-b643-587928c4f6a2" />
