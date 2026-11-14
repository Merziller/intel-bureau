<#
.SYNOPSIS
  停止后台运行的情报局工作台（隐藏方式启动后，如果大屏窗口已经关了但服务还在，或者想强制停止，就用它）。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\stop.ps1
#>
[CmdletBinding()]
param([int]$Port = 8765)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

function Test-PortInUse([int]$P) {
    # 直接连一下最可靠：不依赖 Get-NetTCPConnection / netstat 的状态字段
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
    # 先试 netstat: 第二列是本地地址:端口，状态为 LISTENING 的才是监听进程
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
    # 退路：不带 -State 查，挑「远端端口 0」或 Listen 的条目（有些 Windows 版本状态字段返回空）
    try {
        $c = Get-NetTCPConnection -LocalPort $P -ErrorAction SilentlyContinue |
            Where-Object { $_.RemotePort -eq 0 -or "$($_.State)" -eq 'Listen' } |
            Select-Object -First 1
        if ($c) { return [int]$c.OwningProcess }
    } catch { }
    return $null
}

if (-not (Test-PortInUse $Port)) {
    Write-Host "端口 $Port 上没有在运行的工作台。" -ForegroundColor Green
    exit 0
}

$procId = Get-PortOwner $Port
if (-not $procId) {
    Write-Host "端口 $Port 上确实有程序在跑，但查不到它的进程号。请在任务管理器里结束 python.exe。" -ForegroundColor Yellow
    exit 1
}

$p = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
if (-not $p -or $p.CommandLine -notmatch 'bureau\s+serve') {
    $name = if ($p) { $p.Name } else { "进程 $procId" }
    Write-Host "端口 $Port 被别的程序占用（$name），不是情报局工作台，没有动它。" -ForegroundColor Yellow
    exit 1
}

# venv 的 python.exe 会再拉起一个真正的 python，连同它的父进程一起停
$target = $p.ProcessId
$parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" -ErrorAction SilentlyContinue
if ($parent -and $parent.CommandLine -match 'bureau\s+serve') { $target = $parent.ProcessId }

& taskkill.exe /PID $target /T /F 2>&1 | Out-Null
for ($i = 0; $i -lt 20; $i++) {
    if (-not (Test-PortInUse $Port)) {
        Write-Host '工作台已停止。' -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Milliseconds 250
}
Write-Host '没能停止，请重试，或者在任务管理器里结束 python.exe。' -ForegroundColor Red
exit 1
