# 用 GitHub Desktop 维护这个仓库

这个仓库已经在 <https://github.com/Merziller/intel-bureau> 上，正常使用不需要再碰命令行。
下面是最常见的四件事。

## 一、把仓库下载到自己电脑

1. 打开 GitHub Desktop → 菜单 **File → Clone repository**。
2. 选 **GitHub.com** 标签页，列表里找到 `intel-bureau`，点它。
3. **Local path** 选一个空目录（例如 `D:\IntelBureau`），点 **Clone**。
4. 克隆完成后点 **Repository → Show in Explorer**，能看到 `README.md`、`bureau`、`scripts` 等文件夹就成功了。

> 之后运行程序：Windows 双击 `一键安装并启动.bat`，macOS 双击 `一键安装并启动.command`。

## 二、改完东西怎么推上去

GitHub Desktop 的左侧会列出你改动过的文件。确认无误后：

1. 左下角 **Summary** 填一句说明，例如 `修正飞书文档里的错别字`。
2. 点 **Commit to main**。
3. 顶部点 **Push origin**（有时按钮叫 **Publish branch**）。
4. 打开网页版仓库刷新，能看到最新提交就说明成功了。

只想推某一个文件：在左侧取消勾选其它文件再提交。

## 三、别人改了 / 你在别的电脑改了，怎么同步下来

点顶部 **Fetch origin**，如果有新提交，按钮会变成 **Pull origin**，点一下即可。

## 四、常见问题

| 现象 | 原因与处理 |
|---|---|
| Push 报 `Updates were rejected` | 远端有新提交，先点 **Pull origin** 再 Push |
| Push 要求登录 | **File → Options → Accounts** 重新登录 GitHub 账号 |
| 提示文件太大被拒 | 单个文件超过 100 MB 会被 GitHub 拒绝；本仓库已通过 `.gitignore` 排除 `data/`、`third_party/`、`web/node_modules/`，别手动加回来 |
| 提交里混进了 `data/` 或 `config/secrets.yaml` | 立刻在 GitHub Desktop 里取消勾选这些文件；如果已经推上去，需要改仓库里的 `.gitignore` 并把这些文件从历史里移除（这一步建议先开 issue 或问人） |
| 想把仓库改成私有 | 网页版 **Settings → General → Danger Zone → Change visibility** |

## 五、网页版也能改

小改动（改 README 错别字、改文档）可以直接在网页上做：打开文件 → 右上角铅笔图标 → 改 → 底部 **Commit changes** → 选 *Commit directly to the main branch*。

## 六、注意

- 这个仓库是**公开**的，任何人都能看到。不要提交真实聊天记录、密钥、手机号、群名。
- `data/`（数据库、报告、日志）、`config/settings.yaml`、`config/secrets.yaml`、`third_party/`（下载的第三方工具）都已在 `.gitignore` 里，正常不会被提交。
- 提交前可以用 GitHub Desktop 的 **History** 标签页看一眼这次到底改了哪些文件。
