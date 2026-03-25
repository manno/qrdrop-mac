#!/usr/bin/env python3
"""Generate a fancy QR code app icon for QRDrop."""

import math
import os
import shutil
import subprocess

import qrcode
from PIL import Image, ImageDraw


def draw_gradient_background(img_size):
    """Deep blue-to-purple gradient background."""
    base = Image.new("RGBA", (img_size, img_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(base)

    color_top = (30, 60, 180)
    color_bot = (100, 20, 160)

    for y in range(img_size):
        t = y / img_size
        r = int(color_top[0] + t * (color_bot[0] - color_top[0]))
        g = int(color_top[1] + t * (color_bot[1] - color_top[1]))
        b = int(color_top[2] + t * (color_bot[2] - color_top[2]))
        draw.line([(0, y), (img_size, y)], fill=(r, g, b, 255))

    return base


def draw_dot(draw, cx, cy, r, fill, shape="circle"):
    if shape == "circle":
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    elif shape == "rounded":
        draw.rounded_rectangle([cx - r, cy - r, cx + r, cy + r], radius=r * 0.45, fill=fill)
    else:
        draw.rectangle([cx - r, cy - r, cx + r, cy + r], fill=fill)




def generate_icon(size=1024):
    pad_frac = 0.10
    pad = int(size * pad_frac)
    inner = size - 2 * pad

    # --- QR data ---
    qr = qrcode.QRCode(
        version=3,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=10,
        border=0,
    )
    qr.add_data("QRDrop")
    qr.make(fit=True)
    matrix = qr.get_matrix()
    n = len(matrix)

    cell = inner / n

    # --- Canvas ---
    img = draw_gradient_background(size)
    draw = ImageDraw.Draw(img)

    # --- Finder pattern positions (top-left, top-right, bottom-left) ---
    finder_cells = 7  # standard QR finder is 7x7
    finder_centers = [
        (pad + (finder_cells / 2) * cell, pad + (finder_cells / 2) * cell),
        (pad + (n - finder_cells / 2) * cell, pad + (finder_cells / 2) * cell),
        (pad + (finder_cells / 2) * cell, pad + (n - finder_cells / 2) * cell),
    ]

    # Mask finder pattern cells so we draw them specially
    finder_mask = set()
    for fc_x, fc_y in finder_centers:
        col = round((fc_x - pad) / cell - 0.5)
        row = round((fc_y - pad) / cell - 0.5)
        for dr in range(-1, finder_cells + 1):
            for dc in range(-1, finder_cells + 1):
                finder_mask.add((row + dr, col + dc))

    # --- Data modules ---
    for row in range(n):
        for col in range(n):
            if not matrix[row][col]:
                continue
            if (row, col) in finder_mask:
                continue
            cx = pad + (col + 0.5) * cell
            cy = pad + (row + 0.5) * cell
            r = cell * 0.40
            # Slight warm-white tint, fully opaque
            draw_dot(draw, cx, cy, r, (235, 240, 255, 255), shape="circle")

    # --- Finder patterns (stylised) ---
    outer_col = (255, 255, 255, 255)
    inner_col = (80, 120, 255, 255)
    gap_col_approx = (60, 80, 190, 255)  # close to background mid-colour
    for cx, cy in finder_centers:
        # Outer white rounded square
        outer = cell * 3.5
        draw.rounded_rectangle(
            [cx - outer, cy - outer, cx + outer, cy + outer],
            radius=cell * 0.9,
            fill=outer_col,
        )
        # Background-coloured gap
        mid = cell * 2.3
        draw.rounded_rectangle(
            [cx - mid, cy - mid, cx + mid, cy + mid],
            radius=cell * 0.6,
            fill=gap_col_approx,
        )
        # Blue inner square
        inner_r = cell * 1.4
        draw.rounded_rectangle(
            [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
            radius=cell * 0.4,
            fill=inner_col,
        )

    return img


def main():
    # sizes required for macOS .icns
    sizes = [16, 32, 64, 128, 256, 512, 1024]

    print("Generating base icon at 1024x1024...")
    base = generate_icon(1024)

    iconset_dir = "/Users/mm/co/qrdrop-mac/Resources/AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)

    mapping = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }

    for filename, px in mapping.items():
        resized = base.resize((px, px), Image.LANCZOS)
        out_path = os.path.join(iconset_dir, filename)
        resized.save(out_path, "PNG")
        print(f"  Saved {filename} ({px}x{px})")

    icns_path = "/Users/mm/co/qrdrop-mac/Resources/AppIcon.icns"
    print(f"\nRunning iconutil → {icns_path}")
    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path],
        check=True,
    )

    shutil.rmtree(iconset_dir)
    print("Done! Icon saved to Resources/AppIcon.icns")


if __name__ == "__main__":
    main()
