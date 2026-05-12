#!/usr/bin/env python3
"""
V0rtexOS — aet-scan
Automatiza o nmap com scripts NSE de detecção de vulnerabilidades críticas.
Uso: aet-scan [opções] <alvo>
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import Optional

# ─────────────────────────────────────────────────
# CONSTANTES
# ─────────────────────────────────────────────────
VERSION = "1.0.0"
NMAP_BIN = shutil.which("nmap") or "/usr/bin/nmap"
OUTPUT_DIR = Path(os.environ.get("VORTEX_OUTPUT", "/tmp/vortex-scans"))

# Perfis de scan pré-definidos
SCAN_PROFILES = {
    "stealth": {
        "desc": "Scan furtivo (-sS -T2) — lento, menos detectável",
        "flags": ["-sS", "-T2", "-Pn", "--randomize-hosts"],
    },
    "fast": {
        "desc": "Scan rápido (-sV -T4) — agressivo",
        "flags": ["-sV", "-sC", "-T4", "-Pn"],
    },
    "full": {
        "desc": "Scan completo — todas as portas + detecção de OS",
        "flags": ["-sS", "-sV", "-sC", "-O", "-T3", "-p-", "-Pn"],
    },
    "udp": {
        "desc": "Scan UDP — SNMP, DNS, DHCP",
        "flags": ["-sU", "-T3", "-Pn", "--top-ports", "200"],
    },
    "vuln": {
        "desc": "Detecção de vulnerabilidades críticas via NSE",
        "flags": ["-sV", "-T3", "-Pn"],
    },
}

# NSE Scripts por categoria de vulnerabilidade
NSE_SCRIPTS = {
    "critical": [
        "vuln",                     # Categoria completa de vulns
        "exploit",                  # Scripts de exploração NSE
        "auth",                     # Auth bypass
        "default",
    ],
    "smb": [
        "smb-vuln-ms17-010",        # EternalBlue
        "smb-vuln-ms08-067",        # MS08-067 NetAPI
        "smb-vuln-cve2009-3103",
        "smb-vuln-ms06-025",
        "smb-vuln-ms07-029",
        "smb-vuln-ms10-054",
        "smb-vuln-ms10-061",        # PrintSpooler
        "smb-vuln-regsvc-dos",
        "smb2-security-mode",
        "smb-security-mode",
        "smb-enum-shares",
        "smb-enum-users",
    ],
    "http": [
        "http-shellshock",          # ShellShock
        "http-vuln-cve2017-5638",   # Apache Struts
        "http-vuln-cve2021-41773",  # Apache path traversal
        "http-vuln-cve2014-3704",   # Drupalgeddon
        "http-vuln-cve2017-1001000",# WordPress
        "http-title",
        "http-methods",
        "http-headers",
        "http-server-header",
        "http-robots.txt",
        "http-auth",
    ],
    "ssl": [
        "ssl-heartbleed",           # HeartBleed
        "ssl-poodle",               # POODLE
        "ssl-drown",
        "ssl-ccs-injection",
        "ssl-cert",
        "ssl-enum-ciphers",
        "sslv2",
    ],
    "ftp": [
        "ftp-anon",                 # FTP anônimo
        "ftp-bounce",
        "ftp-vuln-cve2010-4221",
        "ftp-proftpd-backdoor",
        "ftp-vsftpd-backdoor",      # VSFTPD backdoor
    ],
    "ssh": [
        "ssh-auth-methods",
        "ssh-hostkey",
        "ssh-run",
        "sshv1",
    ],
    "database": [
        "mysql-empty-password",
        "mysql-vuln-cve2012-2122",
        "ms-sql-empty-password",
        "ms-sql-info",
        "ms-sql-config",
        "oracle-sid-brute",
        "redis-info",
        "mongodb-databases",
    ],
    "iot": [
        "snmp-info",
        "snmp-sysdescr",
        "upnp-info",
        "telnet-ntlm-info",
        "tftp-enum",
    ],
}

# ─────────────────────────────────────────────────
# CORES ANSI
# ─────────────────────────────────────────────────
C = {
    "reset":  "\033[0m",
    "red":    "\033[1;31m",
    "green":  "\033[1;32m",
    "yellow": "\033[1;33m",
    "cyan":   "\033[1;36m",
    "bold":   "\033[1m",
    "dim":    "\033[2m",
}


def cprint(color: str, msg: str, prefix: str = "") -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"{C['dim']}[{ts}]{C['reset']} {C[color]}{prefix}{msg}{C['reset']}")


# ─────────────────────────────────────────────────
# VALIDAÇÃO
# ─────────────────────────────────────────────────
def validate_target(target: str) -> bool:
    """Aceita IP, CIDR, hostname ou range."""
    ip_pattern = re.compile(
        r"^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$|"
        r"^(\d{1,3}\.){3}\d{1,3}-\d{1,3}$|"
        r"^[a-zA-Z0-9][a-zA-Z0-9\-\.]+$"
    )
    return bool(ip_pattern.match(target))


def check_nmap() -> None:
    if not Path(NMAP_BIN).exists():
        cprint("red", "nmap não encontrado. Instale: pacman -S nmap", "✗ ")
        sys.exit(1)
    if os.geteuid() != 0:
        cprint("yellow", "Execute como root para scans SYN (-sS) e detecção de OS.", "⚠ ")


# ─────────────────────────────────────────────────
# CONSTRUÇÃO DO COMANDO NMAP
# ─────────────────────────────────────────────────
def build_nmap_command(
    target: str,
    profile: str,
    ports: Optional[str],
    script_categories: list[str],
    extra_scripts: list[str],
    output_base: Path,
    extra_flags: list[str],
) -> list[str]:
    cmd = [NMAP_BIN]

    # Flags do perfil
    cmd.extend(SCAN_PROFILES[profile]["flags"])

    # Scripts NSE
    all_scripts = []
    for cat in script_categories:
        all_scripts.extend(NSE_SCRIPTS.get(cat, [cat]))
    all_scripts.extend(extra_scripts)

    if all_scripts:
        cmd.extend(["--script", ",".join(set(all_scripts))])
        # Argumentos úteis para scripts
        cmd.extend([
            "--script-args",
            "unsafe=1,vulns.showall=on,http.max-cache-size=10000000",
        ])

    # Portas
    if ports:
        cmd.extend(["-p", ports])
    elif profile == "full":
        pass  # -p- já está em full

    # Saída em múltiplos formatos
    cmd.extend([
        "-oX", str(output_base.with_suffix(".xml")),
        "-oN", str(output_base.with_suffix(".txt")),
        "-oG", str(output_base.with_suffix(".gnmap")),
    ])

    # Flags extras do usuário
    cmd.extend(extra_flags)

    # Versão detalhada e timing
    cmd.extend(["--version-intensity", "9"])
    cmd.extend(["--min-rate", "100"])

    cmd.append(target)
    return cmd


# ─────────────────────────────────────────────────
# PARSING DE RESULTADOS XML
# ─────────────────────────────────────────────────
def parse_xml_results(xml_path: Path) -> dict:
    """Extrai hosts, portas e vulnerabilidades do XML do nmap."""
    results = {"hosts": [], "total_vulns": 0, "critical": []}

    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except ET.ParseError as e:
        cprint("red", f"Erro ao parsear XML: {e}", "✗ ")
        return results

    for host in root.findall("host"):
        addr_elem = host.find("address")
        if addr_elem is None:
            continue

        ip = addr_elem.get("addr", "unknown")
        status = host.find("status")
        state = status.get("state", "unknown") if status is not None else "unknown"

        if state != "up":
            continue

        host_data = {"ip": ip, "ports": [], "os": "unknown", "vulns": []}

        # OS detection
        os_elem = host.find("os/osmatch")
        if os_elem is not None:
            host_data["os"] = f"{os_elem.get('name', '?')} ({os_elem.get('accuracy', '?')}%)"

        # Portas e serviços
        for port in host.findall("ports/port"):
            port_id = port.get("portid")
            protocol = port.get("protocol")
            state_elem = port.find("state")
            service_elem = port.find("service")

            if state_elem is None or state_elem.get("state") != "open":
                continue

            port_info = {
                "port": f"{port_id}/{protocol}",
                "service": service_elem.get("name", "?") if service_elem is not None else "?",
                "version": (
                    f"{service_elem.get('product', '')} "
                    f"{service_elem.get('version', '')}".strip()
                    if service_elem is not None else ""
                ),
                "scripts": [],
            }

            # Scripts NSE e vulnerabilidades
            for script in port.findall("script"):
                script_id = script.get("id", "")
                script_output = script.get("output", "")

                port_info["scripts"].append({
                    "id": script_id,
                    "output": script_output[:500],  # truncar saída longa
                })

                # Detectar CVEs e vulnerabilidades nos scripts
                cves = re.findall(r"CVE-\d{4}-\d+", script_output)
                if cves or "VULNERABLE" in script_output.upper():
                    vuln = {
                        "port": port_id,
                        "script": script_id,
                        "cves": list(set(cves)),
                        "snippet": script_output[:300],
                    }
                    host_data["vulns"].append(vuln)
                    results["critical"].append({**vuln, "host": ip})
                    results["total_vulns"] += 1

            host_data["ports"].append(port_info)

        results["hosts"].append(host_data)

    return results


# ─────────────────────────────────────────────────
# RELATÓRIO
# ─────────────────────────────────────────────────
def print_summary(results: dict, output_base: Path) -> None:
    print()
    cprint("cyan", "═" * 60, "")
    cprint("cyan", "  V0RTEX SCAN — RELATÓRIO FINAL", "")
    cprint("cyan", "═" * 60, "")

    for host in results["hosts"]:
        cprint("green", f"\n  HOST: {host['ip']}", "")
        cprint("dim",   f"  OS  : {host['os']}", "")

        if host["ports"]:
            cprint("bold", "  PORTAS ABERTAS:", "")
            for p in host["ports"]:
                line = f"    {p['port']:<16} {p['service']:<12} {p['version']}"
                cprint("green" if not p["scripts"] else "yellow", line, "")

        if host["vulns"]:
            cprint("red", f"\n  ⚠ VULNERABILIDADES ({len(host['vulns'])}):", "")
            for v in host["vulns"]:
                cprint("red",    f"    Porta  : {v['port']}", "")
                cprint("red",    f"    Script : {v['script']}", "")
                if v["cves"]:
                    cprint("red", f"    CVEs   : {', '.join(v['cves'])}", "")
                cprint("dim",    f"    Trecho : {v['snippet'][:150]}...", "")
                print()

    print()
    cprint("cyan", f"  Total de hosts UP     : {len(results['hosts'])}", "")
    cprint("red",  f"  Total de vulnerabilidades: {results['total_vulns']}", "")
    cprint("dim",  f"  Outputs salvos em     : {output_base.parent}/", "")
    cprint("cyan", "═" * 60, "")

    # Salvar JSON
    json_path = output_base.with_suffix(".json")
    with open(json_path, "w") as f:
        json.dump(results, f, indent=2)
    cprint("dim", f"  JSON salvo: {json_path}", "")


# ─────────────────────────────────────────────────
# EXECUÇÃO DO SCAN
# ─────────────────────────────────────────────────
def run_scan(args: argparse.Namespace) -> int:
    if not validate_target(args.target):
        cprint("red", f"Alvo inválido: {args.target}", "✗ ")
        return 1

    check_nmap()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    safe_target = args.target.replace("/", "_").replace(":", "_")
    output_base = OUTPUT_DIR / f"{safe_target}-{args.profile}-{ts}"

    # Categorias NSE
    if args.scripts:
        cats = args.scripts
    elif args.profile == "vuln":
        cats = ["critical", "smb", "http", "ssl", "ftp", "database"]
    else:
        cats = []

    # Flags extras
    extra = args.extra.split() if args.extra else []

    cmd = build_nmap_command(
        target=args.target,
        profile=args.profile,
        ports=args.ports,
        script_categories=cats,
        extra_scripts=[],
        output_base=output_base,
        extra_flags=extra,
    )

    cprint("cyan", "═" * 60, "")
    cprint("cyan", "  V0rtexOS — aet-scan", "")
    cprint("cyan", f"  Alvo   : {args.target}", "")
    cprint("cyan", f"  Perfil : {args.profile} — {SCAN_PROFILES[args.profile]['desc']}", "")
    if cats:
        cprint("cyan", f"  NSE    : {', '.join(cats)}", "")
    cprint("cyan", "═" * 60, "")
    cprint("dim",  "  Comando: " + " ".join(cmd), "")
    print()

    try:
        proc = subprocess.run(cmd, text=True, check=False)
        rc = proc.returncode
    except KeyboardInterrupt:
        cprint("yellow", "\nScan interrompido pelo usuário.", "⚠ ")
        return 130
    except Exception as e:
        cprint("red", f"Erro ao executar nmap: {e}", "✗ ")
        return 1

    # Parsear XML e exibir resumo
    xml_path = output_base.with_suffix(".xml")
    if xml_path.exists():
        results = parse_xml_results(xml_path)
        print_summary(results, output_base)

    return rc


# ─────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="aet-scan",
        description=f"V0rtexOS — Scanner de Vulnerabilidades v{VERSION}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  aet-scan 192.168.1.0/24                  # Scan rápido da rede local
  aet-scan -p vuln 10.10.10.5              # Detecção de vulnerabilidades
  aet-scan -p full -s smb,http 10.0.0.1   # Scan completo com NSE SMB+HTTP
  aet-scan -p stealth -P 80,443 target.com # Scan furtivo em portas específicas
  aet-scan -p fast --extra "-D RND:10" 192.168.1.1  # Decoys

Perfis disponíveis: stealth, fast, full, udp, vuln
Categorias NSE    : critical, smb, http, ssl, ftp, ssh, database, iot
        """,
    )
    p.add_argument("target", help="IP, CIDR, hostname ou range (ex: 192.168.1.0/24)")
    p.add_argument("-p", "--profile", choices=SCAN_PROFILES.keys(), default="fast",
                   help="Perfil de scan (default: fast)")
    p.add_argument("-s", "--scripts", nargs="+", metavar="CATEGORY",
                   help="Categorias NSE: smb http ssl ftp ssh database iot critical")
    p.add_argument("-P", "--ports", metavar="PORTS",
                   help="Portas: 80,443 | 1-1000 | U:137,T:139")
    p.add_argument("-o", "--output", metavar="DIR",
                   help=f"Diretório de saída (default: {OUTPUT_DIR})")
    p.add_argument("--extra", metavar="FLAGS",
                   help='Flags adicionais do nmap (ex: "--min-rate 1000 -D RND:5")')
    p.add_argument("--list-profiles", action="store_true",
                   help="Listar perfis disponíveis e sair")
    p.add_argument("--list-scripts", action="store_true",
                   help="Listar categorias NSE e sair")
    p.add_argument("-v", "--version", action="version", version=f"aet-scan {VERSION}")
    return p


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.list_profiles:
        print("\nPerfis disponíveis:")
        for name, info in SCAN_PROFILES.items():
            print(f"  {name:<10} {info['desc']}")
        print()
        return 0

    if args.list_scripts:
        print("\nCategorias NSE:")
        for cat, scripts in NSE_SCRIPTS.items():
            print(f"\n  [{cat}]")
            for s in scripts:
                print(f"    {s}")
        print()
        return 0

    if args.output:
        global OUTPUT_DIR
        OUTPUT_DIR = Path(args.output)

    return run_scan(args)


if __name__ == "__main__":
    sys.exit(main())
