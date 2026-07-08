param(
    [string]$Video = "",
    [int]$Duration = 5,
    [int]$Camera = 0,
    [string]$Name = "",
    [switch]$SkipRecord,
    [switch]$SkipViz
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DataDir = Join-Path $Root "data"
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

function ConvertTo-WslPath([string]$Path) {
    $resolved = (Resolve-Path $Path).Path -replace '\\', '/'
    if ($resolved -match '^([A-Za-z]):(.*)$') {
        return "/mnt/$($Matches[1].ToLower())$($Matches[2])"
    }
    return $resolved
}

function Test-SmplxModels {
    $smplxDir = Join-Path $Root "third_party\PromptHMR\data\body_models\smplx"
    return (Test-Path (Join-Path $smplxDir "SMPLX_NEUTRAL.pkl")) -or
           (Test-Path (Join-Path $smplxDir "SMPLX_NEUTRAL.npz"))
}

if (-not (Test-SmplxModels)) {
    Write-Host ""
    Write-Host "SMPL-X models are missing." -ForegroundColor Yellow
    Write-Host "Download them once in WSL:"
    Write-Host "  wsl bash -c 'cd /mnt/d/python/video2robot/third_party/PromptHMR && bash scripts/fetch_smplx.sh'"
    Write-Host ""
    exit 1
}

if (-not $SkipRecord) {
    if ($Video -eq "") {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $Video = Join-Path $DataDir "webcam_$stamp.mp4"
    }

    Write-Host "=== Recording webcam ($Duration s) ===" -ForegroundColor Cyan
    python (Join-Path $Root "scripts\record_webcam.py") `
        --output $Video `
        --duration $Duration `
        --camera $Camera
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} elseif ($Video -eq "") {
    Write-Host "Provide -Video path when using -SkipRecord" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Video)) {
    Write-Host "Video not found: $Video" -ForegroundColor Red
    exit 1
}

$wslVideo = ConvertTo-WslPath $Video
$wslRoot = "/mnt/d/python/video2robot"

if ($Name -eq "") {
    $Name = "run_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}
$ProjectDir = Join-Path $DataDir $Name

Write-Host ""
Write-Host "=== Pipeline: video -> pose -> G1 (project: $Name) ===" -ForegroundColor Cyan
Write-Host "Pose step takes ~10-20 min on GPU — looks idle, that's normal." -ForegroundColor Yellow
wsl bash -lc "source `$HOME/miniconda3/etc/profile.d/conda.sh && cd $wslRoot && conda run --no-capture-output -n gmr python scripts/run_pipeline.py --video '$wslVideo' --static-camera --robot unitree_g1 --name $Name --force"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipViz) {
    Write-Host ""
    Write-Host "=== Browser viewer ===" -ForegroundColor Cyan
    wsl bash -lc "source `$HOME/miniconda3/etc/profile.d/conda.sh && cd $wslRoot && conda run --no-capture-output -n phmr python scripts/visualize.py --project $wslRoot/data/$Name --robot-viser --robot-type unitree_g1"
}

Write-Host ""
Write-Host "Done. Project: $ProjectDir" -ForegroundColor Green
