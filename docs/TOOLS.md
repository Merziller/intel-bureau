# 第三方工具选型（调研时间 2026-11-14）

数据来自 GitHub API（星数、最近推送时间、Release 资产与 sha256）和各项目 README。选型原则：只读、本地运行、能离线校验、维护活跃。

> 本仓库**不包含也不分发**这些工具，只在你运行下载脚本时从官方发布页取原始文件并校验 SHA-256。许可与注意事项见 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。

## 微信

| 工具 | 现状 | 结论 |
|---|---|---|
| [LifeArchiveProject/WeChatDataAnalysis](https://github.com/LifeArchiveProject/WeChatDataAnalysis) | 最新 v2.10.1；Windows `Setup.exe` 与 macOS `mac-arm64.dmg` 都在发；本地 FastAPI `:10392`，提供 `/api/chat/accounts`、`/api/chat/sessions`、`/api/chat/messages`、`/api/chat/search` | **主选**。风险：本地 API 无鉴权且 CORS 为 `*`；会上报不含内容的使用事件；macOS 只支持 Apple Silicon + macOS 15，且数据库密钥每次获取要联网校验 |
| [hicccc77/WeFlow](https://github.com/hicccc77/WeFlow) | 活跃；HTTP API `:5031`，有 Token 鉴权、`/api/v1/sessions`、`/api/v1/messages`，以及 SSE 主动推送 | **备选**。官方说明「不再内置任何读取/解密组件」，需要用户自行提供第三方组件（来源无法校验），所以不作为默认 |
| [sjzar/chatlog](https://github.com/sjzar/chatlog) | 仓库内容已清空（作者按微信官方要求下架），无 Release | **不用** |
| 小型 MCP 项目（wxq、wechatlog-mcp-server 等） | 星数个位到几十，维护者少 | 不用 |

## QQ

工作台只依赖 **OneBot 11 HTTP 协议**，不绑定实现。需要选型时参考：

| 实现 | 现状 | 结论 |
|---|---|---|
| [TomyJan/SnowLuma](https://github.com/TomyJan/SnowLuma) | 活跃；OneBot v11 · WebUI · SDK · MCP；Windows x64、Linux x64/arm64，**无 macOS 构建** | 可用。**源码可见的非商业许可**（不是 OSI 开源），商用需书面授权；Lite 版需 Node.js 24+ |
| [LuckyLilliaDev/LuckyLilliaBot](https://github.com/LuckyLilliaDev/LuckyLilliaBot) | 活跃；Windows x64、**macOS arm64**、Linux x64/arm64 | 可用（唯一有 macOS 构建的常见实现）。**GPL-2.0**，需 Node.js 24+ |
| [NapNeko/NapCatQQ](https://github.com/NapNeko/NapCatQQ) | **已终止**：README 只剩「Ending」一行，Releases 与 Tags 全部下线 | 不再提供下载脚本。历史副本自行寻找，不在支持范围 |
| [SXP-Simon/astrbot_plugin_qq_group_daily_analysis](https://github.com/SXP-Simon/astrbot_plugin_qq_group_daily_analysis) | 529★，MIT | 只作为群日报提示词和报告结构的参考，不引入 |

风险提示：这些都属于非官方客户端，存在被风控的可能。**建议用一个"情报员小号"登录**，拉进目标群，主号不受影响。推送到主号时，用小号私聊主号。

## 飞书

| 工具 | 现状 | 结论 |
|---|---|---|
| [larksuite/cli](https://github.com/larksuite/cli)（npm `@larksuite/cli`） | 官方，MIT，最新 v1.0.100；提供 Windows zip、macOS arm64/amd64、Linux 各架构 | **主选**。`im +chat-list`、`im +chat-messages-list`、`im +messages-send`、`docs +create`。首次使用先 `lark-cli config init` 配置应用，再 `lark-cli auth login` 授权用户身份 |
| 飞书自定义机器人 Webhook | 官方 | 推送备选，无需应用权限 |

## 推送到微信

企业微信群机器人、Server酱（sct.ftqq.com）、PushPlus（pushplus.plus）、WxPusher（wxpusher.zjiecode.com）。都是官方 HTTP 接口，无需 Hook 微信。实现时以各自的官方文档为准。

## 大模型

支持 `openai_compat`（DeepSeek、通义、Kimi、智谱、硅基流动、OpenRouter、Ollama）、`anthropic`、本机 `claude` CLI，以及完全离线的规则提取。密钥填在「智能体」页面或 `config/secrets.yaml`。
