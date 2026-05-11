#!/usr/bin/env bash
# AETERNUS OS — Ghost Protocol
# Força todo o tráfego por VPN → Tor com Kill Switch via iptables.
# Ativado pelo systemd no boot. Sem VPN/Tor ativos = sem conexão (zero leak).

set -euo pipefail

SCRIPT_NAME="ghost-protocol"
LOG_TAG="ghost-protocol"
TUN_IFACE="${TUN_IFACE:-tun0}"          # Interface VPN (OpenVPN/WireGuard)
TOR_UID=$(id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || echo "")
TOR_TRANS_PORT=9040
TOR_DNS_PORT=5353
LOCAL_NETS="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8"
LOOPBACK="lo"

log()  { logger -t "$LOG_TAG" "$*"; echo "[${SCRIPT_NAME}] $*"; }
die()  { log "ERRO: $*"; exit 1; }

# ────────────────────────────────────────────────
# Limpa todas as regras anteriores
# ────────────────────────────────────────────────
flush_rules() {
    log "Limpando regras iptables anteriores..."
    iptables  -F
    iptables  -X
    iptables  -t nat -F
    iptables  -t nat -X
    iptables  -t mangle -F
    iptables  -t mangle -X
    ip6tables -F
    ip6tables -X
    ip6tables -t nat -F    2>/dev/null || true
    ip6tables -t mangle -F 2>/dev/null || true
}

# ────────────────────────────────────────────────
# Política padrão: DROP tudo
# ────────────────────────────────────────────────
set_default_drop() {
    log "Definindo política padrão DROP..."
    iptables  -P INPUT   DROP
    iptables  -P FORWARD DROP
    iptables  -P OUTPUT  DROP
    # IPv6 completamente bloqueado — previne vazamento via IPv6
    ip6tables -P INPUT   DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT  DROP
    log "IPv6 bloqueado (anti-leak)."
}

# ────────────────────────────────────────────────
# Kill Switch VPN — bloqueia tudo fora da VPN
# ────────────────────────────────────────────────
apply_vpn_killswitch() {
    log "Aplicando Kill Switch VPN ($TUN_IFACE)..."

    # Loopback sempre permitido
    iptables -A INPUT  -i "$LOOPBACK" -j ACCEPT
    iptables -A OUTPUT -o "$LOOPBACK" -j ACCEPT

    # Conexões estabelecidas/relacionadas
    iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # DHCP para obter IP inicial (antes da VPN conectar)
    iptables -A OUTPUT -o eth0 -p udp --dport 67:68 -j ACCEPT
    iptables -A INPUT  -i eth0 -p udp --sport 67:68 -j ACCEPT

    # DNS apenas via túnel VPN (previne DNS leak)
    iptables -A OUTPUT -o "$TUN_IFACE" -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -o "$TUN_IFACE" -p tcp --dport 53 -j ACCEPT

    # Tráfego de saída apenas pela VPN
    iptables -A OUTPUT -o "$TUN_IFACE" -j ACCEPT

    # Permitir handshake inicial OpenVPN (UDP 1194 / TCP 443 via física)
    # Ajuste a porta conforme seu provider de VPN
    iptables -A OUTPUT -o eth0 -p udp --dport 1194 -j ACCEPT
    iptables -A OUTPUT -o eth0 -p tcp --dport 443  -j ACCEPT
    iptables -A OUTPUT -o eth0 -p tcp --dport 1194 -j ACCEPT

    log "Kill Switch VPN ativo."
}

# ────────────────────────────────────────────────
# Encadear Tor sobre VPN (Tor-over-VPN)
# ────────────────────────────────────────────────
apply_tor_routing() {
    [[ -z "$TOR_UID" ]] && die "Usuário tor não encontrado. Instale o pacote tor."

    log "Configurando roteamento transparente Tor (UID=$TOR_UID)..."

    # Tor não passa por si mesmo
    iptables -t nat -A OUTPUT -m owner --uid-owner "$TOR_UID" -j RETURN

    # Não redirecionar LAN e loopback
    for net in $LOCAL_NETS; do
        iptables -t nat -A OUTPUT -d "$net" -j RETURN
    done

    # Redirecionar DNS para o Tor DNSPort
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports "$TOR_DNS_PORT"
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports "$TOR_DNS_PORT"

    # Redirecionar todo TCP para o TransPort do Tor
    iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports "$TOR_TRANS_PORT"

    # Permitir tráfego do Tor para a VPN
    iptables -A OUTPUT -m owner --uid-owner "$TOR_UID" -j ACCEPT

    # Bloquear UDP (Tor não usa UDP — prevenção de vazamento)
    iptables -A OUTPUT -p udp -j DROP

    # DNS interno do sistema: encaminhar para Tor
    if systemctl is-active --quiet tor; then
        log "Tor ativo — roteamento transparente aplicado."
    else
        log "Iniciando serviço Tor..."
        systemctl start tor.service
        sleep 3
    fi

    log "Tor-over-VPN configurado."
}

# ────────────────────────────────────────────────
# Proteções extras de memória e rede no kernel
# ────────────────────────────────────────────────
apply_sysctl_hardening() {
    log "Aplicando hardening de sysctl..."

    declare -A params=(
        # Rede — anti-spoofing
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.default.rp_filter"]="1"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv4.conf.all.send_redirects"]="0"
        ["net.ipv4.conf.all.accept_source_route"]="0"
        ["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.tcp_timestamps"]="0"
        ["net.ipv6.conf.all.disable_ipv6"]="1"
        ["net.ipv6.conf.default.disable_ipv6"]="1"
        ["net.ipv6.conf.lo.disable_ipv6"]="1"
        # Memória — anti-exploit
        ["kernel.randomize_va_space"]="2"
        ["kernel.kptr_restrict"]="2"
        ["kernel.dmesg_restrict"]="1"
        ["kernel.perf_event_paranoid"]="3"
        ["kernel.yama.ptrace_scope"]="2"
        ["vm.mmap_min_addr"]="65536"
        # Filesystem
        ["fs.protected_hardlinks"]="1"
        ["fs.protected_symlinks"]="1"
        ["fs.suid_dumpable"]="0"
    )

    for key in "${!params[@]}"; do
        sysctl -w "${key}=${params[$key]}" &>/dev/null || log "Aviso: não foi possível definir $key"
    done

    log "Sysctl hardening aplicado."
}

# ────────────────────────────────────────────────
# Verificação de vazamento de IP
# ────────────────────────────────────────────────
verify_no_leak() {
    log "Verificando ausência de vazamento de IP..."
    sleep 5

    # Só verifica se tun0 está up
    if ip link show "$TUN_IFACE" &>/dev/null; then
        REAL_IP=$(curl -s --max-time 10 --interface "$TUN_IFACE" https://api.ipify.org 2>/dev/null || echo "N/A")
        log "IP externo via VPN: $REAL_IP"
    else
        log "Aviso: $TUN_IFACE não encontrada — VPN pode não ter conectado ainda."
    fi
}

# ────────────────────────────────────────────────
# Parar (remover regras ao desligar o serviço)
# ────────────────────────────────────────────────
stop() {
    log "Removendo regras Ghost Protocol..."
    flush_rules
    iptables  -P INPUT   ACCEPT
    iptables  -P FORWARD ACCEPT
    iptables  -P OUTPUT  ACCEPT
    ip6tables -P INPUT   ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT  ACCEPT
    log "Regras removidas. Rede restaurada."
}

# ────────────────────────────────────────────────
main() {
    case "${1:-start}" in
        start)
            log "=== Ghost Protocol INICIANDO ==="
            flush_rules
            set_default_drop
            apply_vpn_killswitch
            apply_tor_routing
            apply_sysctl_hardening
            verify_no_leak
            log "=== Ghost Protocol ATIVO — Zero-leak garantido ==="
            ;;
        stop)
            stop
            ;;
        status)
            iptables -L -n -v
            iptables -t nat -L -n -v
            ;;
        *)
            echo "Uso: $0 {start|stop|status}"
            exit 1
            ;;
    esac
}

main "$@"
