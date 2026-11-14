#!/bin/bash
# 飞书重新授权（macOS）：重新授权「用户身份」（消息 + 文档两类权限）。
# 一般不用直接运行它，双击项目根目录的「飞书重新授权.command」即可。
#   bash scripts/feishu-reauth-mac.sh [--status-only|--url-only|--no-browser]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PORT="${BUREAU_PORT:-8765}"
DOMAINS='im,docs'
NO_BROWSER=0
URL_ONLY=0
STATUS_ONLY=0
for a in "$@"; do
  case "$a" in
    --status-only) STATUS_ONLY=1 ;;
    --url-only)    URL_ONLY=1 ;;
    --no-browser)  NO_BROWSER=1 ;;
  esac
done

say() { printf '%s\n' "$*"; }

# 找一个能解析 JSON 的 python：优先项目虚拟环境
PY=""
for c in "$ROOT/.venv/bin/python" python3 python; do
  if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done

# 从混合输出里取出第一行 JSON，并读字段：jget <json> <key>
jget() {
  if [ -n "$PY" ]; then
    printf '%s' "$1" | "$PY" -c 'import json,sys
raw=sys.stdin.read()
key=sys.argv[1]
obj=None
for line in raw.splitlines():
    t=line.strip()
    if t.startswith("{") and t.endswith("}"):
        try:
            obj=json.loads(t); break
        except Exception:
            continue
if obj is None:
    try: obj=json.loads(raw)
    except Exception: sys.exit(1)
v=obj
for part in key.split("."):
    if not isinstance(v, dict): sys.exit(1)
    v=v.get(part)
if v is None: sys.exit(1)
if isinstance(v, bool): print("true" if v else "false")
elif isinstance(v, (dict, list)): print(json.dumps(v, ensure_ascii=False))
else: print(v)' "$2" 2>/dev/null
  fi
}

find_cli() {
  local c
  for c in "$ROOT/third_party/tools/lark-cli/bin/lark-cli" \
           "$ROOT/third_party/tools/lark-cli/node_modules/.bin/lark-cli"; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  if command -v lark-cli >/dev/null 2>&1; then command -v lark-cli; return 0; fi
  return 1
}

fmt_time() { # ISO -> 本地时间
  [ -z "${1:-}" ] && { printf '%s' '-'; return; }
  if [ -n "$PY" ]; then
    "$PY" -c 'import sys
from datetime import datetime
s=sys.argv[1]
try:
    if s.endswith("Z"): s=s[:-1]+"+00:00"
    print(datetime.fromisoformat(s).astimezone().strftime("%Y-%m-%d %H:%M"))
except Exception:
    print(s)' "$1" 2>/dev/null && return
  fi
  printf '%s' "$1"
}

show_status() { # 返回 0 表示 ready
  local cli="$1" st status name exp ref msg
  st="$("$cli" auth status 2>/dev/null)"
  status="$(jget "$st" identities.user.status)"
  if [ -z "$status" ]; then say '读不到授权状态。'; return 1; fi
  name="$(jget "$st" identities.user.userName)"
  msg="$(jget "$st" identities.user.message)"
  exp="$(jget "$st" identities.user.expiresAt)"
  ref="$(jget "$st" identities.user.refreshExpiresAt)"
  if [ "$status" = "ready" ]; then
    say "用户身份：已授权（${name}）"
  else
    say "用户身份：未授权（${msg}）"
  fi
  [ -n "$exp" ] && say "  访问令牌到期：$(fmt_time "$exp")（到期后会自动续期）"
  [ -n "$ref" ] && say "  授权最迟有效到：$(fmt_time "$ref")（过了这个时间要重新双击本脚本）"
  [ "$status" = "ready" ]
}

# 工作台在运行的话，顺便让它重新检查一次飞书连接
test_workbench() {
  local sess token body
  sess="$(curl -fsS --max-time 3 "http://127.0.0.1:$PORT/api/session" 2>/dev/null)" || {
    say '工作台没有在运行，跳过连接检查（不影响授权，工作台不用重启）。'; return 0; }
  token="$(jget "$sess" token)"
  [ -z "$token" ] && { say '工作台没有在运行，跳过连接检查。'; return 0; }
  body="$(curl -fsS --max-time 60 -X POST -H "X-Bureau-Token: $token" \
          "http://127.0.0.1:$PORT/api/platforms/feishu/test" 2>/dev/null)" || {
    say '连接检查没成功（不影响授权）。'; return 0; }
  say "工作台里的飞书连接：$(jget "$body" health)（$(jget "$body" detail)）"
}

say ''
say '=== 个人情报局 · 飞书重新授权 ==='

CLI="$(find_cli)" || {
  say '没有找到 lark-cli。请先双击根目录的「安装接入工具.command」，选 3（飞书）。'
  say '  或者手动：bash scripts/tools/install-bundled-tools-mac.sh feishu'
  exit 1
}
say "使用的 lark-cli：$CLI"

if [ "$STATUS_ONLY" = "1" ]; then
  say ''
  if show_status "$CLI"; then test_workbench; exit 0; else test_workbench; exit 1; fi
fi

say ''
say '步骤 1/3：申请授权链接...'
out="$("$CLI" auth login --domain "$DOMAINS" --no-wait --json 2>/dev/null)"
url="$(jget "$out" verification_url)"
code="$(jget "$out" device_code)"
if [ -z "$url" ] || [ -z "$code" ]; then
  say '申请授权链接失败。命令输出：'
  printf '%s\n' "$out" | head -n 12
  exit 1
fi
user_code=""
case "$url" in *user_code=*) user_code="${url##*user_code=}"; user_code="${user_code%%&*}" ;; esac

say ''
say '请在浏览器里打开下面的链接，确认登录的是你本人的飞书账号，然后点「授权」：'
say "  $url"
[ -n "$user_code" ] && say "  授权码：$user_code（链接有效期 10 分钟）"

if [ "$URL_ONLY" = "1" ]; then
  say ''
  say '（测试模式：只生成链接，不等待授权）'
  exit 0
fi

if [ "$NO_BROWSER" = "0" ]; then
  /usr/bin/open "$url" 2>/dev/null && say '已尝试用默认浏览器打开授权页；没弹出来的话，请复制上面的链接到浏览器。'
fi

say ''
say '步骤 2/3：等待你在浏览器里确认授权（最多 10 分钟，请不要关闭本窗口）...'
res="$("$CLI" auth login --device-code "$code" --json 2>/dev/null)"
event="$(jget "$res" event)"
if [ "$event" != "authorization_complete" ]; then
  say ''
  say '没有收到授权完成的结果（可能超时或没有点授权）。命令输出：'
  printf '%s\n' "$res" | head -n 12
  say '请重新双击本脚本再试一次。'
  exit 1
fi
say '授权完成。'
missing="$(jget "$res" missing)"
if [ -n "$missing" ] && [ "$missing" != "[]" ] && [ "$missing" != "null" ]; then
  say "提示：这些权限没有获批：$missing。需要飞书管理员在开发者后台审批。"
fi

say ''
say '步骤 3/3：确认结果...'
if show_status "$CLI"; then ok=0; else ok=1; fi
test_workbench
say ''
if [ "$ok" = "0" ]; then
  say '完成。工作台不需要重启，下次定时任务会自动用新的授权。'
  exit 0
fi
say '授权后读到的状态不是 ready，请把上面的信息发给我。'
exit 1
