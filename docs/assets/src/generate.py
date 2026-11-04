#!/usr/bin/env python3
"""Generate the README images. Numbers come from docs/measurements/ (see README).

Usage: python3 docs/assets/src/generate.py  (needs rsvg-convert and the Geist Mono font)
"""
import pathlib
import subprocess

ASSETS = pathlib.Path(__file__).resolve().parents[1]
FONT = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

THEMES = {
    "light": {"ink": "#1f2328", "muted": "#59636e", "grid": "#d1d9e0", "stock": "#C8691F", "now": "#2B6FD6"},
    "dark": {"ink": "#f0f6fc", "muted": "#9198a1", "grid": "#3d444d", "stock": "#C4722A", "now": "#4F8BE6"},
}

ROWS = [("rmm", 52.8, "52.8 %", 21.0, "21.0 %"), ("all processes", 60.4, "60.4 %", 25.0, "~25 %")]


def chart(theme):
    t = THEMES[theme]
    left, top, scale, bar, gap, group = 170, 74, 7.4, 22, 4, 88
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 268" width="720" height="268" '
        f'role="img" aria-label="CPU use, stock against patched: rmm 52.8 to 21.0 percent, '
        f'all processes 60.4 to about 25 percent" font-family="{FONT}">',
        f'<text x="0" y="20" font-size="16" font-weight="700" fill="{t["ink"]}">Camera CPU use, %</text>',
        f'<rect x="0" y="36" width="12" height="12" rx="3" fill="{t["stock"]}"/>',
        f'<text x="18" y="46" font-size="13" fill="{t["muted"]}">stock yi-hack-v5</text>',
        f'<rect x="170" y="36" width="12" height="12" rx="3" fill="{t["now"]}"/>',
        f'<text x="188" y="46" font-size="13" fill="{t["muted"]}">yi-dome-hack</text>',
    ]
    for tick in range(0, 80, 20):
        x = left + tick * scale
        parts.append(f'<line x1="{x}" y1="{top - 8}" x2="{x}" y2="{top + 2 * group - 22}" stroke="{t["grid"]}"/>')
        parts.append(f'<text x="{x}" y="{top + 2 * group - 4}" font-size="12" text-anchor="middle" fill="{t["muted"]}">{tick}</text>')
    for i, (name, stock, stock_label, now, now_label) in enumerate(ROWS):
        y = top + i * group
        parts.append(f'<text x="{left - 12}" y="{y + bar + 6}" font-size="14" text-anchor="end" fill="{t["ink"]}">{name}</text>')
        for j, (value, label, color) in enumerate(((stock, stock_label, t["stock"]), (now, now_label, t["now"]))):
            by = y + j * (bar + gap)
            width = value * scale
            parts.append(f'<rect x="{left}" y="{by}" width="{width}" height="{bar}" rx="4" fill="{color}"/>')
            parts.append(f'<text x="{left + width + 8}" y="{by + 16}" font-size="13" font-weight="700" fill="{t["ink"]}">{label}</text>')
    parts.append("</svg>")
    return "\n".join(parts)


BYTES = [
    ("04", "01", True), ("00", "00", False), ("00", "00", False), ("00", "00", False),
    ("02", "02", False), ("00", "00", False), ("00", "00", False), ("00", "00", False),
    ("09", "e6", True), ("70", "00", True), ("09", "e6", True), ("70", "00", True),
]


def hex_strip(x0, y0, cell=78):
    parts = []
    for i, (old, new, changed) in enumerate(BYTES):
        x = x0 + i * cell
        if changed:
            parts.append(f'<rect x="{x - 32}" y="{y0 - 36}" width="64" height="92" rx="10" fill="#6BA4F8" fill-opacity=".14" stroke="#6BA4F8"/>')
        parts.append(f'<text x="{x}" y="{y0}" font-size="28" text-anchor="middle" fill="#7d8590">{old}</text>')
        fill = "#6BA4F8" if changed else "#7d8590"
        weight = 700 if changed else 400
        parts.append(f'<text x="{x}" y="{y0 + 40}" font-size="28" font-weight="{weight}" text-anchor="middle" fill="{fill}">{new}</text>')
    return "".join(parts)


def poster(height):
    y = (height - 420) // 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="{height}" viewBox="0 0 1280 {height}" font-family="Geist Mono">'
        f'<rect width="1280" height="{height}" fill="#0d1117"/>'
        f'<text x="640" y="{y + 110}" font-size="76" font-weight="700" text-anchor="middle" fill="#f0f6fc">yi-dome-hack</text>'
        f'<text x="640" y="{y + 162}" font-size="28" text-anchor="middle" fill="#9198a1">Fixing a closed-source camera, nine bytes at a time</text>'
        f'{hex_strip(211, y + 240)}'
        f'<text x="640" y="{y + 372}" font-size="24" text-anchor="middle" fill="#f0f6fc">rmm CPU 52.8 % → 21 %   ·   motion starts lost 3 of 4 → 0 of 9</text>'
        "</svg>"
    )


def render_png(svg, name):
    path = ASSETS / "src" / f"{name}.svg"
    path.write_text(svg)
    subprocess.run(["rsvg-convert", str(path), "-o", str(ASSETS / f"{name}.png")], check=True)


def main():
    for theme in THEMES:
        (ASSETS / f"cpu-chart-{theme}.svg").write_text(chart(theme))
    render_png(poster(420), "banner")
    render_png(poster(640), "social-preview")


if __name__ == "__main__":
    main()
