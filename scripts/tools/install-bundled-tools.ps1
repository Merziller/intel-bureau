<#
.SYNOPSIS
  准备接入工具：微信 WeChatDataAnalysis、飞书 lark-cli（QQ 用任意 OneBot 11 实现，本项目不代为安装）。
  本地没有时，会调用官方下载脚本联网获取并校验 SHA-256，解压到 third_party\tools\（已 gitignore）。
  一般不用直接运行，双击根目录的「安装接入工具.bat」即可。
.PARAMETER Tool
  menu（默认，显示菜单）/ wechat / qq / feishu / all
.PARAMETER NoRun
  只校验和准备，不运行安装程序（测试用）。
#>
[CmdletBinding()]
param(
    [ValidateSet('menu', 'wechat', 'qq', 'feishu', 'all')][string]$Tool = 'menu',
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Tools = Join-Path $Root 'third_party\tools'

function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Sha256([string]$p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant() }
function Ask([string]$q) { if ($NoRun) { return $false }; (Read-Host "$q (Y/n)") -notmatch '^[nN]' }

# 运行同目录下的官方下载脚本（它们都用 GitHub Releases 的 asset.digest 或官方 SHA256SUMS 校验）
function Invoke-Downloader([string]$name, [string[]]$arguments = @()) {
    $script = Join-Path $PSScriptRoot $name
    if (-not (Test-Path -LiteralPath $script)) {
        Say "找不到下载脚本 scripts\tools\$name，请确认项目完整。" 'Red'
        return $false
    }
    Say "本地没有现成的安装文件，开始联网下载（脚本：scripts\tools\$name）..." 'Yellow'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @arguments
    if ($LASTEXITCODE -ne 0) {
        Say "下载失败（退出码 $LASTEXITCODE）。可以稍后重试，或按文档手动下载后放到 third_party\tools\ 下。" 'Red'
        return $false
    }
    return $true
}

# ---------------------------------------------------------------- 微信
function Install-Wechat {
    Say ''
    Say '=== 微信：WeChatDataAnalysis ===' 'Cyan'
    $dir = Join-Path $Tools 'wda'
    $setup = Get-ChildItem -LiteralPath $dir -Filter '*Setup.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $setup) {
        if (-not (Invoke-Downloader 'get-wechat-data-analysis.ps1')) { return }
        $setup = Get-ChildItem -LiteralPath $dir -Filter '*Setup.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $setup) { Say '下载完成但没找到安装程序，请查看上面的输出。' 'Red'; return }
    }
    $sums = Get-ChildItem -LiteralPath $dir -Filter '*SHA256SUMS*.txt' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $expected = $null
    if ($sums) {
        foreach ($line in Get-Content -LiteralPath $sums.FullName -Encoding UTF8) {
            if ($line -match '^([0-9A-Fa-f]{64})\s+\*?(.+Setup\.exe)\s*$' -and $Matches[2] -eq $setup.Name) { $expected = $Matches[1].ToLowerInvariant() }
        }
    }
    Say ('校验安装程序（{0:N0} MB，需要几秒）...' -f ($setup.Length / 1MB))
    $actual = Sha256 $setup.FullName
    if ($expected -and $actual -ne $expected) {
        Say "校验不一致！文件可能损坏，请删掉后重新下载。期望 $expected，实际 $actual" 'Red'
        return
    }
    Say ($(if ($expected) { '校验通过（与官方 SHA-256 一致）。' } else { '没有找到官方校验值，无法比对；请确认文件来自官方发布页。' })) 'Green'
    Say ('安装程序：' + $setup.FullName)
    if (Ask '现在运行安装程序吗？（会弹出安装向导，一路下一步即可）') {
        Start-Process -FilePath $setup.FullName
        Say '安装向导已打开。装好后打开「微信数据分析助手」，按 docs\SETUP_WECHAT.md 登录并完成解密，然后回到工作台「情报源」→ 微信，打开启用开关。' 'Yellow'
    } else {
        Say '需要时双击上面这个 Setup.exe 即可。装好后按 docs\SETUP_WECHAT.md 操作。'
    }
}

# ---------------------------------------------------------------- QQ
function Install-Qq {
    Say ''
    Say '=== QQ：任意 OneBot 11 实现 ===' 'Cyan'
    Say '工作台的 QQ 采集器只依赖 OneBot 11 HTTP 协议，不绑定具体实现，也不代为安装。'
    Say '可选实现（本项目不背书，请自行核实许可与可用性）：'
    Say '  SnowLuma        https://github.com/TomyJan/SnowLuma          Windows x64 / Linux，非商业许可'
    Say '  LuckyLilliaBot  https://github.com/LuckyLilliaDev/LuckyLilliaBot  Win / macOS arm64 / Linux，GPL-2.0'
    Say ''
    Say '装好并登录后，在它的网络配置里开启 HTTP 服务端：主机 127.0.0.1、端口 3010、消息格式 array，并设一个 token。'
    Say '详细步骤见 docs\SETUP_QQ.md（含实时上报的可选配置）。'
    Say ''
    Say '如果不想引入任何框架：把导出的聊天记录放进 data\inbox\qq\，或在「情报源」页面导入。'
}

# ---------------------------------------------------------------- 飞书
function Install-Feishu {
    Say ''
    Say '=== 飞书：lark-cli（官方命令行工具）===' 'Cyan'
    $exe = Join-Path $Tools 'lark-cli\node_modules\@larksuite\cli\bin\lark-cli.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        if (-not (Invoke-Downloader 'get-lark-cli.ps1')) { return }
        if (-not (Test-Path -LiteralPath $exe)) { Say '下载完成但没找到 lark-cli，请查看上面的输出。' 'Red'; return }
    }
    $ver = (& $exe --version 2>&1 | Select-Object -First 1)
    Say ("lark-cli 已就绪：$ver（不需要额外配置 Node.js 路径，工作台会自动找到它）") 'Green'
    Say ''
    Say '接下来（详细步骤见 docs\SETUP_FEISHU.md）：' 'Yellow'
    Say '  1. 第一次使用要配置一个飞书应用：运行下面这条命令，按提示在浏览器里操作。'
    Say ('       "' + $exe + '" config init')
    Say '  2. 然后双击根目录的「飞书重新授权.bat」，在浏览器里点「授权」。'
    Say '  3. 回到工作台「情报源」→ 飞书，打开启用开关，点「测试」。'
    if (Ask '现在运行「config init」吗？') {
        & $exe config init
    }
}

function Show-Menu {
    Say ''
    Say '=== 个人情报局 · 准备接入工具 ===' 'Cyan'
    Say '想读取哪个平台的群消息，就装哪个。只想看演示或导入聊天记录文件的话，这三个都不用装。'
    Say '本地没有时会联网下载官方文件并校验 SHA-256（微信约 380 MB，需要几分钟）。'
    Say ''
    Say '  1  微信（WeChatDataAnalysis 安装程序）'
    Say '  2  QQ（说明：用任意 OneBot 11 实现，本项目不代为安装）'
    Say '  3  飞书（lark-cli，需要 Node.js 20 以上）'
    Say '  4  三个都处理'
    Say '  0  退出'
    Say ''
    switch ((Read-Host '请输入数字').Trim()) {
        '1' { Install-Wechat }
        '2' { Install-Qq }
        '3' { Install-Feishu }
        '4' { Install-Wechat; Install-Qq; Install-Feishu }
        default { }
    }
}

switch ($Tool) {
    'wechat' { Install-Wechat }
    'qq' { Install-Qq }
    'feishu' { Install-Feishu }
    'all' { Install-Wechat; Install-Qq; Install-Feishu }
    default { Show-Menu }
}
