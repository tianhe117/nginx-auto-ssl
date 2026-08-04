#!/bin/bash
# -------------------------------------------------------------------
# entrypoint.sh — acme-sh 容器入口
# 1. 为每个域名生成自签名临时证书（让 nginx 能先起来）
# 2. 逐个检查/签发 Let's Encrypt 泛域名证书（Aliyun DNS 验证）
# 3. 安装证书 + 设置 reload 钩子
# 4. 写入 .ready 标记 → healthcheck 通过 → nginx 启动
# 5. 进入 daemon 模式（每天检查续期，到期自动更新）
# -------------------------------------------------------------------
set -euo pipefail

: "${DOMAINS:?❌ DOMAINS 环境变量未设置}"
: "${CERT_EMAIL:?❌ CERT_EMAIL 环境变量未设置}"

READY_FILE="/acme.sh/.ready"

echo "============================================"
echo "  acme.sh entrypoint 启动"
echo "  DOMAINS: ${DOMAINS}"
echo "============================================"

# ---- 解析域名 ----
# DOMAINS 格式: "ligefei.com;liruixiang.cc;xxx.com"
IFS=';' read -ra DOMAIN_LIST <<< "${DOMAINS}"

# ---- Step 1: 为每个域名生成自签名临时证书 ----
for domain in "${DOMAIN_LIST[@]}"; do
    DOMAIN="$(echo "${domain}" | xargs)"
    [ -z "${DOMAIN}" ] && continue
    CERT_DIR="/acme.sh/live/${DOMAIN}"

    if [ ! -f "${CERT_DIR}/fullchain.pem" ] || [ ! -f "${CERT_DIR}/privkey.pem" ]; then
        echo "→ 生成自签名临时证书: ${DOMAIN}"
        mkdir -p "${CERT_DIR}"
        openssl req -x509 -nodes -days 7 -newkey ec: \
            -pkeyopt ec_paramgen_curve:prime256v1 \
            -keyout "${CERT_DIR}/privkey.pem" \
            -out   "${CERT_DIR}/fullchain.pem" \
            -subj  "/CN=Temporary-${DOMAIN}" 2>/dev/null
        echo "  ✓ 临时证书已生成"
    else
        echo "→ 证书文件已存在: ${DOMAIN}，跳过自签名"
    fi
done

# ---- Step 2 & 3: 为每个域名检查/签发/安装 ----
for domain in "${DOMAIN_LIST[@]}"; do
    DOMAIN="$(echo "${domain}" | xargs)"
    [ -z "${DOMAIN}" ] && continue
    CERT_DIR="/acme.sh/live/${DOMAIN}"

    echo ""
    echo "---- 处理: ${DOMAIN} + *.${DOMAIN} ----"

    if acme.sh --list 2>/dev/null | grep -q "${DOMAIN}"; then
        echo "  → acme.sh 中已有 ${DOMAIN} 的证书记录"
        echo "    （daemon 模式会在到期前自动续期）"
    else
        echo "  → 未找到 ${DOMAIN} 的证书，开始签发..."
        echo "    这可能需要 1-2 分钟..."

        acme.sh --issue --dns dns_ali \
            --keylength ec-256 \
            -d "${DOMAIN}" -d "*.${DOMAIN}" \
            --email "${CERT_EMAIL}" \
            --server letsencrypt

        echo "  ✓ ${DOMAIN} + *.${DOMAIN} 签发成功"
    fi

    # 安装证书 + reload 钩子
    echo "  → 安装证书到 ${CERT_DIR}..."
    acme.sh --install-cert -d "${DOMAIN}" \
        --key-file       "${CERT_DIR}/privkey.pem" \
        --fullchain-file "${CERT_DIR}/fullchain.pem" \
        --reloadcmd      "docker exec nginx nginx -s reload"
    echo "  ✓ ${DOMAIN} 证书已安装"
done

# ---- Step 4: 标记就绪 → nginx 可以启动 ----
touch "${READY_FILE}"
echo ""
echo "============================================"
echo "  全部证书就绪，nginx 即将启动"
echo "============================================"

# ---- Step 5: 进入 daemon 模式 ----
exec acme.sh --daemon
