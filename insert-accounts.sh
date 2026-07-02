#!/usr/bin/env bash
# 从 accounts.txt（每行  用户名:密码 ，# 开头为注释）批量录入 Docker Hub 账号到 D1。
# 用法：先创建 accounts.txt，再 CLOUDFLARE_API_TOKEN=xxx ./insert-accounts.sh
set -e

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

cd "$(dirname "$0")"

[ -f accounts.txt ] || { echo "错误：请先创建 accounts.txt（每行 用户名:密码）" >&2; exit 1; }
[ -x ./node_modules/.bin/wrangler ] || { echo "错误：未安装 wrangler" >&2; exit 1; }

# Cloudflare 鉴权：优先环境变量，回退 token 文件
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  [ -f token ] || { echo "错误：请 export CLOUDFLARE_API_TOKEN，或在项目目录放 token 文件" >&2; exit 1; }
  export CLOUDFLARE_API_TOKEN="$(cat token)"
fi

DB_NAME="docker-hub-accounts"

# 转义单引号（SQLite 字符串里 ' → ''），防注入
escape() { printf "%s" "$1" | sed "s/'/''/g"; }

count=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%%#*}"                                  # 去注释
  line="${line#"${line%%[![:space:]]*}"}"            # 去首空白
  line="${line%"${line##*[![:space:]]}"}"            # 去尾空白
  [ -z "$line" ] && continue
  user="${line%%:*}"
  pass="${line#*:}"
  [ -z "$user" ] && { echo "跳过（无用户名）：$line" >&2; continue; }
  u="$(escape "$user")"
  p="$(escape "$pass")"
  echo ">>> 录入 $user ..."
  ./node_modules/.bin/wrangler d1 execute "$DB_NAME" --remote \
    --command "INSERT OR IGNORE INTO accounts(username,password) VALUES('$u','$p');" >/dev/null
  count=$((count + 1))
done < accounts.txt

echo ""
echo ">>> 完成，处理 $count 个账号。"
echo ">>> 当前账号列表："
./node_modules/.bin/wrangler d1 execute "$DB_NAME" --remote \
  --command "SELECT id,username,enabled,rate_limited_until,last_used,limited_count FROM accounts ORDER BY id;" --json 2>/dev/null | tail -n +2 || true
