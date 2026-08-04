#!/bin/sh
# -------------------------------------------------------------------
# reload-watch.sh
# 轮询 /opt/certs/.nginx-reload 信号文件
# 检测到变化时执行 nginx -s reload
# -------------------------------------------------------------------
LAST_TS=""

while true; do
  if [ -f /opt/certs/.nginx-reload ]; then
    CURRENT_TS=$(cat /opt/certs/.nginx-reload 2>/dev/null)
    if [ -n "${CURRENT_TS}" ] && [ "${CURRENT_TS}" != "${LAST_TS}" ]; then
      LAST_TS="${CURRENT_TS}"
      echo "[$(date)] Reload signal detected, reloading nginx..."
      nginx -s reload 2>&1 || echo "[$(date)] Reload failed"
    fi
  fi
  sleep 10
done
