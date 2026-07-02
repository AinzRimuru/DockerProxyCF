#!/usr/bin/env bash
# 把 Docker Hub 账号写入 Worker secret：DH_USERNAME / DH_PASSWORD（单账号回退用）。
# 先写 dh_creds（格式 user:pass），再运行：CLOUDFLARE_API_TOKEN=xxx ./set-secrets.sh
set -e

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

cd "$(dirname "$0")"

[ -f dh_creds ] || { echo "错误：缺少 dh_creds 文件（格式 user:pass）" >&2; exit 1; }
[ -x ./node_modules/.bin/wrangler ] || { echo "错误：未安装 wrangler" >&2; exit 1; }

# Cloudflare 鉴权：优先环境变量，回退 token 文件
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  [ -f token ] || { echo "错误：请 export CLOUDFLARE_API_TOKEN，或在项目目录放 token 文件" >&2; exit 1; }
  export CLOUDFLARE_API_TOKEN="$(cat token)"
fi

# 按首个冒号拆分：用户名 = 首个冒号前；密码 = 其后全部
CREDS="$(cat dh_creds)"
DH_USER="${CREDS%%:*}"
DH_PASS="${CREDS#*:}"

[ -n "$DH_USER" ] || { echo "错误：dh_creds 解析出的用户名为空" >&2; exit 1; }
[ -n "$DH_PASS" ] || { echo "错误：dh_creds 解析出的密码为空" >&2; exit 1; }

echo ">>> 设置 DH_USERNAME ..."
printf '%s' "$DH_USER" | ./node_modules/.bin/wrangler secret put DH_USERNAME
echo ">>> 设置 DH_PASSWORD ..."
printf '%s' "$DH_PASS" | ./node_modules/.bin/wrangler secret put DH_PASSWORD
echo ">>> 完成。"
