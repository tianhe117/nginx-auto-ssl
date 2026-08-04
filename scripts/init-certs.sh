#!/bin/bash
# -------------------------------------------------------------------
# init-certs.sh — 初始化证书并启动全栈
# 1. 启动 acme-sh daemon
# 2. 逐域名签发/安装证书
# 3. 启动 nginx
# -------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
    echo "❌ 请先创建 .env 文件（参考 .env.example）"
    exit 1
fi
set -a; source .env; set +a

: "${DOMAINS:?❌ DOMAINS 环境变量未设置}"
: "${CERT_EMAIL:?❌ CERT_EMAIL 环境变量未设置}"

# ---- Step 1: 启动 acme-sh daemon ----
echo "→ 启动 acme-sh daemon..."
docker compose up -d acme-sh

echo "→ 等待 daemon 就绪..."
READY=false
for i in $(seq 1 30); do
    if docker compose exec -T acme-sh acme.sh --list >/dev/null 2>&1; then
        echo "  ✓ acme-sh daemon 已就绪"
        READY=true
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if ! $READY; then
    echo "❌ acme-sh daemon 在 60 秒内未能就绪！"
    echo "  请检查: docker compose logs acme-sh"
    exit 1
fi

# ---- Step 2: 为每个域名签发/安装证书 ----
IFS=';' read -ra DOMAIN_LIST <<< "${DOMAINS}"

for domain in "${DOMAIN_LIST[@]}"; do
    DOMAIN="$(echo "${domain}" | xargs)"
    [ -z "${DOMAIN}" ] && continue

    echo "---- 处理: ${DOMAIN} + *.${DOMAIN} ----"

    if docker compose exec -T acme-sh acme.sh --list 2>/dev/null | awk '{print $1}' | grep -Fxq "${DOMAIN}"; then
        echo "  → acme.sh 中已有 ${DOMAIN} 的证书记录，跳过签发"
    else
        echo "  → 开始签发 ${DOMAIN} + *.${DOMAIN}（预计 1-2 分钟）..."
        docker compose exec -T acme-sh \
            acme.sh --issue --dns dns_ali \
            --keylength ec-256 \
            -d "${DOMAIN}" -d "*.${DOMAIN}" \
            --email "${CERT_EMAIL}" \
            --server letsencrypt
        echo "  ✓ 签发成功"
    fi

    echo "  → 安装证书到 /acme.sh/live/${DOMAIN}/..."
    docker compose exec -T acme-sh \
        acme.sh --install-cert -d "${DOMAIN}" \
        --key-file       "/acme.sh/live/${DOMAIN}/privkey.pem" \
        --fullchain-file "/acme.sh/live/${DOMAIN}/fullchain.pem" \
        --reloadcmd      "date +%s > /acme.sh/live/.nginx-reload"
    echo "  ✓ 证书已安装"
    echo ""
done

# ---- Step 3: 启动 nginx ----
echo "→ 启动 nginx..."
docker compose up -d nginx

echo ""
echo "============================================"
echo "✅ 全部就绪！"
echo ""
docker compose ps
echo ""
echo "  测试: curl -k https://localhost"
echo "  日志: docker compose logs -f"
echo "============================================"
