# nginx-auto-ssl

Nginx + acme.sh 容器化方案，一键签发和自动续期 Let's Encrypt 泛域名证书。

## 特性

- 🚀 **一键初始化** — `./scripts/init-certs.sh` 启动 daemon、签发证书、拉起 nginx
- 🔒 **泛域名证书** — 每个根域名签发 `domain` + `*.domain`（SAN 证书）
- 🌐 **多域名** — 分号分隔，每个域名独立证书、独立续期
- 🔄 **全自动续期** — acme.sh daemon 每日检查，到期自动续签并信号触发 nginx reload
- 🛡️ **DNS 验证** — 阿里云 DNS API 完成 DNS-01 challenge，无需开放 80/443 端口
- 🔌 **无 docker.sock** — 通过共享 bind mount 信号文件实现 reload，无安全风险
- 🖥️ **主机可见** — 证书文件 bind mount 到 `./acme.sh/live/`，可直接查看

## 前置条件

- Docker + Docker Compose
- 域名托管在阿里云 DNS
- 阿里云 RAM AccessKey（需 DNS 管理权限）

## 快速开始

### 1. 克隆

```bash
git clone https://github.com/tianhe117/nginx-auto-ssl.git
cd nginx-auto-ssl
```

### 2. 配置

```bash
cp .env.example .env
```

编辑 `.env`：

```env
ALIYUN_AK_ID=your_aliyun_access_key_id
ALIYUN_AK_SECRET=your_aliyun_access_key_secret
DOMAINS=example1.com;example2.com
CERT_EMAIL=admin@example.com
```

| 变量 | 说明 |
|------|------|
| `ALIYUN_AK_ID` | 阿里云 AccessKey ID |
| `ALIYUN_AK_SECRET` | 阿里云 AccessKey Secret |
| `DOMAINS` | 分号分隔的根域名列表 |
| `CERT_EMAIL` | Let's Encrypt 通知邮箱 |

### 3. 添加 Nginx 配置

在 `conf.d/` 下创建 `<domain>.conf`，证书路径为 `/opt/certs/<domain>/`：

```nginx
# example1.com
server {
    listen 80;
    server_name example1.com www.example1.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name example1.com www.example1.com;

    ssl_certificate     /opt/certs/example1.com/fullchain.pem;
    ssl_certificate_key /opt/certs/example1.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;

    root /usr/share/nginx/html;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
```

> **路径规则**：`/opt/certs/<根域名>/fullchain.pem`，目录名必须和 `.env` 中的域名完全一致。

### 4. 启动

```bash
./scripts/init-certs.sh
```

首次运行流程：
1. 启动 acme-sh daemon 容器
2. 通过 `docker compose exec` 逐域名签发 Let's Encrypt 证书
3. 安装证书并写入 reload 信号
4. 启动 nginx 容器，等待证书就绪后开始服务

整个过程约 1-2 分钟。

### 5. 验证

```bash
curl -k https://localhost -H 'Host: your-domain.com'
# 或浏览器访问 https://your-domain.com
```

## 目录结构

```
nginx-auto-ssl/
├── .env.example              # 环境变量模板
├── .gitignore                # 忽略 .env 和 acme.sh/
├── docker-compose.yml        # nginx + acme-sh 双容器
├── conf.d/                   # Nginx server 配置
├── html/                     # 静态文件
├── acme.sh/                  # acme.sh 数据（bind mount，自动生成）
│   └── live/                 #   已签发证书 → nginx 只读挂载
│       ├── example1.com/
│       │   ├── fullchain.pem
│       │   └── privkey.pem
│       └── .nginx-reload     #   reload 信号文件
└── scripts/
    ├── init-certs.sh         # 首次初始化：启动 daemon → 签发证书 → 启动 nginx
    ├── nginx-entrypoint.sh   # nginx 容器入口：等待证书 → 启动 reload-watcher → 启动 nginx
    ├── reload-watch.sh       # 轮询 .nginx-reload 信号 → nginx -s reload
    ├── issue-cert.sh         # 为额外域名签发证书
    └── cert-status.sh        # 查看证书到期时间
```

## 架构

```
                    ┌──────────────────────────────────┐
                    │        ./acme.sh/  (bind mount)   │
                    │  ┌─ account/ ca/ ...              │
                    │  ├─ live/                         │
                    │  │   ├─ example.com/              │
                    │  │   │   ├─ fullchain.pem         │
                    │  │   │   └─ privkey.pem           │
                    │  │   └─ .nginx-reload             │
                    │  └─ ...                           │
                    └───────┬──────────────┬────────────┘
                            │ rw           │ ro
                    ┌───────▼──────┐ ┌─────▼──────────┐
                    │  acme-sh     │ │  nginx         │
                    │  (daemon)    │ │                │
                    │  /acme.sh    │ │  /opt/certs    │
                    │              │ │       │        │
                    │  cron:       │ │  reload-watch  │
                    │  每日检查续期  │ │  检测信号文件   │
                    │  续期 → 写入  │ │  → nginx -s    │
                    │  .nginx-     │ │    reload      │
                    │  reload      │ │                │
                    └──────────────┘ └────────────────┘
```

- **证书续期**：acme.sh daemon 内置 cron 每日检查，到期 < 60 天时自动续签
- **热加载**：续签后 `--reloadcmd` 写入时间戳到 `live/.nginx-reload`，nginx 侧 `reload-watch.sh` 每 10s 轮询检测变化，执行 `nginx -s reload`
- **无需 docker.sock**：两个容器共享 bind mount，信号文件是唯一通信方式

## 常用命令

| 命令 | 说明 |
|------|------|
| `./scripts/init-certs.sh` | 首次初始化并启动全栈 |
| `./scripts/cert-status.sh` | 查看证书到期时间 |
| `./scripts/issue-cert.sh new-domain.com` | 新增域名并签发证书 |
| `docker compose up -d` | 启动已有服务（不签发新证书） |
| `docker compose logs -f acme-sh` | 查看 acme.sh 日志 |
| `docker compose logs -f nginx` | 查看 nginx 日志 |
| `docker compose restart nginx` | 重启 nginx |
| `docker compose down` | 停止所有服务 |

## 新增域名

已运行后再添加新域名：

```bash
# 签发新域名证书
./scripts/issue-cert.sh new-domain.com

# 在 conf.d/ 中添加对应的 nginx server 块
# nginx 会自动检测并热加载
```

如果只是想扩展现有泛域名证书的子域名，无需任何操作 — `*.domain.com` 已覆盖。

## 常见问题

### 证书签发失败

检查 acme-sh 日志：

```bash
docker compose logs acme-sh
```

常见原因：
- 阿里云 AccessKey 权限不足（需要 DNS 管理权限）
- DNS 记录未在阿里云（域名不在阿里云解析）
- Let's Encrypt 速率限制（同一域名一周最多 5 张新证书）

### nginx 无法启动

nginx 在证书就绪前会等待最多 5 分钟。确保先运行了 `./scripts/init-certs.sh`。

### 查看证书详情

```bash
docker compose exec acme-sh acme.sh --list
```

## License

MIT
