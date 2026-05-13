@echo off
chcp 65001 >nul 2>&1
title V0rtexOS QEMU Boot
setlocal enabledelayedexpansion

:: Muda para a pasta do script (resolve problema de espacos no path)
pushd "%~dp0"

:: ── CONFIGURACAO ──────────────────────────────────────────
set "QEMU=C:\Program Files\qemu\qemu-system-x86_64.exe"
set "ISO=v0rtex-os-2026.05.13-x86_64.iso"
:: ──────────────────────────────────────────────────────────

echo.
echo  V0rtexOS - Grey Hat Linux Hardened
echo  ====================================
echo.

if not exist "%QEMU%" (
    echo [ERRO] QEMU nao encontrado em: %QEMU%
    echo.
    echo Baixe e instale em: https://www.qemu.org/download/#windows
    echo Marque "Add to PATH" durante a instalacao.
    echo Ou edite a variavel QEMU neste arquivo .bat
    echo.
    popd
    pause
    exit /b 1
)

if not exist "%ISO%" (
    echo [ERRO] ISO nao encontrada: %ISO%
    echo.
    echo Coloque o arquivo na mesma pasta deste script:
    echo %~dp0%ISO%
    echo.
    popd
    pause
    exit /b 1
)

echo  QEMU : %QEMU%
echo  ISO  : %~dp0%ISO%
echo  RAM  : 4096 MB  ^|  CPUs: 4
echo.

:: ── ARGS COMUNS (sem acelerador) ─────────────────────────
set ARGS=-name V0rtexOS
set ARGS=%ARGS% -smp 4,cores=4
set ARGS=%ARGS% -m 4096
set ARGS=%ARGS% -drive "file=%ISO%,media=cdrom,readonly=on"
set ARGS=%ARGS% -boot order=d
set ARGS=%ARGS% -vga virtio
set ARGS=%ARGS% -display gtk,zoom-to-fit=on
set ARGS=%ARGS% -audiodev none,id=noaudio
set ARGS=%ARGS% -net nic,model=virtio
set ARGS=%ARGS% -net user
set ARGS=%ARGS% -usb
set ARGS=%ARGS% -device usb-tablet
set ARGS=%ARGS% -no-reboot

:: ── TENTATIVA 1: WHPX (Windows Hypervisor Platform, rapido) ──
echo [1/2] Tentando boot com WHPX (aceleracao nativa)...
echo.
"%QEMU%" -machine type=q35,accel=whpx,kernel-irqchip=off -cpu host %ARGS%
set RC=%ERRORLEVEL%

if %RC% equ 0 goto fim

:: ── TENTATIVA 2: TCG (sem aceleracao, mais lento) ─────────
echo.
echo [AVISO] WHPX indisponivel (codigo %RC%). Usando TCG sem aceleracao.
echo.
echo Para ativar WHPX (boot rapido):
echo   Painel de Controle ^> Programas ^> Recursos do Windows
echo   Marcar "Windows Hypervisor Platform" e reiniciar
echo.
echo [2/2] Iniciando em modo TCG...
echo.
timeout /t 3 /nobreak >nul

"%QEMU%" -machine type=q35,accel=tcg -cpu qemu64 %ARGS%

:fim
echo.
echo VM encerrada.
popd
pause
