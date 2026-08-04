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
READY=false
for i in $(seq 1 90); do
    if docker compose exec -T acme-sh test -f /acme.sh/.ready 2>/dev/null; then
        echo " ✓"
        READY=true
        break
    fi
    echo -n "."
    sleep 2
done

if ! $READY; then
    echo ""
    echo "============================================"
    echo "❌ acme-sh 在 180 秒内未能就绪！"
    echo ""
    echo "  请检查 acme-sh 日志:"
    echo "    docker compose logs acme-sh"
    echo ""
    echo "  常见原因:"
    echo "    - Aliyun API 密钥错误"
    echo "    - DNS 解析未生效"
    echo "    - Let's Encrypt 速率限制"
    echo "============================================"
    exit 1
fi

echo ""
echo "============================================"
echo "✅ 全部就绪！"
echo ""
docker compose ps
echo ""
echo "  测试: curl -k https://localhost"
echo "  日志: docker compose logs -f"
echo "============================================"
