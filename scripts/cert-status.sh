#!/bin/bash
# 查看证书状态（到期时间、剩余天数）
set -euo pipefail
cd "$(dirname "$0")/.."

echo "============================================"
echo "  证书状态"
echo "============================================"

docker compose exec -T acme-sh acme.sh --list 2>/dev/null || echo "暂无证书记录"

echo ""
echo "--- 证书文件检查 ---"
for cert in ./certs/live/*/fullchain.pem 2>/dev/null; do
    if [ -f "${cert}" ]; then
        domain="$(basename "$(dirname "${cert}")")"
        expiry="$(openssl x509 -enddate -noout -in "${cert}" 2>/dev/null | cut -d= -f2)"
        echo "  ${domain}: 到期 ${expiry}"
    fi
done
echo "============================================"
