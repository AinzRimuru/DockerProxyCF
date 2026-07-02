#!/usr/bin/env bash
# 生成并设置 PROXY_TOKEN_KEY（token 保护），可选 ACCESS_KEY（访问控制）。
# 用法：CLOUDFLARE_API_TOKEN=xxx ./set-proxy-key.sh
#       CLOUDFLARE_API_TOKEN=xxx ACCESS_KEY=密码 ./set-proxy-key.sh
set -e

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

cd "$(dirname "$0")"

[ -x ./node_modules/.bin/wrangler ] || { echo "错误：未安装 wrangler" >&2; exit 1; }

# Cloudflare 鉴权：优先环境变量，回退 token 文件
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  [ -f token ] || { echo "错误：请 export CLOUDFLARE_API_TOKEN，或在项目目录放 token 文件" >&2; exit 1; }
  export CLOUDFLARE_API_TOKEN="$(cat token)"
fi

# 生成 32 字节随机密钥（HMAC-SHA256 用）。仅 Worker 内部使用，无需记住。
KEY="$(openssl rand -base64 32 2>/dev/null || node -e 'console.log(require("crypto").randomBytes(32).toString("base64"))')"

echo ">>> 设置 PROXY_TOKEN_KEY（启用 token 保护）..."
printf '%s' "$KEY" | ./node_modules/.bin/wrangler secret put PROXY_TOKEN_KEY

if [ -n "$ACCESS_KEY" ]; then
  echo ">>> 设置 ACCESS_KEY（启用访问控制）..."
  printf '%s' "$ACCESS_KEY" | ./node_modules/.bin/wrangler secret put ACCESS_KEY
  echo ""
  echo ">>> 访问控制已启用。客户端需先：docker login <你的域名> -u任意 -p<ACCESS_KEY>"
else
  echo ">>> 未设置 ACCESS_KEY：/token 开放签发 proxy token（任何人都可拉取，但拿不到真实账号 token）"
fi
echo ">>> 完成。接下来运行 deploy.sh 部署新代码。"
