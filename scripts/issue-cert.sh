#!/bin/bash
# -------------------------------------------------------------------
# issue-cert.sh — 为额外域名签发泛域名证书
# 用法: ./scripts/issue-cert.sh <domain>
# 示例: ./scripts/issue-cert.sh liruixiang.cc
#       会自动签发 liruixiang.cc + *.liruixiang.cc
# -------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
    echo "❌ 请先创建 .env 文件（参考 .env.example）"
    exit 1
fi
set -a; source .env; set +a

DOMAIN="${1:-}"
if [ -z "${DOMAIN}" ]; then
    echo "用法: $0 <domain>"
    echo "示例: $0 liruixiang.cc"
    echo "自动签发: <domain> + *.<domain>"
    exit 1
fi

echo "→ 签发泛域名证书: ${DOMAIN} + *.${DOMAIN}"

docker compose exec -T acme-sh \
    acme.sh --issue --dns dns_ali \
    --keylength ec-256 \
    -d "${DOMAIN}" -d "*.${DOMAIN}" \
    --email "${CERT_EMAIL:-admin@${DOMAIN}}" \
    --server letsencrypt

docker compose exec -T acme-sh \
    acme.sh --install-cert -d "${DOMAIN}" \
    --key-file       "/acme.sh/live/${DOMAIN}/privkey.pem" \
    --fullchain-file "/acme.sh/live/${DOMAIN}/fullchain.pem" \
    --reloadcmd      "date +%s > /acme.sh/.nginx-reload"

echo ""
echo "✓ 泛域名证书已签发: ${DOMAIN} + *.${DOMAIN}"
echo "  nginx reload 信号已发送"
echo ""
echo "  别忘了在 conf.d/ 中添加对应的 server 块！"
