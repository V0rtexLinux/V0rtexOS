#!/bin/sh
# V0rtexOS — xinitrc: inicia i3wm com todos os serviços gráficos

# Variáveis de ambiente
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=i3

# Cursor padrão
xsetroot -cursor_name left_ptr &

# Compositor (picom)
picom --config ~/.config/picom/picom.conf -b &

# Notificações (dunst)
dunst &

# Wallpaper (feh) — usa fallback preto se não existir imagem
if [ -f ~/.config/i3/wallpaper.png ]; then
    feh --bg-scale ~/.config/i3/wallpaper.png &
else
    xsetroot -solid "#000000"
fi

# NetworkManager systray
nm-applet &

# Iniciar i3
exec i3
