# Live fault-only debug: dropped draws, pipeline errors, and warnings.
# Streams to this console and writes the same lines to .temp\live-faults-*.log
# (plus a rolling .temp\live-faults.log).
#
#   .\scripts\live-faults.ps1
#   .\scripts\live-faults.ps1 -FrameGen
#   .\scripts\live-faults.ps1 -SeriesS -Dlss performance
#   .\scripts\live-faults.ps1 -Exe 'D:\MyDump\game_scarlett_master.exe'
#
# Under the hood: VICTORY_LIVE_FAULTS=1 + VICTORY_LOG=warn through play-foxhound.
param(
    [string]$Exe = '',
    [ValidateSet('diag', 'release')][string]$Build = 'release',
    [switch]$SeriesS,
    [ValidateSet('1440', '1080to1440', '4k')][string]$Res = '1440',
    [ValidateSet('off', 'dlaa', 'quality', 'balanced', 'performance')][string]$Dlss = 'quality',
    [switch]$FrameGen,
    [ValidateRange(2, 6)][int]$FrameGenX = 2,
    [switch]$NoFrameGenReady,
    [ValidateSet('auto', 'dlss', 'fsr')][string]$FgType = 'auto',
    [ValidateRange(1, 1000)][int]$Fps = 1000,
    [hashtable]$More = @{}
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$temp = Join-Path $repo '.temp'
New-Item -ItemType Directory -Force -Path $temp | Out-Null

function Test-GameDir([string]$d) {
    if (-not $d -or -not (Test-Path (Join-Path $d 'game_scarlett_master.exe'))) { return $false }
    return (Test-Path (Join-Path $d 'shaders.rpf')) -or (Test-Path (Join-Path $d 'MicrosoftGame.config'))
}
function Find-GameDir {
    $txt = Join-Path $repo 'game_dir.txt'
    if (Test-Path $txt) {
        $d = (Get-Content $txt -Encoding UTF8 -TotalCount 1).Trim().Trim('"')
        if (Test-GameDir $d) { return $d }
    }
    $desk = Join-Path $env:USERPROFILE 'Desktop\GTAVI'
    if (Test-GameDir $desk) { return $desk }
    return $null
}

if (-not $Exe) {
    $dir = Find-GameDir
    if (-not $dir) {
        Write-Host 'Pass -Exe <path\to\game_scarlett_master.exe> or put the dump path in game_dir.txt.'
        exit 1
    }
    $Exe = Join-Path $dir 'game_scarlett_master.exe'
}
if (-not (Test-Path -LiteralPath $Exe)) { Write-Host "No $Exe."; exit 1 }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$faultLog = Join-Path $temp "live-faults-$stamp.log"
$latest = Join-Path $temp 'live-faults.log'
"# live-faults $stamp build=$Build exe=$Exe" | Set-Content -LiteralPath $faultLog -Encoding utf8
Copy-Item -LiteralPath $faultLog -Destination $latest -Force

$faultMore = @{
    VICTORY_LIVE_FAULTS   = '1'
    VICTORY_LOG           = 'warn'
    VICTORY_LOG_FILE      = $faultLog
    # Warmup restart would drop this filter and the .temp log attachment.
    VICTORY_WARMUP_RESTART = '0'
}
foreach ($k in @($More.Keys)) { $faultMore[$k] = $More[$k] }

$opts = @{
    Exe     = $Exe
    Build   = $Build
    Res     = $Res
    Dlss    = $Dlss
    FgType  = $FgType
    Fps     = $Fps
    More    = $faultMore
}
if ($SeriesS) { $opts.SeriesS = $true }
if ($FrameGen) { $opts.FrameGen = $true; $opts.FrameGenX = $FrameGenX }
if ($NoFrameGenReady) { $opts.NoFrameGenReady = $true }

Write-Host "Live faults: console + $faultLog"
Write-Host '  (only WARN / dropped / pipeline refuse; rolling copy: .temp\live-faults.log)'
Write-Host '  Tip: keep Frame Gen off first if the PC hard-cuts power (PLAY_FRAMEGEN.cmd 2).'
Write-Host ''

# play-foxhound tees stderr WARN lines; Stop would kill the run on the first warn.
$ErrorActionPreference = 'Continue'
& (Join-Path $PSScriptRoot 'play-foxhound.ps1') @opts

# Keep the rolling name pointed at this run's file.
if (Test-Path -LiteralPath $faultLog) {
    Copy-Item -LiteralPath $faultLog -Destination $latest -Force
    Write-Host "Fault log: $faultLog"
}
