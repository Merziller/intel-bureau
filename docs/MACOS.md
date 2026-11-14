# macOS 安装与使用

这一份是给**苹果电脑**用的。Windows 见 [新手使用说明.md](../新手使用说明.md)，两者用的是同一份代码，只是启动入口不同（`.command` 而不是 `.bat`）。

> **重要区别先看这里**
>
> | 项目 | Windows | macOS |
> |---|---|---|
> | 芯片 | 都行 | **微信工具官方只提供 Apple Silicon（M 系列）版本**；Intel 的 Mac 只能用「导入聊天记录文件」这条路，QQ / 飞书照常可用 |
> | 微信读取方式 | 实时读本机数据库 | Apple Silicon 上同样是实时读，不用手动导出（差异见第四节） |
> | 系统版本 | 10 / 11 | 通用功能 macOS 12 以上；**微信工具要求 macOS 15 以上** |
> | 启动入口 | `.bat` 文件 | `.command` 文件（Finder 里双击） |
> | 图片里的文字（OCR） | 用系统自带 OCR，自动 | 系统没有可用的命令行 OCR，默认关闭；可在设置里改成用 AI 认图（`llm`） |
> | 飞书工具 | 走 npm 装 | 按 CPU 自动选 `darwin-arm64` / `darwin-amd64` 官方包 |
>
> 这份文档的 macOS 部分，代码层面已经在 GitHub Actions 的 `macos-26-arm64`（Apple Silicon）上自动跑过：
> pytest 380 passed、`bureau init`、`bureau demo seed`、`bureau run --demo --dry-run`、`bureau doctor` 全通过。
> **还没有验证的是**：Finder 里双击 `.command` 的真实体验、三个接入工具（微信 / QQ / 飞书）的安装与联调、以及界面在 Mac 上的显示效果。
> 第一次装如果卡住，把终端窗口里的文字发到 [Issues](https://github.com/Merziller/intel-bureau/issues)，或加 QQ 1411574209 说明来意。

---

## 一、准备

| 需要 | 说明 |
|---|---|
| Apple Silicon 的 Mac（M1/M2/M3/M4） | 用微信来源才必须；只用 QQ / 飞书 / 导入文件的话 Intel Mac 也可以 |
| macOS 12 或以上 | 微信工具要求 macOS 15 以上 |
| 能上网 | 第一次安装要下载 Python 依赖（约 100 MB）；接入工具需要时再单独下载（微信约 425 MB） |
| 约 1.5 GB 空闲磁盘 | 依赖、工具和几个月的运行数据 |
| Python 3.12 | 没有的话，安装脚本会用 Homebrew 装，或者提示你手动装 |
| Node.js 20.19+ | 只在需要构建前端时用；如果你拿到的是已构建好的仓库（`web/dist` 存在），脚本会跳过 |

---

## 二、安装（只做一次）

### 第 1 步：拿到代码

```bash
git clone https://github.com/Merziller/intel-bureau.git ~/IntelBureau
cd ~/IntelBureau
```

没有 git 的话，在 GitHub 页面点「Code → Download ZIP」，解压到 `~/IntelBureau`。

建议放在你的用户目录下。**不要**放在「下载」「桌面」「iCloud 云盘」「Dropbox」里：这些目录会被同步或按需下载，容易出现文件缺失。

### 第 2 步：跑安装脚本

```bash
bash scripts/setup-mac.sh
```

它会依次做：

1. 找 Python 3.12；没有就用 Homebrew 装（没装 Homebrew 会提示你去 python.org 下载安装包）。
2. 创建 `.venv` 虚拟环境并安装依赖（约 2~5 分钟）。
3. 有 `web/dist` 就跳过前端构建，否则 `npm ci && npm run build`。
4. 初始化配置和数据库。

也可以直接在 Finder 里双击 `一键安装并启动.command`（第一次要右键 →「打开」放行，见下）。

### 第 3 步：第一次双击要放行

macOS 默认不允许运行从网络下载的脚本：

1. 在 Finder 里**右键**（或按住 Control 点）`一键安装并启动.command` → 选「**打开**」。
2. 弹窗里再点「**打开**」。

> 如果提示「无法打开，因为无法验证开发者」：到 **系统设置 → 隐私与安全性**，在下面找到这条拦截，点「**仍要打开**」。
> 只需要做一次，之后普通双击就能用。也可以一次性清掉整个目录的隔离标记：`xattr -dr com.apple.quarantine ~/IntelBureau`。

---

## 三、以后怎么打开

| 想做什么 | 双击 | 或命令行 |
|---|---|---|
| 打开工作台 | `启动情报局.command` | `bash scripts/start-mac.sh` |
| 立刻停掉后台服务 | `停止情报局.command` | `bash scripts/stop-mac.sh` |
| 准备微信 / 飞书的接入工具 | `安装接入工具.command` | `bash scripts/tools/install-bundled-tools-mac.sh` |
| 飞书重新授权 | `飞书重新授权.command` | `bash scripts/feishu-reauth-mac.sh` |
| 一键安装并启动 | `一键安装并启动.command` | `bash scripts/first-run-mac.sh` |

- 启动时会闪过一个终端窗口，几秒后就没了；大屏会以独立窗口打开（优先用 Edge / Chrome 的应用模式，没有就用默认浏览器）。
- **关掉大屏窗口约 20 秒后，后台服务自己停止**；如果那时正好有任务在跑，会等它跑完再停。
- 出错时不会静默失败：会弹一个系统提示框，细节记在 `data/logs/launcher.log`、`data/logs/server-console.err.log`。
- 想让它开机自动在后台跑（定时出报准点）：见第七节。

> 注意：大屏关着的时候服务也停了，**定时任务不会执行**。要每天准点出报，要么让大屏一直开着，要么用第七节的开机自启。
> 另外，macOS 默认在合上盖子时休眠，休眠期间任务不会跑。

---

## 四、接入你自己的群

| 来源 | macOS 能不能用 | 怎么装 |
|---|---|---|
| 导入聊天记录文件（JSON / CSV / 复制粘贴） | ✅ 都能用，最简单 | 不用装任何东西，直接拖进「情报源」页 |
| 飞书 | ✅ Apple Silicon 和 Intel 都行 | `安装接入工具.command` → 选 3 |
| QQ | ✅ Apple Silicon 和 Intel 都行 | 自己装一个 OneBot 11 实现，见下 |
| 微信（WeChatDataAnalysis） | ⚠️ **只有 Apple Silicon**，且要 macOS 15+ | `安装接入工具.command` → 选 1 |

### 微信（仅 Apple Silicon）

1. 双击 `安装接入工具.command`，选 1：脚本先判断芯片（Intel 直接退出，不会白下 425 MB），再从官方发布页下载 `WeChatDataAnalysis-2.10.1-mac-arm64.dmg`、校验 SHA-256，然后打开镜像。
2. 把图标拖进「应用程序」；第一次打开若被拦，去 **系统设置 → 隐私与安全性** 点「仍要打开」。
3. 打开「微信数据分析助手」，按向导「获取密钥 → 解密数据库」。按提示授予必要的权限（部分步骤需要「辅助功能」权限）。
4. 它会在 `http://127.0.0.1:10392` 提供本地接口；工作台「情报源」→ 微信，适配器选 **WeChatDataAnalysis 本地 API**，地址保持默认，点「测试」。
5. 确认它开着「实时模式」，这样每次定时任务读到的都是最新消息。

#### 和 Windows 版有什么不同（依据 WDA 源码与安装包核对）

先给结论：**Apple Silicon 的 Mac 和 Windows 一样是「实时读」，不需要手动导出聊天记录。**

WeChatDataAnalysis 2.10.1 的 macOS 安装包里有实时 WCDB 组件，它的平台能力判定
（`platform_support.py` 的 `runtime_capabilities()`）在 Apple Silicon 且组件齐全时给出 `realtime_wcdb = True`。
工作台只调用它的本地 HTTP 接口，这些接口没有按平台做限制。

| 能力 | Windows | macOS（Apple Silicon） |
|---|---|---|
| 实时读数据库（不用导出） | ✅ | ✅ 实时 WCDB，读的是微信正在写的那个库 |
| 取聊天里的图片、视频 | ✅ | ✅ 从解密后的资源目录取，取不到时再走 CDN 原图 |
| 图片密钥 | ✅ 进程内读取 | ✅ 从微信自己的 kvcomm 本地文件读 |
| 数据库密钥 | ✅ | ✅ 但每次获取要联网做一次安全校验（见下） |
| 「微信进程内媒体 Hook」 | ✅ | 仅 Windows 提供；macOS 走上面两条路，不是必需 |

最后那一项是 Windows 上「还没解密也能拿到图」的兜底手段，macOS 没有这条路径；
Mac 走的是「解密资源目录 + kvcomm 图片密钥 + CDN 原图」，图片、视频同样能取回放进报告。

两点注意：

- **数据库密钥要联网校验。** macOS 上取微信数据库密钥需要完整安装包里的本地受控组件，
  而且**每次获取密钥时都会做一次联网安全校验**（校验不过就取不到，也可以手动填已有的 64 位密钥）。
  WDA 的构建清单里带了组件有效期，2.10.1 这一版到 **2026-12-17** 左右到期；到期后 WDA 会提示更新，装新版即可。
- **图片里的文字要开 AI 认图。** macOS 没有系统命令行 OCR，默认关闭，见本节最后的说明。

> **Intel 的 Mac：确实没有官方微信工具。** WDA 的 macOS 发行包只提供 `mac-arm64`，主程序本身也是 arm64 单架构，
> Intel 机器装不上；同类工具 WeFlow 的 macOS 版同样只支持 Apple Silicon；更早的 chatlog 已被作者按微信官方要求下架。
> 所以 Intel Mac 只能走「导入聊天记录文件」：在任意能导出微信记录的设备上导出 JSON / CSV，再拖进「情报源」页。
> 这不是打包没做好，是上游工具的事实限制。

### QQ（任意 OneBot 11 实现）

工作台的 QQ 采集器只依赖 **OneBot 11 HTTP 协议**，不绑定具体实现，也不代为安装。

1. 自己选一个实现并装好，用**小号**登录。本项目不背书，请自行核实许可与可用性：
   - [SnowLuma](https://github.com/TomyJan/SnowLuma)：Windows x64 / Linux，源码可见的**非商业**许可，**没有 macOS 构建**
   - [LuckyLilliaBot](https://github.com/LuckyLilliaDev/LuckyLilliaBot)：Windows x64 / **macOS arm64** / Linux，**GPL-2.0**，需 Node.js 24+
2. 在它的网络配置里开启 **HTTP 服务端**：主机 `127.0.0.1`、端口 `3010`、消息格式 `array`，并设一个 token（`uuidgen | tr -d '-' | tr 'A-Z' 'a-z'`）。
3. 工作台「情报源」→ QQ，填入同一个 token，点「测试」。

> **历史说明：** 早期版本用的是 NapCatQQ，它已停止维护（仓库内容清空、Release 与 Tag 全部下线），
> 因此本仓库不再提供它的下载与安装脚本。

详细设置（含安全提醒、实时上报）见 [SETUP_QQ.md](SETUP_QQ.md)。

### 飞书

1. `安装接入工具.command` → 选 3：脚本按你的 CPU 自动选 `darwin-arm64` 或 `darwin-amd64` 的官方 `lark-cli`，下载并校验 SHA-256 后解压到 `third_party/tools/lark-cli/bin/`。
2. 第一次使用要配置一个飞书应用：`third_party/tools/lark-cli/bin/lark-cli config init`。
3. 双击 `飞书重新授权.command`，在浏览器里点「授权」。
4. 工作台「情报源」→ 飞书，打开启用开关，点「测试」。

详细步骤见 [SETUP_FEISHU.md](SETUP_FEISHU.md)。

### 图片文字识别（OCR）

macOS 上没有 Windows 那种系统自带 OCR。默认**关闭 OCR**：图片仍会被取回、放进报告的「图片与文档」板块，只是不会识别里面的文字。

想识别图片里的文字，到「智能体 → 媒体」把 OCR 改成 `llm`（用你配置的 AI 模型看图，会计入费用），或在 `config/settings.yaml` 里设 `media.ocr: llm`。

---

## 五、让 AI 帮你写专题文章（可选）

和 Windows 版完全一样：

1. 到 <https://platform.deepseek.com/> 注册并创建一个 API Key。
2. 工作台 →「智能体」→ 模型提供方选「OpenAI 兼容接口」，预设选「DeepSeek」，粘贴 Key，点「测试调用」。
3. 打开「云端同意」开关（打开后白名单群的聊天内容才会发给 AI）。
4. 建议把「单次费用上限」设成 5 元左右。

---

## 六、安全与隐私

- 聊天记录只存在这台 Mac 的 `data` 文件夹里，不会上传；只有打开「云端同意」后，白名单群的内容才会发给你选的 AI。
- 密钥在 `config/secrets.yaml`，**不要提交或发给别人**（`.gitignore` 已排除它和 `data/`）。
- 服务只监听 `127.0.0.1:8765`，同一 Wi-Fi 下的其他人访问不到。
- WeChatDataAnalysis 的本地接口 `127.0.0.1:10392` **没有密码，而且允许任何网页跨域访问**：它运行期间不要打开不可信的网页，不用时关掉它。
- 程序只**读**聊天记录，不会替你发消息，也不会改动微信 / QQ / 飞书。

---

## 七、开机自启（想每天准点出报才需要）

```bash
cd ~/IntelBureau
bash scripts/install-autostart-mac.sh      # 登录后在后台常驻运行工作台
bash scripts/uninstall-autostart-mac.sh    # 取消
```

它会写一个 `~/Library/LaunchAgents/com.intelbureau.workbench.plist`，登录时启动服务（大屏不用开着）。
取消后如果还有残留进程：`bash scripts/stop-mac.sh`。

---

## 八、常见问题

**双击 `.command` 提示「无法打开，因为无法验证开发者」。**
右键（Control + 点）→「打开」，再在弹窗里点「打开」。之后就不用这样了。或者：`xattr -dr com.apple.quarantine ~/IntelBureau`。

**提示「operation not permitted」或「Permission denied」。**
确认代码在你的用户目录（不要在 `/Applications`、`/usr/local` 这种系统目录），并且没有被「文件保险箱」或 MDM 策略限制。如果 `.command` 丢了执行权限：`chmod +x *.command scripts/*.sh scripts/tools/*.sh`。

**提示「Python 3.12 not found」，也没有 Homebrew。**
去 <https://www.python.org/downloads/macos/> 下载 Python 3.12 的安装包装上，再跑一次 `bash scripts/setup-mac.sh`。或者先装 Homebrew（<https://brew.sh>）。

**端口 8765 被占用。**
说明已经有一个工作台在跑：直接打开 <http://127.0.0.1:8765>。如果是别的程序占用，先 `停止情报局.command`，或改端口：`BUREAU_PORT=8790 bash scripts/start-mac.sh`。

**微信工具装上了，但工作台测试连不上。**
先在「微信数据分析助手」里完成「获取密钥 → 解密数据库」，并确认它自己在 `http://127.0.0.1:10392` 能打开；再检查它有没有开「实时模式」。

**下载接入工具时校验不一致。**
说明文件没下完整或被中间人替换。脚本不会使用未通过校验的文件：删掉 `third_party/tools/` 下对应的文件，重跑一次即可。

**图片里的字没有识别出来。**
macOS 默认关闭 OCR，见第四节最后一段。

**想升级到新版本。**
`git pull`，再跑一次 `bash scripts/setup-mac.sh`（依赖或前端有变化时它会重装）；`data/` 和 `config/settings.yaml` 不会被覆盖。

**怎么彻底卸载。**
`bash scripts/stop-mac.sh`，如果你装了开机自启先 `bash scripts/uninstall-autostart-mac.sh`，然后删掉整个文件夹（连带 `.venv`、`data`）。
