# AETERNUS OS — .zshrc
# Caminho: ~/.zshrc

# ─────────────────────────────────────────────────
# PERFORMANCE — Compilar zsh
# ─────────────────────────────────────────────────
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# ─────────────────────────────────────────────────
# HISTÓRICO — Desativado por padrão (amnésia)
# ─────────────────────────────────────────────────
HISTFILE=""          # Sem arquivo de histórico persistente
HISTSIZE=1000        # Apenas em memória
SAVEHIST=0
setopt NO_HIST_BEEP
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE    # Comandos com espaço inicial não são gravados

# ─────────────────────────────────────────────────
# OPÇÕES
# ─────────────────────────────────────────────────
setopt AUTO_CD
setopt CORRECT
setopt NOCLOBBER            # Previne sobrescrever arquivos com >
setopt EXTENDED_GLOB
setopt NO_BEEP
setopt INTERACTIVE_COMMENTS

# ─────────────────────────────────────────────────
# PROMPT — Starship (fallback manual)
# ─────────────────────────────────────────────────
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
else
    # Prompt manual: usuário@host em verde, diretório em ciano
    PROMPT='%F{green}%n@aeternus%f %F{cyan}%~%f %F{red}❯%f %F{yellow}❯%f %F{green}❯%f '
fi

# ─────────────────────────────────────────────────
# PLUGINS
# ─────────────────────────────────────────────────
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ─────────────────────────────────────────────────
# FZF
# ─────────────────────────────────────────────────
[[ -f /usr/share/fzf/key-bindings.zsh  ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh    ]] && source /usr/share/fzf/completion.zsh

export FZF_DEFAULT_OPTS="
    --color=bg:#0d0d0d,bg+:#1a1a1a,fg:#00ff41,fg+:#00ff41
    --color=hl:#ffaa00,hl+:#ffcc00,prompt:#00ff41,pointer:#ff0040
    --color=marker:#00ff41,spinner:#00ff41,header:#cc00ff
    --border rounded --height 40% --layout reverse --info inline"

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# ─────────────────────────────────────────────────
# VARIÁVEIS DE AMBIENTE
# ─────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R --use-color"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# PATH — Adicionar binários de justiça
export PATH="$PATH:/usr/local/bin"

# Proxychains/Tor
export AETERNUS_OUTPUT="/tmp/aeternus-scans"
export TORSOCKS_CONF="/etc/tor/torsocks.conf"

# Desativar telemetria de ferramentas
export DO_NOT_TRACK=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export NEXT_TELEMETRY_DISABLED=1
export GATSBY_TELEMETRY_DISABLED=1

# ─────────────────────────────────────────────────
# ALIASES — Sistema
# ─────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias lt='ls -lath --color=auto'  # ordenar por tempo
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -c'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias cat='bat --style=plain'
alias find='fd'
alias top='btop'
alias vi='nvim'
alias vim='nvim'
alias cls='clear'

# ─────────────────────────────────────────────────
# ALIASES — Segurança / AETERNUS
# ─────────────────────────────────────────────────

# Ghost Protocol
alias gp-start='sudo systemctl start ghost-protocol.service'
alias gp-stop='sudo systemctl stop ghost-protocol.service'
alias gp-status='sudo /usr/local/bin/ghost-protocol.sh status'
alias gp-restart='sudo systemctl restart ghost-protocol.service'

# Tor
alias tor-check='curl -s https://check.torproject.org/api/ip'
alias my-ip='curl -s https://api.ipify.org && echo'
alias tor-ip='torsocks curl -s https://api.ipify.org && echo'

# Proxychains
alias pchain='proxychains4 -q'

# aet-scan atalhos
alias scan='sudo aet-scan'
alias scan-vuln='sudo aet-scan -p vuln -s critical,smb,http,ssl'
alias scan-fast='sudo aet-scan -p fast'
alias scan-stealth='sudo aet-scan -p stealth'
alias scan-full='sudo aet-scan -p full'

# aet-nuke
alias nuke='sudo aet-nuke monitor'
alias nuke-bans='sudo aet-nuke list-bans'

# Amnésia
alias amnesia='sudo /usr/local/bin/amnesia --confirm'
alias poweroff-safe='sudo /usr/local/bin/amnesia --confirm && sudo poweroff'
alias reboot-safe='sudo /usr/local/bin/amnesia --confirm && sudo reboot'

# Iptables
alias fw-list='sudo iptables -L -n -v --line-numbers'
alias fw-nat='sudo iptables -t nat -L -n -v'

# Network
alias ports='ss -tulnp'
alias conns='ss -tnp'
alias ifaces='ip -br addr'
alias routes='ip route show'

# ─────────────────────────────────────────────────
# FUNÇÕES
# ─────────────────────────────────────────────────

# Procurar em todo o sistema com ripgrep
rg-all() { rg --no-ignore --hidden "$@"; }

# Extrair qualquer arquivo comprimido
extract() {
    [[ -f "$1" ]] || { echo "Arquivo não encontrado: $1"; return 1; }
    case "$1" in
        *.tar.bz2)   tar xjf "$1"   ;;
        *.tar.gz)    tar xzf "$1"   ;;
        *.tar.xz)    tar xJf "$1"   ;;
        *.tar.zst)   tar --zstd -xf "$1" ;;
        *.bz2)       bunzip2 "$1"   ;;
        *.rar)       unrar x "$1"   ;;
        *.gz)        gunzip "$1"    ;;
        *.tar)       tar xf "$1"    ;;
        *.tbz2)      tar xjf "$1"   ;;
        *.tgz)       tar xzf "$1"   ;;
        *.zip)       unzip "$1"     ;;
        *.Z)         uncompress "$1";;
        *.7z)        7z x "$1"      ;;
        *)           echo "Formato desconhecido: $1" ;;
    esac
}

# Verificar se o Tor está ativo e o IP está mascarado
check-anon() {
    echo "IP real (via eth0):"
    curl -s --max-time 5 --interface eth0 https://api.ipify.org 2>/dev/null || echo "N/A"
    echo
    echo "IP via Tor/VPN:"
    torsocks curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "N/A"
    echo
    echo "Status do Ghost Protocol:"
    systemctl is-active ghost-protocol.service
}

# Criar sessão tmux de recon com múltiplas janelas
recon-session() {
    local TARGET="${1:-}"
    [[ -z "$TARGET" ]] && { echo "Uso: recon-session <alvo>"; return 1; }
    tmux new-session -d -s "recon-${TARGET}" -x 220 -y 50
    tmux rename-window -t "recon-${TARGET}:0" "SCAN"
    tmux send-keys -t "recon-${TARGET}:0" "sudo aet-scan -p fast $TARGET" Enter
    tmux new-window -t "recon-${TARGET}" -n "VULN"
    tmux send-keys -t "recon-${TARGET}:1" "sudo aet-scan -p vuln -s critical,smb,http $TARGET" Enter
    tmux new-window -t "recon-${TARGET}" -n "SHELL"
    tmux new-window -t "recon-${TARGET}" -n "NOTES"
    tmux send-keys -t "recon-${TARGET}:3" "nvim notes-${TARGET}.md" Enter
    tmux attach-session -t "recon-${TARGET}"
}

# ─────────────────────────────────────────────────
# BANNER DE BOAS-VINDAS
# ─────────────────────────────────────────────────
if [[ $- == *i* ]]; then
    echo -e "\033[1;32m"
    cat <<'BANNER'
    ___   _____________________  _   ____  _______
   /   | / ____/_  __/ ____/ \ | | / / / / / ___/
  / /| |/ __/   / / / __/ /  \| |/ / / / /\__ \ 
 / ___ / /___  / / / /___/ /|  / /_/ / /___/ __/ 
/_/  |_/_____/ /_/ /_____/_/ |_/\____/\____/____/ 
BANNER
    echo -e "\033[2;32m  Ghost Protocol: $(systemctl is-active ghost-protocol.service 2>/dev/null || echo 'inactive')\033[0m"
    echo -e "\033[2;32m  $(date '+%Y-%m-%d %H:%M:%S') | $(uname -r)\033[0m"
    echo -e "\033[0m"
fi
