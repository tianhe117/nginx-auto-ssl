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
# 通过 docker exec 检查容器内证书（certs 是 named volume，非 bind mount）
for cert in $(docker compose exec -T acme-sh sh -c "ls /acme.sh/live/*/fullchain.pem 2>/dev/null"); do
    domain="$(basename "$(dirname "${cert}")")"
    expiry="$(docker compose exec -T acme-sh openssl x509 -enddate -noout -in "${cert}" 2>/dev/null | cut -d= -f2)"
    echo "  ${domain}: 到期 ${expiry}"
done
echo "============================================"
