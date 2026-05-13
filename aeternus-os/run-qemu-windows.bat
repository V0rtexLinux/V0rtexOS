@echo off
title V0rtexOS QEMU Boot
setlocal enabledelayedexpansion

pushd "%~dp0"

set "QEMU=C:\Program Files\qemu\qemu-system-x86_64.exe"
set "ISO=v0rtex-os-2026.05.13-x86_64.iso"

echo.
echo  V0rtexOS - Grey Hat Linux Hardened
echo  ====================================
echo.

if not exist "%QEMU%" (
    echo [ERRO] QEMU nao encontrado em: %QEMU%
    echo.
    echo Baixe em: https://www.qemu.org/download/#windows
    echo Marque "Add to PATH" durante a instalacao.
    echo Ou edite a variavel QEMU neste arquivo .bat
    echo.
    popd & pause & exit /b 1
)

if not exist "%ISO%" (
    echo [ERRO] ISO nao encontrada: %ISO%
    echo Coloque o arquivo na mesma pasta deste script.
    echo.
    popd & pause & exit /b 1
)

echo  ISO  : %~dp0%ISO%
echo  RAM  : 4096 MB
echo  CPUs : 4
echo.

set "ARGS=-smp 4,cores=4 -m 4096"
set "ARGS=%ARGS% -drive file=%ISO%,media=cdrom,readonly=on"
set "ARGS=%ARGS% -boot order=d"
set "ARGS=%ARGS% -vga virtio"
set "ARGS=%ARGS% -display gtk,zoom-to-fit=on"
set "ARGS=%ARGS% -audiodev none,id=noaudio"
set "ARGS=%ARGS% -net nic,model=virtio -net user"
set "ARGS=%ARGS% -usb -device usb-tablet"
set "ARGS=%ARGS% -no-reboot"

:: CPU sem MPX e APX (evita o conflito em CPUs Intel recentes com APX)
set "CPUFIX=host,-mpx,-apxf"

echo [1/3] WHPX com kernel-irqchip=on (fix VP exit code 4)...
echo.
"%QEMU%" -machine type=q35,accel=whpx,kernel-irqchip=on -cpu %CPUFIX% %ARGS% 2>nul
if %ERRORLEVEL% equ 0 goto :fim

echo.
echo [2/3] WHPX com kernel-irqchip=off...
echo.
"%QEMU%" -machine type=q35,accel=whpx,kernel-irqchip=off -cpu %CPUFIX% %ARGS% 2>nul
if %ERRORLEVEL% equ 0 goto :fim

echo.
echo [AVISO] WHPX indisponivel nesta maquina.
echo Para habilitar: Painel de Controle - Programas - Recursos do Windows
echo Marcar "Windows Hypervisor Platform" e reiniciar o PC.
echo.
echo [3/3] Iniciando em modo TCG (sem aceleracao, mais lento)...
echo.
timeout /t 3 /nobreak >nul

"%QEMU%" -machine type=q35,accel=tcg -cpu qemu64 %ARGS%

:fim
echo.
echo VM encerrada.
popd
pause
