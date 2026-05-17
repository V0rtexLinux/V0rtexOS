# V0rtexOS — Build da ISO no Windows
# Requer: ~20 GB livres em C: + Docker ou Podman funcionando
# Alternativa: dispara build no GitHub Actions (sem espaço local)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$IsoOutput   = Join-Path $ProjectRoot "iso-output"
New-Item -ItemType Directory -Force -Path $IsoOutput | Out-Null

function Show-DiskSpace {
    $free = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
    Write-Host "Espaco livre em C: ${free} GB (recomendado: 20+ GB)" -ForegroundColor $(if ($free -lt 15) { "Yellow" } else { "Green" })
    return $free
}

Write-Host ""
Write-Host " V0rtexOS ISO Builder (Windows)" -ForegroundColor Cyan
Write-Host ""

$freeGb = Show-DiskSpace

if ($freeGb -lt 15) {
    Write-Host "[AVISO] Espaco insuficiente para build local." -ForegroundColor Yellow
    Write-Host "        Use GitHub Actions: push o repo e baixe o artifact." -ForegroundColor Yellow
    Write-Host "        Ou libere ~20 GB (desinstale apps, esvazie Lixeira, Disk Cleanup)." -ForegroundColor Yellow
    Write-Host ""
}

# Podman
if (Get-Command podman -ErrorAction SilentlyContinue) {
    if (-not (podman machine list --format "{{.Name}}" 2>$null | Select-String "podman-machine")) {
        Write-Host "[BUILD] Inicializando Podman machine (disco 40 GB)..." -ForegroundColor Yellow
        podman machine init --cpus 2 --memory 3072 --disk-size 40
    }
    if (-not (podman machine list --format "{{.Running}}" 2>$null | Select-String "true")) {
        podman machine start
    }

    if ($freeGb -ge 15) {
        Write-Host "[BUILD] Compilando via Podman + Arch Linux..." -ForegroundColor Cyan
        $proj = ($ProjectRoot -replace '\\', '/') -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }
        podman run --privileged --rm `
            -v "${ProjectRoot}:/project:ro" `
            -v "${IsoOutput}:/output" `
            docker.io/archlinux:latest `
            bash /project/../COMPILE-ISO.sh 2>&1
        # Fallback: entrypoint inline (COMPILE-ISO path inside container)
        exit $LASTEXITCODE
    }
}

# Docker
if (Get-Command docker -ErrorAction SilentlyContinue) {
    if (docker info 2>$null) {
        if ($freeGb -ge 15) {
            Write-Host "[BUILD] Compilando via Docker..." -ForegroundColor Cyan
            bash -lc "cd '$ProjectRoot' && bash COMPILE-ISO.sh"
            exit $LASTEXITCODE
        }
    }
}

# GitHub Actions
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "[BUILD] Disparando workflow no GitHub Actions..." -ForegroundColor Cyan
    Push-Location (Split-Path $ProjectRoot -Parent)
    gh workflow run build-iso.yml
    gh run watch
    Pop-Location
    exit 0
}

Write-Host "[ERRO] Nenhum metodo de build disponivel." -ForegroundColor Red
Write-Host "  1. Libere 20+ GB e instale Podman: scoop install podman" -ForegroundColor White
Write-Host "  2. Ou instale GitHub CLI: scoop install gh && gh auth login" -ForegroundColor White
Write-Host "  3. Push para GitHub — workflow em .github/workflows/build-iso.yml" -ForegroundColor White
exit 1
