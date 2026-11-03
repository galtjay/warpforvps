#!/bin/bash
# WARP 容器启动脚本
# 流程：启动 warp-svc -> 等待守护进程就绪 -> 注册 -> proxy 模式 -> 连接 -> 校验 warp=on
set -uo pipefail

PROXY_PORT="${WARP_PROXY_PORT:-40000}"
LOG_PREFIX="[warp]"

log() { echo "${LOG_PREFIX} $(date '+%Y-%m-%d %H:%M:%S') $*"; }

WARP_CLI=(warp-cli --accept-tos)
# 注意：如果是非 root 用户运行，需要加上 sudo；本镜像默认以 root 运行。

# 0. 启动 D-Bus 系统总线：warp-svc 用它监听电源/休眠事件。
#    容器内没有 systemd，若不启动会每 3 秒刷一条 dbus connection failed 噪音日志。
if command -v dbus-daemon >/dev/null 2>&1; then
    mkdir -p /run/dbus
    if dbus-daemon --system --fork >/dev/null 2>&1; then
        log "dbus system bus started."
    else
        log "WARNING: failed to start dbus system bus (non-fatal)."
    fi
fi

# 1. 启动 warp-svc 守护进程（supervisor 前台运行，日志输出到容器标准输出）
log "starting warp-svc (supervisord)..."
mkdir -p /var/log/supervisor
exec 3>&1
supervisord -n -c /etc/supervisor/supervisord.conf &
SUPERVISOR_PID=$!

# 容器收到 SIGTERM 时优雅退出，并关闭 supervisord
term_handler() {
    log "received stop signal, shutting down..."
    warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
    kill -TERM "${SUPERVISOR_PID}" 2>/dev/null || true
    wait "${SUPERVISOR_PID}" 2>/dev/null || true
    exit 0
}
trap term_handler TERM INT

# 2. 等待 warp-svc 可响应命令
log "waiting for warp-svc daemon..."
for _ in $(seq 1 60); do
    if warp-cli --accept-tos status >/dev/null 2>&1; then
        log "warp-svc is ready."
        break
    fi
    if ! kill -0 "${SUPERVISOR_PID}" 2>/dev/null; then
        log "ERROR: supervisord exited unexpectedly."
        exit 1
    fi
    sleep 2
done

if ! warp-cli --accept-tos status >/dev/null 2>&1; then
    log "ERROR: warp-svc did not become ready in time."
    exit 1
fi

# 3. 注册（失败则重试；已是注册状态则跳过）
if ! warp-cli --accept-tos registration show >/dev/null 2>&1; then
    log "registering new client..."
    for attempt in 1 2 3 4 5; do
        if warp-cli --accept-tos registration new; then
            log "registration succeeded (attempt ${attempt})."
            break
        fi
        log "registration attempt ${attempt} failed, retrying in 5s..."
        sleep 5
        if [ "${attempt}" = "5" ]; then
            log "ERROR: registration failed after 5 attempts."
            exit 1
        fi
    done
else
    log "client already registered, skipping registration."
fi

# 4. 切换为 proxy 模式，对外暴露 localhost:${PROXY_PORT} 的 SOCKS5 代理
log "setting mode to proxy (port ${PROXY_PORT})..."
"${WARP_CLI[@]}" mode proxy || { log "ERROR: failed to set proxy mode."; exit 1; }

# 5. 连接
log "connecting to WARP..."
"${WARP_CLI[@]}" connect || { log "ERROR: failed to connect."; exit 1; }

# 6. 校验连接状态，并确认 warp=on
#    注意：connect 返回 Success 后隧道仍需几秒建立，这里轮询确认。
log "verifying WARP connection..."
connected=false
for _ in $(seq 1 30); do
    status="$("${WARP_CLI[@]}" status 2>/dev/null || true)"
    trace="$(curl -fsS --max-time 15 --proxy "socks5://127.0.0.1:${PROXY_PORT}" https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null || true)"
    if grep -q '^warp=on' <<<"${trace}"; then
        log "WARP is UP. cloudflare trace: $(tr '\n' ' ' <<<"${trace}")"
        connected=true
        break
    fi
    sleep 2
done

if [ "${connected}" != "true" ]; then
    log "WARNING: could not verify warp=on. current status: ${status:-unknown}"
    log "hint: run 'docker logs <container>' or restart the container."
else
    log "proxy ready at socks5://127.0.0.1:${PROXY_PORT}"
fi

# 7. 保持前台运行，跟随 supervisord 生命周期
wait "${SUPERVISOR_PID}"
