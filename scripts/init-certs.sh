#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ 启动 nginx + acme.sh..."
docker compose up -d

echo ""
echo "→ 等待 acme.sh 完成证书初始化..."
echo "  （首次签发需要 1-2 分钟，之后启动只需几秒）"
echo ""

# 等待 acme-sh healthy
echo -n "  等待 acme-sh 就绪"
for i in $(seq 1 90); do
    if docker compose exec -T acme-sh test -f /acme.sh/.ready 2>/dev/null; then
        echo " ✓"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo "============================================"
echo "✅ 全部就绪！"
echo ""
docker compose ps
echo ""
echo "  测试: curl -k https://localhost"
echo "  日志: docker compose logs -f"
echo "============================================"
