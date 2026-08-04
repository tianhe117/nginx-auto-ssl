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

编辑 `conf.d/default.conf`，将 `example1.com` / `example2.com` 替换为你的域名：

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name your-domain.com www.your-domain.com;

    ssl_certificate     /opt/nginx/certs/your-domain.com/fullchain.pem;
    ssl_certificate_key /opt/nginx/certs/your-domain.com/privkey.pem;
    ...
}
```

### 4. 启动

```bash
docker compose up -d
```

首次启动时，acme-sh 容器会：
1. 生成自签名临时证书（让 nginx 先起来）
2. 通过阿里云 DNS 验证签发 Let's Encrypt 证书
3. 安装证书并写入 `.ready` 标记
4. nginx 检测到标记后启动，加载真实证书

整个过程约 1-2 分钟。

### 5. 验证

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
├── conf.d/
│   └── default.conf      # Nginx HTTPS 配置
├── html/
│   └── index.html        # 默认首页
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
