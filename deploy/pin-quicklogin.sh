#!/usr/bin/env bash
# 把快速登录参数固化进容器启动命令 —— 脱敏模板
#
# 核心结论（2026-10-30 实测）：entrypoint 判断的是环境变量 ACCOUNT。
# 镜像名后面跟的 -q 会进入 Config.Cmd，但被完全忽略，日志仍报「没有 -q 指令」。
# 因此真正生效的是 -e ACCOUNT=<uin>。
#
# 退出码：0=已登录  2=需要扫码  1=其他失败
set -uo pipefail

UIN="${ACCOUNT:?set ACCOUNT to your bot uin}"
IMG="${IMG:-mlikiowa/napcat-docker:latest}"
TOKEN="${WEBUI_TOKEN:?set WEBUI_TOKEN}"
QUICK_MD5="${QUICK_PASSWORD_MD5:-}"   # 可选：票据失效时走密码回退登录

echo "== 备份当前容器参数 =="
docker inspect napcat > "${BACKUP_DIR:-.}/napcat-inspect.$(date +%Y%m%d_%H%M%S).json" 2>/dev/null || true

echo "== 重建（带 ACCOUNT） =="
args=(-d --name napcat --restart=always
  -e NAPCAT_UID=0 -e NAPCAT_GID=0 -e WEBUI_TOKEN="$TOKEN" -e TZ=Asia/Shanghai
  -e ACCOUNT="$UIN"
  -p 127.0.0.1:3000:3000 -p 127.0.0.1:3001:3001 -p 127.0.0.1:6099:6099
  -v "${REMOTE_HOME}/napcat/config:/app/napcat/config"
  -v "${REMOTE_HOME}/napcat/qq:/app/.config/QQ"
  --memory=1200m --memory-swap=1600m)
[ -n "$QUICK_MD5" ] && args+=(-e NAPCAT_QUICK_PASSWORD_MD5="$QUICK_MD5")

docker rm -f napcat >/dev/null 2>&1 || true
docker run "${args[@]}" "$IMG" -q "$UIN" >/dev/null || { echo FAIL_RUN; exit 1; }

echo "== 等登录（最多 150s） =="
for i in $(seq 1 50); do
  sleep 3
  if curl -s -m 3 http://127.0.0.1:3000/get_login_info 2>/dev/null | grep -q '"user_id"'; then
    echo PINNED_OK; exit 0
  fi
done
echo NEED_QRCODE; exit 2
