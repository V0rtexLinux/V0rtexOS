@echo off
title V0rtexOS — QEMU Boot
setlocal

:: ─────────────────────────────────────────────────────
::  CONFIGURACAO — ajuste o caminho do QEMU se necessario
:: ─────────────────────────────────────────────────────
set QEMU="C:\Program Files\qemu\qemu-system-x86_64.exe"
set ISO=%~dp0v0rtex-os-2026.05.13-x86_64.iso

:: ─────────────────────────────────────────────────────
::  VERIFICA SE O QEMU EXISTE
:: ─────────────────────────────────────────────────────
if not exist %QEMU% (
    echo.
    echo [ERRO] QEMU nao encontrado em: %QEMU%
    echo.
    echo Baixe e instale em: https://www.qemu.org/download/#windows
    echo Ou ajuste a variavel QEMU neste arquivo .bat
    echo.
    pause
    exit /b 1
)

:: ─────────────────────────────────────────────────────
::  VERIFICA SE A ISO EXISTE
:: ─────────────────────────────────────────────────────
if not exist %ISO% (
    echo.
    echo [ERRO] ISO nao encontrada: %ISO%
    echo.
    echo Coloque o arquivo v0rtex-os-2026.05.13-x86_64.iso
    echo na mesma pasta deste script .bat
    echo.
    pause
    exit /b 1
)

echo.
echo  ██╗   ██╗ ██████╗ ██████╗ ████████╗███████╗██╗  ██╗
echo  ██║   ██║██╔═████╗██╔══██╗╚══██╔══╝██╔════╝╚██╗██╔╝
echo  ██║   ██║██║██╔██║██████╔╝   ██║   █████╗   ╚███╔╝ 
echo  ╚██╗ ██╔╝████╔╝██║██╔══██╗   ██║   ██╔══╝   ██╔██╗ 
echo   ╚████╔╝ ╚██████╔╝██║  ██║   ██║   ███████╗██╔╝ ██╗
echo    ╚═══╝   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
echo.
echo  V0rtexOS — Grey Hat Linux Hardened
echo  Iniciando VM com QEMU + KVM (WHPX)...
echo  RAM: 4096 MB  ^|  CPUs: 4  ^|  ISO: %ISO%
echo.

:: ─────────────────────────────────────────────────────
::  BOOT COM WHPX (Windows Hypervisor Platform = KVM no Windows)
::  Requer: Habilitar "Windows Hypervisor Platform" em:
::  Painel de Controle > Programas > Recursos do Windows
:: ─────────────────────────────────────────────────────
%QEMU% ^
  -name "V0rtexOS" ^
  -machine type=q35,accel=whpx,kernel-irqchip=off ^
  -cpu host ^
  -smp 4,cores=4 ^
  -m 4096 ^
  -drive file=%ISO%,media=cdrom,readonly=on ^
  -boot order=d ^
  -vga virtio ^
  -display gtk,zoom-to-fit=on ^
  -audiodev none,id=noaudio ^
  -net nic,model=virtio ^
  -net user ^
  -usb ^
  -device usb-tablet ^
  -no-reboot ^
  2>nul

:: Se WHPX falhar, tenta TCG (mais lento, sem requisitos)
if %ERRORLEVEL% neq 0 (
    echo.
    echo [AVISO] WHPX indisponivel. Rodando em modo TCG (lento).
    echo         Para ativar aceleracao: Painel de Controle ^>
    echo         Programas ^> Recursos do Windows ^>
    echo         Marcar "Windows Hypervisor Platform"
    echo.
    timeout /t 3 /nobreak >nul

    %QEMU% ^
      -name "V0rtexOS" ^
      -machine type=q35,accel=tcg ^
      -cpu qemu64 ^
      -smp 4 ^
      -m 4096 ^
      -drive file=%ISO%,media=cdrom,readonly=on ^
      -boot order=d ^
      -vga virtio ^
      -display gtk,zoom-to-fit=on ^
      -audiodev none,id=noaudio ^
      -net nic,model=virtio ^
      -net user ^
      -usb ^
      -device usb-tablet ^
      -no-reboot
)

echo.
echo VM encerrada.
pause
