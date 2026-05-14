# Komari_ttyd

All-in-one Docker image: **Komari + Nginx + Cloudflare Tunnel + TTYD**  
零端口暴露，一条隧道复用多个服务。

---

## 目录

- [架构](#架构)
- [环境变量](#环境变量)
- [快速开始（PaaS 部署）](#快速开始paas-部署)
- [快速开始（自建服务器）](#快速开始自建服务器)
- [Cloudflare Zero Trust 配置](#cloudflare-zero-trust-配置)
- [TTYD 多实例说明](#ttyd-多实例说明)
- [Komari 初始化](#komari-初始化)
- [构建镜像](#构建镜像)
- [与 Nezha_ttyd 的区别](#与-nezha_ttyd-的区别)

---

## 架构

```
Agent → Cloudflare(443) → Tunnel → cloudflared → nginx:80 → komari:25774
                                                      └─ ttyd:7681
                                                      └─ ttyd:7682 ...
```

所有服务通过**同一条 Cloudflare Tunnel** 暴露，不同域名映射不同端口。

---

## 环境变量

### 必须

| 变量 | 说明 |
|------|------|
| `TUNNEL_TOKEN` | Cloudflare Tunnel Token，同一条隧道可复用 |

### 可选

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TTYD_P1` | — | TTYD 实例，格式 `端口:用户名:密码` |
| `TTYD_P2` | — | 第二个 TTYD 实例（支持 P3、P4... 无限扩展） |
| `KOMARI_LISTEN` | `0.0.0.0:25774` | Komari 监听地址，一般无需修改 |
| `KOMARI_ENABLE_CLOUDFLARED` | `false` | 启用 Komari 内建 cloudflared 隧道（与本镜像的 cloudflared 冲突，建议保持 `false`） |

### 示例

```bash
TUNNEL_TOKEN=eyJhIjoi...
TTYD_P1=7681:admin:pass123
TTYD_P2=7682:root:pass456
```

---

## 快速开始（PaaS 部署）

适用平台：爪云、justrunmy.app 等支持自定义 Docker 镜像的 PaaS 平台。

1. **创建应用**，填写以下信息：

   | 字段 | 值 |
   |------|------|
   | 容器镜像 | `ghcr.io/zv201413/komari_ttyd/komari-ttyd:latest` |
   | 端口 | `80` |
   | 环境变量 | 按上表填写 `TUNNEL_TOKEN`、`TTYD_P1` 等 |

2. **Cloudflare Zero Trust 面板** → Networks → Tunnels → 点你的隧道 → 添加 Public Hostname：

   | 域名 | 服务 |
   |------|------|
   | `komari.你的域名.com` | `localhost:80` |
   | `ttyd.你的域名.com` | `localhost:7681` |

3. 部署完成后访问 `https://komari.你的域名.com` 进入 Komari 面板。

---

## 快速开始（自建服务器）

```bash
docker run -d --name komari \
  -p 80:80 \
  -v /app/data:/app/data \
  -e TUNNEL_TOKEN=eyJhIjoi... \
  -e TTYD_P1=7681:admin:pass123 \
  ghcr.io/zv201413/komari_ttyd/komari-ttyd:latest
```

---

## Cloudflare Zero Trust 配置

同一条隧道（同一个 `TUNNEL_TOKEN`），通过不同域名访问不同服务：

| 域名 | 服务 |
|------|------|
| `komari.你的域名.com` | `localhost:80` → nginx → komari:25774 |
| `ttyd1.你的域名.com` | `localhost:7681` |
| `ttyd2.你的域名.com` | `localhost:7682` |

配置路径：Cloudflare Zero Trust Dashboard → Networks → Tunnels → 点你的隧道 → 添加 Public Hostname。

---

## TTYD 多实例说明

支持任意数量的 TTYD 实例，格式统一：

```bash
TTYD_P1=7681:用户名:密码
TTYD_P2=7682:用户名:密码
TTYD_P3=7683:用户名:密码
```

Cloudflare 面板里为每个 TTYD 实例添加一条 Public Hostname 即可。

---

## Komari 初始化

首次启动后，访问 `https://komari.你的域名.com`：

1. 查看容器日志获取默认管理员账号密码：
   ```bash
   # 如果是自建服务器
   docker logs komari 2>&1 | grep -i "admin"
   ```
2. 首次登录后立即修改密码
3. 如需添加 Agent（被监控的服务器），在 Komari 面板中生成安装命令

---

## 构建镜像

### GitHub Actions 自动构建（推荐）

推送代码到 main 分支后，GitHub Actions 自动构建并推送到：

```
ghcr.io/zv201413/komari_ttyd/komari-ttyd:latest
ghcr.io/zv201413/komari_ttyd/komari-ttyd:<commit-sha>
```

### 手动构建

```bash
git clone https://github.com/zv201413/Komari_ttyd.git
cd Komari_ttyd
docker build -t komari-ttyd .
```

---

## 与 Nezha_ttyd 的区别

| | Nezha_ttyd | Komari_ttyd |
|--|-----------|-------------|
| 监控面板 | 哪吒面板 v2 | Komari v1.2.0 |
| 默认端口 | 8008 | 25774 |
| gRPC 代理 | ✅ nginx grpc_pass | ❌ 不需要（普通 HTTP） |
| 数据目录 | `/opt/nezha/data` | `/app/data` |
| 镜像仓库 | `ghcr.io/zv201413/nezha_ttyd/nezha-ttyd` | `ghcr.io/zv201413/komari_ttyd/komari-ttyd` |
