# V0rtexOS — Guia de Build e Instalação

> Grey Hat Linux — linux-hardened · Ghost Protocol · BlackArch · i3wm

---

## Requisitos para Build

| Item | Mínimo |
|------|--------|
| Host | Arch Linux (live ou instalado) |
| CPU | x86_64, 4+ cores recomendado |
| RAM | 4GB+ (8GB para build rápido) |
| Disco | 30GB livres em `/tmp` |
| Rede | Necessária para baixar pacotes |

### Dependências do host

```bash
pacman -Sy --needed archiso git curl python3 unzip openssl
```

---

## Build

```bash
sudo bash build.sh
# ISO → ./release/v0rtex-os-YYYY.MM.DD-x86_64.iso
```

---

## Gravar em USB

```bash
sudo dd if=release/v0rtex-os-*.iso of=/dev/sdX bs=4M status=progress && sync
```

---

## Primeiros Passos

```bash
sudo install-tools all      # instala 100+ ferramentas via curl
check-anon                  # verifica anonimização Tor
sudo aet-scan -p vuln <IP>  # scan de vulnerabilidades
payload-gen <LHOST> <LPORT> # gera payloads msfvenom
shell-gen <LHOST> <LPORT>   # cheatsheet de shells reversos
sudo aet-nuke monitor       # active defense / auto-ban
safe-off                    # amnésia + desligar
```

---

## Estrutura Completa

```
aeternus-os/
├── build.sh                          # Script principal — gera a ISO
├── amnesia.sh                        # Script de limpeza de memória/logs
├── INSTALL.md                        # Este arquivo
│
├── ghost-protocol/
│   ├── ghost-protocol.sh             # Script de rede (VPN+Tor kill switch)
│   ├── ghost-protocol.service        # Systemd unit — ativa no boot
│   └── amnesia-shutdown.service      # Systemd unit — roda amnésia no shutdown
│
├── kernel/
│   ├── hardened.conf                 # → /etc/modprobe.d/v0rtex-blacklist.conf
│   ├── hardened-sysctl.conf          # → /etc/sysctl.d/99-v0rtex.conf
│   └── mkinitcpio-hardened.conf      # → /etc/mkinitcpio.conf
│
├── config/
│   ├── i3/
│   │   ├── config                    # → ~/.config/i3/config
│   │   ├── i3status.conf             # → ~/.config/i3/i3status.conf
│   │   └── picom.conf                # → ~/.config/picom/picom.conf
│   ├── alacritty/
│   │   └── alacritty.toml            # → ~/.config/alacritty/alacritty.toml
│   └── zsh/
│       └── .zshrc                    # → ~/.zshrc
│
└── justice/
    ├── aet-scan.py                   # → /usr/local/bin/aet-scan
    └── aet-nuke.py                   # → /usr/local/bin/aet-nuke
```

---

## Opção A — Build da ISO Completa (Arch Linux host)

```bash
# 1. Instalar dependências no host Arch Linux
sudo pacman -S archiso git curl

# 2. Clonar / copiar este repositório
git clone <repo> aeternus-os
cd aeternus-os

# 3. Executar o build (requer root)
sudo bash build.sh

# A ISO será gerada em ./release/v0rtex-os-YYYY.MM.DD-x86_64.iso
# Gravar em USB:
sudo dd if=release/v0rtex-os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## Opção B — Instalação Manual em Arch Linux Existente

### 1. Kernel Hardened

```bash
sudo pacman -S linux-hardened linux-hardened-headers

# Atualizar GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Copiar configurações de kernel
sudo cp kernel/hardened.conf /etc/modprobe.d/v0rtex-blacklist.conf
sudo cp kernel/hardened-sysctl.conf /etc/sysctl.d/99-v0rtex.conf
sudo cp kernel/mkinitcpio-hardened.conf /etc/mkinitcpio.conf

# Regenerar initramfs para o kernel hardened
sudo mkinitcpio -p linux-hardened

# Aplicar sysctl imediatamente
sudo sysctl --system
```

### 2. Ghost Protocol (VPN+Tor Kill Switch)

```bash
# Instalar dependências
sudo pacman -S tor iptables openvpn

# Copiar scripts
sudo cp ghost-protocol/ghost-protocol.sh /usr/local/bin/ghost-protocol.sh
sudo chmod 755 /usr/local/bin/ghost-protocol.sh

# Configurar o Tor para TransPort e DNSPort
sudo tee -a /etc/tor/torrc <<EOF
TransPort 9040
DNSPort 5353
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
EOF

# Instalar e habilitar o serviço
sudo cp ghost-protocol/ghost-protocol.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ghost-protocol.service
sudo systemctl start ghost-protocol.service

# Verificar status
sudo /usr/local/bin/ghost-protocol.sh status
```

### 3. Serviço de Amnésia no Shutdown

```bash
# Instalar secure-delete (fornece sdmem)
sudo pacman -S secure-delete

# Instalar script
sudo cp amnesia.sh /usr/local/bin/amnesia
sudo chmod 755 /usr/local/bin/amnesia

# Instalar serviço de shutdown
sudo cp ghost-protocol/amnesia-shutdown.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable amnesia-shutdown.service
```

### 4. Interface i3wm + Alacritty

```bash
# Instalar pacotes
sudo pacman -S i3-wm i3status i3lock alacritty picom dmenu feh dunst \
    xorg-server xorg-xinit xorg-xrandr

# Instalar fontes (Michroma e Zekton via AUR ou manual)
sudo pacman -S ttf-jetbrains-mono-nerd
# Michroma: https://fonts.google.com/specimen/Michroma
# Zekton:   instalar via AUR (ttf-zekton) ou manual

# Copiar configurações
mkdir -p ~/.config/{i3,alacritty,picom}
cp config/i3/config ~/.config/i3/config
cp config/i3/i3status.conf ~/.config/i3/i3status.conf
cp config/i3/picom.conf ~/.config/picom/picom.conf
cp config/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml

# Copiar .zshrc
cp config/zsh/.zshrc ~/.zshrc
chsh -s /bin/zsh

# Iniciar i3 (adicionar ao .xinitrc)
echo "exec i3" >> ~/.xinitrc
```

### 5. Binários de Justiça

```bash
# Instalar dependências Python
sudo pacman -S python nmap

# Instalar aet-scan
sudo cp justice/aet-scan.py /usr/local/bin/aet-scan
sudo chmod 755 /usr/local/bin/aet-scan

# Instalar aet-nuke
sudo cp justice/aet-nuke.py /usr/local/bin/aet-nuke
sudo chmod 755 /usr/local/bin/aet-nuke

# Testar
sudo aet-scan --list-profiles
sudo aet-nuke --help
```

---

## Uso Rápido

### Ghost Protocol
```bash
# Verificar se está ativo
systemctl status ghost-protocol.service

# Ver regras de firewall
sudo /usr/local/bin/ghost-protocol.sh status

# Parar (restaura rede normal)
sudo systemctl stop ghost-protocol.service
```

### aet-scan
```bash
# Scan rápido de rede local
sudo aet-scan 192.168.1.0/24

# Detecção de vulnerabilidades num alvo
sudo aet-scan -p vuln -s critical,smb,http,ssl 10.10.10.5

# Scan stealth em portas específicas
sudo aet-scan -p stealth -P 22,80,443,3389 alvo.exemplo.com

# Scan completo com decoys (evasão)
sudo aet-scan -p full --extra "-D RND:10 --data-length 25" 192.168.1.1
```

### aet-nuke (Defesa Ativa)
```bash
# Iniciar monitor de defesa ativa
sudo aet-nuke monitor

# Listar IPs banidos
sudo aet-nuke list-bans

# Desbanir um IP
sudo aet-nuke unban 192.168.1.100

# Verificar portas expostas no host
sudo aet-nuke scan-self
```

### Amnésia
```bash
# Limpeza completa (RAM + logs + histórico)
sudo amnesia --confirm

# Desligar com limpeza automática
poweroff-safe   # alias no .zshrc

# Ou via menu i3: Super+Shift+E → P
```

---

## Verificação de Segurança

```bash
# Verificar se IPv6 está desativado
cat /proc/sys/net/ipv6/conf/all/disable_ipv6  # deve retornar 1

# Verificar ASLR
cat /proc/sys/kernel/randomize_va_space  # deve retornar 2

# Verificar IP externo (deve ser da VPN/Tor)
curl -s https://api.ipify.org

# Verificar que não há vazamento DNS
nslookup whoami.akamai.net  # deve resolver via Tor

# Testar kill switch (desconectar VPN e tentar acessar internet)
sudo systemctl stop openvpn  # tráfego deve ser bloqueado
curl -s --max-time 5 https://api.ipify.org  # deve falhar
```
