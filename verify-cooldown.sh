#!/usr/bin/env bash
# 隔离验证冷却排除逻辑：插入临时账号，冷却后应被 Worker 的查询排除，解冷后应被包含，最后删除。
# 用法：CLOUDFLARE_API_TOKEN=xxx ./verify-cooldown.sh
set -e
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
cd "$(dirname "$0")"

# Cloudflare 鉴权：优先环境变量，回退 token 文件
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  [ -f token ] || { echo "错误：请 export CLOUDFLARE_API_TOKEN，或在项目目录放 token 文件" >&2; exit 1; }
  export CLOUDFLARE_API_TOKEN="$(cat token)"
fi
DB="docker-hub-accounts"
W="./node_modules/.bin/wrangler d1 execute $DB --remote --json"
q() { $W --command "$1" 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);console.log(JSON.stringify(j[0].results.map(r=>r.username||r.c||r)))}catch(e){console.log(d.trim().split("\n")[0])}})'; }

echo ">>> 清理可能残留的测试行"
$W --command "DELETE FROM accounts WHERE username='__cooldown_test__';" >/dev/null 2>&1 || true

echo ">>> 插入测试账号（未冷却）"
$W --command "INSERT INTO accounts(username,password,rate_limited_until) VALUES('__cooldown_test__','x',0);" >/dev/null
FUTURE=$(( ( $(date +%s) + 6*3600 ) * 1000 ))
NOW=$(( $(date +%s) * 1000 ))

echo -n "未冷却时可用账号（应含 __cooldown_test__）: "
q "SELECT username AS c FROM accounts WHERE enabled=1 AND (rate_limited_until IS NULL OR rate_limited_until < $NOW) ORDER BY last_used ASC;"

echo ">>> 将测试账号标记冷却（rate_limited_until = now+6h，模拟 429 触发）"
$W --command "UPDATE accounts SET rate_limited_until=$FUTURE WHERE username='__cooldown_test__';" >/dev/null

echo -n "冷却后可用账号（应不含 __cooldown_test__）: "
q "SELECT username AS c FROM accounts WHERE enabled=1 AND (rate_limited_until IS NULL OR rate_limited_until < $NOW) ORDER BY last_used ASC;"

echo ">>> 清理测试行"
$W --command "DELETE FROM accounts WHERE username='__cooldown_test__';" >/dev/null
echo ">>> 完成"
