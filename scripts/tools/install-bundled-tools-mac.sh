#!/bin/bash
# 准备接入工具：微信 WeChatDataAnalysis、飞书 lark-cli（QQ 用任意 OneBot 11 实现，本项目不代为安装）。
# 本地没有时用 curl 从官方发布页下载并校验 SHA-256，解压到 third_party/tools/（已 gitignore）。
# 一般不用直接运行，双击根目录的「安装接入工具.command」即可。
#   bash scripts/tools/install-bundled-tools-mac.sh [wechat|qq|feishu|all]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLS="$ROOT/third_party/tools"
TOOL="${1:-menu}"

WDA_VERSION="2.10.1"
LARK_VERSION="1.0.100"
WDA_DMG_NAME="WeChatDataAnalysis-${WDA_VERSION}-mac-arm64.dmg"
SHA_WDA_DMG="2bd75e0b5d1d1f18c52b90fbeb38c62b3a11a617588f7800da5a4929fa447fb6"
SHA_LARK_ARM64="d068a27f608335016a8a7fb1b3cd1fccfb96bda92075a027e2bf1c4c23134e30"
SHA_LARK_AMD64="7f5d442e5da3ae62b03a5b552880b651637b16b2eed91b588afaca6d72a6643a"

WDA_URL="https://github.com/LifeArchiveProject/WeChatDataAnalysis/releases/download/v${WDA_VERSION}/${WDA_DMG_NAME}"
LARK_URL_BASE="https://github.com/larksuite/cli/releases/download/v${LARK_VERSION}"

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s\n' "$*"; }
bad()  { printf '[问题] %s\n' "$*"; }
head1(){ printf '\n=== %s ===\n' "$*"; }

# 询问一次 yn；没有终端（比如被别处调用）时默认不执行
ask() {
  local q="$1" ans
  printf '%s (Y/n) ' "$q"
  if ! read -r ans; then printf '\n'; return 1; fi
  case "$ans" in n|N|no|NO) return 1 ;; *) return 0 ;; esac
}

sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# download url dest：先下到 .part，成功后改名（失败不留半截文件）
download() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")" || { bad "创建目录失败：$(dirname "$dest")"; return 1; }
  say "下载中：$url"
  say "      → $dest"
  if ! curl -fL --retry 2 --connect-timeout 20 -o "$dest.part" "$url"; then
    bad '下载失败（检查网络、代理，或稍后重试）。'
    rm -f "$dest.part"
    return 1
  fi
  mv -f "$dest.part" "$dest" || { bad '保存文件失败'; return 1; }
  return 0
}

# ensure path expected label url：文件不存在就下载，然后校验
ensure() {
  local p="$1" exp="$2" label="$3" url="$4" actual
  if [ ! -f "$p" ]; then
    say "本地没有 $label，需要联网获取。"
    download "$url" "$p" || return 1
  fi
  say "校验 $label（$(du -h "$p" | awk '{print $1}')，需要几秒）..."
  actual="$(sha256_of "$p")"
  if [ "$actual" != "$exp" ]; then
    bad "校验不一致！文件可能损坏或被替换。"
    say "  期望 $exp"
    say "  实际 $actual"
    say "  已下载的文件：$p（删掉后重跑本脚本即可重新下载）"
    return 1
  fi
  ok '校验通过（与官方 SHA-256 一致）。'
  return 0
}

# ---------------------------------------------------------------- 微信
install_wechat() {
  head1 '微信：WeChatDataAnalysis'
  if [ "$(uname -m)" != "arm64" ]; then
    bad '微信工具官方只提供 Apple Silicon（M 系列芯片）版本，这台 Intel Mac 用不了。'
    say '  Intel Mac 上微信来源请改成「导入聊天记录文件」（把导出的 JSON / CSV / 文本'
    say '  放进 data/inbox/wechat/，或在「情报源」页面导入），或换一台 M 芯片的 Mac。'
    say '  详见 docs/MACOS.md 的「微信」一节。'
    return 1
  fi
  local dmg="$TOOLS/wda/$WDA_DMG_NAME"
  ensure "$dmg" "$SHA_WDA_DMG" '微信数据分析助手（.dmg，约 425 MB）' "$WDA_URL" || return 1
  say ''
  say '安装方法：把打开的窗口里的图标拖进「应用程序」文件夹。'
  say '  第一次打开如果提示「无法验证开发者」：到 系统设置 → 隐私与安全性，点「仍要打开」。'
  say '  装好后打开「微信数据分析助手」，按 docs/MACOS.md 的「微信」一节登录并完成解密，'
  say '  然后回到工作台「情报源」→ 微信，打开启用开关。'
  if ask '现在打开安装镜像吗？'; then
    open "$dmg"
  else
    say "需要时双击这个文件即可：$dmg"
  fi
}

# ---------------------------------------------------------------- QQ
install_qq() {
  head1 'QQ：任意 OneBot 11 实现'
  say '工作台的 QQ 采集器只依赖 OneBot 11 HTTP 协议，不绑定具体实现，也不代为安装。'
  say '可选实现（本项目不背书，请自行核实许可与可用性）：'
  say '  SnowLuma        https://github.com/TomyJan/SnowLuma                Windows / Linux，非商业许可'
  say '  LuckyLilliaBot  https://github.com/LuckyLilliaDev/LuckyLilliaBot  Win / macOS arm64 / Linux，GPL-2.0'
  say ''
  say '装好并用小号登录后，在它的网络配置里开启 HTTP 服务端：'
  say '  主机 127.0.0.1、端口 3010、消息格式 array，并设一个 token。'
  say '详细步骤见 docs/SETUP_QQ.md（含实时上报的可选配置）。'
  say ''
  say '如果不想引入任何框架：把导出的聊天记录放进 data/inbox/qq/，或在「情报源」页面导入。'
  say ''
  say '历史说明：早期版本用的是 NapCatQQ，它已停止维护（仓库内容清空、Release 与 Tag 全部'
  say '下线），所以这里不再提供它的下载与安装。'
}

# ---------------------------------------------------------------- 飞书
install_feishu() {
  head1 '飞书：lark-cli（官方命令行工具）'
  local arch tgz exp
  case "$(uname -m)" in
    arm64)  arch='darwin-arm64'; exp="$SHA_LARK_ARM64"; tgz="$TOOLS/lark-cli/lark-cli-${LARK_VERSION}-darwin-arm64.tar.gz" ;;
    x86_64) arch='darwin-amd64'; exp="$SHA_LARK_AMD64"; tgz="$TOOLS/lark-cli/lark-cli-${LARK_VERSION}-darwin-amd64.tar.gz" ;;
    *) bad "不认识的 CPU 架构：$(uname -m)"; return 1 ;;
  esac
  say "当前架构：$arch"
  if [ -x "$TOOLS/lark-cli/bin/lark-cli" ]; then
    ok "lark-cli 已就绪：$("$TOOLS/lark-cli/bin/lark-cli" --version 2>&1 | head -n 1)"
  else
    ensure "$tgz" "$exp" 'lark-cli' "$LARK_URL_BASE/$(basename "$tgz")" || return 1
    say '解压中...'
    rm -rf "$TOOLS/lark-cli/bin"
    mkdir -p "$TOOLS/lark-cli/bin" || { bad '创建目录失败'; return 1; }
    # 官方 tar.gz 里没有外层目录（直接是 lark-cli / LICENSE / README.md / CHANGELOG.md）
    if ! tar -xzf "$tgz" -C "$TOOLS/lark-cli/bin"; then
      bad '解压失败'; return 1
    fi
    chmod +x "$TOOLS/lark-cli/bin/lark-cli" || { bad '设置执行权限失败'; return 1; }
    xattr -dr com.apple.quarantine "$TOOLS/lark-cli/bin/lark-cli" 2>/dev/null || true
    ok "已安装到：$TOOLS/lark-cli/bin/lark-cli（$("$TOOLS/lark-cli/bin/lark-cli" --version 2>&1 | head -n 1)）"
  fi
  say ''
  say '接下来（详细步骤见 docs/SETUP_FEISHU.md）：'
  say '  1. 第一次使用要配置一个飞书应用，运行：'
  say "       \"$TOOLS/lark-cli/bin/lark-cli\" config init"
  say '  2. 然后双击根目录的「飞书重新授权.command」，在浏览器里点「授权」。'
  say '  3. 回到工作台「情报源」→ 飞书，打开启用开关，点「测试」。'
  if ask '现在运行「config init」吗？'; then
    "$TOOLS/lark-cli/bin/lark-cli" config init
  fi
}

show_menu() {
  head1 '个人情报局 · 准备接入工具（macOS）'
  say '想读取哪个平台的群消息，就装哪个。只想看演示或导入聊天记录文件的话，这三个都不用装。'
  say '本地没有时会联网下载官方文件并校验 SHA-256（微信约 425 MB，需要几分钟）。'
  say ''
  say '  1  微信（WeChatDataAnalysis，仅 Apple Silicon）'
  say '  2  QQ（说明：用任意 OneBot 11 实现，本项目不代为安装）'
  say '  3  飞书（lark-cli，按芯片自动选择 arm64 / amd64）'
  say '  4  三个都处理'
  say '  0  退出'
  say ''
  printf '请输入数字：'
  local c
  read -r c || return 0
  case "$c" in
    1) install_wechat ;;
    2) install_qq ;;
    3) install_feishu ;;
    4) install_wechat; install_qq; install_feishu ;;
    *) say '什么也没做。' ;;
  esac
}

case "$TOOL" in
  wechat) install_wechat ;;
  qq)     install_qq ;;
  feishu) install_feishu ;;
  all)    install_wechat; install_qq; install_feishu ;;
  *)      show_menu ;;
esac

printf '\n按回车键关闭这个窗口...'
read -r _ || true
