#!/usr/bin/env bash
# AETERNUS OS — Web Enumeration Pipeline
# Pipeline completo de enumeração web em um comando
# Uso: web-enum.sh <url> [wordlist]

set -euo pipefail

URL="${1:?Informe a URL alvo (ex: http://192.168.1.100)}"
WORDLIST="${2:-/opt/wordlists/SecLists/Discovery/Web-Content/raft-medium-words.txt}"
OUT="${3:-/tmp/aeternus-web-$(date +%Y%m%d-%H%M%S)}"

RED='\033[1;31m' GRN='\033[1;32m' CYN='\033[1;36m' RST='\033[0m'
ok()  { echo -e "${GRN}[+]${RST} $*"; }
log() { echo -e "${CYN}[*]${RST} $*"; }

mkdir -p "$OUT"/{headers,dirs,tech,vulns,params,js}

echo -e "\n${CYN}╔══════════════════════════════════════════════════╗"
echo    "║  AETERNUS OS — Web Enumeration Pipeline         ║"
echo -e "╚══════════════════════════════════════════════════╝${RST}\n"
log "Alvo: $URL"
log "Output: $OUT"

# ── 1. Informações básicas e headers ──────────────
log "[1/9] Headers HTTP..."
curl -sI --max-time 10 "$URL" | tee "$OUT/headers/headers.txt"
curl -s --max-time 10 "$URL/robots.txt" -o "$OUT/headers/robots.txt" && ok "robots.txt obtido"
curl -s --max-time 10 "$URL/sitemap.xml" -o "$OUT/headers/sitemap.xml" 2>/dev/null || true

# ── 2. Fingerprinting de tecnologia ───────────────
log "[2/9] Fingerprinting de tecnologia (whatweb)..."
whatweb -a 3 "$URL" 2>/dev/null | tee "$OUT/tech/whatweb.txt" || true

# ── 3. SSL/TLS Analysis ───────────────────────────
if [[ "$URL" == https* ]]; then
    log "[3/9] Análise SSL/TLS (sslyze)..."
    sslyze "$(echo "$URL" | sed 's|https://||')" 2>/dev/null \
        | tee "$OUT/tech/sslyze.txt" || true
else
    log "[3/9] SSL/TLS: skipped (HTTP)"
fi

# ── 4. WAF Detection ──────────────────────────────
log "[4/9] Detecção de WAF (wafw00f)..."
wafw00f "$URL" 2>/dev/null | tee "$OUT/tech/waf.txt" || true

# ── 5. Directory/File Bruteforce ──────────────────
log "[5/9] Bruteforce de diretórios (ffuf)..."
ffuf -u "${URL}/FUZZ" \
    -w "$WORDLIST" \
    -mc 200,201,202,204,301,302,307,401,403 \
    -fc 404 \
    -t 50 \
    -timeout 10 \
    -recursion -recursion-depth 2 \
    -o "$OUT/dirs/ffuf.json" -of json \
    2>/dev/null | tee "$OUT/dirs/ffuf.txt" || true

# ── 6. Backup e arquivos sensíveis ────────────────
log "[6/9] Buscando backups e arquivos sensíveis..."
ffuf -u "${URL}/FUZZ" \
    -w /opt/wordlists/SecLists/Discovery/Web-Content/raft-small-files.txt \
    -e ".bak,.old,.zip,.tar.gz,.sql,.config,.env,.git,.svn,.DS_Store" \
    -mc 200,301,302 -fc 404 \
    -t 30 \
    -o "$OUT/dirs/backup-files.json" -of json \
    2>/dev/null || true

# ── 7. Parâmetros HTTP ────────────────────────────
log "[7/9] Descoberta de parâmetros (arjun)..."
arjun -u "$URL" \
    -oJ "$OUT/params/arjun.json" \
    --stable 2>/dev/null || true

# ── 8. JavaScript parsing ─────────────────────────
log "[8/9] Extraindo endpoints de JS..."
DOMAIN=$(echo "$URL" | sed 's|https\?://||' | cut -d/ -f1)
python3 /opt/aeternus/Photon/photon.py \
    -u "$URL" \
    --level 3 \
    -o "$OUT/js" \
    --only-urls \
    2>/dev/null || true

# ── 9. Nikto scan rápido ──────────────────────────
log "[9/9] Nikto scan..."
nikto -h "$URL" \
    -output "$OUT/vulns/nikto.txt" \
    -Format txt \
    -Tuning 13458 \
    -timeout 10 \
    2>/dev/null | tail -30 || true

# ── Nuclei template scan ───────────────────────────
log "[BONUS] Nuclei — Templates de vulnerabilidades críticas..."
nuclei -u "$URL" \
    -severity critical,high,medium \
    -t /root/nuclei-templates/ \
    -o "$OUT/vulns/nuclei.txt" \
    -silent 2>/dev/null || true

# ── Sumário ────────────────────────────────────────
echo
echo -e "${CYN}═══════════════════════════════════════════════${RST}"
echo -e "${CYN}  WEB ENUM CONCLUÍDO — $URL${RST}"
echo -e "${CYN}═══════════════════════════════════════════════${RST}"
echo -e "  Headers    : $OUT/headers/"
echo -e "  Tecnologia : $OUT/tech/"
echo -e "  Diretórios : $OUT/dirs/ffuf.txt"
echo -e "  Parâmetros : $OUT/params/arjun.json"
echo -e "  Vuln scan  : $OUT/vulns/"
echo -e "${CYN}═══════════════════════════════════════════════${RST}"

# Mostrar achados críticos
echo -e "\n${RED}=== ACHADOS RELEVANTES ===${RST}"
grep -h -E "200|VULNERABLE|CVE|backup|\.env|\.git|admin|login|upload|config" \
    "$OUT"/**/*.txt 2>/dev/null | sort -u | head -30 || true
