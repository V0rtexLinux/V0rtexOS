# V0rtexOS — Script PowerShell para QEMU no Windows
# Execute com: powershell -ExecutionPolicy Bypass -File run-qemu-windows.ps1

$QemuPath  = "C:\Program Files\qemu\qemu-system-x86_64.exe"
$IsoPath   = Join-Path $PSScriptRoot "v0rtex-os-2026.05.13-x86_64.iso"

Write-Host ""
Write-Host " V0rtexOS — Grey Hat Linux Hardened" -ForegroundColor Cyan
Write-Host " QEMU Boot Script para Windows" -ForegroundColor Cyan
Write-Host ""

# Verifica QEMU
if (-not (Test-Path $QemuPath)) {
    Write-Host "[ERRO] QEMU nao encontrado em: $QemuPath" -ForegroundColor Red
    Write-Host "       Baixe em: https://www.qemu.org/download/#windows" -ForegroundColor Yellow
    Write-Host "       Ou edite a variavel `$QemuPath neste script." -ForegroundColor Yellow
    Read-Host "Pressione Enter para sair"
    exit 1
}

# Verifica ISO
if (-not (Test-Path $IsoPath)) {
    Write-Host "[ERRO] ISO nao encontrada: $IsoPath" -ForegroundColor Red
    Write-Host "       Coloque a ISO na mesma pasta deste script." -ForegroundColor Yellow
    Read-Host "Pressione Enter para sair"
    exit 1
}

Write-Host " ISO  : $IsoPath" -ForegroundColor Green
Write-Host " QEMU : $QemuPath" -ForegroundColor Green
Write-Host " RAM  : 4096 MB  |  CPUs: 4" -ForegroundColor Green
Write-Host ""

# Argumentos base
$BaseArgs = @(
    "-name",    "V0rtexOS",
    "-smp",     "4,cores=4",
    "-m",       "4096",
    "-drive",   "file=$IsoPath,media=cdrom,readonly=on",
    "-boot",    "order=d",
    "-vga",     "virtio",
    "-display", "gtk,zoom-to-fit=on",
    "-audiodev","none,id=noaudio",
    "-net",     "nic,model=virtio",
    "-net",     "user",
    "-usb",
    "-device",  "usb-tablet",
    "-no-reboot"
)

# Tenta WHPX (Windows Hypervisor Platform — rapido)
Write-Host "[1/2] Tentando boot com WHPX (aceleracao nativa)..." -ForegroundColor Yellow
$WhpxArgs = @("-machine", "type=q35,accel=whpx,kernel-irqchip=off", "-cpu", "host") + $BaseArgs

try {
    $proc = Start-Process -FilePath $QemuPath -ArgumentList $WhpxArgs `
            -NoNewWindow -Wait -PassThru -ErrorAction Stop
    if ($proc.ExitCode -eq 0) {
        Write-Host "`nVM encerrada normalmente." -ForegroundColor Green
        exit 0
    }
} catch {}

# Fallback: TCG (sem requisitos, mais lento)
Write-Host ""
Write-Host "[AVISO] WHPX indisponivel. Usando TCG (sem aceleracao)." -ForegroundColor Yellow
Write-Host "        Para ativar WHPX:" -ForegroundColor Yellow
Write-Host "        Painel de Controle > Programas > Recursos do Windows" -ForegroundColor Yellow
Write-Host "        Marcar 'Windows Hypervisor Platform' e reiniciar" -ForegroundColor Yellow
Write-Host ""
Write-Host "[2/2] Iniciando em modo TCG..." -ForegroundColor Yellow

$TcgArgs = @("-machine", "type=q35,accel=tcg", "-cpu", "qemu64") + $BaseArgs
Start-Process -FilePath $QemuPath -ArgumentList $TcgArgs -NoNewWindow -Wait

Write-Host "`nVM encerrada." -ForegroundColor Green
Read-Host "Pressione Enter para sair"
