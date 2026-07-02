#!/usr/bin/env bash
# 部署 Worker。
# 鉴权：export CLOUDFLARE_API_TOKEN=...  （或在项目目录放 token 文件，已 gitignore）
# 用法：CLOUDFLARE_API_TOKEN=xxx ./deploy.sh
set -e

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

cd "$(dirname "$0")"

if [ ! -x ./node_modules/.bin/wrangler ]; then
  echo "错误：未安装 wrangler，请先 npm install" >&2
  exit 1
fi

# Cloudflare 鉴权：优先环境变量，回退本地 token 文件
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  [ -f token ] || { echo "错误：请 export CLOUDFLARE_API_TOKEN，或在项目目录放 token 文件" >&2; exit 1; }
  export CLOUDFLARE_API_TOKEN="$(cat token)"
fi

echo ">>> 正在部署 docker-hub-proxy ..."
./node_modules/.bin/wrangler deploy
