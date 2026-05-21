# Docker Image Comparison / 镜像对比

Komari 生态中目前有 3 个相关的 Docker 镜像，适用于不同的部署场景。

| 对比项 | ① 官方原版 `ghcr.io/komari-monitor/komari` | ② Fork 服务端 `ghcr.io/zv201413/komari_new` | ③ 一体镜像 `ghcr.io/zv201413/komari_ttyd` |
|:---|:---|:---|:---|
| **维护者** | komari-monitor (上游) | zv201413 (本 Fork) | zv201413 (本 Fork) |
| **构建源** | 上游 release-docker.yml | Fork release-docker.yml | Fork docker-build.yml (Komari_ttyd 仓库) |
| **前端来源** | upstream komari-web | fork komari-web_new | fork komari-web_new |
| **NAT 类型显示** | ❌ 无 | ✅ 有 (OS 行内) | ✅ 有 |
| **TCP CC 显示** | ❌ 无 | ✅ 有 (bbr 等) | ✅ 有 |
| **CPU 小数核** | ❌ int 截断 | ✅ float64 精确 | ✅ float64 精确 |
| **离线通知修复** | ❌ 偶发误报 | ✅ 已修复 | ✅ 已修复 |
| **Cgroup 内存** | ❌ 读物理内存 | ✅ 读 cgroup 限额 | ✅ 读 cgroup 限额 |
| **非 Root 支持** | ❌ 强制 root | ✅ 自动降级 nohup | ✅ 自动降级 nohup |
| **ttyd 网页终端** | ❌ 无 | ❌ 无 | ✅ 内置 (多端口) |
| **Cloudflare Tunnel** | ❌ 无 | ❌ 无 | ✅ 内置 |
| **Nginx 反向代理** | ❌ 无 | ❌ 无 | ✅ 内置 |
| **Supervisor 进程管理** | ❌ 单进程 | ❌ 单进程 | ✅ 多进程管理 |
| **暴露端口** | 25774 | 25774 | 80 + 7681+ (自定义) |
| **编译方式** | Go 原生编译 | Zig 静态交叉编译 | Zig 静态交叉编译 |
| **适用场景** | 自建 VPS / 手动部署 | 需要 fork 特性的自建用户 | PaaS 平台 / 一体化部署 |

## 选型建议 / Recommendation

- **我只是需要监控，不需要额外功能** → 用 ① 官方原版
- **我需要 NAT 检测 / TCP CC / CPU 小数核等 fork 特性** → 用 ② Fork 服务端
- **我需要开箱即用的一体化方案（面板 + 终端 + Tunnel）** → 用 ③ Komari_ttyd

## 构建说明 / Build Notes

### 镜像 ② 构建方式
由 `komari_new` 仓库的 `release-docker.yml` 自动构建。触发条件：
- GitHub Release 发布时自动触发
- 也可手动 workflow_dispatch

```bash
docker pull ghcr.io/zv201413/komari_new:latest
```

### 镜像 ③ 构建方式
由 `Komari_ttyd` 仓库的 `docker-build.yml` 自动构建。触发条件：
- push 到 `main` 分支
- 手动 workflow_dispatch

```bash
docker pull ghcr.io/zv201413/komari_ttyd:latest
```

> ⚠️ **注意**: 两个 Fork 镜像的版本号都写死为 `"latest"`，实际代码版本取决于构建时 `main` 分支的内容。如需追踪具体版本，请查看对应仓库的 GitHub Release。
