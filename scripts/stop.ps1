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

$l = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $l) {
    Write-Host "端口 $Port 上没有在运行的工作台。" -ForegroundColor Green
    exit 0
}
$p = Get-CimInstance Win32_Process -Filter "ProcessId=$($l.OwningProcess)"
if (-not $p -or $p.CommandLine -notmatch 'bureau\s+serve') {
    Write-Host "端口 $Port 被别的程序占用（进程 $($l.OwningProcess)），不是情报局工作台，没有动它。" -ForegroundColor Yellow
    exit 1
}
# venv 的 python.exe 会再拉起一个真正的 python，连同它的父进程一起停
$target = $p.ProcessId
$parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" -ErrorAction SilentlyContinue
if ($parent -and $parent.CommandLine -match 'bureau\s+serve') { $target = $parent.ProcessId }
& taskkill.exe /PID $target /T /F | Out-Null
Start-Sleep -Seconds 1
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    Write-Host '没能停止，请重试，或者在任务管理器里结束 python.exe。' -ForegroundColor Red
    exit 1
}
Write-Host '工作台已停止。' -ForegroundColor Green
