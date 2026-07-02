#!/usr/bin/env bash
# 创建 D1 数据库 docker-hub-accounts + 建表，输出 database_id。
# 用法：CLOUDFLARE_API_TOKEN=xxx ./d1-setup.sh
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

DB_NAME="docker-hub-accounts"

echo ">>> 创建 D1 数据库 $DB_NAME ..."
OUT="$(./node_modules/.bin/wrangler d1 create "$DB_NAME" 2>&1 || true)"
echo "$OUT"

# 从输出里提取 database_id（UUID 格式）
DB_ID="$(echo "$OUT" | grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"

if [ -z "$DB_ID" ]; then
  echo "错误：未能从输出中解析出 database_id（可能数据库已存在或创建失败）" >&2
  exit 1
fi
echo ""
echo ">>> database_id = $DB_ID"
echo "$DB_ID" > .d1_id

echo ">>> 建表 accounts ..."
./node_modules/.bin/wrangler d1 execute "$DB_NAME" --remote --command "
CREATE TABLE IF NOT EXISTS accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  rate_limited_until INTEGER DEFAULT 0,
  last_used INTEGER DEFAULT 0,
  limited_count INTEGER NOT NULL DEFAULT 0
);
"

echo ""
echo ">>> 当前表内容："
./node_modules/.bin/wrangler d1 execute "$DB_NAME" --remote --command "SELECT id,username,enabled,rate_limited_until,last_used,limited_count FROM accounts;" --json 2>/dev/null | tail -n +2 || true

echo ""
echo ">>> 完成。database_id 已存入 .d1_id。请将其写入 wrangler.jsonc 的 D1 binding。"
