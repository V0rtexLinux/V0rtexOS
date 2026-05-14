/*
 * V0rtexOS — Desktop Taskbar (bottom panel)
 * Compile: gcc -O2 -o aeternus-taskbar aeternus-taskbar.c \
 *          $(pkg-config --libs --cflags x11 cairo xrender) -lm
 *
 * Layout (left → right):
 *   [V0RTEX ▾] | [TERM] [WWW] [FILES] [CTRL] [GHOST] | ... | [CPU%] [RAM] | [date] [clock]
 *
 * Colors: #000000 bg | #ffffff primary | #888888 secondary
 */

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>

/* ── Layout ────────────────────────────────────────────────────────────────── */
#define BAR_H        38
#define FONT_SZ      11.0
#define FONT_SZ_SM   9.5
#define LOGO_W       96.0
#define BTN_PAD_X    14.0
#define BTN_H        26.0
#define SEP_W        1.0

/* ── Colors ────────────────────────────────────────────────────────────────── */
#define C_BG         0.031, 0.031, 0.031
#define C_BG2        0.067, 0.067, 0.067
#define C_PRI        1.000, 1.000, 1.000
#define C_SEC        0.533, 0.533, 0.533
#define C_DIM        0.180, 0.180, 0.180
#define C_HOVER      0.110, 0.110, 0.110
#define C_LOGO       0.078, 0.078, 0.078
#define C_LOGO_HOV   0.133, 0.133, 0.133
#define C_ACTIVE     0.133, 0.133, 0.133

/* ── Button registry ──────────────────────────────────────────────────────── */
#define MAX_BTNS 24

typedef struct {
    double   x, w;
    char     label[40];
    char     cmd[256];
    int      hover;
    int      is_logo;
    int      is_sep;
    int      is_right;     /* right-aligned, no click */
    int      is_toggle;
    int      tog_active;   /* live toggle state */
} TBtn;

static TBtn   g_btns[MAX_BTNS];
static int    g_nbtns   = 0;
static int    g_hover   = -1;
static volatile int g_running = 1;

/* ── Utility: launch app (double-fork, no zombie) ─────────────────────────── */
static void launch(const char *cmd) {
    pid_t pid = fork();
    if (pid == 0) {
        if (fork() != 0) _exit(0);
        setsid();
        execl("/bin/sh", "sh", "-c", cmd, NULL);
        _exit(1);
    }
    if (pid > 0) waitpid(pid, NULL, 0);
}

/* ── Ghost protocol status ────────────────────────────────────────────────── */
static int ghost_active(void) {
    /* check if ghost-protocol is running via pidfile / systemd cgroup */
    struct stat st;
    /* systemd cgroup path when service is active */
    if (stat("/sys/fs/cgroup/system.slice/ghost-protocol.service", &st) == 0)
        return 1;
    /* fallback: check for lock file written by ghost-protocol.sh */
    if (stat("/run/ghost-protocol.pid", &st) == 0)
        return 1;
    return 0;
}

/* ── CPU usage ────────────────────────────────────────────────────────────── */
static long g_prev_idle = 0, g_prev_total = 0;
static float read_cpu(void) {
    FILE *f = fopen("/proc/stat", "r");
    if (!f) return 0.0f;
    long u, n, s, i, iow, irq, sirq;
    fscanf(f, "cpu %ld %ld %ld %ld %ld %ld %ld", &u, &n, &s, &i, &iow, &irq, &sirq);
    fclose(f);
    long total = u + n + s + i + iow + irq + sirq;
    long dt = total - g_prev_total;
    long di = i - g_prev_idle;
    float pct = dt > 0 ? (float)(dt - di) * 100.0f / (float)dt : 0.0f;
    g_prev_total = total;
    g_prev_idle  = i;
    return pct;
}

/* ── RAM usage ────────────────────────────────────────────────────────────── */
static void read_mem(long *used_mb, long *total_mb) {
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) { *used_mb = *total_mb = 0; return; }
    long total = 0, avail = 0;
    char key[32]; long val; char unit[8];
    while (fscanf(f, "%31s %ld %7s", key, &val, unit) == 3) {
        if (!strcmp(key, "MemTotal:"))     total = val;
        if (!strcmp(key, "MemAvailable:")) avail = val;
    }
    fclose(f);
    *total_mb = total / 1024;
    *used_mb  = (total - avail) / 1024;
}

/* ── Rounded rect ─────────────────────────────────────────────────────────── */
static void rrect(cairo_t *cr, double x, double y, double w, double h, double r) {
    if (w < 2*r) r = w/2;
    if (h < 2*r) r = h/2;
    cairo_new_sub_path(cr);
    cairo_arc(cr, x+w-r, y+r,   r, -M_PI/2,  0);
    cairo_arc(cr, x+w-r, y+h-r, r,  0,       M_PI/2);
    cairo_arc(cr, x+r,   y+h-r, r,  M_PI/2,  M_PI);
    cairo_arc(cr, x+r,   y+r,   r,  M_PI,    3*M_PI/2);
    cairo_close_path(cr);
}

/* ── Text width helper ────────────────────────────────────────────────────── */
static double tw(cairo_t *cr, const char *s) {
    cairo_text_extents_t te;
    cairo_text_extents(cr, s, &te);
    return te.x_advance;
}

/* ── Center text in box ───────────────────────────────────────────────────── */
static void draw_text_center(cairo_t *cr, const char *s,
                              double bx, double bw, double by, double bh) {
    cairo_text_extents_t te;
    cairo_text_extents(cr, s, &te);
    cairo_move_to(cr,
        bx + (bw - te.width) / 2.0 - te.x_bearing,
        by + (bh + te.height) / 2.0 - te.height - te.y_bearing);
    cairo_show_text(cr, s);
}

/* ── Draw one app button ──────────────────────────────────────────────────── */
static double draw_app_btn(cairo_t *cr, double x, double H,
                            const char *label, int hover,
                            int is_logo, int tog_active) {
    cairo_save(cr);

    cairo_select_font_face(cr, "Liberation Mono",
        CAIRO_FONT_SLANT_NORMAL,
        is_logo ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, is_logo ? FONT_SZ + 0.5 : FONT_SZ);

    double lw   = tw(cr, label);
    double pw   = lw + BTN_PAD_X * 2.0 + (is_logo ? 10.0 : 0.0);
    double ph   = BTN_H;
    double py   = (H - ph) / 2.0;

    if (is_logo) {
        /* Logo button: filled background */
        if (hover)
            cairo_set_source_rgba(cr, C_LOGO_HOV, 1.0);
        else
            cairo_set_source_rgba(cr, C_LOGO, 1.0);
        rrect(cr, x, py, pw, ph, 4.0);
        cairo_fill(cr);

        /* thin left accent */
        cairo_set_source_rgba(cr, C_PRI, 0.5);
        cairo_set_line_width(cr, 1.5);
        cairo_move_to(cr, x + 1, py + 4);
        cairo_line_to(cr, x + 1, py + ph - 4);
        cairo_stroke(cr);

        cairo_set_source_rgba(cr, C_PRI, hover ? 1.0 : 0.9);
    } else if (tog_active) {
        /* Active toggle: subtle white bg */
        cairo_set_source_rgba(cr, C_ACTIVE, 1.0);
        rrect(cr, x, py, pw, ph, 4.0);
        cairo_fill(cr);
        cairo_set_source_rgba(cr, C_PRI, 1.0);
    } else if (hover) {
        cairo_set_source_rgba(cr, C_HOVER, 1.0);
        rrect(cr, x, py, pw, ph, 4.0);
        cairo_fill(cr);
        cairo_set_source_rgba(cr, C_PRI, 0.95);
    } else {
        cairo_set_source_rgba(cr, C_SEC, 0.65);
    }

    draw_text_center(cr, label, x, pw, py, ph);
    cairo_restore(cr);
    return pw + 4.0;
}

/* ── Draw separator ───────────────────────────────────────────────────────── */
static double draw_sep(cairo_t *cr, double x, double H) {
    cairo_set_source_rgba(cr, C_DIM, 0.8);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x + 5, 7);
    cairo_line_to(cr, x + 5, H - 7);
    cairo_stroke(cr);
    return 12.0;
}

/* ── Main render ──────────────────────────────────────────────────────────── */
static void render(cairo_t *cr, int W, int H) {
    /* reset buttons */
    g_nbtns = 0;

    /* background */
    cairo_set_source_rgba(cr, C_BG, 1.0);
    cairo_paint(cr);

    /* top border */
    cairo_set_source_rgba(cr, C_DIM, 0.9);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, 0, 0.5);
    cairo_line_to(cr, W, 0.5);
    cairo_stroke(cr);

    /* ── Time / Status (measure right side first) ── */
    char clock_s[16], date_s[20];
    time_t now_t = time(NULL);
    struct tm *tm = localtime(&now_t);
    strftime(clock_s, sizeof(clock_s), "%H:%M:%S", tm);
    strftime(date_s,  sizeof(date_s),  "%a %d %b", tm);

    float  cpu = read_cpu();
    long   mem_used = 0, mem_total = 0;
    read_mem(&mem_used, &mem_total);
    char cpu_s[16], mem_s[24], ghost_s[16];
    snprintf(cpu_s,   sizeof(cpu_s),   "CPU %.0f%%", cpu);
    snprintf(mem_s,   sizeof(mem_s),   "%ldM/%ldM",  mem_used, mem_total);
    int ghost_on = ghost_active();
    snprintf(ghost_s, sizeof(ghost_s), ghost_on ? "⬢ GHOST" : "⬡ GHOST");

    /* measure right section width */
    cairo_save(cr);
    cairo_select_font_face(cr, "Liberation Mono",
        CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, FONT_SZ_SM);
    double w_cpu   = tw(cr, cpu_s)   + BTN_PAD_X;
    double w_mem   = tw(cr, mem_s)   + BTN_PAD_X;
    double w_date  = tw(cr, date_s)  + BTN_PAD_X;
    cairo_set_font_size(cr, FONT_SZ);
    double w_clock = tw(cr, clock_s) + BTN_PAD_X + 4;
    cairo_restore(cr);

    double right_x = W - w_clock - w_date - w_mem - w_cpu - 28.0;

    /* ── LEFT section ── */
    double x = 6.0;

    /* Logo button */
    {
        int hov = (g_hover == g_nbtns);
        double adv = draw_app_btn(cr, x, H, "V0RTEX", hov, 1, 0);
        g_btns[g_nbtns++] = (TBtn){
            .x=x, .w=adv-4, .hover=hov, .is_logo=1,
            .cmd="rofi -show drun -theme-str 'window {background-color: #000000;} element {background-color: #000000; text-color: #888888;} element selected {background-color: #111111; text-color: #ffffff;}'",
        };
        snprintf(g_btns[g_nbtns-1].label, 40, "V0RTEX");
        x += adv;
    }

    x += draw_sep(cr, x, H);

    /* Pinned apps */
    struct { const char *label; const char *cmd; } pinned[] = {
        { ">_ TERM",  "alacritty"                    },
        { "◎  WWW",   "firefox"                      },
        { "⬡  FILES", "thunar"                       },
        { "✦  CTRL",  "vortex-center"                },
    };
    for (int i = 0; i < (int)(sizeof(pinned)/sizeof(pinned[0])); i++) {
        int hov = (g_hover == g_nbtns);
        double adv = draw_app_btn(cr, x, H, pinned[i].label, hov, 0, 0);
        g_btns[g_nbtns++] = (TBtn){
            .x=x, .w=adv-4, .hover=hov,
        };
        snprintf(g_btns[g_nbtns-1].label, 40, "%s", pinned[i].label);
        snprintf(g_btns[g_nbtns-1].cmd,  256, "%s", pinned[i].cmd);
        x += adv;
    }

    x += draw_sep(cr, x, H);

    /* Ghost protocol toggle */
    {
        int hov = (g_hover == g_nbtns);
        double adv = draw_app_btn(cr, x, H, ghost_s, hov, 0, ghost_on);
        g_btns[g_nbtns++] = (TBtn){
            .x=x, .w=adv-4, .hover=hov, .is_toggle=1, .tog_active=ghost_on,
        };
        snprintf(g_btns[g_nbtns-1].label, 40, "%s", ghost_s);
        snprintf(g_btns[g_nbtns-1].cmd, 256,
            ghost_on
            ? "sudo systemctl stop ghost-protocol.service"
            : "sudo systemctl start ghost-protocol.service");
        x += adv;
    }

    /* ── Window separator (decorative) ── */
    {
        double mid  = (right_x + x) / 2.0;
        double dash = 3.0, gap = 5.0;
        cairo_save(cr);
        cairo_set_source_rgba(cr, C_DIM, 0.5);
        cairo_set_line_width(cr, 1.0);
        double cx = x + 20;
        while (cx + dash < right_x - 20) {
            cairo_move_to(cr, cx, H / 2.0);
            cairo_line_to(cr, cx + dash, H / 2.0);
            cairo_stroke(cr);
            cx += dash + gap;
        }
        (void)mid;
        cairo_restore(cr);
    }

    /* ── RIGHT section ── */
    {
        double rx = right_x;
        cairo_save(cr);

        rx += draw_sep(cr, rx, H);

        /* CPU */
        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, FONT_SZ_SM);
        cairo_set_source_rgba(cr, cpu > 80 ? 1.0 : 0.45,
                                  cpu > 80 ? 1.0 : 0.45,
                                  cpu > 80 ? 1.0 : 0.45,
                                  0.65);
        cairo_text_extents_t te;
        cairo_text_extents(cr, cpu_s, &te);
        cairo_move_to(cr, rx + 4,
            (H + te.height) / 2.0 - 1);
        cairo_show_text(cr, cpu_s);
        rx += w_cpu;

        /* MEM */
        cairo_set_source_rgba(cr, C_SEC, 0.6);
        cairo_text_extents(cr, mem_s, &te);
        cairo_move_to(cr, rx + 4, (H + te.height) / 2.0 - 1);
        cairo_show_text(cr, mem_s);
        rx += w_mem;

        rx += draw_sep(cr, rx, H);

        /* Date */
        cairo_set_source_rgba(cr, C_SEC, 0.55);
        cairo_text_extents(cr, date_s, &te);
        cairo_move_to(cr, rx + 4, (H + te.height) / 2.0 - 1);
        cairo_show_text(cr, date_s);
        rx += w_date;

        /* Clock */
        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, FONT_SZ);
        cairo_set_source_rgba(cr, C_PRI, 0.9);
        cairo_text_extents(cr, clock_s, &te);
        cairo_move_to(cr, rx + 6, (H + te.height) / 2.0 - 1);
        cairo_show_text(cr, clock_s);

        cairo_restore(cr);
    }
}

/* ── Hit test ─────────────────────────────────────────────────────────────── */
static int hit_btn(double mx) {
    for (int i = 0; i < g_nbtns; i++) {
        if (!g_btns[i].is_sep && !g_btns[i].is_right) {
            if (mx >= g_btns[i].x && mx <= g_btns[i].x + g_btns[i].w)
                return i;
        }
    }
    return -1;
}

/* ── Signals ──────────────────────────────────────────────────────────────── */
static void on_sig(int s) { (void)s; g_running = 0; }

/* ── main ─────────────────────────────────────────────────────────────────── */
int main(void) {
    signal(SIGTERM, on_sig);
    signal(SIGINT,  on_sig);
    signal(SIGCHLD, SIG_DFL); /* let double-fork children be reaped */

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "v0rtex-taskbar: cannot open display\n");
        return 1;
    }

    int scr   = DefaultScreen(dpy);
    Window root = RootWindow(dpy, scr);
    int W     = DisplayWidth(dpy, scr);
    int H_scr = DisplayHeight(dpy, scr);

    XSetWindowAttributes attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.override_redirect = True;
    attrs.background_pixel  = BlackPixel(dpy, scr);
    attrs.event_mask        = ExposureMask | ButtonPressMask
                            | PointerMotionMask | LeaveWindowMask;

    Window win = XCreateWindow(
        dpy, root,
        0, H_scr - BAR_H, W, BAR_H, 0,
        DefaultDepth(dpy, scr),
        InputOutput,
        DefaultVisual(dpy, scr),
        CWOverrideRedirect | CWBackPixel | CWEventMask,
        &attrs
    );

    /* EWMH: dock + always-on-bottom hint */
    Atom wm_type  = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE",      False);
    Atom wm_dock  = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
    Atom wm_state = XInternAtom(dpy, "_NET_WM_STATE",            False);
    Atom wm_below = XInternAtom(dpy, "_NET_WM_STATE_BELOW",      False);
    Atom wm_sticky= XInternAtom(dpy, "_NET_WM_STATE_STICKY",     False);

    XChangeProperty(dpy, win, wm_type, XA_ATOM, 32,
                    PropModeReplace, (unsigned char *)&wm_dock, 1);

    Atom states[2] = { wm_below, wm_sticky };
    XChangeProperty(dpy, win, wm_state, XA_ATOM, 32,
                    PropModeReplace, (unsigned char *)states, 2);

    /* Reserve bottom screen space (_NET_WM_STRUT_PARTIAL) */
    Atom strut_p = XInternAtom(dpy, "_NET_WM_STRUT_PARTIAL", False);
    long sv[12]  = { 0, 0, 0, BAR_H,   /* left right top bottom */
                     0, 0, 0, 0,         /* top_start/end left_start/end */
                     0, 0,               /* right_start/end */
                     0, W };             /* bottom_start/end */
    XChangeProperty(dpy, win, strut_p, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char *)sv, 12);

    Atom strut = XInternAtom(dpy, "_NET_WM_STRUT", False);
    long sv4[4] = { 0, 0, 0, BAR_H };
    XChangeProperty(dpy, win, strut, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char *)sv4, 4);

    /* WM_NAME */
    XStoreName(dpy, win, "V0rtexOS Taskbar");

    XMapWindow(dpy, win);
    XRaiseWindow(dpy, win);
    XFlush(dpy);

    /* Cairo surface */
    cairo_surface_t *surf = cairo_xlib_surface_create(
        dpy, win, DefaultVisual(dpy, scr), W, BAR_H);
    cairo_t *cr = cairo_create(surf);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);

    unsigned int tick = 0;

    while (g_running) {
        /* drain events */
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);

            if (ev.type == Expose) {
                /* will redraw below */
            } else if (ev.type == MotionNotify) {
                int new_hover = hit_btn((double)ev.xmotion.x);
                if (new_hover != g_hover) {
                    g_hover = new_hover;
                }
            } else if (ev.type == LeaveNotify) {
                g_hover = -1;
            } else if (ev.type == ButtonPress && ev.xbutton.button == 1) {
                int idx = hit_btn((double)ev.xbutton.x);
                if (idx >= 0 && g_btns[idx].cmd[0] != '\0') {
                    launch(g_btns[idx].cmd);
                }
            }
        }

        /* redraw every frame; full stats update every ~1s */
        render(cr, W, BAR_H);
        cairo_surface_flush(surf);
        XFlush(dpy);

        tick++;
        usleep(33333); /* ~30 fps */
    }

    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
