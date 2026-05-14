/*
 * AETERNUS OS — Desktop Panel (top bar)
 * Compile: gcc -O2 -o aeternus-panel aeternus-panel.c \
 *          $(pkg-config --libs --cflags x11 cairo xrender) -lm
 *
 * A lightweight X11 status bar in pure C + Cairo.
 * Features:
 *   · Workspace indicators via EWMH (_NET_CURRENT_DESKTOP, _NET_NUMBER_OF_DESKTOPS)
 *   · System clock (HH:MM:SS)
 *   · Hostname display
 *   · CPU / RAM quick stats via /proc
 *   · Scrolling marquee for long status text
 *   · Colors: #000000 bg | #ffffff primary | #888888 secondary
 */

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <math.h>
#include <signal.h>

/* ── Layout ────────────────────────────────────────────────────────────────── */
#define PANEL_H      28
#define FONT_SIZE    11.0
#define FONT_SMALL   9.5
#define PAD_X        14.0

/* ── Colors ────────────────────────────────────────────────────────────────── */
#define C_BG     0.00, 0.00, 0.00
#define C_PRI    1.00, 1.00, 1.00
#define C_SEC    0.53, 0.53, 0.53
#define C_DIM    0.18, 0.18, 0.18
#define C_ACT    0.85, 0.85, 0.85

/* workspace names matching i3 config */
static const char *WS_NAMES[] = {
    "TERM-A", "TERM-B", "TERM-C", "RECON",
    "EXPLOIT", "WEB", "NETWORK", "FORENSE",
    "MONITOR", "MISC"
};
#define WS_COUNT 10

/* ── System info ───────────────────────────────────────────────────────────── */
typedef struct {
    char hostname[64];
    char clock_str[16];
    char date_str[24];
    float cpu_pct;
    float mem_pct;
    long  mem_used_mb;
    long  mem_total_mb;
    int   cur_ws;
    int   num_ws;
} SysInfo;

static long prev_idle = 0, prev_total = 0;

static float read_cpu(void) {
    FILE *f = fopen("/proc/stat", "r");
    if (!f) return 0.0f;
    long user, nice, sys, idle, iow, irq, sirq;
    fscanf(f, "cpu %ld %ld %ld %ld %ld %ld %ld",
           &user, &nice, &sys, &idle, &iow, &irq, &sirq);
    fclose(f);

    long total = user + nice + sys + idle + iow + irq + sirq;
    long dt    = total - prev_total;
    long di    = idle  - prev_idle;
    float pct  = dt > 0 ? (float)(dt - di) * 100.0f / (float)dt : 0.0f;

    prev_total = total;
    prev_idle  = idle;
    return pct;
}

static void read_mem(long *used_mb, long *total_mb, float *pct) {
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) { *used_mb = *total_mb = 0; *pct = 0; return; }
    long total = 0, avail = 0;
    char key[32];
    long val;
    char unit[8];
    while (fscanf(f, "%31s %ld %7s", key, &val, unit) == 3) {
        if (strcmp(key, "MemTotal:") == 0)     total = val;
        if (strcmp(key, "MemAvailable:") == 0) avail = val;
    }
    fclose(f);
    long used = total - avail;
    *total_mb = total / 1024;
    *used_mb  = used  / 1024;
    *pct      = total > 0 ? (float)used * 100.0f / (float)total : 0.0f;
}

static void update_sysinfo(SysInfo *si, Display *dpy, Window root) {
    /* Time */
    time_t now = time(NULL);
    struct tm *tm = localtime(&now);
    strftime(si->clock_str, sizeof(si->clock_str), "%H:%M:%S", tm);
    strftime(si->date_str,  sizeof(si->date_str),  "%a %d %b %Y", tm);

    /* Hostname */
    gethostname(si->hostname, sizeof(si->hostname));
    si->hostname[sizeof(si->hostname)-1] = '\0';

    /* CPU / RAM */
    si->cpu_pct = read_cpu();
    read_mem(&si->mem_used_mb, &si->mem_total_mb, &si->mem_pct);

    /* Current workspace via EWMH */
    Atom cur_desk = XInternAtom(dpy, "_NET_CURRENT_DESKTOP", False);
    Atom num_desk = XInternAtom(dpy, "_NET_NUMBER_OF_DESKTOPS", False);

    Atom actual; int fmt; unsigned long n, remain;
    unsigned char *data = NULL;

    si->cur_ws = 0;
    if (XGetWindowProperty(dpy, root, cur_desk, 0, 1, False,
            XA_CARDINAL, &actual, &fmt, &n, &remain, &data) == Success && data) {
        si->cur_ws = (int)*(unsigned long *)data;
        XFree(data); data = NULL;
    }

    si->num_ws = WS_COUNT;
    if (XGetWindowProperty(dpy, root, num_desk, 0, 1, False,
            XA_CARDINAL, &actual, &fmt, &n, &remain, &data) == Success && data) {
        si->num_ws = (int)*(unsigned long *)data;
        XFree(data);
    }
}

/* ── Draw rounded rect ─────────────────────────────────────────────────────── */
static void rrect(cairo_t *cr, double x, double y, double w, double h, double r) {
    if (w <= 0 || h <= 0) return;
    if (r > w/2) r = w/2;
    if (r > h/2) r = h/2;
    cairo_new_sub_path(cr);
    cairo_arc(cr, x+w-r, y+r,   r, -M_PI/2, 0);
    cairo_arc(cr, x+w-r, y+h-r, r,  0,      M_PI/2);
    cairo_arc(cr, x+r,   y+h-r, r,  M_PI/2, M_PI);
    cairo_arc(cr, x+r,   y+r,   r,  M_PI,   3*M_PI/2);
    cairo_close_path(cr);
}

/* ── Measure text width ─────────────────────────────────────────────────────── */
static double text_w(cairo_t *cr, const char *s) {
    cairo_text_extents_t te;
    cairo_text_extents(cr, s, &te);
    return te.x_advance;
}

/* ── Draw one workspace pill ─────────────────────────────────────────────────── */
static double draw_ws_pill(cairo_t *cr, double x, double y,
                            const char *name, int active, int H) {
    cairo_save(cr);
    cairo_select_font_face(cr, "Liberation Mono",
        CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, FONT_SMALL);

    double tw = text_w(cr, name);
    double pw = tw + 14.0;
    double ph = 18.0;
    double py = (H - ph) / 2.0;

    if (active) {
        /* Active: white pill */
        cairo_set_source_rgba(cr, C_PRI, 1.0);
        rrect(cr, x, py, pw, ph, 3.0);
        cairo_fill(cr);
        cairo_set_source_rgba(cr, 0, 0, 0, 1.0);
    } else {
        /* Inactive: dim border */
        cairo_set_source_rgba(cr, C_DIM, 0.8);
        rrect(cr, x, py, pw, ph, 3.0);
        cairo_fill(cr);
        cairo_set_source_rgba(cr, C_SEC, 0.7);
    }

    cairo_text_extents_t te;
    cairo_text_extents(cr, name, &te);
    cairo_move_to(cr,
        x + (pw - te.width) / 2.0 - te.x_bearing,
        py + (ph + te.height) / 2.0 - te.height);
    cairo_show_text(cr, name);

    cairo_restore(cr);
    return pw + 4.0;
}

/* ── Render full panel ─────────────────────────────────────────────────────── */
static void render_panel(cairo_t *cr, int W, int H, SysInfo *si) {
    /* Background */
    cairo_set_source_rgba(cr, C_BG, 1.0);
    cairo_paint(cr);

    /* Bottom border line */
    cairo_set_source_rgba(cr, C_DIM, 1.0);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, 0, H - 0.5);
    cairo_line_to(cr, W, H - 0.5);
    cairo_stroke(cr);

    /* ── LEFT: brand mark ── */
    {
        double x = PAD_X;
        cairo_save(cr);
        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, FONT_SIZE);
        cairo_set_source_rgba(cr, C_PRI, 0.9);

        cairo_text_extents_t te;
        cairo_text_extents(cr, "AET", &te);
        cairo_move_to(cr, x, (H + te.height) / 2.0 - 1);
        cairo_show_text(cr, "AET");
        x += te.x_advance;

        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_source_rgba(cr, C_SEC, 0.7);
        cairo_text_extents_t te2;
        cairo_text_extents(cr, "ERNUS", &te2);
        cairo_move_to(cr, x, (H + te2.height) / 2.0 - 1);
        cairo_show_text(cr, "ERNUS");
        x += te2.x_advance;

        /* separator */
        cairo_set_source_rgba(cr, C_DIM, 0.9);
        cairo_set_line_width(cr, 1.0);
        cairo_move_to(cr, x + 10, 6);
        cairo_line_to(cr, x + 10, H - 6);
        cairo_stroke(cr);

        cairo_restore(cr);
    }

    /* ── LEFT-CENTER: workspace pills ── */
    {
        double x = PAD_X + 90.0;
        int count = si->num_ws < WS_COUNT ? si->num_ws : WS_COUNT;
        for (int i = 0; i < count; i++) {
            x += draw_ws_pill(cr, x, 0, WS_NAMES[i], i == si->cur_ws, H);
        }
    }

    /* ── RIGHT: system stats + clock ── */
    {
        double rx = W - PAD_X;
        cairo_save(cr);

        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, FONT_SIZE);
        cairo_set_source_rgba(cr, C_PRI, 0.95);

        /* Clock */
        cairo_text_extents_t te;
        cairo_text_extents(cr, si->clock_str, &te);
        rx -= te.x_advance;
        cairo_move_to(cr, rx, (H + te.height) / 2.0 - 1);
        cairo_show_text(cr, si->clock_str);

        /* Date */
        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, FONT_SMALL);
        cairo_set_source_rgba(cr, C_SEC, 0.6);
        cairo_text_extents_t ted;
        cairo_text_extents(cr, si->date_str, &ted);
        rx -= ted.x_advance + 18.0;
        cairo_move_to(cr, rx, (H + ted.height) / 2.0 - 1);
        cairo_show_text(cr, si->date_str);

        /* Separator */
        rx -= 14;
        cairo_set_source_rgba(cr, C_DIM, 0.9);
        cairo_set_line_width(cr, 1.0);
        cairo_move_to(cr, rx, 6);
        cairo_line_to(cr, rx, H - 6);
        cairo_stroke(cr);
        rx -= 10;

        /* RAM */
        char mem_str[32];
        snprintf(mem_str, sizeof(mem_str), "RAM %ldM/%ldM",
                 si->mem_used_mb, si->mem_total_mb);
        cairo_set_font_size(cr, FONT_SMALL);
        cairo_set_source_rgba(cr, C_SEC, 0.65);
        cairo_text_extents_t tm;
        cairo_text_extents(cr, mem_str, &tm);
        rx -= tm.x_advance;
        cairo_move_to(cr, rx, (H + tm.height) / 2.0 - 1);
        cairo_show_text(cr, mem_str);
        rx -= 16;

        /* CPU */
        char cpu_str[16];
        snprintf(cpu_str, sizeof(cpu_str), "CPU %.0f%%", si->cpu_pct);
        cairo_text_extents_t tc;
        cairo_text_extents(cr, cpu_str, &tc);
        rx -= tc.x_advance;

        /* CPU color: white if high, gray otherwise */
        if (si->cpu_pct > 80.0f)
            cairo_set_source_rgba(cr, C_PRI, 0.9);
        else
            cairo_set_source_rgba(cr, C_SEC, 0.65);

        cairo_move_to(cr, rx, (H + tc.height) / 2.0 - 1);
        cairo_show_text(cr, cpu_str);
        rx -= 14;

        /* Separator */
        cairo_set_source_rgba(cr, C_DIM, 0.9);
        cairo_set_line_width(cr, 1.0);
        cairo_move_to(cr, rx, 6);
        cairo_line_to(cr, rx, H - 6);
        cairo_stroke(cr);
        rx -= 10;

        /* Hostname */
        cairo_set_font_size(cr, FONT_SMALL);
        cairo_set_source_rgba(cr, C_SEC, 0.5);
        cairo_text_extents_t th;
        cairo_text_extents(cr, si->hostname, &th);
        rx -= th.x_advance;
        cairo_move_to(cr, rx, (H + th.height) / 2.0 - 1);
        cairo_show_text(cr, si->hostname);

        cairo_restore(cr);
    }
}

/* ── Signal handler ─────────────────────────────────────────────────────────── */
static volatile int g_running = 1;
static void on_signal(int sig) { (void)sig; g_running = 0; }

/* ── main ────────────────────────────────────────────────────────────────────── */
int main(void) {
    signal(SIGTERM, on_signal);
    signal(SIGINT,  on_signal);

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "aeternus-panel: cannot open display\n");
        return 1;
    }

    int scr  = DefaultScreen(dpy);
    Window root = RootWindow(dpy, scr);
    int W    = DisplayWidth(dpy, scr);

    /* Create panel window */
    XSetWindowAttributes attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.override_redirect = True;
    attrs.background_pixel  = BlackPixel(dpy, scr);
    attrs.event_mask        = ExposureMask | ButtonPressMask;

    Window win = XCreateWindow(
        dpy, root,
        0, 0, W, PANEL_H, 0,
        DefaultDepth(dpy, scr),
        InputOutput,
        DefaultVisual(dpy, scr),
        CWOverrideRedirect | CWBackPixel | CWEventMask,
        &attrs
    );

    /* EWMH dock hints */
    Atom wm_type  = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
    Atom wm_dock  = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
    XChangeProperty(dpy, win, wm_type, XA_ATOM, 32,
                    PropModeReplace, (unsigned char *)&wm_dock, 1);

    /* Reserve screen space (_NET_WM_STRUT_PARTIAL) */
    Atom strut = XInternAtom(dpy, "_NET_WM_STRUT_PARTIAL", False);
    long strut_vals[12] = { 0, 0, PANEL_H, 0,
                             0, 0, 0, 0,
                             0, W, 0, 0 };
    XChangeProperty(dpy, win, strut, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char *)strut_vals, 12);

    Atom strut_s = XInternAtom(dpy, "_NET_WM_STRUT", False);
    long strut_s_vals[4] = { 0, 0, PANEL_H, 0 };
    XChangeProperty(dpy, win, strut_s, XA_CARDINAL, 32,
                    PropModeReplace, (unsigned char *)strut_s_vals, 4);

    XMapWindow(dpy, win);
    XFlush(dpy);

    /* Cairo */
    cairo_surface_t *surf = cairo_xlib_surface_create(
        dpy, win, DefaultVisual(dpy, scr), W, PANEL_H);
    cairo_t *cr = cairo_create(surf);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);

    SysInfo si;
    memset(&si, 0, sizeof(si));

    int tick = 0;
    while (g_running) {
        /* Drain events */
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);
        }

        /* Update sysinfo every ~1s (30 * 33ms ≈ 1s) */
        if (tick % 30 == 0) {
            update_sysinfo(&si, dpy, root);
        }
        tick++;

        render_panel(cr, W, PANEL_H, &si);
        cairo_surface_flush(surf);
        XFlush(dpy);

        usleep(33333); /* ~30 fps */
    }

    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
