#!/bin/sh
# -------------------------------------------------------------------
# nginx-entrypoint.sh
# 1. 后台启动 reload-watcher（监听证书目录中的 reload 信号文件）
# 2. 等待证书文件出现（最多 5 分钟）
# 3. 启动 nginx
# -------------------------------------------------------------------
set -e

# 启动 reload 监听器
/scripts/reload-watch.sh &
WATCHER_PID=$!
echo "[$(date)] reload-watcher started (pid=${WATCHER_PID})"

# 等待至少一张证书存在
echo "[$(date)] Waiting for certificates..."
for i in $(seq 1 60); do
  if ls /opt/certs/*/fullchain.pem >/dev/null 2>&1; then
    echo "[$(date)] Certificates found, starting nginx"
    break
  fi
  echo "[$(date)] No certs yet (${i}/60)..."
  sleep 5
done

exec nginx -g "daemon off;"
