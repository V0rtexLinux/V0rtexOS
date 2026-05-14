/*
 * V0rtexOS — Splash Screen
 * Compile: gcc -O2 -o aeternus-splash aeternus-splash.c \
 *          $(pkg-config --libs --cflags x11 cairo xrender)
 *
 * Colors: #000000 bg | #ffffff primary | #888888 secondary
 * Animation sequence (time in seconds):
 *   0.00 → black
 *   0.10 → top/bottom accent bars swipe in (left/right)
 *   0.45 → "V0RTEX" swipes in from left
 *   0.65 → "OS" swipes in from right
 *   0.85 → tagline fades in
 *   1.20 → hex grid draws in
 *   1.80 → loading bar fills
 *   3.20 → full fade-out
 *   3.60 → exit
 */

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/extensions/Xrender.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

/* ── Color palette ────────────────────────────────────────────────────────── */
#define C_BG_R   0.000
#define C_BG_G   0.000
#define C_BG_B   0.000

#define C_PRI_R  1.000
#define C_PRI_G  1.000
#define C_PRI_B  1.000

#define C_SEC_R  0.533
#define C_SEC_G  0.533
#define C_SEC_B  0.533

#define C_DIM_R  0.133
#define C_DIM_G  0.133
#define C_DIM_B  0.133

/* ── Timing constants (seconds) ───────────────────────────────────────────── */
#define T_BARS_START   0.10
#define T_BARS_END     0.55
#define T_LOGO_START   0.45
#define T_LOGO_END     0.90
#define T_OS_START     0.65
#define T_OS_END       1.05
#define T_TAG_START    0.90
#define T_TAG_END      1.30
#define T_HEX_START    1.20
#define T_HEX_END      1.90
#define T_BAR_START    1.80
#define T_BAR_END      3.00
#define T_FADE_START   3.20
#define T_FADE_END     3.60
#define T_TOTAL        3.70

#define FPS            60
#define FRAME_MS       (1000000 / FPS)

/* ── Math helpers ─────────────────────────────────────────────────────────── */
static inline double clamp(double v, double lo, double hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

static inline double progress(double t, double start, double end) {
    return clamp((t - start) / (end - start), 0.0, 1.0);
}

/* Cubic ease-out */
static inline double ease_out(double p) {
    double q = 1.0 - p;
    return 1.0 - q * q * q;
}

/* Cubic ease-in-out */
static inline double ease_inout(double p) {
    if (p < 0.5) return 4.0 * p * p * p;
    double q = -2.0 * p + 2.0;
    return 1.0 - q * q * q / 2.0;
}

/* ── Time helper ──────────────────────────────────────────────────────────── */
static double get_time(struct timespec *start) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (now.tv_sec - start->tv_sec)
         + (now.tv_nsec - start->tv_nsec) * 1e-9;
}

/* ── Draw a single hex outline ────────────────────────────────────────────── */
static void draw_hex(cairo_t *cr, double cx, double cy, double r) {
    cairo_new_sub_path(cr);
    for (int i = 0; i < 6; i++) {
        double a = M_PI / 180.0 * (60.0 * i - 30.0);
        double x = cx + r * cos(a);
        double y = cy + r * sin(a);
        if (i == 0) cairo_move_to(cr, x, y);
        else        cairo_line_to(cr, x, y);
    }
    cairo_close_path(cr);
}

/* ── Draw hex grid (partially revealed by 'reveal' 0..1) ─────────────────── */
static void draw_hex_grid(cairo_t *cr, int W, int H, double reveal, double alpha) {
    if (alpha <= 0.0 || reveal <= 0.0) return;

    double r    = 34.0;
    double dx   = r * 1.732;
    double dy   = r * 1.5;
    int cols    = (int)(W / dx) + 3;
    int rows    = (int)(H / dy) + 3;
    int total   = cols * rows;
    int visible = (int)(total * reveal);
    int drawn   = 0;

    cairo_save(cr);
    cairo_set_line_width(cr, 0.6);
    cairo_set_source_rgba(cr, C_DIM_R, C_DIM_G, C_DIM_B, alpha * 0.7);

    for (int row = 0; row < rows && drawn < visible; row++) {
        for (int col = 0; col < cols && drawn < visible; col++) {
            double cx = col * dx + (row % 2) * (dx / 2.0) - dx;
            double cy = row * dy - dy;
            draw_hex(cr, cx, cy, r - 2);
            drawn++;
        }
    }
    cairo_stroke(cr);
    cairo_restore(cr);
}

/* ── Draw a rounded rectangle ─────────────────────────────────────────────── */
static void rounded_rect(cairo_t *cr, double x, double y, double w, double h, double rad) {
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - rad, y + rad,     rad,  -M_PI/2,  0);
    cairo_arc(cr, x + w - rad, y + h - rad, rad,   0,       M_PI/2);
    cairo_arc(cr, x + rad,     y + h - rad, rad,   M_PI/2,  M_PI);
    cairo_arc(cr, x + rad,     y + rad,     rad,   M_PI,    3*M_PI/2);
    cairo_close_path(cr);
}

/* ── Main render function ─────────────────────────────────────────────────── */
static void render_frame(cairo_t *cr, int W, int H, double t) {

    /* --- Background --- */
    cairo_set_source_rgb(cr, C_BG_R, C_BG_G, C_BG_B);
    cairo_paint(cr);

    double cx = W / 2.0;
    double cy = H / 2.0;

    /* --- Hex grid background --- */
    {
        double p = ease_out(progress(t, T_HEX_START, T_HEX_END));
        draw_hex_grid(cr, W, H, p, 0.45 * p);
    }

    /* --- Top accent bar (swipes from left) --- */
    {
        double p    = ease_out(progress(t, T_BARS_START, T_BARS_END));
        double barH = 2.0;
        double barY = cy - 120.0;
        double barW = (double)W * p;

        cairo_set_source_rgba(cr, C_PRI_R, C_PRI_G, C_PRI_B, 0.9);
        cairo_rectangle(cr, 0, barY, barW, barH);
        cairo_fill(cr);

        /* thin secondary line beside it */
        cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.4 * p);
        cairo_rectangle(cr, 0, barY + 6.0, barW * 0.6, 1.0);
        cairo_fill(cr);
    }

    /* --- Bottom accent bar (swipes from right) --- */
    {
        double p    = ease_out(progress(t, T_BARS_START, T_BARS_END));
        double barH = 2.0;
        double barY = cy + 118.0;
        double barW = (double)W * p;

        cairo_set_source_rgba(cr, C_PRI_R, C_PRI_G, C_PRI_B, 0.9);
        cairo_rectangle(cr, W - barW, barY, barW, barH);
        cairo_fill(cr);

        cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.4 * p);
        cairo_rectangle(cr, W - barW * 0.6, barY - 6.0, barW * 0.6, 1.0);
        cairo_fill(cr);
    }

    /* --- Vertical side markers --- */
    {
        double p = ease_out(progress(t, T_BARS_START + 0.1, T_BARS_END));
        if (p > 0.0) {
            double mH = 60.0 * p;
            cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.35 * p);
            /* left */
            cairo_rectangle(cr, 60, cy - mH/2, 1, mH);
            cairo_fill(cr);
            /* right */
            cairo_rectangle(cr, W - 61, cy - mH/2, 1, mH);
            cairo_fill(cr);
        }
    }

    /* --- "V0RTEX" text swipes from left --- */
    {
        double p = ease_out(progress(t, T_LOGO_START, T_LOGO_END));
        if (p > 0.0) {
            cairo_save(cr);

            cairo_select_font_face(cr, "Liberation Mono",
                CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
            cairo_set_font_size(cr, 88.0);

            cairo_text_extents_t te;
            cairo_text_extents(cr, "V0RTEX", &te);

            /* swipe: starts far left, ends at center */
            double dest_x = cx - te.width / 2.0 - te.x_bearing;
            double src_x  = -te.width - 100.0;
            double tx     = src_x + (dest_x - src_x) * p;
            double ty     = cy - 28.0;

            cairo_set_source_rgba(cr, C_PRI_R, C_PRI_G, C_PRI_B, 0.97);
            cairo_move_to(cr, tx, ty);
            cairo_show_text(cr, "V0RTEX");

            /* subtle glow / shadow layer */
            cairo_set_source_rgba(cr, C_PRI_R, C_PRI_G, C_PRI_B, 0.06 * p);
            cairo_move_to(cr, tx + 2, ty + 2);
            cairo_show_text(cr, "V0RTEX");

            cairo_restore(cr);
        }
    }

    /* --- "OS" text swipes from right --- */
    {
        double p = ease_out(progress(t, T_OS_START, T_OS_END));
        if (p > 0.0) {
            cairo_save(cr);

            cairo_select_font_face(cr, "Liberation Mono",
                CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 28.0);

            cairo_text_extents_t te_main;
            cairo_select_font_face(cr, "Liberation Mono",
                CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
            cairo_set_font_size(cr, 88.0);
            cairo_text_extents(cr, "V0RTEX", &te_main);

            /* position "OS" label to the right of main text */
            double main_x   = cx - te_main.width / 2.0 - te_main.x_bearing;
            double after_main = main_x + te_main.width + 14.0;

            cairo_select_font_face(cr, "Liberation Mono",
                CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 26.0);

            cairo_text_extents_t te;
            cairo_text_extents(cr, "OS", &te);

            double dest_x = after_main;
            double src_x  = (double)W + te.width + 100.0;
            double tx     = src_x + (dest_x - src_x) * p;
            double ty     = cy - 28.0 - 88.0 + 26.0 + 10.0; /* baseline align */

            cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.85 * p);
            cairo_move_to(cr, tx, ty);
            cairo_show_text(cr, "OS");

            cairo_restore(cr);
        }
    }

    /* --- Tagline fades in --- */
    {
        double p = ease_out(progress(t, T_TAG_START, T_TAG_END));
        if (p > 0.0) {
            cairo_save(cr);
            cairo_select_font_face(cr, "Liberation Mono",
                CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 13.0);

            const char *tag = "V0RTEX OS  ·  SECURITY  ·  ANONYMITY  ·  CONTROL";
            cairo_text_extents_t te;
            cairo_text_extents(cr, tag, &te);

            double tx = cx - te.width / 2.0 - te.x_bearing;
            double ty = cy + 30.0;

            cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.7 * p);
            cairo_move_to(cr, tx, ty);
            cairo_show_text(cr, tag);

            cairo_restore(cr);
        }
    }

    /* --- Version badge swipes in with OS tag --- */
    {
        double p = ease_out(progress(t, T_OS_START + 0.1, T_OS_END + 0.2));
        if (p > 0.0) {
            cairo_save(cr);
            cairo_select_font_face(cr, "Liberation Mono",
                CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 10.0);

            const char *ver = "V0RTEX OS  v2.0 · GREY HAT EDITION";
            cairo_text_extents_t te;
            cairo_text_extents(cr, ver, &te);

            double tx = cx - te.width / 2.0 - te.x_bearing;
            double ty = cy + 55.0;

            cairo_set_source_rgba(cr, C_DIM_R * 2.5, C_DIM_G * 2.5, C_DIM_B * 2.5, 0.5 * p);
            cairo_move_to(cr, tx, ty);
            cairo_show_text(cr, ver);

            cairo_restore(cr);
        }
    }

    /* --- Loading bar --- */
    {
        double p    = ease_inout(progress(t, T_BAR_START, T_BAR_END));
        double barW = 420.0;
        double barH = 3.0;
        double bx   = cx - barW / 2.0;
        double by   = cy + 100.0;

        /* track */
        cairo_set_source_rgba(cr, C_DIM_R, C_DIM_G, C_DIM_B, 0.6);
        rounded_rect(cr, bx, by, barW, barH, 1.5);
        cairo_fill(cr);

        /* fill */
        if (p > 0.0) {
            cairo_set_source_rgba(cr, C_PRI_R, C_PRI_G, C_PRI_B, 0.9);
            rounded_rect(cr, bx, by, barW * p, barH, 1.5);
            cairo_fill(cr);

            /* glow at leading edge */
            if (p < 0.99) {
                double gx = bx + barW * p;
                cairo_pattern_t *grd = cairo_pattern_create_linear(
                    gx - 18, by, gx, by);
                cairo_pattern_add_color_stop_rgba(grd, 0.0,
                    C_PRI_R, C_PRI_G, C_PRI_B, 0.0);
                cairo_pattern_add_color_stop_rgba(grd, 1.0,
                    C_PRI_R, C_PRI_G, C_PRI_B, 0.6);
                cairo_set_source(cr, grd);
                cairo_rectangle(cr, gx - 18, by - 2, 18, barH + 4);
                cairo_fill(cr);
                cairo_pattern_destroy(grd);
            }
        }

        /* loading label */
        {
            double lp = clamp((t - T_BAR_START) / 0.3, 0.0, 1.0);
            if (lp > 0.0) {
                cairo_save(cr);
                cairo_select_font_face(cr, "Liberation Mono",
                    CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
                cairo_set_font_size(cr, 10.0);

                /* animated dots */
                int dots  = (int)(t * 3.0) % 4;
                char label[32];
                snprintf(label, sizeof(label), "INITIALIZING%s",
                    dots == 0 ? "" : dots == 1 ? "." : dots == 2 ? ".." : "...");

                cairo_text_extents_t te;
                cairo_text_extents(cr, label, &te);
                cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.55 * lp);
                cairo_move_to(cr, cx - te.width / 2.0 - te.x_bearing, by + 18.0);
                cairo_show_text(cr, label);

                /* percentage */
                char pct[8];
                snprintf(pct, sizeof(pct), "%d%%", (int)(p * 100));
                cairo_text_extents_t tep;
                cairo_text_extents(cr, pct, &tep);
                cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.4 * lp);
                cairo_move_to(cr, bx + barW - tep.width - tep.x_bearing, by - 7.0);
                cairo_show_text(cr, pct);

                cairo_restore(cr);
            }
        }
    }

    /* --- Corner decorations --- */
    {
        double p = ease_out(progress(t, T_BARS_START + 0.2, T_BARS_END + 0.1));
        if (p > 0.0) {
            double len = 20.0 * p;
            double margin = 40.0;
            cairo_set_source_rgba(cr, C_SEC_R, C_SEC_G, C_SEC_B, 0.35 * p);
            cairo_set_line_width(cr, 1.5);

            /* top-left */
            cairo_move_to(cr, margin, margin + len);
            cairo_line_to(cr, margin, margin);
            cairo_line_to(cr, margin + len, margin);
            cairo_stroke(cr);

            /* top-right */
            cairo_move_to(cr, W - margin - len, margin);
            cairo_line_to(cr, W - margin, margin);
            cairo_line_to(cr, W - margin, margin + len);
            cairo_stroke(cr);

            /* bottom-left */
            cairo_move_to(cr, margin, H - margin - len);
            cairo_line_to(cr, margin, H - margin);
            cairo_line_to(cr, margin + len, H - margin);
            cairo_stroke(cr);

            /* bottom-right */
            cairo_move_to(cr, W - margin - len, H - margin);
            cairo_line_to(cr, W - margin, H - margin);
            cairo_line_to(cr, W - margin, H - margin - len);
            cairo_stroke(cr);
        }
    }

    /* --- Ghost scanning line effect --- */
    {
        double speed = 0.7;
        double loop  = fmod(t * speed, 1.2);
        if (loop < 1.0) {
            double gy = loop * (double)H;
            cairo_pattern_t *g = cairo_pattern_create_linear(0, gy - 60, 0, gy + 4);
            cairo_pattern_add_color_stop_rgba(g, 0.0, C_PRI_R, C_PRI_G, C_PRI_B, 0.0);
            cairo_pattern_add_color_stop_rgba(g, 0.85, C_PRI_R, C_PRI_G, C_PRI_B, 0.025);
            cairo_pattern_add_color_stop_rgba(g, 1.0,  C_PRI_R, C_PRI_G, C_PRI_B, 0.07);
            cairo_set_source(cr, g);
            cairo_rectangle(cr, 0, gy - 60, W, 64);
            cairo_fill(cr);
            cairo_pattern_destroy(g);
        }
    }

    /* --- Full fade-out overlay --- */
    {
        double p = progress(t, T_FADE_START, T_FADE_END);
        if (p > 0.0) {
            double alpha = ease_inout(p);
            cairo_set_source_rgba(cr, C_BG_R, C_BG_G, C_BG_B, alpha);
            cairo_paint(cr);
        }
    }
}

/* ── main ─────────────────────────────────────────────────────────────────── */
int main(int argc, char **argv) {
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "v0rtex-splash: cannot open display\n");
        return 1;
    }

    int scr    = DefaultScreen(dpy);
    Window root = RootWindow(dpy, scr);
    int W      = DisplayWidth(dpy, scr);
    int H      = DisplayHeight(dpy, scr);

    /* Create fullscreen override-redirect window */
    XSetWindowAttributes attrs;
    attrs.override_redirect = True;
    attrs.background_pixel  = BlackPixel(dpy, scr);
    attrs.event_mask        = KeyPressMask | ButtonPressMask;

    Window win = XCreateWindow(
        dpy, root,
        0, 0, W, H, 0,
        DefaultDepth(dpy, scr),
        InputOutput,
        DefaultVisual(dpy, scr),
        CWOverrideRedirect | CWBackPixel | CWEventMask,
        &attrs
    );

    /* Grab keyboard so ESC can skip */
    XMapRaised(dpy, win);
    XFlush(dpy);
    XGrabKeyboard(dpy, win, True, GrabModeAsync, GrabModeAsync, CurrentTime);

    /* Cairo setup */
    cairo_surface_t *surf = cairo_xlib_surface_create(
        dpy, win, DefaultVisual(dpy, scr), W, H);
    cairo_t *cr = cairo_create(surf);

    /* Anti-aliasing */
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);

    /* Start clock */
    struct timespec start;
    clock_gettime(CLOCK_MONOTONIC, &start);

    int running = 1;
    while (running) {
        double t = get_time(&start);

        /* Drain X events */
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if (ev.type == KeyPress || ev.type == ButtonPress)
                running = 0;
        }

        if (t >= T_TOTAL)
            running = 0;

        render_frame(cr, W, H, t);
        cairo_surface_flush(surf);
        XFlush(dpy);

        usleep(FRAME_MS);
    }

    /* Cleanup */
    XUngrabKeyboard(dpy, CurrentTime);
    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);

    return 0;
}
