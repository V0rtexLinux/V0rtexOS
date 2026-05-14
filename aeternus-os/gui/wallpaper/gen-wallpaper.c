/*
 * V0rtexOS — Wallpaper Generator
 * Compile: gcc -O2 -o gen-wallpaper gen-wallpaper.c \
 *          $(pkg-config --libs --cflags cairo) -lm
 *
 * Generates a 1920x1080 PNG wallpaper with:
 *   · Pure black base
 *   · Subtle hex grid overlay (gray)
 *   · Corner geometric accents (white)
 *   · Center vertical gradient gradient line
 *   · "V0RTEX OS" watermark (dim)
 *   · Scan-line texture
 */

#include <cairo/cairo.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#define W 1920
#define H 1080

static void draw_hex(cairo_t *cr, double cx, double cy, double r) {
    cairo_new_sub_path(cr);
    for (int i = 0; i < 6; i++) {
        double a = M_PI / 180.0 * (60.0 * i - 30.0);
        if (i == 0) cairo_move_to(cr, cx + r * cos(a), cy + r * sin(a));
        else        cairo_line_to(cr, cx + r * cos(a), cy + r * sin(a));
    }
    cairo_close_path(cr);
}

static void rrect(cairo_t *cr, double x, double y, double w, double h, double r) {
    cairo_new_sub_path(cr);
    cairo_arc(cr, x+w-r, y+r,   r, -M_PI/2, 0);
    cairo_arc(cr, x+w-r, y+h-r, r,  0,      M_PI/2);
    cairo_arc(cr, x+r,   y+h-r, r,  M_PI/2, M_PI);
    cairo_arc(cr, x+r,   y+r,   r,  M_PI,   3*M_PI/2);
    cairo_close_path(cr);
}

int main(int argc, char **argv) {
    const char *out = argc > 1 ? argv[1] : "wallpaper.png";

    cairo_surface_t *surf = cairo_image_surface_create(CAIRO_FORMAT_RGB24, W, H);
    cairo_t *cr = cairo_create(surf);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);

    /* ── Black background ── */
    cairo_set_source_rgb(cr, 0, 0, 0);
    cairo_paint(cr);

    /* ── Subtle radial vignette (slightly lighter at center) ── */
    {
        cairo_pattern_t *p = cairo_pattern_create_radial(
            W/2.0, H/2.0, 0,
            W/2.0, H/2.0, W * 0.65);
        cairo_pattern_add_color_stop_rgba(p, 0.0, 1, 1, 1, 0.03);
        cairo_pattern_add_color_stop_rgba(p, 1.0, 0, 0, 0, 0.0);
        cairo_set_source(cr, p);
        cairo_paint(cr);
        cairo_pattern_destroy(p);
    }

    /* ── Hex grid ── */
    {
        double r  = 42.0;
        double dx = r * 1.732;
        double dy = r * 1.5;
        int cols  = (int)(W / dx) + 3;
        int rows  = (int)(H / dy) + 3;

        cairo_set_line_width(cr, 0.5);
        cairo_set_source_rgba(cr, 0.15, 0.15, 0.15, 0.6);

        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < cols; col++) {
                double cx = col * dx + (row % 2) * (dx / 2.0) - dx / 2;
                double cy = row * dy - dy / 2;
                draw_hex(cr, cx, cy, r - 1.5);
            }
        }
        cairo_stroke(cr);

        /* highlight a few hexes near center */
        int hc = 5;
        double cx0 = W / 2.0, cy0 = H / 2.0;
        for (int i = -hc; i <= hc; i++) {
            for (int j = -hc; j <= hc; j++) {
                double dist = sqrt(i*i + j*j);
                if (dist > hc) continue;
                double alpha = (1.0 - dist / hc) * 0.07;
                double cx = cx0 + j * dx + (((int)round(cy0 / dy)) % 2) * (dx / 2.0);
                double cy = cy0 + i * dy;
                cairo_set_source_rgba(cr, 1, 1, 1, alpha);
                draw_hex(cr, cx, cy, r - 1.5);
                cairo_fill(cr);
            }
        }
    }

    /* ── Scan lines ── */
    {
        cairo_set_source_rgba(cr, 0, 0, 0, 0.22);
        for (int y = 0; y < H; y += 2) {
            cairo_rectangle(cr, 0, y, W, 1);
        }
        cairo_fill(cr);
    }

    /* ── Horizontal center line ── */
    {
        cairo_pattern_t *p = cairo_pattern_create_linear(0, H/2.0, W, H/2.0);
        cairo_pattern_add_color_stop_rgba(p, 0.0,  1, 1, 1, 0.0);
        cairo_pattern_add_color_stop_rgba(p, 0.25, 1, 1, 1, 0.12);
        cairo_pattern_add_color_stop_rgba(p, 0.5,  1, 1, 1, 0.25);
        cairo_pattern_add_color_stop_rgba(p, 0.75, 1, 1, 1, 0.12);
        cairo_pattern_add_color_stop_rgba(p, 1.0,  1, 1, 1, 0.0);
        cairo_set_source(cr, p);
        cairo_set_line_width(cr, 1.0);
        cairo_move_to(cr, 0, H / 2.0);
        cairo_line_to(cr, W, H / 2.0);
        cairo_stroke(cr);
        cairo_pattern_destroy(p);
    }

    /* ── Corner accents ── */
    {
        double margin = 48.0;
        double len    = 40.0;
        cairo_set_source_rgba(cr, 0.53, 0.53, 0.53, 0.45);
        cairo_set_line_width(cr, 1.5);

        /* TL */
        cairo_move_to(cr, margin, margin + len);
        cairo_line_to(cr, margin, margin);
        cairo_line_to(cr, margin + len, margin);
        cairo_stroke(cr);
        /* TR */
        cairo_move_to(cr, W - margin - len, margin);
        cairo_line_to(cr, W - margin, margin);
        cairo_line_to(cr, W - margin, margin + len);
        cairo_stroke(cr);
        /* BL */
        cairo_move_to(cr, margin, H - margin - len);
        cairo_line_to(cr, margin, H - margin);
        cairo_line_to(cr, margin + len, H - margin);
        cairo_stroke(cr);
        /* BR */
        cairo_move_to(cr, W - margin - len, H - margin);
        cairo_line_to(cr, W - margin, H - margin);
        cairo_line_to(cr, W - margin, H - margin - len);
        cairo_stroke(cr);

        /* inner corner dots */
        cairo_set_source_rgba(cr, 1, 1, 1, 0.4);
        double pts[4][2] = {
            {margin, margin},
            {W-margin, margin},
            {margin, H-margin},
            {W-margin, H-margin}
        };
        for (int i = 0; i < 4; i++) {
            cairo_arc(cr, pts[i][0], pts[i][1], 2.5, 0, 2*M_PI);
            cairo_fill(cr);
        }
    }

    /* ── Side accent bars ── */
    {
        double bh  = 80.0;
        double bw  = 2.0;
        double cy  = H / 2.0;

        /* left */
        cairo_pattern_t *p = cairo_pattern_create_linear(0, cy - bh/2, 0, cy + bh/2);
        cairo_pattern_add_color_stop_rgba(p, 0.0, 1, 1, 1, 0.0);
        cairo_pattern_add_color_stop_rgba(p, 0.5, 1, 1, 1, 0.35);
        cairo_pattern_add_color_stop_rgba(p, 1.0, 1, 1, 1, 0.0);
        cairo_set_source(cr, p);
        cairo_rectangle(cr, 0, cy - bh/2, bw, bh);
        cairo_fill(cr);
        cairo_pattern_destroy(p);

        /* right */
        p = cairo_pattern_create_linear(0, cy - bh/2, 0, cy + bh/2);
        cairo_pattern_add_color_stop_rgba(p, 0.0, 1, 1, 1, 0.0);
        cairo_pattern_add_color_stop_rgba(p, 0.5, 1, 1, 1, 0.35);
        cairo_pattern_add_color_stop_rgba(p, 1.0, 1, 1, 1, 0.0);
        cairo_set_source(cr, p);
        cairo_rectangle(cr, W - bw, cy - bh/2, bw, bh);
        cairo_fill(cr);
        cairo_pattern_destroy(p);
    }

    /* ── Watermark text ── */
    {
        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 14.0);
        cairo_set_source_rgba(cr, 1, 1, 1, 0.04);

        const char *wm = "V0RTEX OS";
        cairo_text_extents_t te;
        cairo_text_extents(cr, wm, &te);
        cairo_move_to(cr,
            W / 2.0 - te.width / 2.0 - te.x_bearing,
            H / 2.0 - te.height / 2.0 - te.y_bearing);
        cairo_show_text(cr, wm);
    }

    /* ── Bottom status line ── */
    {
        cairo_set_source_rgba(cr, 0.53, 0.53, 0.53, 0.15);
        cairo_set_line_width(cr, 1.0);
        cairo_move_to(cr, 60, H - 60);
        cairo_line_to(cr, W - 60, H - 60);
        cairo_stroke(cr);

        cairo_select_font_face(cr, "Liberation Mono",
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 9.0);
        cairo_set_source_rgba(cr, 0.53, 0.53, 0.53, 0.2);

        const char *tag = "V0RTEX OS · SECURITY · ANONYMITY · CONTROL";
        cairo_text_extents_t te;
        cairo_text_extents(cr, tag, &te);
        cairo_move_to(cr,
            W / 2.0 - te.width / 2.0 - te.x_bearing,
            H - 42.0);
        cairo_show_text(cr, tag);
    }

    /* ── Write PNG ── */
    cairo_status_t status = cairo_surface_write_to_png(surf, out);
    if (status != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "gen-wallpaper: failed to write %s: %s\n",
                out, cairo_status_to_string(status));
        cairo_destroy(cr);
        cairo_surface_destroy(surf);
        return 1;
    }

    fprintf(stdout, "gen-wallpaper: wrote %s\n", out);
    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    return 0;
}
