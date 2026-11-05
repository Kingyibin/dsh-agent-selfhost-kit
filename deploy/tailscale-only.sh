#!/usr/bin/env bash
# 零公网端口组网 —— 脱敏模板
set -euo pipefail

# 必须 --accept-dns=false：否则 Tailscale 接管 DNS 后，内网镜像源会解析到
# CGNAT 地址而不可达，装包/更新全线超时。
tailscale up --accept-dns=false --auth-key="${TAILSCALE_AUTH_KEY:?set TAILSCALE_AUTH_KEY}"

# 把本机服务借进 tailnet，不对外暴露端口
tailscale serve --bg "${LOCAL_SERVICE_PORT:-8123}"

echo "== 状态 =="
tailscale status
echo "提示：所有服务仍只绑 127.0.0.1，公网扫描看不到。"
