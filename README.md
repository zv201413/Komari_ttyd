# Komari_ttyd

一个 Docker 镜像，同时运行 **Komari 监控面板 + 网页终端（TTYD）**，通过 Cloudflare Tunnel 对外暴露，**不需要公网 IP，不需要开放端口，不需要买服务器**。

---

## 这是什么？

这个镜像把几个工具打包到一起：

| 组件 | 干什么用的 |
|------|-----------|
| **Komari** | 服务器监控面板，监控 CPU、内存、硬盘、流量等 |
| **Nginx** | 转发请求（Komari 和 TTYD 的流量都经过它） |
| **cloudflared** | Cloudflare 隧道，让外网能访问，但不暴露你的 IP |
| **TTYD** | 网页版终端，直接在浏览器里 SSH 进容器 |
| **Supervisor** | 管理上面 4 个进程，挂了自动重启 |

### 架构图

```
你访问 komari.你的域名.com
        ↓
    Cloudflare（自动处理 HTTPS 证书）
        ↓
    cloudflared 隧道（通过 Tunnel Token 连接）
        ↓
    nginx → Komari（端口 25774）
        ↓
    ttyd（端口 7681、7682...）
```

**优点**：你的服务器不用开任何端口，流量全走 Cloudflare，安全又省事。

---

## 准备工作（必须做的两件事）

### 1️⃣ 有一个 Cloudflare 账号

去 [https://dash.cloudflare.com](https://dash.cloudflare.com) 注册（免费的就行）。

### 2️⃣ 拿到 Tunnel Token（一串以 eyJ... 开头的字符）

不知道怎么拿？按下面步骤：

1. 打开 [https://one.dash.cloudflare.com](https://one.dash.cloudflare.com)
2. 左侧菜单 → **Networks** → **Tunnels**
3. 点 **Add a tunnel** → 选 **Cloudflared** → 起个名字（比如 `komari`）
4. 到了 **Install connectors** 页面，直接拉到下面点 **Next**
5. 在 **Public Hostname** 页面先点 **Save tunnel**
6. 回到隧道列表，点你刚创建的隧道，右上角有个 **...** → **View tunnel token**
7. 复制那串以 `eyJ...` 开头的字符

> 这串 token 是容器连接 Cloudflare 的钥匙，**不要泄露给别人**。

---

## 环境变量（配置参数）

部署时需要填以下参数：

| 变量 | 必填 | 说明 |
|------|------|------|
| `TUNNEL_TOKEN` | ✅ | 上面拿到的那串 eyJ... 开头的 token |
| `TTYD_P1` | ❌ | 网页终端，格式 `端口:用户名:密码` |
| `TTYD_P2` | ❌ | 第二个网页终端（支持 P3、P4...） |

### 示例

```bash
# 最少只需要填这一个
TUNNEL_TOKEN=eyJhIjoi...

# 如果需要网页终端，加上
TTYD_P1=7681:admin:123456
TTYD_P2=7682:root:abcdef
```

---

## 部署

### 方式一：在 PaaS 平台部署（推荐新手）

适用：爪云、justrunmy.app、Zeabur 等。

1. **创建应用**，填入：

   | 设置项 | 填什么 |
   |--------|--------|
   | 镜像地址 | `ghcr.io/zv201413/komari_ttyd/komari-ttyd:latest` |
   | 端口 | `80` |
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

### 方式二：在自己的服务器上运行

```bash
docker run -d --name komari \
  -p 80:80 \
  -v /app/data:/app/data \
  -e TUNNEL_TOKEN=eyJhIjoi... \
  -e TTYD_P1=7681:admin:123456 \
  ghcr.io/zv201413/komari_ttyd/komari-ttyd:latest
```

---

## 首次登录

1. 打开 `https://komari.你的域名.com`
2. **账号密码在哪看？** 这步不同方式不一样：
   - **PaaS 平台**：去平台的控制台看容器日志，里面有 `admin` 的初始密码
   - **自建服务器**：执行 `docker logs komari 2>&1 \| grep -i "admin"`
3. 登录后**立即修改密码**（点右上角头像 → 设置）
4. 接下来可以添加服务器（Agent）进行监控了

---

## 添加更多 TTYD（网页终端）

想开多个终端窗口？加环境变量就行：

```bash
TTYD_P1=7681:admin:密码1
TTYD_P2=7682:user2:密码2
TTYD_P3=7683:user3:密码3
```

每加一个，Cloudflare 面板里加一条 Public Hostname：

| 域名 | 服务 |
|------|------|
| `ttyd1.你的域名.com` | `localhost:7681` |
| `ttyd2.你的域名.com` | `localhost:7682` |

---

## 常见问题

### Q：怎么知道我部署成没成功？

等 1-2 分钟后，打开 `https://komari.你的域名.com`。如果能打开页面，说明成功了。

### Q：页面打不开，显示 502 / 524 / 超时？

1. 检查 `TUNNEL_TOKEN` 有没有填对（少一个字母都不行）
2. 检查 Cloudflare 面板里 Public Hostname 配了没
3. 去 PaaS 平台看日志，有没有报错

### Q：TTYD 登录不上？

确认用户名密码跟 `TTYD_P1` 里填的一致。注意冒号是英文 `:` 不是中文 `：`。

### Q：怎么更新到最新版本？

PaaS 平台一般点重新部署就行。自建服务器：

```bash
docker pull ghcr.io/zv201413/komari_ttyd/komari-ttyd:latest
docker stop komari && docker rm komari
# 重新运行上面的 docker run 命令
```

### Q：用 Komari 自带的 cloudflared 可不可以？

镜像默认用外部的 cloudflared。如果要用 Komari 自带的，设 `KOMARI_ENABLE_CLOUDFLARED=true`，但这时**不需要**填 `TUNNEL_TOKEN`（两条隧道会冲突，二选一）。

---

## 构建自己的镜像

如果你改了代码想自己构建：

```bash
git clone https://github.com/zv201413/Komari_ttyd.git
cd Komari_ttyd
docker build -t komari-ttyd .
```

或者 push 到 GitHub main 分支后，Actions 会自动构建推送到：

```
ghcr.io/zv201413/komari_ttyd/komari-ttyd:latest
```

---

## 跟 Nezha_ttyd 的区别

| | Nezha_ttyd | Komari_ttyd |
|--|-----------|-------------|
| 监控面板 | 哪吒监控 | Komari 监控 |
| 默认端口 | 8008 | 25774 |
| 数据目录 | `/opt/nezha/data` | `/app/data` |
