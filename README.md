# nginx-auto-ssl

基于 Docker Compose 的 Nginx + acme.sh 自动证书管理方案。启动时自动签发 Let's Encrypt 泛域名证书，之后每天自动检查续期，无需人工干预。

## 特性

- 🚀 **一键启动** — `docker compose up -d` 即可，无需额外初始化
- 🔒 **泛域名证书** — 自动签发 `domain` + `*.domain`，一个证书覆盖所有子域名
- 🌐 **多域名支持** — 分号分隔即可，每个域名独立证书、独立续期
- 🔄 **全自动续期** — acme.sh daemon 每天检查，到期自动续签并 reload nginx
- 🛡️ **DNS 验证** — 通过阿里云 DNS API 完成 DNS-01 验证，无需开放 80 端口
- 📦 **零依赖** — 只需要 Docker

## 前置条件

1. Docker 和 Docker Compose
2. 域名托管在阿里云 DNS
3. 阿里云 AccessKey（需要有 DNS 管理权限）

## 快速开始

### 1. 克隆仓库

```bash
git clone git@github.com:tianhe117/nginx-auto-ssl.git
cd nginx-auto-ssl
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`，填入你的阿里云密钥和域名：

```env
ALIYUN_AK_ID=your_aliyun_access_key_id
ALIYUN_AK_SECRET=your_aliyun_access_key_secret
DOMAINS=example1.com;example2.com
CERT_EMAIL=admin@example.com
```

- **DOMAINS** — 分号分隔的根域名列表，每个会自动签发 `domain + *.domain`
- **CERT_EMAIL** — Let's Encrypt 证书到期通知邮箱

### 3. 配置 Nginx

在 `conf.d/` 目录下创建 `<your-domain>.conf`，参考下方模板：

<details>
<summary><b>点击展开 Nginx 配置模板</b></summary>

```nginx
# ---- example1.com ----
server {
    listen 80;
    server_name example1.com www.example1.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name example1.com www.example1.com;

    # 证书路径 — 目录名 = 根域名
    ssl_certificate     /opt/nginx/certs/example1.com/fullchain.pem;
    ssl_certificate_key /opt/nginx/certs/example1.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 223.5.5.5 223.6.6.6 valid=300s;
    resolver_timeout 5s;

    root /usr/share/nginx/html;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}

# ---- example2.com ----
server {
    listen 80;
    server_name example2.com www.example2.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name example2.com www.example2.com;

    ssl_certificate     /opt/nginx/certs/example2.com/fullchain.pem;
    ssl_certificate_key /opt/nginx/certs/example2.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 223.5.5.5 223.6.6.6 valid=300s;
    resolver_timeout 5s;

    root /usr/share/nginx/html;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
```

</details>

### 4. 添加首页（可选）

在 `html/` 目录下放入你的静态文件。以下是一个测试页面：

<details>
<summary><b>点击展开 index.html 模板</b></summary>

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>It Works!</title>
  <style>
    body { font-family: system-ui, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f5f5f5; }
    .card { background: #fff; padding: 2rem 3rem; border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,0.08); text-align: center; }
    h1 { color: #2c3e50; margin-bottom: 0.5rem; }
    p { color: #7f8c8d; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🚀 Nginx + acme.sh is running!</h1>
    <p>TLS certificates managed automatically via Aliyun DNS challenge.</p>
  </div>
</body>
</html>
```

</details>

### 5. 启动

```bash
docker compose up -d
```

首次启动时，acme-sh 容器会：
1. 生成自签名临时证书（让 nginx 先起来）
2. 通过阿里云 DNS 验证签发 Let's Encrypt 证书
3. 安装证书并写入 `.ready` 标记
4. nginx 检测到标记后启动，加载真实证书

整个过程约 1-2 分钟。

### 6. 验证

```bash
curl -k https://localhost -H 'Host: your-domain.com'
```

访问 `https://your-domain.com` 确认证书生效。

## 目录结构

```
nginx-auto-ssl/
├── .env.example          # 环境变量模板
├── .gitignore            # 忽略 .env 和 certs/
├── docker-compose.yml    # nginx + acme-sh 双容器编排
├── conf.d/               # 在此放入你的 Nginx 配置
├── html/                 # 在此放入你的静态文件
└── scripts/
    ├── entrypoint.sh     # acme-sh 容器入口脚本
    ├── issue-cert.sh     # 手动签发额外证书
    └── cert-status.sh    # 查看证书到期时间
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `docker compose up -d` | 启动服务 |
| `docker compose logs -f acme-sh` | 查看 acme.sh 日志 |
| `docker compose logs -f nginx` | 查看 nginx 日志 |
| `docker compose restart nginx` | 重启 nginx |
| `./scripts/cert-status.sh` | 查看证书到期时间 |
| `./scripts/issue-cert.sh new-domain.com` | 新增域名并签发证书 |

## 新增域名

1. 编辑 `.env`，在 `DOMAINS` 中追加：

    ```env
    DOMAINS=example1.com;example2.com;new-domain.com
    ```

2. 在 `conf.d/default.conf` 中添加对应的 server 块

3. 重启：

    ```bash
    docker compose up -d
    ```

## 续期机制

acme-sh 容器以 daemon 模式运行，每天自动检查证书到期时间。距离到期不足 60 天时自动续签，续签成功后通过 `docker exec nginx nginx -s reload` 热加载 nginx，无需重启容器。

## License

MIT
