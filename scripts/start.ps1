<#
.SYNOPSIS
  启动情报局工作台。

  默认（-Gui，由 launch-hidden.vbs 带上）：不出现黑色窗口。服务在后台隐藏运行，用 Edge 应用窗口打开大屏；
  所有大屏页面都关掉后约 20 秒，服务自己退出（如果这时有任务正在运行，会等它跑完再退）。
  「是否还开着」由服务统计实时连接来判断，不依赖浏览器窗口，所以任何浏览器、多个标签页都适用。
  出错时弹出提示框，详细记录在 data\logs\launcher.log 和 server-console.log。

  不带 -Gui：旧的控制台方式，服务在本窗口里运行，关闭窗口或按 Ctrl+C 停止（调试时用）。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\start.ps1            # 控制台方式
  powershell -ExecutionPolicy Bypass -File scripts\start.ps1 -Gui       # 隐藏方式（双击 bat 时用的就是它）
  powershell -ExecutionPolicy Bypass -File scripts\start.ps1 -NoBrowser
#>
[CmdletBinding()]
param(
    [int]$Port = 8765,
    [switch]$NoBrowser,
    [switch]$Gui,
    [int]$IdleSeconds = 20
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$VenvPy = Join-Path $Root '.venv\Scripts\python.exe'
$Url = "http://127.0.0.1:$Port"
$DataDir = if ($env:BUREAU_DATA_DIR) { $env:BUREAU_DATA_DIR } else { Join-Path $Root 'data' }
$LogDir = Join-Path $DataDir 'logs'
$ProfileDir = Join-Path $DataDir 'edge-app-profile'
$LauncherLog = Join-Path $LogDir 'launcher.log'
$ServerOut = Join-Path $LogDir 'server-console.log'
$ServerErr = Join-Path $LogDir 'server-console.err.log'

function Test-Bureau {
    try {
        $r = Invoke-RestMethod -Uri "$Url/api/health" -TimeoutSec 2
        return [bool]$r.ok
    } catch {
        return $false
    }
}

function Test-PortInUse([int]$P) {
    # 直接连一下最可靠：不依赖 Get-NetTCPConnection / netstat 的状态字段
    # （有些 Windows 上监听 socket 的状态是空值，-State Listen 会漏掉）
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('127.0.0.1', $P, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(800)) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-PortOwner([int]$P) {
    try {
        foreach ($line in (& netstat.exe -ano 2>$null)) {
            $f = @($line -split '\s+' | Where-Object { $_ })
            if ($f.Count -lt 4 -or $f[0] -ne 'TCP') { continue }
            if ($f[1] -notmatch ":$P$") { continue }
            if ($f[2] -notmatch ':0$' -and $f[3] -ne 'LISTENING') { continue }
            $owner = if ($f[3] -eq 'LISTENING') { $f[4] } else { $f[3] }
            if ($owner -match '^\d+$') { return [int]$owner }
        }
    } catch { }
    try {
        $c = Get-NetTCPConnection -LocalPort $P -ErrorAction SilentlyContinue |
            Where-Object { $_.RemotePort -eq 0 -or "$($_.State)" -eq 'Listen' } |
            Select-Object -First 1
        if ($c) { return [int]$c.OwningProcess }
    } catch { }
    return $null
}

function Find-Browser {
    $c = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
    )
    return $c | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

# ======================================================================== 旧的控制台方式
if (-not $Gui) {
    if (-not (Test-Path $VenvPy)) {
        throw '还没有安装。请先运行：powershell -ExecutionPolicy Bypass -File scripts\setup.ps1'
    }
    function Open-Dashboard {
        if ($NoBrowser) { return }
        $edge = Find-Browser
        if ($edge) {
            Start-Process -FilePath $edge -ArgumentList "--app=$Url", '--window-size=1920,1080'
        } else {
            Start-Process $Url
        }
    }
    if (Test-Bureau) {
        Write-Host "工作台已在运行：$Url" -ForegroundColor Green
        Write-Host '已为你打开大屏窗口；这个窗口可以直接关掉，不影响正在运行的工作台。' -ForegroundColor Gray
        Open-Dashboard
        if (-not $NoBrowser) { Start-Sleep -Seconds 4 }          # 让提示留在屏幕上，不要一闪而过
        return
    }
    Write-Host "启动工作台：$Url （关闭本窗口或按 Ctrl+C 停止）" -ForegroundColor Cyan
    $proc = Start-Process -FilePath $VenvPy -ArgumentList @('-X', 'utf8', '-m', 'bureau', 'serve', '--port', "$Port") `
        -WorkingDirectory $Root -NoNewWindow -PassThru
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        if ($proc.HasExited) { break }
        if (Test-Bureau) { $ready = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) {
        if ($proc.HasExited) {
            throw ("服务启动失败（退出码 $($proc.ExitCode)）。常见原因：端口 $Port 被别的程序占用、依赖没装完整、杀毒软件拦截。`n" +
                   "可以重新双击「一键安装并启动.bat」修复安装，或运行 .venv\Scripts\python.exe -X utf8 -m bureau doctor 查看原因。")
        }
        Write-Warning '服务 30 秒内没有就绪，仍会继续等待；可以稍后手动打开浏览器。'
    } else {
        Open-Dashboard
    }
    Wait-Process -Id $proc.Id
    return
}

# ======================================================================== 隐藏方式（没有黑窗）
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log([string]$m) {
    try { Add-Content -LiteralPath $LauncherLog -Value ("{0}  {1}" -f (Get-Date -Format 'MM-dd HH:mm:ss'), $m) -Encoding UTF8 } catch { }
}

function Show-Popup([string]$msg, [int]$icon = 48) {
    # 没有控制台，所以用提示框；BUREAU_POPUP_TIMEOUT 只给自动化测试用，让提示框自己关闭
    $sec = 0
    if ($env:BUREAU_POPUP_TIMEOUT) { [void][int]::TryParse($env:BUREAU_POPUP_TIMEOUT, [ref]$sec) }
    try { [void](New-Object -ComObject WScript.Shell).Popup($msg, $sec, '个人情报局', $icon) } catch { }
}

function Get-LogTail([string]$path, [int]$n = 6) {
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    try { return ((Get-Content -LiteralPath $path -Tail $n -Encoding UTF8 -ErrorAction Stop) -join "`n") } catch { return '' }
}

function Get-AppProcesses {
    # 只认带着本工作台专用配置目录的浏览器进程，不会误碰你平时用的 Edge
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($ProfileDir, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
}

function Start-AppWindow([string]$browser) {
    New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null
    $argLine = "--app=$Url --user-data-dir=`"$ProfileDir`" --no-first-run --no-default-browser-check --window-size=1920,1080"
    Start-Process -FilePath $browser -ArgumentList $argLine | Out-Null
}

function Stop-ServerTree([int]$id) {
    & taskkill.exe /PID $id /T /F 2>&1 | Out-Null
}

function Invoke-Gui {
    Write-Log "启动 Port=$Port NoBrowser=$($NoBrowser.IsPresent)"
    if (-not (Test-Path $VenvPy)) {
        $fr = Join-Path $PSScriptRoot 'first-run.ps1'
        if (Test-Path $fr) {
            Write-Log '还没安装，转到一键安装'
            Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$fr`"")
            return
        }
        throw '还没有安装。请先双击「一键安装并启动.bat」。'
    }

    $browser = Find-Browser

    if (Test-Bureau) {
        # 已经有一个在跑（比如开机自启的后台服务、或另一个窗口启动的）：只负责打开窗口，不接管它的生命周期
        Write-Log '工作台已在运行，只打开窗口'
        if (-not $NoBrowser) {
            if ($browser) { Start-AppWindow $browser } else { Start-Process $Url }
        }
        return
    }

    if (Test-PortInUse $Port) {
        $owner = Get-PortOwner $Port
        $pn = if ($owner) { (Get-Process -Id $owner -ErrorAction SilentlyContinue).ProcessName } else { '' }
        $who = if ($pn) { "（$pn）" } else { '' }
        throw "端口 $Port 已经被别的程序占用$who，工作台没法启动。`n关闭那个程序，或者双击「停止情报局.bat」后再试。"
    }

    $env:PYTHONIOENCODING = 'utf-8'
    $serveArgs = @('-X', 'utf8', '-m', 'bureau', 'serve', '--port', "$Port")
    # 所有大屏页面都关闭、且没有任务在运行，持续 IdleSeconds 秒后服务自己退出（判断在服务里做，不依赖浏览器窗口）
    if (-not $NoBrowser) { $serveArgs += @('--exit-when-idle', "$IdleSeconds") }
    $proc = Start-Process -FilePath $VenvPy -ArgumentList $serveArgs `
        -WorkingDirectory $Root -WindowStyle Hidden -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru
    $null = $proc.Handle                                       # 先取句柄，否则进程退出后 ExitCode 读出来是空的
    Write-Log "服务进程已启动 pid=$($proc.Id)"

    $ready = $false
    for ($i = 0; $i -lt 180; $i++) {                          # 最多等 90 秒（冷启动、杀毒软件扫描时会慢）
        if ($proc.HasExited) { break }
        if (Test-Bureau) { $ready = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) {
        $tail = Get-LogTail $ServerErr
        if (-not $proc.HasExited) { Stop-ServerTree $proc.Id }
        throw ("服务没能启动。常见原因：依赖没装完整、杀毒软件拦截。`n可以重新双击「一键安装并启动.bat」修复安装。`n`n" +
               "日志：$ServerErr`n$tail")
    }
    Write-Log '服务已就绪'

    if ($NoBrowser) { Wait-Process -Id $proc.Id; return }      # 自动化测试用：不开窗口，服务一直跑到被停止

    if ($browser) {
        Start-AppWindow $browser
        Write-Log "已打开应用窗口 ($browser)"
    } else {
        Start-Process $Url                                     # 没有 Edge / Chrome：默认浏览器的标签页同样算「打开着」
        Write-Log '没有找到 Edge / Chrome，用默认浏览器打开'
    }

    # ---- 等服务退出：大屏全部关闭且没有任务在跑，服务会在 IdleSeconds 秒后自己退出 ----
    $proc.WaitForExit()
    $code = $proc.ExitCode
    Write-Log "服务已退出，退出码 $code"
    foreach ($p in @(Get-AppProcesses)) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    if ($null -ne $code -and $code -ne 0) {
        throw ("服务意外退出了（退出码 $code）。`n日志：$ServerErr`n" + (Get-LogTail $ServerErr))
    }
}

try {
    Invoke-Gui
} catch {
    Write-Log ("出错：" + $_.Exception.Message)
    Show-Popup ($_.Exception.Message + "`n`n详细记录：$LauncherLog") 16
    exit 1
}
