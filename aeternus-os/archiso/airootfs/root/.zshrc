#!/usr/bin/env zsh
# V0rtexOS — Root .zshrc

HISTFILE=""
HISTSIZE=500
SAVEHIST=0
setopt NO_HIST_BEEP HIST_IGNORE_SPACE HIST_IGNORE_ALL_DUPS

autoload -Uz compinit && compinit -C
setopt AUTO_CD CORRECT EXTENDED_GLOB NO_BEEP INTERACTIVE_COMMENTS

# Starship
command -v starship &>/dev/null && eval "$(starship init zsh)"

# Plugins
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh

export FZF_DEFAULT_OPTS="--color=bg:#000000,bg+:#1a1a1a,fg:#aaaaaa,fg+:#ffffff --color=hl:#ffffff,hl+:#ffffff,prompt:#aaaaaa,pointer:#ffffff --border rounded --height 40% --layout reverse"
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export EDITOR=nvim VISUAL=nvim PAGER=less

# PATH
export PATH="$PATH:/usr/local/bin:/opt/vortex/bin:$HOME/.local/bin:$HOME/go/bin:/usr/share/exploitdb"
export GOPATH="$HOME/go" GOBIN="$HOME/go/bin"
export TOOLS=/opt/vortex EXPLOITS=/opt/exploits CVE=/opt/cve WORDLISTS=/opt/wordlists

# ── Aliases sistema ────────────────────────────
alias ls='eza --icons --color=always'
alias ll='eza -lah --icons --color=always --git'
alias lt='eza -lah --icons --color=always --sort=modified'
alias tree='eza --tree --icons'
alias cat='bat --style=plain'
alias grep='grep --color=auto'
alias find='fd'
alias top='btop'
alias vi='nvim' vim='nvim'
alias ip='ip -c'
alias ports='ss -tulnp'
alias conns='ss -tnp'
alias ifaces='ip -br addr'

# ── Ghost Protocol ─────────────────────────────
alias gp='sudo systemctl status ghost-protocol'
alias gp-start='sudo systemctl start ghost-protocol && echo "[+] Ghost Protocol ATIVO"'
alias gp-stop='sudo systemctl stop ghost-protocol && echo "[!] Ghost Protocol PARADO"'
alias gp-fw='sudo iptables -L -n -v --line-numbers'
alias check-anon='echo "IP via Tor:"; torsocks curl -s https://api.ipify.org; echo; echo "Check Tor:"; torsocks curl -s https://check.torproject.org/api/ip | python3 -m json.tool'

# ── Ferramentas ────────────────────────────────
alias scan='sudo aet-scan'
alias vuln-scan='sudo aet-scan -p vuln -s critical,smb,http,ssl,database'
alias stealth-scan='sudo aet-scan -p stealth'
alias full-scan='sudo aet-scan -p full'
alias nuke='sudo aet-nuke monitor'
alias linpeas='sudo /opt/vortex/PEASS/linpeas.sh'
alias les='sudo perl /usr/local/bin/les2.pl'

# ── Impacket shortcuts ─────────────────────────
alias psexec='python3 /opt/vortex/impacket/examples/psexec.py'
alias smbclient-imp='python3 /opt/vortex/impacket/examples/smbclient.py'
alias secretsdump='python3 /opt/vortex/impacket/examples/secretsdump.py'
alias getuserspns='python3 /opt/vortex/impacket/examples/GetUserSPNs.py'
alias getnpusers='python3 /opt/vortex/impacket/examples/GetNPUsers.py'
alias ticketer='python3 /opt/vortex/impacket/examples/ticketer.py'
alias lookupsid='python3 /opt/vortex/impacket/examples/lookupsid.py'
alias ntlmrelayx='python3 /opt/vortex/impacket/examples/ntlmrelayx.py'
alias wmiexec='python3 /opt/vortex/impacket/examples/wmiexec.py'
alias dcomexec='python3 /opt/vortex/impacket/examples/dcomexec.py'

# ── Wordlists rápidos ──────────────────────────
alias wl-web='ls /opt/wordlists/SecLists/Discovery/Web-Content/'
alias wl-pass='ls /opt/wordlists/SecLists/Passwords/'
alias wl-user='ls /opt/wordlists/SecLists/Usernames/'
alias wl-sub='ls /opt/wordlists/SecLists/Discovery/DNS/'

# ── Payload generators ─────────────────────────
alias gen-rev='msfvenom -p linux/x64/shell_reverse_tcp'
alias gen-win='msfvenom -p windows/x64/shell_reverse_tcp'
alias gen-php='msfvenom -p php/meterpreter_reverse_tcp'
alias gen-jsp='msfvenom -p java/jsp_shell_reverse_tcp'

# ── Amnésia ────────────────────────────────────
alias amnesia='sudo /usr/local/bin/amnesia --confirm'
alias safe-off='sudo /usr/local/bin/amnesia --confirm && sudo poweroff'
alias safe-reboot='sudo /usr/local/bin/amnesia --confirm && sudo reboot'

# ── Funções ────────────────────────────────────
mkworkdir() {
    local name="${1:-pentest-$(date +%Y%m%d)}"
    mkdir -p ~/"$name"/{recon,exploit,post,loot,notes,screenshots}
    echo "# $name — $(date)" > ~/"$name/notes/notes.md"
    cd ~/"$name"
    echo "[+] Workdir: ~/$name"
}

# Shell handler rápido
listener() {
    local port="${1:-4444}"
    echo "[*] Ouvindo em 0.0.0.0:$port (pwncat)"
    pwncat-cs -lp "$port"
}

# Sessão tmux de recon multi-janela
recon() {
    local t="${1:?Informe o alvo}"
    tmux new-session -d -s "recon-$t" -x 240 -y 55 2>/dev/null || true
    tmux rename-window -t "recon-$t:0" "SCAN"
    tmux send-keys -t "recon-$t:0" "sudo aet-scan -p fast $t" Enter
    tmux new-window -t "recon-$t" -n "VULN"
    tmux send-keys -t "recon-$t:VULN" "sudo aet-scan -p vuln -s critical,smb,http $t" Enter
    tmux new-window -t "recon-$t" -n "WEB"
    tmux send-keys -t "recon-$t:WEB" "whatweb http://$t; echo; nikto -h $t" Enter
    tmux new-window -t "recon-$t" -n "SHELL"
    tmux new-window -t "recon-$t" -n "NOTES"
    tmux send-keys -t "recon-$t:NOTES" "nvim ~/pentest-$(date +%Y%m%d)/notes/notes.md" Enter
    tmux attach-session -t "recon-$t"
}

# Extrair
extract() {
    [[ -f "$1" ]] || { echo "Arquivo não existe: $1"; return 1; }
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz)          tar xJf "$1" ;;
        *.tar.zst)         tar --zstd -xf "$1" ;;
        *.bz2)             bunzip2 "$1" ;;
        *.gz)              gunzip "$1"  ;;
        *.tar)             tar xf "$1"  ;;
        *.zip)             unzip "$1"   ;;
        *.7z)              7z x "$1"    ;;
        *.rar)             unrar x "$1" ;;
        *)  echo "Formato desconhecido: $1" ;;
    esac
}

# Banner
if [[ $- == *i* ]]; then
    printf "\033[1;37m"
    cat /etc/v0rtex-banner 2>/dev/null || cat <<'B'
 __   ___  ____  ____  _______  __    ___  ___ 
 \ \ / / \| _ \|_  _||   __\ \/ /   / _ \/ __|
  \ V /| o| v /  | |   | |_  >  <  | |_| \__ \
   \_/ |___|_|_\ |_|  |____/_/\_\  \___/ |___/
B
    printf "\033[2;37m  kernel: %s | tor: %s | ghost: %s\033[0m\n" \
        "$(uname -r)" \
        "$(systemctl is-active tor 2>/dev/null)" \
        "$(systemctl is-active ghost-protocol 2>/dev/null)"
    echo
fi
