# Komari_ttyd

> **Komari 生态**: [`komari_new`](https://github.com/zv201413/komari_new) (服务端) · [`komari-agent_new`](https://github.com/zv201413/komari-agent_new) (探针) · **`Komari_ttyd`** (本仓库, Docker 一体镜像) · [`komari-web_new`](https://github.com/zv201413/komari-web_new) (前端 UI 源码)

高度精简的 Docker 镜像，在极低资源占用的前提下，同时运行 **Komari 监控面板** 与 **网页终端（TTYD）**。

本镜像由 fork 仓库构建，相比上游 komari-monitor 有大量增强。👉 [查看完整增强特性说明](https://github.com/zv201413/komari_new/blob/main/docs/features.md)

主要亮点：登录自定义记住天数、全局时区设置、签到管理、NAT 类型检测、点亮全球地图、图片直传、Agent 自动更新、终端 sudo-2FA 等。

<img width="1815" height="896" alt="screenshot" src="https://github.com/user-attachments/assets/b4241e9f-1536-4d62-b643-587928c4f6a2" />

## 🚀 快速部署

### Northflank（最简单，自带 SSL）

1. 创建 Service，选择 Docker image 模式：

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/komari_ttyd:latest` |
| **端口 1** | `25774`（Komari 面板） |
| **端口 2** | `7681`（TTYD 网页终端） |
| **持久化存储** | 挂载路径 `/app/data`（必填） |

| 环境变量 | 示例值 | 说明 |
|--------|----|------|
| **`USER_PWD`** | `admin:你的密码` | 面板管理员账号，仅首次部署生效 |
| `TTYD_P0` | `7681:admin:密码` | 网页终端 Basic Auth（`port:用户名:密码`） |
| `TTYD_P1` | `7682:user2:密码2` | 第二个终端（可继续 `TTYD_P2`...） |

> ⚠️ **端口变更（2026-07）**：面板端口由 `80` 改为 `25774`。老部署升级后若打不开面板，把平台端口配置从 80 改成 25774，或用 `KOMARI_LISTEN=0.0.0.0:80` 改回。

### ☁️ 其他 PaaS（爪云 / Zeabur 等）

不提供 SSL 或不能暴露多端口时，推荐配合 Cloudflare Tunnel。详见：[高级用法指南](./ADVANCED_GUIDE.md#☁️-cloudflare-tunnel-详细配置指南)

### 💻 自建服务器

```bash
docker run -d --name komari \
  --restart unless-stopped \
  -p 8000:25774 \
  -p 7681:7681 \
  -v /opt/komari/data:/app/data \
  -e USER_PWD=admin:你的复杂密码 \
  -e TTYD_P0=7681:admin:你的终端密码 \
  ghcr.io/zv201413/komari_ttyd:latest
```

访问 `http://你的IP:8000` 进入面板。

---

## 🔐 首次登录 & 密码管理

**必须设置管理员密码，不设密码不会启动。** `USER_PWD` 仅在首次部署（数据库为空）时生效，后续以数据库内密码为准。

> ⚠️ 必须挂载持久卷到 `/app/data`，否则每次重启数据库重建，密码丢失。

详见：[密码持久化深度逻辑](./ADVANCED_GUIDE.md#🧠-密码持久化深度逻辑)

---

## 🛠 TTYD 多终端配置

```bash
TTYD_P0=7681:admin:密码1
TTYD_P1=7682:user2:密码2
```

格式：`TTYD_P序号=端口:用户名:密码`。增加端口后记得在平台放行对应端口。

> 🔒 ttyd 未开启 HTTPS，建议通过 Nginx 反代或 Cloudflare Tunnel 暴露。

---

## 🔔 Telegram 通知

登录面板 → **设置** → **通知**：开启通知，方式选 `telegram`，填入 `bot_token`、`chat_id`、`endpoint`，保存后点测试验证。

详见：[自定义通知配置](./ADVANCED_GUIDE.md#💻-javascript-自定义通知发送器-高级)

---

## 🗑️ 探针卸载

```bash
# systemd 环境
sudo systemctl stop komari-agent && sudo systemctl disable komari-agent
sudo rm /etc/systemd/system/komari-agent.service && sudo systemctl daemon-reload
sudo rm -rf /opt/komari

# nohup 环境
/opt/komari/agent.sh stop && rm -rf /opt/komari
```
