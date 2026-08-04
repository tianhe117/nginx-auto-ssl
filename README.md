# Nginx SSL 证书自动续期

基于 docker-compose 的 nginx 反代 + acme.sh 自动签发/续期通配符证书方案。

## 架构

```
nginx:alpine          (host 网络, 反代)
neilpang/acme.sh      (host 网络, 通过阿里云 DNS API 签发证书)
          ↓
      ./certs          (证书落盘, nginx 只读, acme.sh 读写)
```

- acme.sh 自带 cron，每天凌晨检查，到期前 60 天自动续期
- 证书写入 `./certs`，nginx 通过宿主机 crontab 每天凌晨 3 点重启加载

## 目录结构

```
├── docker-compose.yml
├── .env                # 阿里云 API 密钥 (不入库)
├── .env.template       # .env 模板
├── certs/              # SSL 证书 (不入库)
├── conf.d/             # nginx 反代配置 (不入库)
├── html/               # 静态文件 (不入库)
├── acme.sh/            # acme.sh 运行时数据 (不入库)
└── README.md
```

## 部署

```bash
git clone git@github.com:tianhe117/nginx-auto-ssl.git /opt/app/nginx
cd /opt/app/nginx

# 1. 创建 .env，填入阿里云 AccessKey
cp .env.template .env
chmod 600 .env

# 2. 创建运行时目录
mkdir -p acme.sh certs conf.d html

# 3. 启动
docker compose up -d

# 4. 切到 Let's Encrypt (首次)
docker exec acme.sh acme.sh --set-default-ca --server letsencrypt

# 5. 添加每日重启 nginx 的 cron
crontab -e
# 0 3 * * * docker restart nginx
```

## 证书管理

### 新增证书

```bash
# 1. 添加 nginx conf.d 配置（证书路径 /opt/nginx/certs/xxx.crt）
# 2. 签发
docker exec acme.sh acme.sh --issue --dns dns_ali \
  -d 'example.com' -d '*.example.com'

# 3. 安装证书 + 绑定自动续期
docker exec acme.sh acme.sh --install-cert -d example.com \
  --key-file       /output/example.com.key \
  --fullchain-file /output/example.com.crt \
  --reloadcmd      "true"

# 4. 手动重启让新证书生效
docker restart nginx
```

### 删除证书

```bash
# 1. 删除 nginx conf.d 配置
# 2. 移除 acme.sh 中的域名
docker exec acme.sh acme.sh --remove -d example.com

# 3. 删除证书文件
rm /opt/app/nginx/certs/example.com.crt /opt/app/nginx/certs/example.com.key

# 4. 重载
docker restart nginx
```

### 查看状态

```bash
docker exec acme.sh acme.sh --list   # 证书列表及到期时间
docker logs acme.sh                  # 续期日志
docker logs nginx --tail 20          # nginx 日志
```
