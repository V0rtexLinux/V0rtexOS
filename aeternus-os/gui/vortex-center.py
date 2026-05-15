#!/usr/bin/env python3
# V0rtexOS — Centro de Controle GTK3
# Painel gráfico para gerenciar ferramentas, rede, Ghost Protocol e sistema

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Pango
import subprocess
import threading
import os
import socket
import datetime

# ─── CSS / Tema dark ──────────────────────────────────────────────────────────
CSS = b"""
* {
    font-family: "JetBrains Mono Nerd Font", "Hack Nerd Font", monospace;
}
window {
    background-color: #0a0a0a;
    color: #cccccc;
}
#sidebar {
    background-color: #0d0d0d;
    border-right: 1px solid #1f1f1f;
    min-width: 180px;
}
#sidebar button {
    background: transparent;
    border: none;
    border-radius: 0;
    color: #666666;
    padding: 14px 20px;
    font-size: 12px;
    text-align: left;
}
#sidebar button:hover {
    background-color: #141414;
    color: #aaaaaa;
}
#sidebar button.active {
    background-color: #141414;
    color: #ffffff;
    border-left: 2px solid #ffffff;
}
#header {
    background-color: #000000;
    border-bottom: 1px solid #1f1f1f;
    padding: 12px 20px;
}
#header-title {
    color: #ffffff;
    font-size: 15px;
    font-weight: bold;
    letter-spacing: 3px;
}
#header-subtitle {
    color: #444444;
    font-size: 10px;
    letter-spacing: 2px;
}
#content {
    background-color: #0a0a0a;
    padding: 24px;
}
.section-title {
    color: #888888;
    font-size: 10px;
    letter-spacing: 3px;
    margin-bottom: 12px;
    margin-top: 8px;
}
.card {
    background-color: #0f0f0f;
    border: 1px solid #1a1a1a;
    border-radius: 4px;
    padding: 16px;
    margin-bottom: 12px;
}
.card-title {
    color: #ffffff;
    font-size: 12px;
    font-weight: bold;
    margin-bottom: 6px;
}
.card-value {
    color: #666666;
    font-size: 11px;
}
.status-on {
    color: #aaffaa;
    font-size: 10px;
}
.status-off {
    color: #ff6666;
    font-size: 10px;
}
.status-unknown {
    color: #888888;
    font-size: 10px;
}
.tool-button {
    background-color: #111111;
    border: 1px solid #222222;
    border-radius: 3px;
    color: #cccccc;
    font-size: 11px;
    padding: 8px 14px;
    margin: 3px;
}
.tool-button:hover {
    background-color: #1a1a1a;
    border-color: #333333;
    color: #ffffff;
}
.action-button {
    background-color: #151515;
    border: 1px solid #333333;
    border-radius: 3px;
    color: #ffffff;
    font-size: 11px;
    padding: 10px 20px;
    margin: 4px;
}
.action-button:hover {
    background-color: #222222;
}
.danger-button {
    background-color: #1a0000;
    border: 1px solid #440000;
    border-radius: 3px;
    color: #ff6666;
    font-size: 11px;
    padding: 10px 20px;
    margin: 4px;
}
.danger-button:hover {
    background-color: #220000;
    border-color: #660000;
}
.log-view {
    background-color: #050505;
    color: #00cc00;
    font-family: "JetBrains Mono Nerd Font", monospace;
    font-size: 11px;
    padding: 12px;
    border: 1px solid #111111;
    border-radius: 3px;
}
separator {
    background-color: #1a1a1a;
    min-height: 1px;
    margin: 8px 0;
}
scrolledwindow {
    background-color: transparent;
}
"""

# ─── Utilitários ──────────────────────────────────────────────────────────────
def run_cmd(cmd, timeout=5):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip() or r.stderr.strip()
    except Exception as e:
        return str(e)

def run_terminal(cmd):
    subprocess.Popen(["alacritty", "-e", "bash", "-c", f"{cmd}; echo; echo '[ pressione Enter ]'; read"], 
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def service_active(name):
    r = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True)
    return r.stdout.strip() == "active"

# ─── Página: Dashboard ────────────────────────────────────────────────────────
class DashboardPage(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_name("content")

        title = Gtk.Label(label="DASHBOARD")
        title.get_style_context().add_class("section-title")
        title.set_halign(Gtk.Align.START)
        self.pack_start(title, False, False, 0)

        grid = Gtk.Grid(column_spacing=12, row_spacing=12)
        grid.set_column_homogeneous(True)

        # Cards de status
        self.cards = {}
        def _get_env_field(field, default="—"):
            try:
                with open("/run/v0rtex/env") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith(field + "="):
                            return line.split("=", 1)[1].strip()
            except Exception:
                pass
            return default

        def _get_ambiente():
            vendor  = _get_env_field("VORTEX_VM_VENDOR", "—")
            profile = _get_env_field("VORTEX_HW_PROFILE", "—")
            is_vm   = _get_env_field("VORTEX_IS_VM", "—")
            label   = "VM" if is_vm == "1" else "REAL"
            return f"[{label}] {vendor} · {profile}"

        items = [
            ("hostname",    "HOSTNAME",      lambda: run_cmd("hostname")),
            ("ip",          "IP LOCAL",      lambda: run_cmd("ip -4 addr show | grep -oP '(?<=inet )\\d+\\.\\d+\\.\\d+\\.\\d+' | grep -v 127 | head -1")),
            ("tor",         "TOR EXIT IP",   lambda: run_cmd("curl -s --max-time 4 https://check.torproject.org/api/ip | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['IP'])\" 2>/dev/null || echo 'offline'")),
            ("kernel",      "KERNEL",        lambda: run_cmd("uname -r")),
            ("uptime",      "UPTIME",        lambda: run_cmd("uptime -p | sed 's/up //'").replace("minutes","min").replace("hours","h").replace("hour","h")),
            ("mem",         "RAM LIVRE",     lambda: run_cmd("free -h | awk '/^Mem/ {print $7 \" / \" $2}'")),
            ("disk",        "DISCO /",       lambda: run_cmd("df -h / | awk 'NR==2 {print $4 \" livre de \" $2}'")),
            ("ghost",       "GHOST PROTOCOL",lambda: "● ATIVO" if service_active("ghost-protocol") else "● INATIVO"),
            ("ambiente",    "AMBIENTE",      _get_ambiente),
        ]

        positions = [(0,0),(1,0),(2,0),(3,0),(0,1),(1,1),(2,1),(3,1),(0,2)]
        for (key, label, fn), (col, row) in zip(items, positions):
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            card.get_style_context().add_class("card")
            lbl = Gtk.Label(label=label)
            lbl.get_style_context().add_class("card-title")
            lbl.set_halign(Gtk.Align.START)
            val = Gtk.Label(label="—")
            val.get_style_context().add_class("card-value")
            val.set_halign(Gtk.Align.START)
            val.set_ellipsize(Pango.EllipsizeMode.END)
            card.pack_start(lbl, False, False, 0)
            card.pack_start(val, False, False, 0)
            grid.attach(card, col, row, 1, 1)
            self.cards[key] = (val, fn)

        self.pack_start(grid, False, False, 0)

        # Serviços
        svc_title = Gtk.Label(label="SERVIÇOS")
        svc_title.get_style_context().add_class("section-title")
        svc_title.set_halign(Gtk.Align.START)
        self.pack_start(svc_title, False, False, 12)

        svc_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.svc_labels = {}
        for svc in ["ghost-protocol", "tor", "NetworkManager", "apparmor", "dnscrypt-proxy"]:
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            box.get_style_context().add_class("card")
            name_lbl = Gtk.Label(label=svc)
            name_lbl.get_style_context().add_class("card-value")
            name_lbl.set_halign(Gtk.Align.START)
            status_lbl = Gtk.Label(label="checking...")
            status_lbl.get_style_context().add_class("status-unknown")
            status_lbl.set_halign(Gtk.Align.START)
            box.pack_start(name_lbl, False, False, 0)
            box.pack_start(status_lbl, False, False, 0)
            svc_box.pack_start(box, True, True, 0)
            self.svc_labels[svc] = status_lbl

        self.pack_start(svc_box, False, False, 0)

        # Botão refresh
        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        btn_row.set_margin_top(16)
        refresh_btn = Gtk.Button(label="↻  ATUALIZAR")
        refresh_btn.get_style_context().add_class("action-button")
        refresh_btn.connect("clicked", self.refresh)
        btn_row.pack_start(refresh_btn, False, False, 0)
        self.pack_start(btn_row, False, False, 0)

        GLib.timeout_add(500, self._initial_load)

    def _initial_load(self):
        self.refresh(None)
        return False

    def refresh(self, _btn):
        def worker():
            results = {}
            for key, (val, fn) in self.cards.items():
                try:
                    results[key] = fn()
                except Exception:
                    results[key] = "erro"
            svc_results = {}
            for svc in self.svc_labels:
                svc_results[svc] = service_active(svc)
            GLib.idle_add(self._apply_results, results, svc_results)
        threading.Thread(target=worker, daemon=True).start()

    def _apply_results(self, results, svc_results):
        for key, (val_lbl, _) in self.cards.items():
            text = results.get(key, "—") or "—"
            val_lbl.set_text(text[:40])
            ctx = val_lbl.get_style_context()
            if key == "ghost" or key == "tor":
                ctx.remove_class("status-on")
                ctx.remove_class("status-off")
                ctx.remove_class("card-value")
                if "ATIVO" in text or (key == "tor" and "." in text):
                    ctx.add_class("status-on")
                else:
                    ctx.add_class("status-off")

        for svc, active in svc_results.items():
            lbl = self.svc_labels[svc]
            lbl.get_style_context().remove_class("status-on")
            lbl.get_style_context().remove_class("status-off")
            lbl.get_style_context().remove_class("status-unknown")
            if active:
                lbl.set_text("● ativo")
                lbl.get_style_context().add_class("status-on")
            else:
                lbl.set_text("○ inativo")
                lbl.get_style_context().add_class("status-off")
        return False

# ─── Página: Ferramentas ──────────────────────────────────────────────────────
class ToolsPage(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_name("content")

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        categories = [
            ("RECONHECIMENTO", [
                ("aet-scan",     "Scanner de vulnerabilidades",  "sudo aet-scan -h"),
                ("nmap",         "Port scanner",                 "nmap -h"),
                ("rustscan",     "Scanner ultrarrápido",         "rustscan -h"),
                ("dnsrecon",     "Reconhecimento DNS",           "dnsrecon -h"),
                ("fierce",       "DNS brute force",              "fierce -h"),
                ("netdiscover",  "Descoberta de rede ARP",       "sudo netdiscover"),
            ]),
            ("EXPLORAÇÃO", [
                ("sqlmap",       "SQL injection",                "sqlmap -h"),
                ("hydra",        "Força bruta de credenciais",   "hydra -h"),
                ("hashcat",      "Quebra de hashes GPU",         "hashcat -h"),
                ("john",         "John the Ripper",              "john --help"),
                ("exploit-search","Busca ExploitDB",             "exploit-search -h"),
            ]),
            ("WEB", [
                ("gobuster",     "Dir/DNS bruteforce",           "gobuster -h"),
                ("ffuf",         "Fuzzer web",                   "ffuf -h"),
                ("nikto",        "Scanner de vulnerabilidades web","nikto -h"),
                ("mitmproxy",    "Proxy MITM",                   "mitmproxy"),
                ("sqlmap",       "SQLi automatizado",            "sqlmap --wizard"),
            ]),
            ("REDE / WIRELESS", [
                ("net-attack",   "Ataques de rede",              "sudo net-attack"),
                ("wireless-attack","Ataques wireless",           "sudo wireless-attack"),
                ("aircrack-ng",  "Quebra WPA/WEP",              "aircrack-ng --help"),
                ("wireshark",    "Captura de pacotes",           "wireshark &"),
                ("tcpdump",      "Dump de pacotes CLI",          "sudo tcpdump -i any -n"),
            ]),
            ("PÓS-EXPLORAÇÃO", [
                ("post-exploit", "Módulos pós-exploração",       "post-exploit"),
                ("privesc",      "Escalada de privilégios",      "sudo privesc"),
                ("payload-gen",  "Gerador de payloads",          "payload-gen"),
                ("shell-gen",    "Gerador de shells",            "shell-gen"),
                ("tunnel-setup", "Configuração de túneis",       "tunnel-setup"),
            ]),
            ("FORENSE / ANÁLISE", [
                ("foremost",     "Recuperação de arquivos",      "foremost -h"),
                ("binwalk",      "Análise de firmware",          "binwalk -h"),
                ("strings",      "Extrair strings de binários",  "strings --help"),
                ("exiftool",     "Metadados de arquivos",        "exiftool -h"),
                ("sleuthkit",    "Análise de disco (TSK)",       "mmls"),
            ]),
            ("SISTEMA", [
                ("aet-nuke",     "Destruição segura de dados",   "sudo aet-nuke -h"),
                ("amnesia",      "Limpar RAM/tmp ao desligar",   "amnesia --help"),
                ("ad-attack",    "Ataques a Active Directory",   "ad-attack"),
                ("web-enum",     "Enumeração web completa",      "web-enum"),
            ]),
        ]

        for cat_name, tools in categories:
            cat_label = Gtk.Label(label=cat_name)
            cat_label.get_style_context().add_class("section-title")
            cat_label.set_halign(Gtk.Align.START)
            inner.pack_start(cat_label, False, False, 8)

            flow = Gtk.FlowBox()
            flow.set_max_children_per_line(4)
            flow.set_min_children_per_line(2)
            flow.set_selection_mode(Gtk.SelectionMode.NONE)
            flow.set_column_spacing(6)
            flow.set_row_spacing(6)

            for cmd_name, desc, cmd in tools:
                box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                box.get_style_context().add_class("card")
                box.set_size_request(160, -1)

                name_lbl = Gtk.Label(label=cmd_name)
                name_lbl.get_style_context().add_class("card-title")
                name_lbl.set_halign(Gtk.Align.START)
                desc_lbl = Gtk.Label(label=desc)
                desc_lbl.get_style_context().add_class("card-value")
                desc_lbl.set_halign(Gtk.Align.START)
                desc_lbl.set_line_wrap(True)
                desc_lbl.set_max_width_chars(22)

                btn = Gtk.Button(label="▶  EXECUTAR")
                btn.get_style_context().add_class("tool-button")
                btn.connect("clicked", lambda w, c=cmd: run_terminal(c))

                box.pack_start(name_lbl, False, False, 0)
                box.pack_start(desc_lbl, False, False, 0)
                box.pack_start(btn, False, False, 6)
                flow.add(box)

            inner.pack_start(flow, False, False, 0)

        scroll.add(inner)
        scroll.set_margin_start(0)
        scroll.set_margin_end(0)
        self.pack_start(scroll, True, True, 0)

# ─── Página: Ghost Protocol ───────────────────────────────────────────────────
class GhostPage(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.set_name("content")

        title = Gtk.Label(label="GHOST PROTOCOL")
        title.get_style_context().add_class("section-title")
        title.set_halign(Gtk.Align.START)
        self.pack_start(title, False, False, 0)

        # Status card
        status_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        status_card.get_style_context().add_class("card")

        status_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.status_lbl = Gtk.Label(label="● VERIFICANDO...")
        self.status_lbl.get_style_context().add_class("status-unknown")
        self.status_lbl.set_halign(Gtk.Align.START)
        status_row.pack_start(self.status_lbl, True, True, 0)

        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        start_btn = Gtk.Button(label="▶  INICIAR")
        start_btn.get_style_context().add_class("action-button")
        start_btn.connect("clicked", lambda w: self._svc_action("start"))
        stop_btn = Gtk.Button(label="■  PARAR")
        stop_btn.get_style_context().add_class("danger-button")
        stop_btn.connect("clicked", lambda w: self._svc_action("stop"))
        restart_btn = Gtk.Button(label="↺  REINICIAR")
        restart_btn.get_style_context().add_class("action-button")
        restart_btn.connect("clicked", lambda w: self._svc_action("restart"))
        btn_row.pack_start(start_btn, False, False, 0)
        btn_row.pack_start(stop_btn, False, False, 0)
        btn_row.pack_start(restart_btn, False, False, 0)

        status_card.pack_start(status_row, False, False, 0)
        status_card.pack_start(btn_row, False, False, 0)
        self.pack_start(status_card, False, False, 0)

        # IP info
        ip_title = Gtk.Label(label="ANONIMATO")
        ip_title.get_style_context().add_class("section-title")
        ip_title.set_halign(Gtk.Align.START)
        self.pack_start(ip_title, False, False, 4)

        ip_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        ip_card.get_style_context().add_class("card")
        self.real_ip_lbl  = Gtk.Label(label="IP Real:    —")
        self.tor_ip_lbl   = Gtk.Label(label="IP Tor:     —")
        self.tor_ok_lbl   = Gtk.Label(label="Tor Check:  —")
        for lbl in [self.real_ip_lbl, self.tor_ip_lbl, self.tor_ok_lbl]:
            lbl.get_style_context().add_class("card-value")
            lbl.set_halign(Gtk.Align.START)
            ip_card.pack_start(lbl, False, False, 0)

        check_btn = Gtk.Button(label="↻  VERIFICAR IP / TOR")
        check_btn.get_style_context().add_class("action-button")
        check_btn.connect("clicked", self._check_ip)
        ip_card.pack_start(check_btn, False, False, 8)
        self.pack_start(ip_card, False, False, 0)

        # Log do serviço
        log_title = Gtk.Label(label="LOG DO SERVIÇO")
        log_title.get_style_context().add_class("section-title")
        log_title.set_halign(Gtk.Align.START)
        self.pack_start(log_title, False, False, 4)

        log_scroll = Gtk.ScrolledWindow()
        log_scroll.set_min_content_height(160)
        self.log_buf = Gtk.TextBuffer()
        log_view = Gtk.TextView(buffer=self.log_buf)
        log_view.get_style_context().add_class("log-view")
        log_view.set_editable(False)
        log_view.set_cursor_visible(False)
        log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        log_scroll.add(log_view)
        self.pack_start(log_scroll, True, True, 0)

        refresh_log_btn = Gtk.Button(label="↻  ATUALIZAR LOG")
        refresh_log_btn.get_style_context().add_class("action-button")
        refresh_log_btn.connect("clicked", self._refresh_log)
        self.pack_start(refresh_log_btn, False, False, 0)

        GLib.timeout_add(600, self._initial_load)

    def _initial_load(self):
        self._refresh_status()
        return False

    def _svc_action(self, action):
        def worker():
            run_cmd(f"sudo systemctl {action} ghost-protocol.service")
            import time; time.sleep(1)
            GLib.idle_add(self._refresh_status)
        threading.Thread(target=worker, daemon=True).start()

    def _refresh_status(self):
        def worker():
            active = service_active("ghost-protocol")
            GLib.idle_add(self._apply_status, active)
        threading.Thread(target=worker, daemon=True).start()

    def _apply_status(self, active):
        self.status_lbl.get_style_context().remove_class("status-on")
        self.status_lbl.get_style_context().remove_class("status-off")
        self.status_lbl.get_style_context().remove_class("status-unknown")
        if active:
            self.status_lbl.set_text("● GHOST PROTOCOL ATIVO — VPN+TOR KILL SWITCH ON")
            self.status_lbl.get_style_context().add_class("status-on")
        else:
            self.status_lbl.set_text("○ GHOST PROTOCOL INATIVO")
            self.status_lbl.get_style_context().add_class("status-off")
        return False

    def _check_ip(self, _btn):
        def worker():
            real = run_cmd("curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'erro'")
            tor  = run_cmd("curl -s --max-time 5 --socks5 127.0.0.1:9050 https://api.ipify.org 2>/dev/null || echo 'erro'")
            check = run_cmd("curl -s --max-time 5 https://check.torproject.org/api/ip 2>/dev/null | python3 -c \"import sys,json;d=json.load(sys.stdin);print('SIM' if d['IsTor'] else 'NÃO')\" 2>/dev/null || echo 'erro'")
            GLib.idle_add(self._apply_ip, real, tor, check)
        threading.Thread(target=worker, daemon=True).start()

    def _apply_ip(self, real, tor, check):
        self.real_ip_lbl.set_text(f"IP Real:    {real}")
        self.tor_ip_lbl.set_text(f"IP Tor:     {tor}")
        self.tor_ok_lbl.set_text(f"Tor Check:  {check}")
        return False

    def _refresh_log(self, _btn=None):
        def worker():
            log = run_cmd("journalctl -u ghost-protocol.service -n 30 --no-pager 2>/dev/null")
            GLib.idle_add(self._apply_log, log)
        threading.Thread(target=worker, daemon=True).start()

    def _apply_log(self, log):
        self.log_buf.set_text(log or "(sem logs)")
        return False

# ─── Página: Rede ─────────────────────────────────────────────────────────────
class NetworkPage(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.set_name("content")

        title = Gtk.Label(label="REDE")
        title.get_style_context().add_class("section-title")
        title.set_halign(Gtk.Align.START)
        self.pack_start(title, False, False, 0)

        # Interfaces
        iface_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        iface_card.get_style_context().add_class("card")
        iface_title = Gtk.Label(label="INTERFACES")
        iface_title.get_style_context().add_class("card-title")
        iface_title.set_halign(Gtk.Align.START)
        iface_card.pack_start(iface_title, False, False, 0)
        self.iface_lbl = Gtk.Label(label="carregando...")
        self.iface_lbl.get_style_context().add_class("card-value")
        self.iface_lbl.set_halign(Gtk.Align.START)
        self.iface_lbl.set_selectable(True)
        iface_card.pack_start(self.iface_lbl, False, False, 0)
        self.pack_start(iface_card, False, False, 0)

        # Rotas
        route_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        route_card.get_style_context().add_class("card")
        route_title = Gtk.Label(label="ROTA PADRÃO")
        route_title.get_style_context().add_class("card-title")
        route_title.set_halign(Gtk.Align.START)
        route_card.pack_start(route_title, False, False, 0)
        self.route_lbl = Gtk.Label(label="—")
        self.route_lbl.get_style_context().add_class("card-value")
        self.route_lbl.set_halign(Gtk.Align.START)
        self.route_lbl.set_selectable(True)
        route_card.pack_start(self.route_lbl, False, False, 0)
        self.pack_start(route_card, False, False, 0)

        # Ações de rede
        action_title = Gtk.Label(label="AÇÕES")
        action_title.get_style_context().add_class("section-title")
        action_title.set_halign(Gtk.Align.START)
        self.pack_start(action_title, False, False, 4)

        actions_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        actions = [
            ("TROCAR MAC",     "sudo macchanger -r $(ip -o link | awk 'NR==2{print $2}' | tr -d :)"),
            ("MONITOR MODE",   "sudo airmon-ng start wlan0"),
            ("SCAN WIFI",      "sudo iwlist wlan0 scan | grep ESSID"),
            ("FIREWALL STATUS","sudo nft list ruleset"),
            ("NETSTAT",        "ss -tulnp"),
            ("NET ATTACK",     "sudo net-attack"),
        ]
        for label, cmd in actions:
            btn = Gtk.Button(label=label)
            btn.get_style_context().add_class("action-button")
            btn.connect("clicked", lambda w, c=cmd: run_terminal(c))
            actions_box.pack_start(btn, False, False, 0)
        self.pack_start(actions_box, False, False, 0)

        # Scan de rede
        scan_title = Gtk.Label(label="SCAN RÁPIDO")
        scan_title.get_style_context().add_class("section-title")
        scan_title.set_halign(Gtk.Align.START)
        self.pack_start(scan_title, False, False, 4)

        scan_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        scan_card.get_style_context().add_class("card")

        target_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        target_lbl = Gtk.Label(label="Alvo:")
        target_lbl.get_style_context().add_class("card-value")
        self.target_entry = Gtk.Entry()
        self.target_entry.set_placeholder_text("192.168.1.0/24 ou IP")
        self.target_entry.set_width_chars(24)
        target_row.pack_start(target_lbl, False, False, 0)
        target_row.pack_start(self.target_entry, True, True, 0)

        scan_types = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        for lbl, flag in [("PING SWEEP", "-sn"), ("TOP PORTS", "-F"), ("COMPLETO", "-sV -O"), ("VULN", "--script vuln")]:
            btn = Gtk.Button(label=lbl)
            btn.get_style_context().add_class("tool-button")
            btn.connect("clicked", lambda w, f=flag: self._run_nmap(f))
            scan_types.pack_start(btn, False, False, 0)

        scan_card.pack_start(target_row, False, False, 0)
        scan_card.pack_start(scan_types, False, False, 0)
        self.pack_start(scan_card, False, False, 0)

        refresh_btn = Gtk.Button(label="↻  ATUALIZAR INTERFACES")
        refresh_btn.get_style_context().add_class("action-button")
        refresh_btn.connect("clicked", self._refresh)
        self.pack_start(refresh_btn, False, False, 0)

        GLib.timeout_add(600, self._initial_load)

    def _initial_load(self):
        self._refresh(None)
        return False

    def _refresh(self, _btn):
        def worker():
            ifaces = run_cmd("ip -br addr show")
            route  = run_cmd("ip route | grep default | head -3")
            GLib.idle_add(self._apply, ifaces, route)
        threading.Thread(target=worker, daemon=True).start()

    def _apply(self, ifaces, route):
        self.iface_lbl.set_text(ifaces or "—")
        self.route_lbl.set_text(route or "—")
        return False

    def _run_nmap(self, flag):
        target = self.target_entry.get_text().strip() or "127.0.0.1"
        run_terminal(f"sudo nmap {flag} {target}")

# ─── Página: Sistema ──────────────────────────────────────────────────────────
class SystemPage(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.set_name("content")

        title = Gtk.Label(label="SISTEMA")
        title.get_style_context().add_class("section-title")
        title.set_halign(Gtk.Align.START)
        self.pack_start(title, False, False, 0)

        # Hardening status
        hard_title = Gtk.Label(label="HARDENING DO KERNEL")
        hard_title.get_style_context().add_class("section-title")
        hard_title.set_halign(Gtk.Align.START)
        self.pack_start(hard_title, False, False, 4)

        hard_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        hard_card.get_style_context().add_class("card")
        self.hard_labels = {}
        checks = [
            ("ASLR",        "cat /proc/sys/kernel/randomize_va_space",    lambda v: v == "2"),
            ("PTI",         "cat /sys/kernel/debug/x86/pti_enabled 2>/dev/null || grep -o 'pti' /proc/cpuinfo | head -1", lambda v: bool(v)),
            ("AppArmor",    "cat /sys/module/apparmor/parameters/enabled 2>/dev/null", lambda v: v == "Y"),
            ("Seccomp",     "cat /proc/1/status | grep Seccomp | awk '{print $2}'",    lambda v: v in ("1","2")),
            ("Ptrace Scope","cat /proc/sys/kernel/yama/ptrace_scope",                  lambda v: v in ("1","2","3")),
            ("SMEP/SMAP",   "grep -o 'smep\\|smap' /proc/cpuinfo | sort -u | tr '\\n' ' '", lambda v: bool(v)),
        ]
        for name, cmd, ok_fn in checks:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            name_lbl = Gtk.Label(label=name)
            name_lbl.get_style_context().add_class("card-value")
            name_lbl.set_halign(Gtk.Align.START)
            name_lbl.set_width_chars(16)
            val_lbl = Gtk.Label(label="—")
            val_lbl.set_halign(Gtk.Align.START)
            row.pack_start(name_lbl, False, False, 0)
            row.pack_start(val_lbl, False, False, 0)
            hard_card.pack_start(row, False, False, 0)
            self.hard_labels[name] = (val_lbl, cmd, ok_fn)
        self.pack_start(hard_card, False, False, 0)

        # Ações do sistema
        act_title = Gtk.Label(label="AÇÕES DO SISTEMA")
        act_title.get_style_context().add_class("section-title")
        act_title.set_halign(Gtk.Align.START)
        self.pack_start(act_title, False, False, 4)

        act_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        normal_actions = [
            ("PACMAN UPDATE", "sudo pacman -Syu"),
            ("LYNIS AUDIT",   "sudo lynis audit system"),
            ("RKHUNTER",      "sudo rkhunter --check"),
        ]
        for lbl, cmd in normal_actions:
            btn = Gtk.Button(label=lbl)
            btn.get_style_context().add_class("action-button")
            btn.connect("clicked", lambda w, c=cmd: run_terminal(c))
            act_box.pack_start(btn, False, False, 0)
        self.pack_start(act_box, False, False, 0)

        # Zona de perigo
        danger_title = Gtk.Label(label="ZONA DE PERIGO")
        danger_title.get_style_context().add_class("section-title")
        danger_title.set_halign(Gtk.Align.START)
        self.pack_start(danger_title, False, False, 4)

        danger_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        danger_card.get_style_context().add_class("card")

        danger_desc = Gtk.Label(label="Estas ações são irreversíveis. Use com cuidado.")
        danger_desc.get_style_context().add_class("status-off")
        danger_desc.set_halign(Gtk.Align.START)
        danger_card.pack_start(danger_desc, False, False, 0)

        danger_btns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        nuke_btn = Gtk.Button(label="☠  AET-NUKE")
        nuke_btn.get_style_context().add_class("danger-button")
        nuke_btn.connect("clicked", self._confirm_nuke)

        amnesia_btn = Gtk.Button(label="⚡  AMNESIA (DESLIGAR SEGURO)")
        amnesia_btn.get_style_context().add_class("danger-button")
        amnesia_btn.connect("clicked", self._confirm_amnesia)

        danger_btns.pack_start(nuke_btn, False, False, 0)
        danger_btns.pack_start(amnesia_btn, False, False, 0)
        danger_card.pack_start(danger_btns, False, False, 0)
        self.pack_start(danger_card, False, False, 0)

        refresh_btn = Gtk.Button(label="↻  VERIFICAR HARDENING")
        refresh_btn.get_style_context().add_class("action-button")
        refresh_btn.connect("clicked", self._refresh_hardening)
        self.pack_start(refresh_btn, False, False, 0)

        GLib.timeout_add(600, self._initial_load)

    def _initial_load(self):
        self._refresh_hardening(None)
        return False

    def _refresh_hardening(self, _btn):
        def worker():
            results = {}
            for name, (_, cmd, ok_fn) in self.hard_labels.items():
                val = run_cmd(cmd)
                results[name] = (val, ok_fn(val))
            GLib.idle_add(self._apply_hardening, results)
        threading.Thread(target=worker, daemon=True).start()

    def _apply_hardening(self, results):
        for name, (val_lbl, _, _) in self.hard_labels.items():
            val, ok = results.get(name, ("—", False))
            val_lbl.set_text(val or "—")
            val_lbl.get_style_context().remove_class("status-on")
            val_lbl.get_style_context().remove_class("status-off")
            val_lbl.get_style_context().remove_class("card-value")
            val_lbl.get_style_context().add_class("status-on" if ok else "status-off")
        return False

    def _confirm_nuke(self, _btn):
        dialog = Gtk.MessageDialog(
            transient_for=self.get_toplevel(),
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text="CONFIRMAR AET-NUKE",
        )
        dialog.format_secondary_text("Isso irá destruir dados sensíveis de forma segura. Continuar?")
        resp = dialog.run()
        dialog.destroy()
        if resp == Gtk.ResponseType.YES:
            run_terminal("sudo aet-nuke --confirm")

    def _confirm_amnesia(self, _btn):
        dialog = Gtk.MessageDialog(
            transient_for=self.get_toplevel(),
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text="CONFIRMAR AMNESIA",
        )
        dialog.format_secondary_text("Isso irá limpar RAM/tmp e desligar o sistema. Continuar?")
        resp = dialog.run()
        dialog.destroy()
        if resp == Gtk.ResponseType.YES:
            run_terminal("sudo amnesia --confirm && systemctl poweroff")

# ─── Janela Principal ─────────────────────────────────────────────────────────
class VortexCenter(Gtk.Window):
    def __init__(self):
        super().__init__(title="V0rtexOS Control Center")
        self.set_default_size(1100, 720)
        self.set_position(Gtk.WindowPosition.CENTER)

        # CSS
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        # ── Header ──
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        header.set_name("header")
        header.set_margin_start(20)
        header.set_margin_end(20)

        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title_lbl = Gtk.Label(label="V0RTEX OS")
        title_lbl.set_name("header-title")
        title_lbl.set_halign(Gtk.Align.START)
        subtitle_lbl = Gtk.Label(label="GREY HAT SECURITY DISTRIBUTION — CONTROL CENTER")
        subtitle_lbl.set_name("header-subtitle")
        subtitle_lbl.set_halign(Gtk.Align.START)
        left.pack_start(title_lbl, False, False, 0)
        left.pack_start(subtitle_lbl, False, False, 0)
        header.pack_start(left, True, True, 0)

        self.clock_lbl = Gtk.Label(label="")
        self.clock_lbl.get_style_context().add_class("card-value")
        header.pack_start(self.clock_lbl, False, False, 0)

        root.pack_start(header, False, False, 0)

        sep = Gtk.Separator()
        root.pack_start(sep, False, False, 0)

        # ── Body (sidebar + content) ──
        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)

        # Sidebar
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar.set_name("sidebar")

        pages = {
            "  ◈  DASHBOARD":    DashboardPage,
            "  ⚙  FERRAMENTAS":  ToolsPage,
            "  ◉  GHOST PROTOCOL": GhostPage,
            "  ◈  REDE":         NetworkPage,
            "  ⚠  SISTEMA":      SystemPage,
        }

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.NONE)

        self.page_instances = {}
        self.sidebar_btns = []
        first = True

        for label, PageClass in pages.items():
            page = PageClass()
            page.set_margin_start(24)
            page.set_margin_end(24)
            page.set_margin_top(20)
            page.set_margin_bottom(20)
            self.stack.add_named(page, label)
            self.page_instances[label] = page

            btn = Gtk.Button(label=label)
            btn.set_relief(Gtk.ReliefStyle.NONE)
            btn.set_halign(Gtk.Align.FILL)
            if first:
                btn.get_style_context().add_class("active")
                first = False
            btn.connect("clicked", self._switch_page, label)
            sidebar.pack_start(btn, False, False, 0)
            self.sidebar_btns.append((label, btn))

        body.pack_start(sidebar, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.add(self.stack)
        body.pack_start(scroll, True, True, 0)

        root.pack_start(body, True, True, 0)

        self.add(root)
        self.connect("destroy", Gtk.main_quit)

        GLib.timeout_add_seconds(1, self._update_clock)
        self._update_clock()

        first_key = list(pages.keys())[0]
        self.stack.set_visible_child_name(first_key)

    def _switch_page(self, btn, label):
        self.stack.set_visible_child_name(label)
        for lbl, b in self.sidebar_btns:
            ctx = b.get_style_context()
            if lbl == label:
                ctx.add_class("active")
            else:
                ctx.remove_class("active")

    def _update_clock(self):
        now = datetime.datetime.now().strftime("%Y-%m-%d  %H:%M:%S")
        self.clock_lbl.set_text(now)
        return True

# ─── Entry point ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    app = VortexCenter()
    app.show_all()
    Gtk.main()
