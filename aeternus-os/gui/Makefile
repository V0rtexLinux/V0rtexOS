# V0rtexOS — GUI Build System
# Targets: all, splash, panel, wallpaper, install, clean
#
# Dependencies (Arch packages):
#   cairo libx11 libxrender

PREFIX     ?= /usr/local
BINDIR     := $(PREFIX)/bin
SHAREDIR   := $(PREFIX)/share/v0rtex

CC         := gcc
CFLAGS     := -O2 -Wall -Wextra -std=c11 \
              $(shell pkg-config --cflags x11 cairo xrender 2>/dev/null)
LDFLAGS    := $(shell pkg-config --libs   x11 cairo xrender 2>/dev/null) -lm

SPLASH_SRC   := splash/aeternus-splash.c
PANEL_SRC    := panel/aeternus-panel.c
TASKBAR_SRC  := panel/aeternus-taskbar.c
WP_SRC       := wallpaper/gen-wallpaper.c

SPLASH_BIN   := splash/aeternus-splash
PANEL_BIN    := panel/aeternus-panel
TASKBAR_BIN  := panel/aeternus-taskbar
WP_BIN       := wallpaper/gen-wallpaper

WALLPAPER    := wallpaper/v0rtex-wallpaper.png

.PHONY: all splash panel taskbar wallpaper install clean

all: splash panel taskbar wallpaper

splash: $(SPLASH_BIN)

panel: $(PANEL_BIN)

wallpaper: $(WP_BIN) $(WALLPAPER)

$(SPLASH_BIN): $(SPLASH_SRC)
        $(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
        @echo "[OK] built $@"

$(PANEL_BIN): $(PANEL_SRC)
        $(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
        @echo "[OK] built $@"

taskbar: $(TASKBAR_BIN)

$(TASKBAR_BIN): $(TASKBAR_SRC)
        $(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
        @echo "[OK] built $@"

$(WP_BIN): $(WP_SRC)
        $(CC) $(CFLAGS) -o $@ $< \
            $(shell pkg-config --libs --cflags cairo 2>/dev/null) -lm
        @echo "[OK] built $@"

$(WALLPAPER): $(WP_BIN)
        $(WP_BIN) $(WALLPAPER)
        @echo "[OK] generated $(WALLPAPER)"

install: all
        install -Dm755 $(SPLASH_BIN)  $(BINDIR)/aeternus-splash
        install -Dm755 $(PANEL_BIN)   $(BINDIR)/aeternus-panel
        install -Dm755 $(TASKBAR_BIN) $(BINDIR)/aeternus-taskbar
        install -Dm644 $(WALLPAPER)   $(SHAREDIR)/wallpaper.png
        @echo "[OK] installed to $(BINDIR)"

clean:
        rm -f $(SPLASH_BIN) $(PANEL_BIN) $(TASKBAR_BIN) $(WP_BIN) $(WALLPAPER)
        @echo "[OK] cleaned"
