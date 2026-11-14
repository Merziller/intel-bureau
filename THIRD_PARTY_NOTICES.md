# 第三方软件声明

**本仓库不包含、也不分发任何第三方软件的二进制文件。** `third_party/` 已被 `.gitignore` 排除，里面只会在你主动运行下载脚本时出现官方发布的原始文件（未做任何修改）。

这些工具由各自的作者开发与授权，与本项目无隶属关系，也与微信、腾讯（QQ）、飞书官方无隶属或授权关系。使用前请阅读各自项目的说明，并遵守对应平台的服务条款和当地法律法规。

## 运行时下载的第三方工具

| 软件 | 版本 | 用途 | 官方来源 | 许可 |
|---|---|---|---|---|
| WeChatDataAnalysis | 2.10.1 | 读取本机微信的聊天记录（只读，本地 API） | <https://github.com/LifeArchiveProject/WeChatDataAnalysis> | 仓库**未提供许可证文件**。其 README 声明：仅可用于处理使用者本人合法持有、管理或已取得明确授权访问的数据；发布的是官方构建。使用前请自行阅读该 README |
| lark-cli | 1.0.100 | 飞书官方命令行工具（用户身份读写文档、知识库） | <https://github.com/larksuite/cli> | MIT（全文见下） |

下载与校验：

- 微信（Windows）：`scripts/tools/get-wechat-data-analysis.ps1` —— 调 GitHub Releases API 取 `*Setup.exe`，用 API 返回的 `digest`（sha256）校验，并与 Release 附带的 `SHA256SUMS.txt` 交叉核对；**没有 digest 就中止，绝不跳过校验**。
- 微信（macOS）：`scripts/tools/install-bundled-tools-mac.sh wechat` —— 固定下载 `v2.10.1` 的 `WeChatDataAnalysis-2.10.1-mac-arm64.dmg`，校验 sha256 `2bd75e0b5d1d1f18c52b90fbeb38c62b3a11a617588f7800da5a4929fa447fb6`。**仅 Apple Silicon + macOS 15 以上**，Intel Mac 没有官方包。
- 飞书（Windows）：`scripts/tools/get-lark-cli.ps1` —— `npm install @larksuite/cli@1.0.100`，npm 按 lock 的 sha512 校验包，包的 postinstall 用包内 `checksums.txt` 校验二进制。
- 飞书（macOS）：`scripts/tools/install-bundled-tools-mac.sh feishu` —— 按 CPU 下载官方 `lark-cli-1.0.100-darwin-arm64.tar.gz`（sha256 `d068a27f608335016a8a7fb1b3cd1fccfb96bda92075a027e2bf1c4c23134e30`）或 `-darwin-amd64.tar.gz`（sha256 `7f5d442e5da3ae62b03a5b552880b651637b16b2eed91b588afaca6d72a6643a`），校验后解压到 `third_party/tools/lark-cli/bin/`。

## QQ：不绑定具体实现

本项目的 QQ 采集器只依赖 **OneBot 11 HTTP 协议**（`get_login_info` / `get_group_list` / `get_group_msg_history`，可选的实时上报 `POST /api/ingest/onebot`），代码里不包含任何 QQ 客户端框架的代码或二进制。你需要自己选择一个 OneBot 11 实现并按其文档安装、登录、开启 HTTP 服务端（本项目约定端口 `3010`）。

> **历史说明：** 本项目早期版本使用并分发了 **NapCatQQ**。该项目已停止维护（仓库内容清空、Release 与 Tag 全部下线），因此本仓库不再提供 NapCat 的下载或安装脚本。你仍可自行寻找历史副本，但那不属于本项目的支持范围。

选型参考（**本项目不为其背书**，请自行核实最新许可与可用性）：

| 实现 | 平台 | 许可 | 备注 |
|---|---|---|---|
| [SnowLuma](https://github.com/TomyJan/SnowLuma) | Windows x64、Linux x64 / arm64 | 源码可见的**非商业**许可（非 OSI 开源） | 需按项目文档安装；Lite 版需 Node.js 24+ |
| [LuckyLilliaBot](https://github.com/LuckyLilliaDev/LuckyLilliaBot) | Windows x64、macOS arm64、Linux x64 / arm64 | **GPL-2.0** | 需 Node.js 24+；GPL 的义务仅在你再分发其代码时触发 |
| 任意 OneBot 11 实现 | 视实现而定 | 视实现而定 | 只要能开 HTTP 服务端并支持上述接口即可 |

如果你不想引入任何第三方 QQ 框架，可以只用「导入聊天记录」：把导出的 JSON / CSV / 文本放进 `data/inbox/qq/` 或拖进「情报源」页面。

---

## lark-cli — MIT License

来源：<https://github.com/larksuite/cli/blob/main/LICENSE>

```
MIT License

Copyright (c) 2026 Lark Technologies Pte. Ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Python 与前端依赖

Python 依赖见 `requirements.txt` / `requirements-dev.txt`，前端依赖见 `web/package.json`，各自的许可证随各自的发行包提供（`pip show <包名>` 或 `node_modules/<包>/LICENSE`）。这些依赖通过包管理器安装，本仓库不包含其源码。
