# Komari_ttyd

> **Komari 生态**: [`komari_new`](https://github.com/zv201413/komari_new) (服务端) · [`komari-agent_new`](https://github.com/zv201413/komari-agent_new) (探针) · **`Komari_ttyd`** (本仓库, Docker 一体镜像) · [`komari-web_new`](https://github.com/zv201413/komari-web_new) (前端 UI 源码)

高度精简的 Docker 镜像，在极低资源占用的前提下，同时运行 **Komari 监控面板** 与 **网页终端（TTYD）**。

本镜像由 fork 仓库构建，相比上游 komari-monitor 有大量增强。👉 [查看完整增强特性说明](https://github.com/zv201413/komari_new/blob/main/docs/features.md)

| 功能 | 上游 Komari | 本 Fork 增强 |
|------|:---:|------|
| 🔐 登录会话 | 固定时长 | 自定义"记住我"天数（1–365），不勾选则会话级 Cookie；IP 白名单免 2FA |
| 🌐 全局时区 | ❌ | 后台配置 IANA 时区，全站时间显示统一 |
| 🖼️ 图片直传 | ❌ | 背景图 / Logo 直传服务器，无需外部图床 |
| 📱 横竖屏背景 | ❌ | 桌面 / 移动端独立设置，支持亮 / 暗双图 |
| ✅ 签到管理 | ❌ | 截止日期 / 间隔 / 提醒，Dashboard 显示状态 |
| 🌐 NAT 类型检测 | ❌ | Agent 基于 STUN 自动检测并在面板展示 |
| 🗺️ 点亮全球地图 | ❌ | Dashboard 顶部标记所有节点地理位置 |
| 🖥️ 系统信息 | 基础 | TCP 拥塞算法、CPU 浮点核数、cgroup 内存、负载 |
| 🔧 Agent | 基础 | 非 Root 安装、内置自动更新、三层保活 |
| 📦 Docker 镜像 | 基础 | 集成 ttyd 网页终端 + Cloudflare Tunnel + Nginx |

<img width="1815" height="896" alt="screenshot" src="https://github.com/user-attachments/assets/b4241e9f-1536-4d62-b643-587928c4f6a2" />

<img width="1920" height="904" alt="image" src="https://github.com/user-attachments/assets/a076ed2c-1eeb-4299-bcb1-593556c808d7" />


## 🚀 快速部署

### Northflank（最简单，自带 SSL）

1. 创建 Service，选择 Docker image 模式：

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/komari_ttyd:latest` |
| **端口 1** | `80`（Komari 面板，经容器内 Nginx） |
| **端口 2** | `7681`（TTYD 网页终端） |
| **持久化存储** | 挂载路径 `/app/data`（必填） |

| 环境变量 | 示例值 | 说明 |
|--------|----|------|
| **`USER_PWD`** | `admin:你的密码` | 面板管理员账号，仅首次部署生效 |
| `TTYD_P0` | `7681:admin:密码` | 网页终端 Basic Auth（`port:用户名:密码`） |
| `TTYD_P1` | `7682:user2:密码2` | 第二个终端（可继续 `TTYD_P2`...） |

> ⚠️ **对外端口必须是 `80`，不要填 `25774`**。`25774` 是容器内 komari 进程的监听端口，
> 平台直接暴露它会**旁路 Nginx** —— 于是 komari 只能看到平台负载均衡的内网地址
> （`10.x.x.x`），导致 **IP 白名单永久失效、登录限速可被绕过、审计日志记错 IP**。
> 走 `80` 才有 Nginx 还原真实客户端 IP 再交给 komari。

### ☁️ 其他 PaaS（Justrunmy.app / Zeabur 等）

不提供 SSL 或不能暴露多端口时，推荐配合 Cloudflare Tunnel。详见：[高级用法指南](./ADVANCED_GUIDE.md#☁️-cloudflare-tunnel-详细配置指南)

### 💻 自建服务器

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

访问 `http://你的IP:8000` 进入面板。

---

## 🔐 首次登录 & 密码管理

**必须设置管理员密码，不设密码不会启动。** `USER_PWD` 仅在首次部署（数据库为空）时生效，后续以数据库内密码为准。

> ⚠️ 必须挂载持久卷到 `/app/data`，否则每次重启数据库重建，密码丢失。

详见：[密码持久化深度逻辑](./ADVANCED_GUIDE.md#🧠-密码持久化深度逻辑)

---

## 🛡️ IP 白名单（免 2FA 登录）

登录面板 → **设置** → **登录** → **IP 白名单**：添加受信任的 IP，之后从该 IP 登录时**免输 2FA 动态码**。

| 行为 | 是否需要 2FA |
|------|:---:|
| 从白名单 IP 登录 | ❌ 免输动态码 |
| 从其他 IP 登录 | ✅ 正常校验 |
| **增删白名单本身** | ✅ 强制校验 |
| 网页终端（ttyd / xterm） | ✅ 不受白名单影响，仍走 `sudo_token` |

> ⚠️ **反代部署必读**：白名单比对的是 `c.ClientIP()`，等价于容器内 Nginx 还原出的
> `$remote_addr`。Nginx 按部署方式自动选择还原规则（`entrypoint.sh` 生成）：
>
> | 部署方式 | 采信的请求头 | 信任的 TCP 对端 |
> |------|------|------|
> | 设了 `TUNNEL_TOKEN`（Cloudflare Tunnel） | `CF-Connecting-IP` | `127.0.0.1`、`::1` |
> | 未设（Northflank / 爪云 / Zeabur 等平台 LB） | `X-Forwarded-For` | 私有网段 `10/8`、`172.16/12`、`192.168/16` |
>
> 两个环境变量可覆盖：`REAL_IP_HEADER`、`TRUSTED_PROXY_CIDR`（逗号分隔多个网段）。
> 信任范围**故意写窄**：只有 TCP 对端落在可信网段时 Nginx 才采信请求头，
> 否则任何人都能伪造 `X-Forwarded-For` 冒充白名单 IP。别改成 `0.0.0.0/0`。

**排查：白名单加了却仍要输 2FA**

看后台「审计日志」里 `login` 那行记的 IP：

| 日志中的 IP | 含义 | 修法 |
|------|------|------|
| 你的公网 IP | 还原正常 | 确认白名单里加的是**这个** IP，而非从别处查到的 |
| `10.x` / `172.x` / `192.168.x` | 拿到的是反代内网地址，白名单必然失效 | 见下 |

内网地址说明真实 IP 没还原成功，按顺序查：

1. **平台对外端口是不是 `80`** —— 填 `25774` 会旁路 Nginx，这是最常见的原因
2. **平台到底传了哪个头** —— 进容器临时加个探测端点：

   ```bash
   cp /etc/nginx/http.d/default.conf /tmp/bak.conf
   sed -i '/client_max_body_size/a \    location = /_debug_ip { default_type text/plain; return 200 "remote_addr=$remote_addr\\nXFF=$http_x_forwarded_for\\nCF=$http_cf_connecting_ip\\n"; }' /etc/nginx/http.d/default.conf
   nginx -t && nginx -s reload
   ```

   访问 `https://你的域名/_debug_ip`：
   - 返回面板首页而非纯文本 → 流量没进 Nginx，回第 1 步
   - `XFF=` 是公网 IP 而 `remote_addr=` 是内网 → 正常，说明配置已生效
   - 两者都是内网、且各头皆空 → 平台未透传，只能改用 Cloudflare Tunnel

   查完务必还原：`cp /tmp/bak.conf /etc/nginx/http.d/default.conf && nginx -s reload`

> 未启用 2FA 的账号：白名单不产生任何效果（本来就不需要动态码）。

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
