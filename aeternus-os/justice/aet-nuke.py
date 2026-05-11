#!/usr/bin/env python3
"""
AETERNUS OS — aet-nuke
Defesa ativa automatizada com bibliotecas de rede assíncronas.
Monitora, detecta e responde a atividades hostis em tempo real.

Funcionalidades:
  - Monitor de conexões suspeitas em tempo real
  - Bloqueio automático via iptables (honeypot-response mode)
  - Rate-limit e banimento temporário
  - Scanner de portas expostas no host
  - Monitoramento de integridade de arquivos críticos
  - Alertas assíncronos em tempo real

Uso: sudo aet-nuke [modo]
"""

import argparse
import asyncio
import hashlib
import json
import logging
import os
import re
import signal
import socket
import struct
import subprocess
import sys
import time
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# ─────────────────────────────────────────────────
# CONFIGURAÇÃO
# ─────────────────────────────────────────────────
VERSION = "1.0.0"

LOG_DIR = Path("/var/log/aeternus")
BAN_FILE = Path("/var/lib/aeternus/banned_ips.json")
WHITELIST_FILE = Path("/etc/aeternus/whitelist.conf")

# Limiares de detecção
THRESHOLDS = {
    "port_scan_pps":      15,    # pacotes/seg de um IP para considerar port scan
    "ssh_fail_attempts":   5,    # falhas SSH antes de banir
    "http_req_per_sec":  100,    # requisições HTTP/s antes de rate-limit
    "ban_duration":      3600,   # segundos de ban (1 hora)
    "syn_flood_pps":     500,    # SYN/s para considerar flood
    "max_connections":    50,    # conexões simultâneas por IP
}

# Arquivos críticos para monitoramento de integridade
CRITICAL_FILES = [
    "/etc/passwd",
    "/etc/shadow",
    "/etc/sudoers",
    "/etc/ssh/sshd_config",
    "/etc/hosts",
    "/usr/local/bin/ghost-protocol.sh",
    "/usr/local/bin/aet-scan",
    "/usr/local/bin/aet-nuke",
]

# ─────────────────────────────────────────────────
# LOGGING ESTRUTURADO
# ─────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="\033[2m%(asctime)s\033[0m \033[1;36m[aet-nuke]\033[0m %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("aet-nuke")


def cprint(color: str, msg: str) -> None:
    colors = {
        "red":    "\033[1;31m",
        "green":  "\033[1;32m",
        "yellow": "\033[1;33m",
        "cyan":   "\033[1;36m",
        "reset":  "\033[0m",
        "dim":    "\033[2m",
    }
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"\033[2m[{ts}]\033[0m {colors.get(color,'')}{msg}{colors['reset']}")


# ─────────────────────────────────────────────────
# ESTADO COMPARTILHADO
# ─────────────────────────────────────────────────
@dataclass
class ThreatState:
    banned_ips: dict = field(default_factory=dict)        # ip -> expire_time
    connection_counts: dict = field(default_factory=lambda: defaultdict(int))
    ssh_failures: dict = field(default_factory=lambda: defaultdict(int))
    port_scan_track: dict = field(default_factory=lambda: defaultdict(list))
    syn_counts: dict = field(default_factory=lambda: defaultdict(int))
    alerts: list = field(default_factory=list)
    whitelist: set = field(default_factory=set)
    file_hashes: dict = field(default_factory=dict)
    running: bool = True

    def is_banned(self, ip: str) -> bool:
        if ip in self.banned_ips:
            if time.time() < self.banned_ips[ip]:
                return True
            del self.banned_ips[ip]
        return False

    def is_whitelisted(self, ip: str) -> bool:
        return ip in self.whitelist or ip.startswith("127.")

    def record_alert(self, level: str, msg: str, ip: Optional[str] = None) -> None:
        alert = {
            "time": datetime.now().isoformat(),
            "level": level,
            "message": msg,
            "ip": ip,
        }
        self.alerts.append(alert)
        fn = {"CRITICAL": "red", "WARNING": "yellow", "INFO": "cyan"}.get(level, "dim")
        cprint(fn, f"[{level}] {msg}")


STATE = ThreatState()


# ─────────────────────────────────────────────────
# IPTABLES — Banimento e bloqueio
# ─────────────────────────────────────────────────
def iptables_ban(ip: str, reason: str, duration: int = THRESHOLDS["ban_duration"]) -> bool:
    """Adiciona regra DROP para um IP via iptables."""
    if STATE.is_whitelisted(ip) or STATE.is_banned(ip):
        return False

    expire = time.time() + duration
    STATE.banned_ips[ip] = expire
    STATE.record_alert("CRITICAL", f"BANINDO {ip} por {duration}s — {reason}", ip=ip)

    try:
        # Bloquear entrada e saída
        subprocess.run(
            ["iptables", "-I", "INPUT", "1", "-s", ip, "-j", "DROP"],
            check=True, capture_output=True,
        )
        subprocess.run(
            ["iptables", "-I", "OUTPUT", "1", "-d", ip, "-j", "DROP"],
            check=True, capture_output=True,
        )
        # Agendar desbloqueio
        asyncio.get_event_loop().call_later(duration, iptables_unban, ip)
        _save_ban_state()
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Falha ao banir {ip}: {e}")
        return False


def iptables_unban(ip: str) -> None:
    """Remove regra DROP de um IP."""
    try:
        subprocess.run(
            ["iptables", "-D", "INPUT", "-s", ip, "-j", "DROP"],
            capture_output=True,
        )
        subprocess.run(
            ["iptables", "-D", "OUTPUT", "-d", ip, "-j", "DROP"],
            capture_output=True,
        )
        STATE.banned_ips.pop(ip, None)
        STATE.record_alert("INFO", f"Ban expirado — {ip} desbloqueado.")
        _save_ban_state()
    except Exception as e:
        logger.error(f"Falha ao desbanir {ip}: {e}")


def _save_ban_state() -> None:
    BAN_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(BAN_FILE, "w") as f:
        json.dump(
            {ip: exp for ip, exp in STATE.banned_ips.items() if time.time() < exp},
            f, indent=2,
        )


def _load_ban_state() -> None:
    if BAN_FILE.exists():
        with open(BAN_FILE) as f:
            data = json.load(f)
        now = time.time()
        STATE.banned_ips = {ip: exp for ip, exp in data.items() if now < exp}
        logger.info(f"Carregados {len(STATE.banned_ips)} IPs banidos do estado anterior.")


def _load_whitelist() -> None:
    if WHITELIST_FILE.exists():
        with open(WHITELIST_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    STATE.whitelist.add(line)
    # Sempre whitelist localhost e VPN local
    STATE.whitelist.update({"127.0.0.1", "::1", "10.0.0.0/8"})
    logger.info(f"Whitelist: {len(STATE.whitelist)} entradas carregadas.")


# ─────────────────────────────────────────────────
# MONITOR DE LOG SSH — Detecta ataques de força bruta
# ─────────────────────────────────────────────────
async def monitor_ssh_log() -> None:
    """Monitora /var/log/auth.log em tempo real para falhas SSH."""
    log_paths = ["/var/log/auth.log", "/var/log/secure"]
    log_path = next((p for p in log_paths if Path(p).exists()), None)

    if not log_path:
        # Tentar via journalctl
        await monitor_ssh_journal()
        return

    cprint("cyan", f"Monitor SSH ativo → {log_path}")
    fail_pattern = re.compile(
        r"Failed (password|publickey) for .* from (\d+\.\d+\.\d+\.\d+)"
    )
    accept_pattern = re.compile(
        r"Accepted (password|publickey) for .* from (\d+\.\d+\.\d+\.\d+)"
    )

    with open(log_path, "r") as f:
        f.seek(0, 2)  # Ir para o final do arquivo
        while STATE.running:
            line = f.readline()
            if not line:
                await asyncio.sleep(0.1)
                continue

            m = fail_pattern.search(line)
            if m:
                ip = m.group(2)
                if not STATE.is_whitelisted(ip):
                    STATE.ssh_failures[ip] += 1
                    count = STATE.ssh_failures[ip]
                    STATE.record_alert(
                        "WARNING",
                        f"SSH falha #{count} de {ip} (limite: {THRESHOLDS['ssh_fail_attempts']})",
                        ip=ip,
                    )
                    if count >= THRESHOLDS["ssh_fail_attempts"]:
                        iptables_ban(ip, f"SSH brute-force ({count} falhas)")
                        STATE.ssh_failures[ip] = 0

            m = accept_pattern.search(line)
            if m:
                ip = m.group(2)
                STATE.record_alert("INFO", f"SSH login bem-sucedido de {ip}", ip=ip)
                STATE.ssh_failures.pop(ip, None)


async def monitor_ssh_journal() -> None:
    """Fallback: monitorar SSH via journalctl -f."""
    cprint("cyan", "Monitor SSH via journalctl")
    proc = await asyncio.create_subprocess_exec(
        "journalctl", "-f", "-u", "ssh.service", "-u", "sshd.service",
        "--no-pager", "-o", "cat",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.DEVNULL,
    )
    fail_re = re.compile(r"Failed .* from (\d+\.\d+\.\d+\.\d+)")
    while STATE.running and proc.stdout:
        try:
            line = await asyncio.wait_for(proc.stdout.readline(), timeout=1.0)
            if not line:
                break
            text = line.decode(errors="replace")
            m = fail_re.search(text)
            if m:
                ip = m.group(1)
                STATE.ssh_failures[ip] += 1
                if STATE.ssh_failures[ip] >= THRESHOLDS["ssh_fail_attempts"]:
                    iptables_ban(ip, "SSH brute-force")
        except asyncio.TimeoutError:
            continue


# ─────────────────────────────────────────────────
# MONITOR DE CONEXÕES — Detecta port scans e floods
# ─────────────────────────────────────────────────
async def monitor_connections() -> None:
    """Monitora conexões ativas via /proc/net/tcp."""
    cprint("cyan", "Monitor de conexões ativo (/proc/net/tcp)")

    def parse_proc_net_tcp(path: str = "/proc/net/tcp") -> list[dict]:
        conns = []
        try:
            with open(path) as f:
                next(f)  # pular cabeçalho
                for line in f:
                    parts = line.split()
                    if len(parts) < 4:
                        continue
                    local = parts[1]
                    remote = parts[2]
                    state = parts[3]
                    # Decodificar endereço hex little-endian
                    def decode_addr(hex_addr: str) -> tuple[str, int]:
                        ip_hex, port_hex = hex_addr.split(":")
                        ip = socket.inet_ntoa(struct.pack("<I", int(ip_hex, 16)))
                        port = int(port_hex, 16)
                        return ip, port

                    try:
                        l_ip, l_port = decode_addr(local)
                        r_ip, r_port = decode_addr(remote)
                        conns.append({
                            "local": f"{l_ip}:{l_port}",
                            "remote": f"{r_ip}:{r_port}",
                            "remote_ip": r_ip,
                            "state": state,
                        })
                    except (ValueError, OSError):
                        continue
        except FileNotFoundError:
            pass
        return conns

    conn_counts_window: dict[str, list[float]] = defaultdict(list)

    while STATE.running:
        await asyncio.sleep(2)
        now = time.time()
        conns = parse_proc_net_tcp()

        # Contar conexões por IP remoto
        ip_conn_map: dict[str, int] = defaultdict(int)
        for c in conns:
            ip = c["remote_ip"]
            if ip and ip != "0.0.0.0":
                ip_conn_map[ip] += 1

        for ip, count in ip_conn_map.items():
            if STATE.is_whitelisted(ip) or STATE.is_banned(ip):
                continue

            # Rastrear no tempo
            conn_counts_window[ip].append(now)
            # Manter apenas últimos 10s
            conn_counts_window[ip] = [t for t in conn_counts_window[ip] if now - t < 10]

            if count > THRESHOLDS["max_connections"]:
                iptables_ban(ip, f"Excesso de conexões ({count})")
            elif len(conn_counts_window[ip]) > THRESHOLDS["port_scan_pps"] * 2:
                STATE.record_alert(
                    "WARNING",
                    f"Possível port scan de {ip} "
                    f"({len(conn_counts_window[ip])} conexões em 10s)",
                    ip=ip,
                )


# ─────────────────────────────────────────────────
# MONITOR DE INTEGRIDADE DE ARQUIVOS
# ─────────────────────────────────────────────────
async def monitor_file_integrity() -> None:
    """Verifica periodicamente hashes SHA-256 de arquivos críticos."""
    cprint("cyan", f"Monitor de integridade ativo ({len(CRITICAL_FILES)} arquivos)")

    # Calcular hashes iniciais
    for fpath in CRITICAL_FILES:
        p = Path(fpath)
        if p.exists():
            STATE.file_hashes[fpath] = _sha256(p)

    while STATE.running:
        await asyncio.sleep(30)
        for fpath in CRITICAL_FILES:
            p = Path(fpath)
            if not p.exists():
                if fpath in STATE.file_hashes:
                    STATE.record_alert(
                        "CRITICAL",
                        f"Arquivo crítico REMOVIDO: {fpath}",
                    )
                    del STATE.file_hashes[fpath]
                continue

            current_hash = _sha256(p)
            if fpath in STATE.file_hashes:
                if current_hash != STATE.file_hashes[fpath]:
                    STATE.record_alert(
                        "CRITICAL",
                        f"Arquivo crítico MODIFICADO: {fpath} "
                        f"(hash anterior: {STATE.file_hashes[fpath][:16]}...)",
                    )
            STATE.file_hashes[fpath] = current_hash


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


# ─────────────────────────────────────────────────
# SCANNER DE PORTAS EXPOSTAS NO HOST
# ─────────────────────────────────────────────────
async def scan_local_exposure() -> None:
    """Verifica portas abertas no host que não deveriam estar expostas."""
    cprint("cyan", "Verificando exposição de portas do host...")

    dangerous_ports = {
        21: "FTP",
        23: "Telnet",
        25: "SMTP",
        69: "TFTP",
        111: "RPC",
        137: "NetBIOS",
        139: "SMB",
        445: "SMB",
        512: "rexec",
        513: "rlogin",
        514: "rsh",
        1433: "MSSQL",
        3306: "MySQL",
        5432: "PostgreSQL",
        5900: "VNC",
        6379: "Redis",
        27017: "MongoDB",
    }

    exposed = []
    for port, service in dangerous_ports.items():
        try:
            _, writer = await asyncio.wait_for(
                asyncio.open_connection("127.0.0.1", port),
                timeout=0.5,
            )
            writer.close()
            exposed.append((port, service))
        except (OSError, asyncio.TimeoutError):
            pass

    if exposed:
        for port, service in exposed:
            STATE.record_alert(
                "WARNING",
                f"Serviço potencialmente perigoso exposto localmente: {port}/{service}",
            )
    else:
        cprint("green", "Nenhuma porta perigosa exposta localmente.")


# ─────────────────────────────────────────────────
# STATUS E DASHBOARD
# ─────────────────────────────────────────────────
async def print_dashboard() -> None:
    """Exibe dashboard de status a cada 30 segundos."""
    while STATE.running:
        await asyncio.sleep(30)
        print()
        cprint("cyan", "─" * 50)
        cprint("cyan", f"  aet-nuke — DASHBOARD  ({datetime.now().strftime('%H:%M:%S')})")
        cprint("cyan", f"  IPs banidos       : {len(STATE.banned_ips)}")
        cprint("cyan", f"  Falhas SSH rastr. : {sum(STATE.ssh_failures.values())}")
        cprint("cyan", f"  Total de alertas  : {len(STATE.alerts)}")
        recent = [a for a in STATE.alerts if a["level"] == "CRITICAL"][-5:]
        if recent:
            cprint("red", "  Últimos críticos:")
            for a in recent:
                cprint("red", f"    {a['time'][11:19]} — {a['message'][:60]}")
        cprint("cyan", "─" * 50)


# ─────────────────────────────────────────────────
# MODO: Listar IPs banidos
# ─────────────────────────────────────────────────
def cmd_list_bans() -> None:
    _load_ban_state()
    if not STATE.banned_ips:
        cprint("green", "Nenhum IP banido no momento.")
        return
    cprint("cyan", f"\nIPs banidos ({len(STATE.banned_ips)}):")
    now = time.time()
    for ip, exp in STATE.banned_ips.items():
        remaining = max(0, int(exp - now))
        cprint("red", f"  {ip:<20} expira em {remaining}s")


def cmd_unban(ip: str) -> None:
    _load_ban_state()
    if ip in STATE.banned_ips:
        iptables_unban(ip)
        cprint("green", f"{ip} desbloqueado.")
    else:
        cprint("yellow", f"{ip} não está banido.")


# ─────────────────────────────────────────────────
# MAIN — Modo monitor
# ─────────────────────────────────────────────────
async def run_monitor(args: argparse.Namespace) -> None:
    if os.geteuid() != 0:
        cprint("red", "aet-nuke requer root para iptables e /proc/net/tcp.")
        sys.exit(1)

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    _load_ban_state()
    _load_whitelist()

    cprint("cyan", "═" * 50)
    cprint("cyan", "  AETERNUS OS — aet-nuke  v" + VERSION)
    cprint("cyan", "  Defesa Ativa Assíncrona")
    cprint("cyan", "═" * 50)

    # Verificar exposição imediata
    await scan_local_exposure()

    # Tarefas assíncronas simultâneas
    tasks = [
        asyncio.create_task(monitor_ssh_log()),
        asyncio.create_task(monitor_connections()),
        asyncio.create_task(monitor_file_integrity()),
        asyncio.create_task(print_dashboard()),
    ]

    def _shutdown(signum, frame):
        STATE.running = False
        cprint("yellow", "\nDesligando aet-nuke...")
        for t in tasks:
            t.cancel()

    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    cprint("green", "Todos os monitores ativos. Ctrl+C para parar.")

    try:
        await asyncio.gather(*tasks, return_exceptions=True)
    except asyncio.CancelledError:
        pass

    # Salvar log de alertas
    log_file = LOG_DIR / f"aet-nuke-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
    with open(log_file, "w") as f:
        json.dump(STATE.alerts, f, indent=2)
    cprint("dim", f"Alertas salvos em: {log_file}")


# ─────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────
def main() -> int:
    p = argparse.ArgumentParser(
        prog="aet-nuke",
        description=f"AETERNUS OS — Defesa Ativa v{VERSION}",
    )
    sub = p.add_subparsers(dest="cmd")

    sub.add_parser("monitor", help="Iniciar modo monitor (default)")
    sub.add_parser("status",  help="Exibir status atual")

    ls = sub.add_parser("list-bans", help="Listar IPs banidos")
    ub = sub.add_parser("unban", help="Desbanir IP")
    ub.add_argument("ip", help="IP a desbanir")

    scan = sub.add_parser("scan-self", help="Verificar exposição local")

    args = p.parse_args()

    if args.cmd == "list-bans":
        cmd_list_bans()
        return 0
    elif args.cmd == "unban":
        cmd_unban(args.ip)
        return 0
    elif args.cmd == "scan-self":
        asyncio.run(scan_local_exposure())
        return 0
    else:
        asyncio.run(run_monitor(args))
        return 0


if __name__ == "__main__":
    sys.exit(main())
