#!/usr/bin/env python3
"""Generates the placeholder art for Bubák as soft, cartoony SVGs.

Run from the project root:  python3 tools/gen_art.py
Every sprite is drawn bottom-centred on a "ground line" so the game can
place it by its feet. Swap any file in assets/art/ for hand-drawn art later
(keep the canvas size and ground line and nothing in code needs to change).
"""
import math
import os
import random
import re

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
os.makedirs(OUT, exist_ok=True)

# ---- palette -------------------------------------------------------------
INK = "#4f3d33"          # warm brown outline
FUR = "#7a7584"          # Bubák's charcoal-lilac fur
FUR_DARK = "#5f5a69"
FUR_LIGHT = "#948f9e"
CREAM = "#f6f0e8"        # white blaze / tummy / tail
PINK = "#f2b3bd"
NOSE = "#e7849a"
BLUSH = "#f59aa6"
EYE = "#2b2230"


def stroke(w=4):
    return f'stroke="{INK}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"'


def wobble_ellipse(cx, cy, rx, ry, rot=0, fill=FUR, w=4, seed=0, amt=0.025, extra=""):
    """An ellipse drawn as a slightly irregular closed curve, for a hand-drawn feel."""
    rnd = random.Random(seed + int(cx * 7 + cy * 13 + rx))
    n = 14
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + rnd.uniform(-amt, amt)
        pts.append((math.cos(a) * rx * k, math.sin(a) * ry * k))
    # Catmull-Rom -> cubic bezier for a smooth closed path
    d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f} "
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f} "
    d += "Z"
    sw = stroke(w) if w else 'stroke="none"'
    return (f'<path transform="translate({cx},{cy}) rotate({rot})" d="{d}" '
            f'fill="{fill}" {sw} {extra}/>')


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}">\n{body}\n</svg>\n')


def _mix(hex_color, amount):
    """Lighten (amount > 0) or darken (amount < 0) a #rrggbb colour."""
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    t = 255 if amount > 0 else 0
    a = abs(amount)
    return "#%02x%02x%02x" % tuple(round(c + (t - c) * a) for c in (r, g, b))


def auto_shade(text):
    """Gives every outlined shape a soft top-lit gradient instead of a flat fill."""
    grads = {}

    def repl(m):
        tag = m.group(0)
        if f'stroke="{INK}"' not in tag:
            return tag
        fm = re.search(r'fill="(#[0-9a-fA-F]{6})"', tag)
        if not fm:
            return tag
        c = fm.group(1).lower()
        grads["s" + c[1:]] = c
        return tag.replace(fm.group(0), f'fill="url(#s{c[1:]})"')

    text = re.sub(r'<(path|rect|ellipse|circle)\b[^>]*>', repl, text)
    if not grads:
        return text
    defs = "<defs>" + "".join(
        f'<linearGradient id="{gid}" x1="0" y1="0" x2="0.25" y2="1">'
        f'<stop offset="0" stop-color="{_mix(c, 0.22)}"/><stop offset="0.5" stop-color="{c}"/>'
        f'<stop offset="1" stop-color="{_mix(c, -0.12)}"/></linearGradient>'
        for gid, c in grads.items()) + "</defs>"
    return re.sub(r'(<svg[^>]*>)', lambda m: m.group(1) + "\n" + defs, text, count=1)


def save(name, content):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(auto_shade(content))


# ---- Bubák ---------------------------------------------------------------
def head(cx, cy, rot=0, ear_angle=-12, eyes="open", seed=1, ear=True, nose=True):
    """Head with one perky ear and one floppy ear (Bubák's trademark)."""
    g = [f'<g transform="translate({cx},{cy}) rotate({rot})">']
    # far (floppy) ear, behind the head
    g.append(wobble_ellipse(-30, 0, 12, 33, 62, FUR_DARK, seed=seed + 1))
    g.append(wobble_ellipse(-1, 0, 43, 38, 0, FUR, seed=seed + 2))
    # soft highlight on the crown
    g.append(wobble_ellipse(-6, -18, 20, 10, -10, FUR_LIGHT, w=0, seed=seed + 3, extra='opacity="0.55"'))
    # white blaze up the forehead (kept away from the eye so it never reads as a tear) + muzzle
    g.append(wobble_ellipse(5, -27, 4, 7, 25, CREAM, w=0, seed=seed + 4))
    g.append(wobble_ellipse(25, 13, 20, 16, 0, CREAM, w=0, seed=seed + 5))
    # rosy cheek, pushed up by the smile
    g.append(f'<ellipse cx="14" cy="14" rx="9" ry="5.5" fill="{BLUSH}" opacity="0.6"/>')
    # eye
    if eyes == "open":
        g.append(f'<ellipse cx="14" cy="-5" rx="7.5" ry="8.5" fill="{EYE}"/>')
        g.append('<circle cx="16.5" cy="-8.5" r="3" fill="#fff"/>')
        g.append('<circle cx="11" cy="-1" r="1.5" fill="#fff"/>')
    else:
        # content, smiling closed eye
        g.append(f'<path d="M5,-2 Q13,-10 21,-2" fill="none" {stroke(3.5)}/>')
    # nose + smiling mouth + whiskers
    if nose:
        g.append(f'<path d="M37,4 q5,-3 7,1 q-1,5 -4,6 q-4,-2 -3,-7z" fill="{NOSE}" {stroke(2.5)}/>')
    # a small, gentle smile
    g.append(f'<path d="M40,11 L40,15" fill="none" {stroke(2.2)}/>')
    g.append(f'<path d="M33,14 Q36,18.5 40,15 Q44,18.5 47,14" fill="none" {stroke(2.5)}/>')
    g.append(f'<path d="M44,11 L64,6 M44,14 L64,16" fill="none" stroke="{INK}" stroke-width="1.6" '
             f'stroke-linecap="round" opacity="0.55"/>')
    # near (perky) ear on top
    if ear:
        g.append(f'<g transform="translate(-8,-26) rotate({ear_angle})">')
        g.append(perky_ear(seed))
        g.append('</g>')
    g.append('</g>')
    return "\n".join(g)


def perky_ear(seed=1):
    return (wobble_ellipse(-2, -34, 13, 37, 0, FUR, seed=seed + 6)
            + wobble_ellipse(-1, -32, 6, 26, 0, PINK, w=0, seed=seed + 7)
            + wobble_ellipse(-6, -50, 3, 12, -6, "#ffffff", w=0, seed=seed + 8, extra='opacity="0.35"'))


# Bubák's soft fluff: a light tummy/chest patch and a lighter top on the body
def bunny(pose, parts=True):
    W, H = 220, 200
    p = []
    if pose in ("sit", "blink"):
        p.append(wobble_ellipse(40, 140, 14, 14, 0, CREAM))  # tail
        p.append(wobble_ellipse(96, 138, 60, 50, -8))
        p.append(wobble_ellipse(84, 128, 30, 16, -12, FUR_LIGHT, w=0, extra='opacity="0.5"'))
        p.append(wobble_ellipse(128, 150, 17, 25, -5, CREAM, w=0))
        p.append(wobble_ellipse(84, 184, 32, 10, 0, FUR))     # hind foot
        p.append(head(146, 92, 0, -12, "closed" if pose == "blink" else "open", ear=parts, nose=parts))
        p.append(wobble_ellipse(140, 186, 13, 8, 0, CREAM))   # front paw
    elif pose == "hop":
        p.append(wobble_ellipse(36, 128, 13, 13, 0, CREAM))
        p.append(wobble_ellipse(42, 160, 32, 10, 28, FUR))    # hind leg kicked back
        p.append(wobble_ellipse(98, 128, 68, 40, -14))
        p.append(wobble_ellipse(90, 112, 34, 12, -18, FUR_LIGHT, w=0, extra='opacity="0.5"'))
        p.append(wobble_ellipse(162, 162, 14, 8, -35, CREAM))  # front paws reaching
        p.append(head(156, 88, -10, -35, "open", ear=parts, nose=parts))
    elif pose in ("loaf", "sleep"):
        p.append(wobble_ellipse(38, 160, 12, 12, 0, CREAM))
        p.append(wobble_ellipse(98, 154, 66, 38, 0))
        p.append(wobble_ellipse(90, 136, 36, 12, -6, FUR_LIGHT, w=0, extra='opacity="0.5"'))
        p.append(wobble_ellipse(152, 186, 14, 7, 0, CREAM))
        p.append(head(148, 132, 4, -48, "closed" if pose == "sleep" else "open", ear=parts, nose=parts))
    elif pose == "eat":
        p.append(wobble_ellipse(40, 138, 14, 14, 0, CREAM))
        p.append(wobble_ellipse(96, 140, 60, 48, -2))
        p.append(wobble_ellipse(84, 124, 30, 14, -8, FUR_LIGHT, w=0, extra='opacity="0.5"'))
        p.append(wobble_ellipse(84, 184, 32, 10, 0, FUR))
        p.append(head(150, 134, 24, -28, "open", ear=parts, nose=parts))
        p.append(wobble_ellipse(140, 186, 13, 8, 0, CREAM))
    elif pose == "flop":
        p.append(wobble_ellipse(26, 166, 26, 9, -8, FUR))     # legs stretched out
        p.append(wobble_ellipse(20, 152, 12, 12, 0, CREAM))
        p.append(wobble_ellipse(94, 166, 68, 27, 3))
        p.append(wobble_ellipse(108, 180, 36, 9, 3, CREAM, w=0))
        p.append(head(160, 160, 30, -100, "closed", ear=parts, nose=parts))
    elif pose == "stand":   # begging on hind legs
        p.append(wobble_ellipse(66, 172, 12, 12, 0, CREAM))
        p.append(wobble_ellipse(84, 186, 30, 9, 0, FUR))
        p.append(wobble_ellipse(98, 128, 42, 60, 12))
        p.append(wobble_ellipse(114, 134, 18, 34, 12, CREAM, w=0))
        p.append(wobble_ellipse(130, 112, 10, 14, 30, CREAM))  # paws held up
        p.append(head(124, 58, -6, 4, "open", ear=parts, nose=parts))
    return svg(W, H, "\n".join(p))


for pose in ("sit", "blink", "hop", "loaf", "sleep", "eat", "flop", "stand"):
    save(f"bunny_{pose}.svg", bunny(pose))
    save(f"bunny_{pose}_body.svg", bunny(pose, parts=False))
# the parts the game animates: ear root at (30,104), nose centre at (9.5,10)
save("bunny_ear.svg", svg(60, 110, f'<g transform="translate(30,104)">{perky_ear()}</g>'))
save("bunny_nose.svg", svg(20, 18, f'<g transform="translate(-31,4)"><path d="M37,4 q5,-3 7,1 q-1,5 -4,6 q-4,-2 -3,-7z" fill="{NOSE}" {stroke(2.5)}/></g>'))

# ---- room ----------------------------------------------------------------
# World is 1280x720; the background over-draws generously so wide phones
# and 4:3 tablets never see an edge. The image's (240,160) is world (0,0).
BX, BY = 240, 160
WALL_Y = 410


## The flat's looks (Shop > Makeover): wall, stripes, little motif, wainscoting, curtains, floor.
ROOM_STYLES = {
    "cream": dict(base="#f7e6d0", stripe="#f2dcc2", motif="dot", mcol="#e8c9b4", wains="#efd5b6", panel="#f4dec3",
                  pstroke="#dcbd98", rail="#fff6e8", rline="#d9b896", curtain="#e9a3a0", floor="#e2bd92", fline="#d1a878",
                  grain="#d6ab7c"),
    "mint": dict(base="#e2f0e4", stripe="#d2e8d6", motif="leaf", mcol="#a9d0b4", wains="#cfe5d4", panel="#dcefe0",
                 pstroke="#a9cdb2", rail="#f6fbf6", rline="#a9cdb2", curtain="#f3cf7a", floor="#ecd6b2", fline="#dcc195",
                 grain="#e2c9a0"),
    "lavender": dict(base="#ece2f2", stripe="#e2d5ec", motif="heart", mcol="#d0b8e2", wains="#dccfe8", panel="#e8def0",
                     pstroke="#c2aed6", rail="#faf6fc", rline="#c2aed6", curtain="#a7c0e8", floor="#e2bd92", fline="#d1a878",
                     grain="#d6ab7c"),
    "sunny": dict(base="#fbf0c8", stripe="#f6e5a8", motif="daisy", mcol="#ffffff", wains="#f3e2a6", panel="#f8ebbd",
                  pstroke="#dcc27e", rail="#fffaf0", rline="#dcc27e", curtain="#e8505b", floor="#e6c39a", fline="#d4ac7e",
                  grain="#dbb588"),
    "starry": dict(base="#3e4c78", stripe="#45548a", motif="star", mcol="#f3cf7a", wains="#34406a", panel="#3b4774",
                   pstroke="#2a3358", rail="#c9d3f0", rline="#2a3358", curtain="#d8a7d0", floor="#9a6a48", fline="#845839",
                   grain="#8e6142"),
    "forest": dict(base="#a9cca5", stripe="#9cc398", motif="leaf", mcol="#77a874", wains="#8fb98c", panel="#9cc499",
                   pstroke="#6f9b6c", rail="#eef5e6", rline="#6f9b6c", curtain="#f3cf7a", floor="#b5a77a", fline="#9d9064",
                   grain="#a69a6c"),
}


def motif(kind, x, y, c):
    if kind == "dot":
        return f'<circle cx="{x}" cy="{y}" r="3" fill="{c}"/>'
    if kind == "heart":
        return f'<path d="M{x},{y + 4} C{x - 7},{y - 1} {x - 4},{y - 7} {x},{y - 3} C{x + 4},{y - 7} {x + 7},{y - 1} {x},{y + 4} Z" fill="{c}"/>'
    if kind == "leaf":
        return f'<ellipse cx="{x}" cy="{y}" rx="7" ry="3.5" transform="rotate(-35 {x} {y})" fill="{c}"/>'
    if kind == "star":
        pts = " ".join(f"{x + (6 if i % 2 == 0 else 2.6) * math.cos(math.radians(-90 + i * 36)):.1f},"
                       f"{y + (6 if i % 2 == 0 else 2.6) * math.sin(math.radians(-90 + i * 36)):.1f}" for i in range(10))
        return f'<polygon points="{pts}" fill="{c}"/>'
    # daisy
    return "".join(f'<circle cx="{x + 4 * math.cos(math.radians(a)):.1f}" cy="{y + 4 * math.sin(math.radians(a)):.1f}" r="2.6" fill="{c}"/>'
                   for a in range(0, 360, 72)) + f'<circle cx="{x}" cy="{y}" r="2" fill="#f2b632"/>'


def room(style="cream"):
    S = ROOM_STYLES[style]
    W, H = 1760, 1040
    p = [f'<rect width="{W}" height="{H}" fill="{S["base"]}"/>']
    # wallpaper stripes + a tiny motif
    for x in range(0, W, 64):
        p.append(f'<rect x="{x}" y="0" width="30" height="{WALL_Y + BY}" fill="{S["stripe"]}" opacity="0.6"/>')
    rnd = random.Random(3)
    for x in range(47, W, 64):
        for y in range(40, WALL_Y + BY - 40, 90):
            yy = y + (32 if (x // 64) % 2 else 0)
            p.append(motif(S["motif"], x, yy, S["mcol"]))
    # window cut out (sky is drawn behind the room by the game)
    wx, wy, ww, wh = 760 + BX, 60 + BY, 220, 240
    hole = f"M{wx},{wy} h{ww} v{wh} h{-ww} z"
    p[0] = (f'<path fill="{S["base"]}" fill-rule="evenodd" d="M0,0 H{W} V{H} H0 Z {hole}"/>')
    # stripes would paint over the window: clip them with an evenodd mask path instead
    p.insert(1, f'<defs><clipPath id="wall"><path clip-rule="evenodd" d="M0,0 H{W} V{H} H0 Z {hole}"/></clipPath></defs>')
    p.insert(2, '<g clip-path="url(#wall)">')
    # daylight from the window spilling across the wall
    wcx, wcy = wx + ww / 2, wy + wh / 2
    p.append(f'<radialGradient id="winlight" cx="{wcx}" cy="{wcy}" r="700" gradientUnits="userSpaceOnUse">'
             '<stop offset="0" stop-color="#fffaf0" stop-opacity="0.55"/>'
             '<stop offset="1" stop-color="#fffaf0" stop-opacity="0"/></radialGradient>')
    p.append(f'<rect width="{W}" height="{WALL_Y + BY}" fill="url(#winlight)"/>')
    # wainscoting panels on the lower wall
    wy0 = 324 + BY
    p.append(f'<rect x="0" y="{wy0}" width="{W}" height="{WALL_Y + BY - wy0}" fill="{S["wains"]}"/>')
    for x in range(30, W, 170):
        p.append(f'<rect x="{x}" y="{wy0 + 18}" width="140" height="{WALL_Y + BY - wy0 - 34}" rx="6" '
                 f'fill="{S["panel"]}" stroke="{S["pstroke"]}" stroke-width="3"/>')
    p.append(f'<rect x="0" y="{wy0 - 8}" width="{W}" height="12" fill="{S["rail"]}"/>')
    p.append(f'<path d="M0,{wy0 - 8} H{W} M0,{wy0 + 4} H{W}" stroke="{S["rline"]}" stroke-width="3"/>')
    p.append('</g>')
    # window frame
    p.append(f'<rect x="{wx}" y="{wy}" width="{ww}" height="{wh}" rx="10" fill="none" '
             f'stroke="#fffaf2" stroke-width="18"/>')
    p.append(f'<rect x="{wx}" y="{wy}" width="{ww}" height="{wh}" rx="10" fill="none" {stroke(4)}/>')
    p.append(f'<path d="M{wx + ww / 2},{wy} v{wh} M{wx},{wy + wh / 2} h{ww}" stroke="#fffaf2" stroke-width="10"/>')
    p.append(f'<path d="M{wx - 26},{wy + wh + 6} h{ww + 52}" stroke="#fffaf2" stroke-width="16" stroke-linecap="round"/>')
    p.append(f'<path d="M{wx - 26},{wy + wh + 14} h{ww + 52}" {stroke(4)}/>')
    # curtains
    for side in (-1, 1):
        cx = wx - 30 if side < 0 else wx + ww + 30
        p.append(f'<path d="M{cx - 26},{wy - 24} q{-10 * side},120 {6 * side},{wh + 40} '
                 f'q30,10 46,0 q{-24 * side},-130 {-4 * side},{-wh - 40} z" fill="{S["curtain"]}" {stroke(4)}/>')
    p.append(f'<path d="M{wx - 70},{wy - 26} h{ww + 140}" {stroke(7)}/>')
    # picture frame with a carrot doodle
    fx, fy = 470 + BX, 110 + BY
    p.append(f'<rect x="{fx}" y="{fy}" width="130" height="104" rx="8" fill="#fff6e8" {stroke(5)}/>')
    p.append(f'<rect x="{fx + 12}" y="{fy + 12}" width="106" height="80" rx="4" fill="#cfe6d2"/>')
    p.append(f'<path d="M{fx + 40},{fy + 74} l40,-34 q10,6 6,14 z" fill="#f4a259" {stroke(3)}/>')
    p.append(f'<path d="M{fx + 82},{fy + 42} l10,-14 M{fx + 84},{fy + 44} l16,-6" stroke="#6aa86d" '
             f'stroke-width="5" stroke-linecap="round"/>')
    # (the wall above the sofa is where Bubák's wardrobe hangs, see closet())
    # skirting board + floor
    fy0 = WALL_Y + BY
    p.append(f'<rect x="0" y="{fy0}" width="{W}" height="{H - fy0}" fill="{S["floor"]}"/>')
    for i, y in enumerate(range(fy0 + 40, H, 52)):
        p.append(f'<path d="M0,{y} H{W}" stroke="{S["fline"]}" stroke-width="3"/>')
        off = (i * 173) % 260
        for x in range(off, W, 260):
            p.append(f'<path d="M{x},{y - 52 if y - 52 > fy0 else fy0} V{y}" stroke="{S["fline"]}" stroke-width="3"/>')
    # wood grain
    rnd = random.Random(17)
    for _ in range(160):
        x, y = rnd.uniform(0, W), rnd.uniform(fy0 + 30, H)
        l = rnd.uniform(40, 120)
        p.append(f'<path d="M{x:.0f},{y:.0f} q{l / 2:.0f},{rnd.uniform(-4, 4):.1f} {l:.0f},0" fill="none" '
                 f'stroke="{S["grain"]}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>')
    # depth: the floor darkens towards the wall, and a soft shadow under the skirting board
    p.append(f'<linearGradient id="floordepth" x1="0" y1="{fy0}" x2="0" y2="{H}" gradientUnits="userSpaceOnUse">'
             '<stop offset="0" stop-color="#7a5236" stop-opacity="0.28"/>'
             '<stop offset="0.12" stop-color="#7a5236" stop-opacity="0.08"/>'
             '<stop offset="1" stop-color="#fff4e0" stop-opacity="0.12"/></linearGradient>')
    p.append(f'<rect x="0" y="{fy0}" width="{W}" height="{H - fy0}" fill="url(#floordepth)"/>')
    p.append(f'<rect x="0" y="{fy0 - 6}" width="{W}" height="24" fill="#fff8ee"/>')
    p.append(f'<path d="M0,{fy0 - 6} H{W} M0,{fy0 + 18} H{W}" {stroke(4)}/>')
    # wall outlet where the (chewable) cable plugs in
    ox, oy = 1035 + BX, 350 + BY   # under the desk, by the charger
    p.append(f'<rect x="{ox - 18}" y="{oy - 22}" width="36" height="44" rx="7" fill="#fffaf2" {stroke(4)}/>')
    p.append(f'<circle cx="{ox - 6}" cy="{oy}" r="3" fill="{INK}"/><circle cx="{ox + 6}" cy="{oy}" r="3" fill="{INK}"/>')
    return svg(W, H, "\n".join(p))


save("room.svg", room())
for _s in ROOM_STYLES:
    if _s != "cream":
        save(f"room_{_s}.svg", room(_s))
    _S = ROOM_STYLES[_s]   # a swatch for the shop
    save(f"icon_style_{_s}.svg", svg(64, 64,
        f'<rect x="4" y="4" width="56" height="56" rx="10" fill="{_S["base"]}"/>'
        + "".join(f'<rect x="{x}" y="4" width="7" height="34" fill="{_S["stripe"]}"/>' for x in (10, 24, 38, 52))
        + motif(_S["motif"], 32, 20, _S["mcol"]) + motif(_S["motif"], 18, 28, _S["mcol"]) + motif(_S["motif"], 46, 28, _S["mcol"])
        + f'<rect x="4" y="38" width="56" height="22" fill="{_S["floor"]}"/><path d="M4,48 H60" stroke="{_S["fline"]}" stroke-width="2"/>'
        + f'<path d="M4,38 H60" stroke="{_S["rail"]}" stroke-width="3"/>'
        + f'<rect x="4" y="4" width="56" height="56" rx="10" fill="none" {stroke(4)}/>'))


def sofa():
    p = [
        f'<rect x="20" y="40" width="380" height="120" rx="40" fill="#8fb8c9" {stroke(5)}/>',
        f'<rect x="10" y="110" width="400" height="80" rx="30" fill="#a4c9d8" {stroke(5)}/>',
        f'<rect x="0" y="80" width="70" height="120" rx="30" fill="#8fb8c9" {stroke(5)}/>',
        f'<rect x="350" y="80" width="70" height="120" rx="30" fill="#8fb8c9" {stroke(5)}/>',
        f'<rect x="90" y="62" width="110" height="70" rx="26" fill="#f3cf7a" {stroke(4)}/>',
        f'<rect x="220" y="62" width="110" height="70" rx="26" fill="#e9a3a0" {stroke(4)}/>',
        f'<path d="M140,96 q5,-8 10,0 q5,-8 10,0 q0,8 -10,14 q-10,-6 -10,-14z" fill="#fff" opacity="0.8"/>',
        f'<rect x="40" y="196" width="14" height="20" rx="4" fill="#c99a6b" {stroke(3)}/>',
        f'<rect x="366" y="196" width="14" height="20" rx="4" fill="#c99a6b" {stroke(3)}/>',
    ]
    return svg(420, 220, "\n".join(p))


def desk():
    p = [
        f'<rect x="10" y="60" width="220" height="18" rx="5" fill="#c99a6b" {stroke(4)}/>',
        f'<rect x="22" y="76" width="14" height="140" rx="4" fill="#b8875a" {stroke(4)}/>',
        f'<rect x="204" y="76" width="14" height="140" rx="4" fill="#b8875a" {stroke(4)}/>',
        f'<rect x="150" y="78" width="60" height="50" rx="5" fill="#d8ad80" {stroke(4)}/>',
        f'<circle cx="180" cy="103" r="4" fill="{INK}"/>',
        # mug
        f'<rect x="190" y="30" width="24" height="30" rx="5" fill="#f3cf7a" {stroke(3)}/>',
        f'<path d="M214,38 q10,0 10,8 q0,8 -10,8" fill="none" {stroke(3)}/>',
    ]
    return svg(240, 220, "\n".join(p))


def laptop():
    """Drawn separately from the desk (same canvas) so it can jiggle when work is waiting."""
    return svg(240, 220, "\n".join([
        f'<path d="M60,10 h100 l6,48 h-112z" fill="#cfd6e3" {stroke(4)}/>',
        '<path d="M68,18 h84 l4,34 h-92z" fill="#9fd2e8"/>',
        '<path d="M86,30 q8,-8 16,0 M112,30 q8,-8 16,0 M96,42 q12,8 24,0" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>',
        f'<rect x="40" y="56" width="140" height="8" rx="4" fill="#b7c0cf" {stroke(4)}/>']))


def closet():
    """Bubák's little wardrobe, hanging on the wall: a cabinet with a mirror, a hat on top and a scarf peeking out."""
    p = [f'<rect x="10" y="40" width="110" height="136" rx="10" fill="#e9c9a8" {stroke(4)}/>',
         f'<rect x="20" y="52" width="42" height="104" rx="6" fill="#f3dcc2" {stroke(3)}/>',
         f'<rect x="68" y="52" width="42" height="104" rx="6" fill="#f3dcc2" {stroke(3)}/>',
         f'<ellipse cx="89" cy="90" rx="13" ry="20" fill="#cfe6f2" {stroke(3)}/>',
         '<path d="M84,80 l6,-6 M86,90 l8,-8" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>',
         f'<circle cx="57" cy="106" r="3.5" fill="{INK}"/><circle cx="73" cy="106" r="3.5" fill="{INK}"/>',
         f'<path d="M30,52 v14 q0,6 6,8 l-4,30 q6,4 12,0 l-4,-30 q6,-2 6,-8 v-14" fill="#5b8fd0" {stroke(3)}/>',
         # it hangs on the wall: a little ledge underneath instead of legs
         f'<path d="M14,176 h102 l-8,10 h-86z" fill="#c99a6b" {stroke(3)}/>',
         # a little top hat and a heart on top
         f'<rect x="28" y="8" width="26" height="28" rx="3" fill="#3b3443" {stroke(3)}/>',
         '<rect x="28" y="26" width="26" height="5" fill="#e8505b"/>',
         f'<ellipse cx="41" cy="38" rx="20" ry="5" fill="#3b3443" {stroke(3)}/>',
         f'<path d="M88,38 C74,28 76,16 84,16 C87,16 88,19 88,21 C88,19 89,16 92,16 C100,16 102,28 88,38Z" fill="#f08a9c" {stroke(3)}/>']
    return svg(130, 186, "\n".join(p))


def toy_chest():
    """The toy chest: a wooden chest with a lid propped open and toys peeking out."""
    p = [  # the lid, open and leaning back (its inside shows)
         f'<path d="M14,48 L22,8 H128 L136,48z" fill="#a8713f" {stroke(3.5)}/>',
         f'<path d="M26,42 L31,15 H119 L124,42z" fill="#b98250"/>',
         # what peeks out: a willow ball, a carrot plush and a leafy twig
         f'<path d="M88,40 l10,-26 q4,-4 8,0 l-6,28z" fill="#f0913a" {stroke(3)}/>',
         '<path d="M98,16 l-6,-10 M101,15 l2,-11 M104,17 l8,-7" stroke="#6aa84f" stroke-width="3.5" stroke-linecap="round"/>',
         f'<circle cx="52" cy="38" r="16" fill="#d9b26a" {stroke(3)}/>',
         '<path d="M40,30 q12,8 24,0 M38,42 q14,-8 28,0 M52,22 v32" stroke="#a9813f" stroke-width="2.5" fill="none"/>',
         f'<path d="M22,44 q-4,-16 6,-24 M28,22 q6,0 8,6 M24,30 q-8,-2 -10,4" stroke="#7a5a3a" stroke-width="3" fill="none" stroke-linecap="round"/>',
         '<ellipse cx="34" cy="26" rx="6" ry="3.5" fill="#8fc46a" transform="rotate(-30 34 26)"/>',
         # the chest
         f'<rect x="8" y="46" width="134" height="74" rx="10" fill="#c98f58" {stroke(4)}/>',
         '<path d="M14,70 h122 M14,94 h122" stroke="#a8713f" stroke-width="3"/>',
         f'<rect x="8" y="46" width="16" height="74" rx="6" fill="#b07a45" {stroke(3)}/>',
         f'<rect x="126" y="46" width="16" height="74" rx="6" fill="#b07a45" {stroke(3)}/>',
         f'<rect x="64" y="58" width="22" height="18" rx="5" fill="#f2cf5b" {stroke(3)}/>',
         f'<circle cx="75" cy="66" r="3" fill="{INK}"/>',
         # a little heart on the front
         '<path d="M75,104 C66,98 67,90 72,90 C74,90 75,92 75,93 C75,92 76,90 78,90 C83,90 84,98 75,104Z" fill="#f08a9c"/>']
    return svg(150, 124, "\n".join(p))


save("sofa.svg", sofa())
save("desk.svg", desk())
save("laptop.svg", laptop())
save("closet.svg", closet())
save("toy_chest.svg", toy_chest())

# ---- care items ------------------------------------------------------------


def bowl(full):
    p = []
    if full:
        rnd = random.Random(5)
        for _ in range(26):
            x, y = 30 + rnd.random() * 60, 26 + rnd.random() * 14
            p.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="6" ry="4" fill="#9c7a45" {stroke(1.5)}/>')
    p.append(f'<path d="M14,34 h92 q-6,36 -46,36 q-40,0 -46,-36z" fill="#f2b3bd" {stroke(4)}/>')
    p.append(f'<ellipse cx="60" cy="34" rx="46" ry="9" fill="none" {stroke(4)}/>')
    p.append(f'<path d="M48,52 q6,-6 12,0 q6,-6 12,0 q0,8 -12,12 q-12,-4 -12,-12z" fill="#fff" opacity="0.85"/>')
    return svg(120, 76, "\n".join(p))


def water(level):
    p = [f'<path d="M14,30 h92 q-6,36 -46,36 q-40,0 -46,-36z" fill="#a7c0e8" {stroke(4)}/>']
    if level:
        p.append('<ellipse cx="60" cy="31" rx="42" ry="7" fill="#7fd0f0"/>')
        p.append('<path d="M38,30 q8,-3 16,0" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round"/>')
    p.append(f'<ellipse cx="60" cy="30" rx="46" ry="9" fill="none" {stroke(4)}/>')
    p.append('<path d="M60,44 q-7,9 0,14 q7,-5 0,-14z" fill="#fff" opacity="0.85"/>')
    return svg(120, 72, "\n".join(p))


def hayrack(full):
    p = []
    if full:
        rnd = random.Random(9)
        for _ in range(40):
            x1, y1 = 20 + rnd.random() * 100, 30 + rnd.random() * 50
            p.append(f'<path d="M{x1:.0f},{y1:.0f} l{rnd.uniform(-20, 20):.0f},{rnd.uniform(-26, 6):.0f}" '
                     f'stroke="{rnd.choice(["#e6cf7a", "#d4b95b", "#c7d27d"])}" stroke-width="4" stroke-linecap="round"/>')
    p.append(f'<rect x="12" y="36" width="116" height="74" rx="10" fill="none" stroke="#b8875a" stroke-width="9"/>')
    for x in range(30, 128, 20):
        p.append(f'<path d="M{x},38 V108" stroke="#b8875a" stroke-width="6"/>')
    p.append(f'<rect x="12" y="36" width="116" height="74" rx="10" fill="none" {stroke(3)}/>')
    p.append(f'<rect x="6" y="100" width="128" height="24" rx="8" fill="#c99a6b" {stroke(4)}/>')
    return svg(140, 128, "\n".join(p))


def litter(dirty):
    p = [f'<path d="M8,30 h164 l-10,48 h-144z" fill="#9cc5a1" {stroke(4)}/>',
         f'<rect x="4" y="22" width="172" height="14" rx="6" fill="#b3d6b6" {stroke(4)}/>']
    rnd = random.Random(2)
    for _ in range(18):
        x, y = 22 + rnd.random() * 136, 26 + rnd.random() * 6
        p.append(f'<path d="M{x:.0f},{y:.0f} l{rnd.uniform(-10, 10):.0f},-8" stroke="#e6cf7a" stroke-width="3" stroke-linecap="round"/>')
    if dirty:
        for _ in range(9):
            x, y = 26 + rnd.random() * 128, 22 + rnd.random() * 8
            p.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="5" fill="#6b4a33" {stroke(1.5)}/>')
        p.append('<path d="M60,4 q6,6 0,12 M90,0 q6,6 0,12 M120,4 q6,6 0,12" stroke="#9cae6a" '
                 'stroke-width="3" fill="none" stroke-linecap="round" opacity="0.8"/>')
    return svg(180, 84, "\n".join(p))


def cable(state):
    # Plug sits at (40,10) in the sprite, cable snakes down to the floor (y~110)
    p = []
    if state == "covered":
        p.append(f'<path d="M40,18 C40,70 60,96 120,102 L190,104" fill="none" stroke="#fffaf2" stroke-width="20" stroke-linecap="round"/>')
        p.append(f'<path d="M40,18 C40,70 60,96 120,102 L190,104" fill="none" {stroke(3)} opacity="0.6"/>')
        for t in range(6):
            x = 60 + t * 24
            p.append(f'<path d="M{x},{92 + min(t, 3) * 3} v16" stroke="#e2d8c8" stroke-width="3"/>')
    elif state == "chewed":
        p.append(f'<path d="M40,18 C40,70 60,96 104,100" fill="none" stroke="#3b3f4a" stroke-width="7" stroke-linecap="round"/>')
        p.append(f'<path d="M132,102 L190,104" fill="none" stroke="#3b3f4a" stroke-width="7" stroke-linecap="round"/>')
        p.append('<path d="M104,100 l8,-6 M104,100 l8,4 M132,102 l-8,-6 M132,102 l-6,6" stroke="#e8a33b" stroke-width="3" stroke-linecap="round"/>')
        p.append('<path d="M118,84 l4,-10 l4,8 l6,-6" stroke="#f3cf7a" stroke-width="3" fill="none" stroke-linecap="round"/>')
    else:
        p.append(f'<path d="M40,18 C40,70 60,96 120,102 L190,104" fill="none" stroke="#3b3f4a" stroke-width="7" stroke-linecap="round"/>')
    p.append(f'<rect x="28" y="2" width="24" height="20" rx="5" fill="#f4f4f4" {stroke(3)}/>')
    p.append(f'<rect x="184" y="92" width="26" height="22" rx="5" fill="#cfd6e3" {stroke(3)}/>')
    return svg(220, 120, "\n".join(p))


save("bowl.svg", bowl(False))
save("bowl_full.svg", bowl(True))
save("water.svg", water(False))
save("water_full.svg", water(True))
save("hayrack.svg", hayrack(False))
save("hayrack_full.svg", hayrack(True))
save("litter.svg", litter(False))
save("litter_dirty.svg", litter(True))
for s in ("ok", "chewed", "covered"):
    save(f"cable_{s}.svg", cable(s))

save("dropping.svg", svg(24, 18, f'<ellipse cx="12" cy="10" rx="7" ry="6" fill="#6b4a33" {stroke(2)}/>'))

# ---- toys & decor ----------------------------------------------------------


RAINBOW = ["#e8505b", "#f39a3d", "#f6d84a", "#7cc96a", "#4fa3e0", "#8a6fd6", "#e872b8"]


def rainbow_ball(cx, cy, r, w=4, tilt=-28):
    """Bubák's real ball: glossy rainbow stripes wrapping round it."""
    cid = f"rb{cx}{cy}{r}"
    bands = []
    n = len(RAINBOW)
    for i, col in enumerate(RAINBOW):
        y = -r + (2 * r) * (i + 0.5) / n    # band centre
        bend = r * 0.35 * (1 - abs(y) / r)  # stripes curve round the sphere
        bands.append(f'<path d="M{-r - 4},{y - bend:.1f} Q0,{y + bend:.1f} {r + 4},{y - bend:.1f}" fill="none" '
                     f'stroke="{col}" stroke-width="{2 * r / n + 1.5:.1f}"/>')
    hx, hy = cx - r * 0.38, cy - r * 0.42
    return (f'<clipPath id="{cid}"><circle cx="{cx}" cy="{cy}" r="{r}"/></clipPath>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{RAINBOW[3]}"/>'
            f'<g clip-path="url(#{cid})"><g transform="translate({cx},{cy}) rotate({tilt})">{"".join(bands)}</g>'
            f'<circle cx="{cx + r * 0.25}" cy="{cy + r * 0.3}" r="{r}" fill="#3b2a4a" opacity="0.12"/></g>'
            f'<ellipse cx="{hx}" cy="{hy}" rx="{r * 0.24}" ry="{r * 0.14}" transform="rotate(-35 {hx} {hy})" '
            'fill="#fff" opacity="0.75"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{INK}" stroke-width="{w}"/>')


def ball():
    return svg(68, 66, rainbow_ball(34, 34, 28))


def box():
    p = [f'<path d="M10,40 h140 v86 h-140z" fill="#d8a46a" {stroke(5)}/>',
         f'<path d="M10,40 l-8,-26 h60 l8,26z" fill="#e8b97f" {stroke(4)}/>',
         f'<path d="M150,40 l8,-26 h-60 l-8,26z" fill="#e8b97f" {stroke(4)}/>',
         # bunny-shaped door
         f'<path d="M58,126 v-34 q0,-22 22,-22 q22,0 22,22 v34z" fill="#5a3f2c" {stroke(4)}/>',
         f'<path d="M66,74 q-6,-24 2,-30 q8,6 6,28z M94,74 q6,-24 -2,-30 q-8,6 -6,28z" fill="#5a3f2c" {stroke(3)}/>',
         '<path d="M118,62 l14,0 M118,72 l10,0" stroke="#b07c4a" stroke-width="3" stroke-linecap="round"/>']
    return svg(160, 132, "\n".join(p))


def tunnel():
    p = [f'<path d="M40,20 h150 q24,0 24,46 q0,46 -24,46 h-150z" fill="#a7c0e8" {stroke(5)}/>']
    for x in range(60, 190, 26):
        p.append(f'<path d="M{x},22 q8,44 0,88" stroke="#8aa6d6" stroke-width="6" fill="none"/>')
    p.append(f'<ellipse cx="40" cy="66" rx="30" ry="46" fill="#c8d8f2" {stroke(5)}/>')
    p.append(f'<ellipse cx="42" cy="68" rx="20" ry="34" fill="#4c5a78"/>')
    return svg(224, 118, "\n".join(p))


def bed():
    p = [f'<ellipse cx="90" cy="54" rx="84" ry="26" fill="#d8a7d0" {stroke(5)}/>',
         f'<ellipse cx="90" cy="46" rx="62" ry="14" fill="#f3dff0" {stroke(4)}/>',
         '<path d="M60,44 q4,-6 8,0 q4,-6 8,0 q0,6 -8,10 q-8,-4 -8,-10z" fill="#d8a7d0"/>']
    return svg(180, 84, "\n".join(p))


def rug():
    p = [f'<ellipse cx="160" cy="50" rx="154" ry="44" fill="#f3cf7a" {stroke(5)}/>',
         '<ellipse cx="160" cy="50" rx="118" ry="32" fill="none" stroke="#e9a3a0" stroke-width="8"/>',
         '<ellipse cx="160" cy="50" rx="74" ry="19" fill="none" stroke="#9cc5a1" stroke-width="8"/>']
    return svg(320, 100, "\n".join(p))


def plant():
    p = []
    rnd = random.Random(4)
    for i in range(7):
        a = -70 + i * 23
        x2 = 50 + math.sin(math.radians(a)) * 56
        y2 = 70 - math.cos(math.radians(a)) * 64
        p.append(f'<path d="M50,104 Q{50 + (x2 - 50) * 0.2:.0f},{y2 + 20:.0f} {x2:.0f},{y2:.0f}" stroke="#6aa86d" stroke-width="5" fill="none"/>')
        p.append(f'<ellipse cx="{x2:.0f}" cy="{y2:.0f}" rx="14" ry="22" transform="rotate({a} {x2:.0f} {y2:.0f})" fill="#88c48a" {stroke(3)}/>')
    p.append(f'<path d="M22,100 h56 l-8,56 h-40z" fill="#e8986e" {stroke(4)}/>')
    p.append(f'<rect x="18" y="94" width="64" height="14" rx="5" fill="#f0ab83" {stroke(4)}/>')
    return svg(170, 200, '<g transform="translate(35,40)">' + "\n".join(p) + '</g>')


def lamp():
    p = [f'<path d="M14,10 h52 l12,50 h-76z" fill="#f3cf7a" {stroke(4)}/>',
         f'<path d="M40,60 V196" {stroke(5)}/>',
         f'<ellipse cx="40" cy="200" rx="26" ry="8" fill="#c99a6b" {stroke(4)}/>']
    return svg(80, 212, "\n".join(p))


def branch(leaves):
    """A fresh branch lying on the floor. Bubák eats the leaves first, then the bark."""
    p = [f'<path d="M10,52 Q70,40 150,30" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round"/>',
         '<path d="M10,52 Q70,40 150,30" fill="none" stroke="#a9825a" stroke-width="7" stroke-linecap="round"/>',
         f'<path d="M62,44 Q76,30 88,14 M104,38 Q124,40 136,52" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>',
         '<path d="M62,44 Q76,30 88,14 M104,38 Q124,40 136,52" fill="none" stroke="#a9825a" stroke-width="4" stroke-linecap="round"/>']
    spots = [(88, 12, -30), (150, 28, 20), (136, 54, 60), (40, 40, -60), (118, 26, -10), (24, 56, 70), (76, 30, -50)]
    if not leaves:
        # nibbled down to bark: a couple of chewed leaves and pale bite marks
        spots = spots[:2]
        p.append('<path d="M30,49 l6,-2 M48,46 l6,-2 M120,34 l6,-1" stroke="#f1dfc0" stroke-width="3" stroke-linecap="round"/>')
    for x, y, a in spots:
        p.append(f'<ellipse cx="{x}" cy="{y}" rx="9" ry="16" transform="rotate({a} {x} {y})" fill="#88c48a" {stroke(3)}/>')
        p.append(f'<path d="M{x},{y - 10} L{x},{y + 10}" transform="rotate({a} {x} {y})" stroke="#5f9d62" stroke-width="2"/>')
    return svg(170, 84, '<g transform="translate(0,12)">' + "\n".join(p) + '</g>')


save("ball.svg", ball())
save("box.svg", box())
save("tunnel.svg", tunnel())
save("bed.svg", bed())
save("rug.svg", rug())
save("plant.svg", plant())
save("lamp.svg", lamp())
save("branch.svg", branch(True))
save("branch_bare.svg", branch(False))

# ---- balcony ----------------------------------------------------------------


def door(state, inside="balcony"):
    """A glass-paned door, bottom-centre on the floor line.
    state: locked / open. `inside` = what you see through an open doorway."""
    p = [f'<rect x="8" y="8" width="144" height="284" rx="6" fill="#fff8ee" {stroke(5)}/>']
    if state == "open":
        if inside.startswith("balcony"):
            night = inside == "balcony_night"
            p.append(f'<rect x="22" y="22" width="116" height="270" fill="{"#2a3060" if night else "#a7d8f0"}"/>')
            if night:
                p.append('<circle cx="60" cy="60" r="2" fill="#fff8d0"/><circle cx="104" cy="44" r="1.6" fill="#fff8d0"/>'
                         '<circle cx="118" cy="96" r="2" fill="#fff8d0"/>')
            p.append(f'<rect x="22" y="196" width="116" height="96" fill="{"#9a6a58" if night else "#e8a37c"}"/>')
            p.append('<path d="M22,150 H138 M22,168 H138" stroke="#fff8ee" stroke-width="6"/>')
            for x in range(34, 138, 18):
                p.append(f'<path d="M{x},150 V196" stroke="#fff8ee" stroke-width="5"/>')
        else:
            p.append('<rect x="22" y="22" width="116" height="270" fill="#f7e6d0"/>')
            p.append('<rect x="22" y="210" width="116" height="82" fill="#e2bd92"/>')
        p.append(f'<path d="M22,22 L56,40 L56,274 L22,292 Z" fill="#c99a6b" {stroke(4)}/>')
        p.append('<path d="M30,48 L50,56 L50,140 L30,140 Z" fill="#bfe3f2"/>')
    else:
        p.append(f'<rect x="22" y="22" width="116" height="270" fill="#c99a6b" {stroke(4)}/>')
        p.append(f'<rect x="36" y="38" width="88" height="112" rx="4" fill="#bfe3f2" {stroke(3)}/>')
        p.append('<path d="M80,38 V150 M36,94 H124" stroke="#fff8ee" stroke-width="5"/>')
        p.append('<path d="M44,60 l18,-14 M48,76 l26,-22" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity="0.8"/>')
        p.append(f'<rect x="36" y="170" width="88" height="104" rx="4" fill="#b8875a" {stroke(3)}/>')
        p.append(f'<circle cx="120" cy="160" r="7" fill="#f3cf7a" {stroke(3)}/>')
        if state == "locked":
            p.append(f'<path d="M110,176 v-8 a10,10 0 0 1 20,0 v8" fill="none" stroke="#8a8f99" stroke-width="5"/>')
            p.append(f'<rect x="104" y="174" width="32" height="26" rx="5" fill="#f3cf7a" {stroke(3)}/>')
            p.append(f'<circle cx="120" cy="185" r="3.5" fill="{INK}"/><path d="M120,186 v7" {stroke(3)}/>')
    return svg(160, 300, "\n".join(p))


def balcony():
    W, H = 1760, 1040
    fy0 = WALL_Y + BY
    wall_x = 1010 + BX
    p = []
    # distant rooftops (the sky above them is drawn by the game)
    rnd = random.Random(12)
    lit = []
    x = 0
    while x < wall_x:
        w = rnd.randint(90, 170)
        top = fy0 - rnd.randint(210, 330)
        p.append(f'<path d="M{x},{fy0} V{top + 20} L{x + w / 2},{top} L{x + w},{top + 20} V{fy0} Z" fill="#cbb7cc" stroke="#b39db5" stroke-width="3"/>')
        for wy in range(top + 40, fy0 - 30, 34):
            for wx in range(x + 16, x + w - 20, 30):
                if rnd.random() < 0.7:
                    p.append(f'<rect x="{wx}" y="{wy}" width="12" height="16" rx="2" fill="#f7efd8" opacity="0.8"/>')
                    if rnd.random() < 0.55 and wy + 18 < fy0 - 112:   # not behind the railing
                        lit.append((wx, wy))
        x += w + rnd.randint(4, 20)
    p.append(f'<linearGradient id="haze" x1="0" y1="{fy0 - 330}" x2="0" y2="{fy0}" gradientUnits="userSpaceOnUse">'
             '<stop offset="0" stop-color="#ffffff" stop-opacity="0"/>'
             '<stop offset="1" stop-color="#fff4f0" stop-opacity="0.45"/></linearGradient>')
    p.append(f'<rect x="0" y="{fy0 - 330}" width="{wall_x}" height="330" fill="url(#haze)"/>')
    # house wall on the right
    p.append(f'<rect x="{wall_x}" y="0" width="{W - wall_x}" height="{fy0}" fill="#f2dcc2"/>')
    for sx in range(wall_x + 20, W, 64):
        p.append(f'<rect x="{sx}" y="0" width="30" height="{fy0}" fill="#ecd2b4" opacity="0.6"/>')
    p.append(f'<path d="M{wall_x},0 V{fy0}" {stroke(5)}/>')
    # string lights
    p.append(f'<path d="M0,{BY + 60} Q{wall_x / 2},{BY + 150} {wall_x},{BY + 50}" fill="none" stroke="{INK}" stroke-width="3"/>')
    colors = ["#f3cf7a", "#e9a3a0", "#a7c0e8", "#9cc5a1"]
    for i in range(1, 16):
        t = i / 16
        bx = t * wall_x
        by = (1 - t) ** 2 * (BY + 60) + 2 * (1 - t) * t * (BY + 150) + t * t * (BY + 50)
        p.append(f'<ellipse cx="{bx:.0f}" cy="{by + 10:.0f}" rx="7" ry="10" fill="{colors[i % 4]}" {stroke(2.5)}/>')
    # tiled floor
    p.append(f'<rect x="0" y="{fy0}" width="{W}" height="{H - fy0}" fill="#e8a37c"/>')
    for y in range(fy0 + 50, H, 56):
        p.append(f'<path d="M0,{y} H{W}" stroke="#d48c66" stroke-width="3"/>')
    for x in range(0, W, 90):
        p.append(f'<path d="M{x},{fy0} V{H}" stroke="#d48c66" stroke-width="3"/>')
    p.append(f'<linearGradient id="tiledepth" x1="0" y1="{fy0}" x2="0" y2="{H}" gradientUnits="userSpaceOnUse">'
             '<stop offset="0" stop-color="#7a4a36" stop-opacity="0.3"/>'
             '<stop offset="0.15" stop-color="#7a4a36" stop-opacity="0.06"/>'
             '<stop offset="1" stop-color="#fff0e0" stop-opacity="0.1"/></linearGradient>')
    p.append(f'<rect x="0" y="{fy0}" width="{W}" height="{H - fy0}" fill="url(#tiledepth)"/>')
    # railing in front of the rooftops
    ry = fy0 - 110
    p.append(f'<rect x="0" y="{ry}" width="{wall_x}" height="14" rx="6" fill="#fff8ee" {stroke(4)}/>')
    for x in range(20, wall_x, 36):
        p.append(f'<rect x="{x}" y="{ry + 12}" width="10" height="{110 - 12}" fill="#fff8ee" {stroke(3)}/>')
    p.append(f'<rect x="0" y="{fy0 - 6}" width="{W}" height="20" fill="#d9967a"/>')
    p.append(f'<path d="M0,{fy0 - 6} H{W} M0,{fy0 + 14} H{W}" {stroke(4)}/>')
    # balcony netting (bunny-safe!) as a soft mesh over the railing
    for x in range(0, wall_x, 18):
        p.append(f'<path d="M{x},{ry} l18,{110}" stroke="#ffffff" stroke-width="1.5" opacity="0.5"/>')
    global BALCONY_LIT
    BALCONY_LIT = lit
    return svg(W, H, "\n".join(p))


def planter(full):
    p = []
    rnd = random.Random(31)
    n = 9 if full else 4
    for i in range(n):
        x = 30 + i * (140 / max(1, n - 1))
        h = rnd.uniform(36, 60) if full else rnd.uniform(14, 26)
        p.append(f'<path d="M{x:.0f},64 q{rnd.uniform(-8, 8):.0f},{-h / 2:.0f} 0,{-h:.0f}" stroke="#5f9d62" stroke-width="4" fill="none"/>')
        if i % 3 == 1 and full:
            p.append(f'<circle cx="{x:.0f}" cy="{64 - h:.0f}" r="10" fill="#f6dc6e" {stroke(3)}/>')
            p.append(f'<circle cx="{x:.0f}" cy="{64 - h:.0f}" r="4" fill="#e8b84a"/>')
        else:
            for dx, dy in ((-7, 0), (7, 0), (0, -7)):
                p.append(f'<circle cx="{x + dx:.0f}" cy="{64 - h + dy:.0f}" r="7" fill="#7cc27e" {stroke(2.5)}/>')
    p.append(f'<path d="M10,60 h180 l-10,46 h-160 z" fill="#c99a6b" {stroke(4)}/>')
    p.append('<path d="M30,76 h140 M34,92 h132" stroke="#b8875a" stroke-width="3"/>')
    return svg(200, 112, "\n".join(p))


save("door_locked.svg", door("locked"))
save("door_open.svg", door("open"))
save("door_open_night.svg", door("open", inside="balcony_night"))
save("balcony_door.svg", door("open", inside="room"))
save("balcony.svg", balcony())
save("balcony_windows.svg", svg(1760, 1040, "".join(
    f'<rect x="{x - 3}" y="{y - 3}" width="18" height="22" rx="4" fill="#ffcf6e" opacity="0.35"/>'
    f'<rect x="{x}" y="{y}" width="12" height="16" rx="2" fill="#ffe7a6"/>' for x, y in BALCONY_LIT)))
save("planter.svg", planter(True))
save("planter_nibbled.svg", planter(False))
save("sunspot.svg", svg(320, 100, '<ellipse cx="160" cy="50" rx="156" ry="46" fill="#fff6c0" opacity="0.55"/>'
                                   '<ellipse cx="160" cy="50" rx="110" ry="30" fill="#fffbe0" opacity="0.6"/>'))
save("bird.svg", svg(70, 50, f'<path d="M30,22 l-24,-16 l8,24 z" fill="#6e8ab8" {stroke(3)}/>'
                             f'<ellipse cx="36" cy="28" rx="20" ry="14" fill="#8fa9d4" {stroke(3)}/>'
                             f'<path d="M55,26 l10,3 l-10,4 z" fill="#f4a259" {stroke(2)}/>'
                             f'<circle cx="46" cy="24" r="2.5" fill="{INK}"/>'))

# ---- progression: upgraded care items, desk gear, more furniture, accessories ----------

def bowl_t(full, tier):
    W = {2: 150, 3: 170}[tier]
    w = W - 28
    color = {2: "#9fdcc4", 3: "#f3cf7a"}[tier]
    p = []
    if full:
        rnd = random.Random(5 + tier)
        for _ in range(18 + tier * 10):
            x, y = 26 + rnd.random() * (W - 52), 26 + rnd.random() * 14
            p.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="6" ry="4" fill="#9c7a45" {stroke(1.5)}/>')
    p.append(f'<path d="M14,36 h{w} q-6,40 {-w / 2:.0f},40 q{-w / 2:.0f},0 {-w / 2:.0f},-40z" fill="{color}" {stroke(4)}/>')
    p.append(f'<ellipse cx="{W / 2}" cy="36" rx="{w / 2}" ry="10" fill="none" {stroke(4)}/>')
    cx = W / 2
    if tier == 2:   # paw print
        p.append(f'<ellipse cx="{cx}" cy="60" rx="9" ry="7" fill="#fff" opacity="0.9"/>')
        for dx, dy in ((-11, -8), (-4, -13), (4, -13), (11, -8)):
            p.append(f'<circle cx="{cx + dx}" cy="{60 + dy}" r="3.5" fill="#fff" opacity="0.9"/>')
    else:           # little crown with gems
        p.append(f'<path d="M{cx - 18},66 l0,-16 l9,8 l9,-12 l9,12 l9,-8 l0,16 z" fill="#fff8e0" {stroke(2.5)}/>')
        for dx, c in ((-9, "#e9a3a0"), (0, "#a7c0e8"), (9, "#9cc5a1")):
            p.append(f'<circle cx="{cx + dx}" cy="60" r="3" fill="{c}"/>')
    return svg(W, 84, "\n".join(p))


def water_t(level, tier):
    if tier == 2:
        p = [f'<path d="M14,32 h122 q-6,38 -61,38 q-55,0 -61,-38z" fill="#8fb8e8" {stroke(4)}/>']
        if level:
            p.append('<ellipse cx="75" cy="33" rx="57" ry="8" fill="#7fd0f0"/>')
        p.append(f'<ellipse cx="75" cy="32" rx="61" ry="10" fill="none" {stroke(4)}/>')
        p.append('<path d="M66,46 q-7,9 0,14 q7,-5 0,-14z M86,46 q-7,9 0,14 q7,-5 0,-14z" fill="#fff" opacity="0.85"/>')
        return svg(150, 76, "\n".join(p))
    # tier 3: a little drinking fountain
    p = [f'<rect x="66" y="20" width="18" height="60" rx="6" fill="#cfd6e3" {stroke(4)}/>',
         f'<ellipse cx="75" cy="20" rx="16" ry="7" fill="#e6ebf3" {stroke(3)}/>']
    if level:
        p.append('<path d="M75,16 q-30,-14 -42,40 M75,16 q30,-14 42,40" fill="none" stroke="#7fd0f0" stroke-width="5" stroke-linecap="round"/>')
    p.append(f'<path d="M10,70 h130 q-6,44 -65,44 q-59,0 -65,-44z" fill="#a7c0e8" {stroke(4)}/>')
    if level:
        p.append('<ellipse cx="75" cy="71" rx="61" ry="9" fill="#7fd0f0"/>')
    p.append(f'<ellipse cx="75" cy="70" rx="65" ry="11" fill="none" {stroke(4)}/>')
    p.append(f'<rect x="66" y="60" width="18" height="14" rx="4" fill="#cfd6e3" {stroke(3)}/>')
    return svg(150, 120, "\n".join(p))


def hayrack_t(full, tier):
    W = 180
    p = []
    top = 36 if tier == 2 else 52
    if full:
        rnd = random.Random(9 + tier)
        for _ in range(60):
            x1, y1 = 20 + rnd.random() * (W - 40), top - 6 + rnd.random() * 50
            p.append(f'<path d="M{x1:.0f},{y1:.0f} l{rnd.uniform(-20, 20):.0f},{rnd.uniform(-26, 6):.0f}" '
                     f'stroke="{rnd.choice(["#e6cf7a", "#d4b95b", "#c7d27d"])}" stroke-width="4" stroke-linecap="round"/>')
    p.append(f'<rect x="12" y="{top}" width="{W - 24}" height="{110 - top}" rx="10" fill="none" stroke="#b8875a" stroke-width="9"/>')
    for x in range(30, W - 12, 20):
        p.append(f'<path d="M{x},{top + 2} V108" stroke="#b8875a" stroke-width="6"/>')
    p.append(f'<rect x="12" y="{top}" width="{W - 24}" height="{110 - top}" rx="10" fill="none" {stroke(3)}/>')
    p.append(f'<rect x="6" y="100" width="{W - 12}" height="24" rx="8" fill="#c99a6b" {stroke(4)}/>')
    if tier == 3:   # little roof
        p.append(f'<path d="M0,{top + 4} L{W / 2},6 L{W},{top + 4} Z" fill="#e9a3a0" {stroke(4)}/>')
        p.append(f'<path d="M30,{top - 4} L{W / 2},16 L{W - 30},{top - 4}" fill="none" stroke="#f6c9c6" stroke-width="5"/>')
    return svg(W, 128, "\n".join(p))


def litter_t(dirty, tier):
    color, light = {2: ("#a7c0e8", "#c8d8f2"), 3: ("#f2b3bd", "#f8d3d9")}[tier]
    p = []
    if tier == 2:   # high-back corner box
        p.append(f'<path d="M8,60 V22 q0,-16 16,-16 h132 q16,0 16,16 V60 z" fill="{light}" {stroke(4)}/>')
    else:           # with bunny ears on the rim
        p.append(f'<path d="M50,40 q-12,-38 2,-40 q12,4 8,40z M130,40 q12,-38 -2,-40 q-12,4 -8,40z" fill="{color}" {stroke(4)}/>')
        p.append('<path d="M52,36 q-6,-26 2,-30 M128,36 q6,-26 -2,-30" stroke="#fff" stroke-width="4" fill="none" opacity="0.7"/>')
    p.append(f'<path d="M8,56 h164 l-10,48 h-144z" fill="{color}" {stroke(4)}/>')
    p.append(f'<rect x="4" y="48" width="172" height="14" rx="6" fill="{light}" {stroke(4)}/>')
    rnd = random.Random(2)
    for _ in range(18):
        x, y = 22 + rnd.random() * 136, 52 + rnd.random() * 6
        p.append(f'<path d="M{x:.0f},{y:.0f} l{rnd.uniform(-10, 10):.0f},-8" stroke="#e6cf7a" stroke-width="3" stroke-linecap="round"/>')
    if dirty:
        for _ in range(9):
            x, y = 26 + rnd.random() * 128, 48 + rnd.random() * 8
            p.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="5" fill="#6b4a33" {stroke(1.5)}/>')
    return svg(180, 110, "\n".join(p))


for t in (2, 3):
    save(f"bowl_t{t}.svg", bowl_t(False, t))
    save(f"bowl_t{t}_full.svg", bowl_t(True, t))
    save(f"water_t{t}.svg", water_t(False, t))
    save(f"water_t{t}_full.svg", water_t(True, t))
    save(f"hayrack_t{t}.svg", hayrack_t(False, t))
    save(f"hayrack_t{t}_full.svg", hayrack_t(True, t))
    save(f"litter_t{t}.svg", litter_t(False, t))
    save(f"litter_t{t}_dirty.svg", litter_t(True, t))


def desk_v(monitor, coffee):
    base = desk()
    extra = []
    if monitor:
        extra += [f'<rect x="2" y="2" width="56" height="38" rx="4" fill="#3b3f4a" {stroke(3)}/>',
                  '<rect x="7" y="7" width="46" height="28" rx="2" fill="#9fd2e8"/>',
                  '<path d="M14,16 h20 M14,23 h30 M14,30 h14" stroke="#fff" stroke-width="3" stroke-linecap="round"/>',
                  f'<path d="M30,40 v14 M18,58 h24" {stroke(4)}/>']
    if coffee:
        extra += [f'<rect x="182" y="4" width="50" height="56" rx="8" fill="#e9a3a0" {stroke(4)}/>',
                  f'<rect x="190" y="12" width="34" height="12" rx="3" fill="#3b3f4a"/>',
                  f'<rect x="198" y="38" width="18" height="18" rx="3" fill="#fff8ee" {stroke(2.5)}/>',
                  '<path d="M202,32 q3,-5 0,-8 M210,32 q3,-5 0,-8" stroke="#fff" stroke-width="2" fill="none"/>']
    if coffee:   # the coffee machine replaces the mug
        base = base.replace(f'<rect x="190" y="30" width="24" height="30" rx="5" fill="#f3cf7a" {stroke(3)}/>', "")
        base = base.replace(f'<path d="M214,38 q10,0 10,8 q0,8 -10,8" fill="none" {stroke(3)}/>', "")
    return base.replace("\n</svg>", "\n" + "\n".join(extra) + "\n</svg>")


save("desk_m.svg", desk_v(True, False))
save("desk_c.svg", desk_v(False, True))
save("desk_mc.svg", desk_v(True, True))
save("chair.svg", svg(120, 160,   # slim chair, tucked in under the desk
    f'<rect x="36" y="14" width="48" height="66" rx="16" fill="#9cc5a1" {stroke(5)}/>'
    f'<rect x="55" y="80" width="10" height="24" fill="#8a8f99" {stroke(3)}/>'
    f'<rect x="30" y="98" width="60" height="18" rx="9" fill="#88b98d" {stroke(5)}/>'
    f'<path d="M60,116 v20 M38,146 L60,136 L82,146" fill="none" {stroke(5)}/>'
    + "".join(f'<circle cx="{x}" cy="150" r="5.5" fill="#3b3f4a" {stroke(2)}/>' for x in (38, 60, 82))))


def grass_tray(full):
    """A shallow tray of wheatgrass on the balcony. Bubák grazes it short; water it to grow back."""
    rnd = random.Random(12)
    p = []
    n = 26
    for i in range(n):
        x = 18 + i * (124 / (n - 1)) + rnd.uniform(-2, 2)
        h = rnd.uniform(30, 52) if full else rnd.uniform(6, 14)
        lean = rnd.uniform(-8, 8)
        col = ["#7cc27e", "#5f9d62", "#93d38a"][i % 3]
        p.append(f'<path d="M{x:.0f},50 q{lean / 2:.0f},{-h / 2:.0f} {lean:.0f},{-h:.0f}" stroke="{col}" stroke-width="4" '
                 'fill="none" stroke-linecap="round"/>')
    p.append(f'<path d="M6,46 h148 l-8,26 h-132z" fill="#8fb8d8" {stroke(4)}/>')
    p.append('<path d="M18,58 h124" stroke="#a9cbe4" stroke-width="3"/>')
    return svg(160, 78, "\n".join(p))


def bird_feeder(full):
    """A little bird house on a pole with a seed tray."""
    p = [f'<rect x="41" y="60" width="8" height="104" rx="3" fill="#a8713f" {stroke(3)}/>',
         f'<path d="M22,164 h46 l-6,8 h-34z" fill="#8f6038" {stroke(3)}/>',
         f'<rect x="16" y="40" width="58" height="30" rx="4" fill="#e9c9a8" {stroke(3.5)}/>',
         f'<path d="M8,42 L45,10 L82,42z" fill="#e8735f" {stroke(3.5)}/>',
         f'<circle cx="45" cy="54" r="7" fill="#5a3f2c" {stroke(2.5)}/>',
         f'<path d="M10,70 h70 l-4,10 h-62z" fill="#c99a6b" {stroke(3)}/>']
    if full:
        rnd = random.Random(4)
        for _ in range(16):
            p.append(f'<circle cx="{rnd.uniform(18, 72):.0f}" cy="{rnd.uniform(66, 71):.0f}" r="2.6" fill="#e6c36a" '
                     'stroke="#9c7a45" stroke-width="1"/>')
    return svg(90, 176, "\n".join(p))


def lookout():
    """A wooden lookout platform with a ramp, so he can see over the railing."""
    p = [f'<path d="M6,104 L70,44 h14 v60z" fill="#c99a6b" {stroke(4)}/>',
         '<path d="M24,94 l8,-8 M40,80 l8,-8 M56,66 l8,-8" stroke="#a8713f" stroke-width="4" stroke-linecap="round"/>',
         f'<rect x="76" y="40" width="96" height="16" rx="5" fill="#d9a46a" {stroke(4)}/>',
         f'<rect x="84" y="54" width="12" height="52" rx="3" fill="#b07a45" {stroke(3)}/>',
         f'<rect x="152" y="54" width="12" height="52" rx="3" fill="#b07a45" {stroke(3)}/>',
         '<path d="M96,80 L152,62 M96,62 L152,80" stroke="#b07a45" stroke-width="5"/>',
         f'<path d="M150,40 v-30 l22,8 l-22,8" fill="#f2cf5b" {stroke(3)}/>']
    return svg(180, 110, "\n".join(p))


def cool_tile():
    """A cool marble slab to stretch out on when it's hot."""
    p = [f'<path d="M20,6 h120 l16,40 h-152z" fill="#dfe6ee" {stroke(4)}/>',
         '<path d="M40,14 q20,10 10,26 M92,10 q-8,14 18,30 M120,12 q6,10 -2,18" stroke="#b9c6d4" stroke-width="3" fill="none"/>']
    return svg(160, 52, "\n".join(p))


def wind_chime():
    """A wind chime on a shepherd's hook."""
    p = [f'<path d="M20,190 V40 q0,-30 30,-30 q24,0 24,24" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>',
         '<path d="M20,190 V40 q0,-30 30,-30 q24,0 24,24" fill="none" stroke="#7a8796" stroke-width="3" stroke-linecap="round"/>',
         f'<ellipse cx="74" cy="44" rx="22" ry="6" fill="#d9a46a" {stroke(3)}/>']
    for i, (x, h) in enumerate(((58, 46), (68, 60), (80, 54), (90, 40))):
        p.append(f'<path d="M{x},46 v12" stroke="{INK}" stroke-width="1.5"/>')
        p.append(f'<rect x="{x - 3}" y="58" width="7" height="{h}" rx="3" fill="{["#a7c0e8", "#9cc5a1", "#f3cf7a", "#e9a3a0"][i]}" {stroke(2.5)}/>')
    p.append(f'<path d="M74,46 v70" stroke="{INK}" stroke-width="1.5"/>')
    p.append(f'<path d="M66,116 h16 l-4,18 h-8z" fill="#f08a9c" {stroke(2.5)}/>')
    p.append(f'<ellipse cx="20" cy="190" rx="14" ry="4" fill="#8f6038" {stroke(2.5)}/>')
    return svg(110, 198, "\n".join(p))


def parasol():
    """A striped sun umbrella: shade for naps on sunny days."""
    p = [f'<rect x="106" y="60" width="8" height="150" rx="3" fill="#e9e1d4" {stroke(3)}/>',
         f'<ellipse cx="110" cy="210" rx="34" ry="9" fill="#8a96a8" {stroke(3)}/>',
         f'<path d="M10,72 Q110,-6 210,72 Q185,62 160,72 Q135,62 110,72 Q85,62 60,72 Q35,62 10,72z" fill="#fff6e8" {stroke(4)}/>']
    # coloured stripes
    for a, b in ((10, 60), (110, 160)):
        p.append(f'<path d="M{a},72 Q{a + 25},62 {b},72 L110,14 z" fill="#e8735f" opacity="0.9"/>')
    p.append(f'<path d="M10,72 Q110,-6 210,72" fill="none" {stroke(4)}/>')
    p.append(f'<path d="M10,72 Q35,62 60,72 Q85,62 110,72 Q135,62 160,72 Q185,62 210,72" fill="none" {stroke(3.5)}/>')
    p.append(f'<circle cx="110" cy="14" r="6" fill="#f2cf5b" {stroke(3)}/>')
    return svg(220, 222, "\n".join(p))


def butterfly():
    p = [f'<path d="M20,16 C6,0 0,10 4,18 C0,26 10,32 20,20z" fill="#f6a5c0" {stroke(2.5)}/>',
         f'<path d="M22,16 C36,0 42,10 38,18 C42,26 32,32 22,20z" fill="#f6a5c0" {stroke(2.5)}/>',
         '<circle cx="10" cy="12" r="3" fill="#fff"/><circle cx="32" cy="12" r="3" fill="#fff"/>',
         f'<rect x="19" y="8" width="4" height="18" rx="2" fill="{INK}"/>',
         f'<path d="M20,8 l-4,-6 M22,8 l4,-6" stroke="{INK}" stroke-width="1.5" stroke-linecap="round"/>']
    return svg(42, 32, "\n".join(p))


def digbox():
    p = [f'<path d="M8,30 h154 l-8,44 h-138z" fill="#c99a6b" {stroke(4)}/>',
         f'<ellipse cx="85" cy="30" rx="78" ry="12" fill="#f0d79a" {stroke(4)}/>',
         '<path d="M40,28 q10,-10 20,0 M100,30 q12,-12 24,0" stroke="#d9b76a" stroke-width="4" fill="none"/>',
         '<path d="M30,52 h110 M34,64 h102" stroke="#b8875a" stroke-width="3"/>']
    return svg(170, 80, "\n".join(p))


def puzzle():
    p = [f'<rect x="6" y="30" width="138" height="34" rx="10" fill="#d8ad80" {stroke(4)}/>']
    for i, x in enumerate((30, 62, 94, 126)):
        p.append(f'<ellipse cx="{x}" cy="38" rx="13" ry="7" fill="#b8875a" {stroke(3)}/>')
        if i % 2:
            p.append(f'<path d="M{x - 13},34 a13,13 0 0 1 26,0 z" fill="#e9a3a0" {stroke(3)}/>')
    return svg(150, 70, "\n".join(p))


def hut():
    p = [f'<path d="M14,64 L90,8 L166,64 Z" fill="#b8875a" {stroke(5)}/>',
         f'<rect x="24" y="60" width="132" height="84" rx="6" fill="#d8ad80" {stroke(5)}/>',
         '<path d="M24,82 h132 M24,104 h132 M24,126 h132" stroke="#c39467" stroke-width="3"/>',
         f'<path d="M66,144 v-36 a24,24 0 0 1 48,0 v36 z" fill="#5a3f2c" {stroke(4)}/>',
         f'<circle cx="130" cy="88" r="10" fill="#bfe3f2" {stroke(3)}/>']
    return svg(180, 150, "\n".join(p))


def castle():
    p = [f'<rect x="20" y="96" width="160" height="120" fill="#e8b97f" {stroke(5)}/>',
         f'<rect x="54" y="40" width="92" height="60" fill="#e8b97f" {stroke(5)}/>']
    for x in range(20, 180, 32):
        p.append(f'<rect x="{x}" y="84" width="18" height="14" fill="#e8b97f" {stroke(4)}/>')
    for x in range(54, 146, 24):
        p.append(f'<rect x="{x}" y="28" width="14" height="14" fill="#e8b97f" {stroke(4)}/>')
    p += [f'<path d="M80,216 v-40 a20,20 0 0 1 40,0 v40 z" fill="#5a3f2c" {stroke(4)}/>',
          f'<path d="M86,100 v-24 a14,14 0 0 1 28,0 v24 z" fill="#5a3f2c" {stroke(4)}/>',
          f'<path d="M100,28 v-24 l24,8 l-24,8" fill="#e9a3a0" {stroke(3)}/>',
          '<path d="M40,130 l14,0 M150,150 l14,0" stroke="#c48f55" stroke-width="3"/>']
    return svg(200, 220, "\n".join(p))


def teepee():
    p = [f'<path d="M90,8 L10,180 H170 Z" fill="#fff3dc" {stroke(5)}/>',
         '<path d="M58,76 H122 M40,116 H140" stroke="#e9a3a0" stroke-width="10"/>',
         '<path d="M50,96 H130" stroke="#a7c0e8" stroke-width="8"/>',
         f'<path d="M90,70 L58,180 H122 Z" fill="#5a3f2c" {stroke(4)}/>',
         f'<path d="M78,0 L90,20 L102,0" fill="none" {stroke(4)}/>']
    return svg(180, 186, "\n".join(p))


def beanbag():
    p = [wobble_ellipse(90, 74, 80, 40, 0, "#a7c0e8", seed=41),
         wobble_ellipse(84, 56, 50, 22, -8, "#c8d8f2", w=0, seed=42, extra='opacity="0.8"'),
         '<path d="M40,90 q50,16 100,0" stroke="#8aa6d6" stroke-width="4" fill="none"/>']
    return svg(180, 120, "\n".join(p))


def lantern():
    p = [f'<path d="M40,60 V196" {stroke(4)}/>',
         f'<ellipse cx="40" cy="200" rx="22" ry="7" fill="#c99a6b" {stroke(4)}/>',
         wobble_ellipse(40, 40, 30, 36, 0, "#f6dc6e", seed=43),
         '<path d="M14,30 q26,8 52,0 M12,46 q28,8 56,0" stroke="#e8b84a" stroke-width="3" fill="none"/>',
         f'<rect x="30" y="0" width="20" height="8" rx="3" fill="#e9a3a0" {stroke(3)}/>']
    return svg(80, 210, "\n".join(p))


def flowers():
    p = []
    for x, y, c in ((30, 30, "#e9a3a0"), (52, 18, "#f6dc6e"), (72, 32, "#d8a7d0"), (44, 44, "#a7c0e8")):
        p.append(f'<path d="M{x},{y} Q50,60 50,70" stroke="#5f9d62" stroke-width="4" fill="none"/>')
        for a in range(0, 360, 72):
            dx, dy = math.cos(math.radians(a)) * 8, math.sin(math.radians(a)) * 8
            p.append(f'<circle cx="{x + dx:.1f}" cy="{y + dy:.1f}" r="6" fill="{c}" {stroke(2)}/>')
        p.append(f'<circle cx="{x}" cy="{y}" r="4" fill="#fff4cf"/>')
    p.append(f'<path d="M24,70 h52 l-8,40 h-36z" fill="#9cc5a1" {stroke(4)}/>')
    return svg(100, 114, "\n".join(p))


save("digbox.svg", digbox())
save("grass_tray.svg", grass_tray(True))
save("grass_tray_short.svg", grass_tray(False))
save("bird_feeder.svg", bird_feeder(True))
save("bird_feeder_empty.svg", bird_feeder(False))
save("lookout.svg", lookout())
save("cool_tile.svg", cool_tile())
save("wind_chime.svg", wind_chime())
save("parasol.svg", parasol())
save("butterfly.svg", butterfly())
save("puzzle.svg", puzzle())
save("hut.svg", hut())
save("castle.svg", castle())
save("teepee.svg", teepee())
save("beanbag.svg", beanbag())
save("lantern.svg", lantern())
save("flowers.svg", flowers())

# accessories, drawn at Bubák's scale (his head is ~85 px wide in the sprite)
save("wear_bow.svg", svg(56, 36,
    f'<path d="M28,18 L6,4 Q0,18 6,32 Z M28,18 L50,4 Q56,18 50,32 Z" fill="#e8505b" {stroke(3)}/>'
    f'<circle cx="28" cy="18" r="7" fill="#f07a83" {stroke(3)}/>'))
save("wear_glasses.svg", svg(60, 26,
    f'<circle cx="16" cy="13" r="10" fill="#ffffff" fill-opacity="0.25" {stroke(3.5)}/>'
    f'<circle cx="44" cy="13" r="10" fill="#ffffff" fill-opacity="0.25" {stroke(3.5)}/>'
    f'<path d="M26,12 q4,-4 8,0" fill="none" {stroke(3)}/>'))
save("wear_glasses_side.svg", svg(56, 26,
    f'<path d="M30,12 L2,8" {stroke(3.5)}/>'
    f'<circle cx="41" cy="13" r="11" fill="#ffffff" fill-opacity="0.3" {stroke(3.5)}/>'))
save("wear_crown.svg", svg(96, 40, "".join(
    f'<circle cx="{10 + i * 15}" cy="{22 - 6 * math.sin(i / 5 * math.pi):.0f}" r="8" fill="{c}" {stroke(2.5)}/>'
    f'<circle cx="{10 + i * 15}" cy="{22 - 6 * math.sin(i / 5 * math.pi):.0f}" r="3" fill="#fff4cf"/>'
    for i, c in enumerate(["#e9a3a0", "#f6dc6e", "#d8a7d0", "#a7c0e8", "#f6dc6e", "#e9a3a0"]))))
save("wear_tophat.svg", svg(56, 60,
    f'<rect x="12" y="4" width="32" height="44" rx="4" fill="#3b3443" {stroke(3.5)}/>'
    f'<rect x="12" y="34" width="32" height="8" fill="#e8505b"/>'
    f'<ellipse cx="28" cy="50" rx="26" ry="7" fill="#3b3443" {stroke(3.5)}/>'))

save("wear_beanie.svg", svg(92, 52,
    f'<path d="M8,40 Q8,6 46,6 Q84,6 84,40 Z" fill="#7fb0d8" {stroke(3.5)}/>'
    + "".join(f'<path d="M{20 + i * 13},{14 if i in (0, 4) else 10} V38" stroke="#6a98c0" stroke-width="3" stroke-linecap="round"/>' for i in range(5))
    + f'<rect x="4" y="36" width="84" height="12" rx="6" fill="#f2f2ee" {stroke(3.5)}/>'
    f'<circle cx="46" cy="7" r="7" fill="#f2f2ee" {stroke(3)}/>'))
save("wear_daisy.svg", svg(36, 36,
    "".join(f'<ellipse cx="{18 + 9 * math.cos(math.radians(a)):.1f}" cy="{18 + 9 * math.sin(math.radians(a)):.1f}" rx="6" ry="4" '
            f'transform="rotate({a} {18 + 9 * math.cos(math.radians(a)):.1f} {18 + 9 * math.sin(math.radians(a)):.1f})" fill="#ffffff" {stroke(2)}/>'
            for a in range(0, 360, 45))
    + f'<circle cx="18" cy="18" r="6" fill="#f6dc6e" {stroke(2.5)}/>'))
STAR = "M18,2 L22.5,12.5 L34,13.5 L25,21 L28,32.5 L18,26.5 L8,32.5 L11,21 L2,13.5 L13.5,12.5 Z"
save("wear_starclip.svg", svg(36, 36,
    f'<path d="{STAR}" fill="#f3cf7a" stroke="#4f3d33" stroke-width="2.5" stroke-linejoin="round"/>'
    '<path d="M14,12 l3,-4" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>'))


def specs(lens, tint, op, side=False):
    """Glasses: front view (for icons) or side view (as worn, facing right)."""
    if side:
        return svg(56, 26, f'<path d="M30,12 L2,8" {stroke(3.5)}/>' + lens(41, 13, tint, op))
    return svg(60, 26, lens(16, 13, tint, op) + lens(44, 13, tint, op) + f'<path d="M26,12 q4,-4 8,0" fill="none" {stroke(3)}/>')


def round_lens(x, y, tint, op):
    return f'<circle cx="{x}" cy="{y}" r="11" fill="{tint}" fill-opacity="{op}" {stroke(3.5)}/>'


def shade_lens(x, y, tint, op):
    return (f'<path d="M{x - 12},{y - 7} h24 q0,16 -12,16 q-12,0 -12,-16z" fill="{tint}" fill-opacity="{op}" {stroke(3.5)}/>'
            f'<path d="M{x - 6},{y - 3} l5,0" stroke="#fff" stroke-width="2.5" stroke-linecap="round" opacity="0.7"/>')


def heart_lens(x, y, tint, op):
    return (f'<path d="M{x},{y + 11} C{x - 15},{y + 2} {x - 13},{y - 11} {x - 6},{y - 10} C{x - 3},{y - 10} {x},{y - 7} {x},{y - 5} '
            f'C{x},{y - 7} {x + 3},{y - 10} {x + 6},{y - 10} C{x + 13},{y - 11} {x + 15},{y + 2} {x},{y + 11}Z" '
            f'fill="{tint}" fill-opacity="{op}" {stroke(3)}/>')


save("wear_sunglasses.svg", specs(shade_lens, "#2f2a36", 0.92))
save("wear_sunglasses_side.svg", specs(shade_lens, "#2f2a36", 0.92, True))
save("wear_heartglasses.svg", specs(heart_lens, "#f08a9c", 0.75))
save("wear_heartglasses_side.svg", specs(heart_lens, "#f08a9c", 0.75, True))
save("wear_bandana.svg", svg(72, 46,
    f'<path d="M4,6 Q36,16 68,6 L40,42 Q36,46 32,42 Z" fill="#5b8fd0" {stroke(3.5)}/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="2.5" fill="#fff"/>' for x, y in ((22, 16), (36, 20), (50, 16), (30, 28), (42, 28), (36, 36)))))
save("wear_bowtie.svg", svg(48, 28,
    f'<path d="M24,14 L4,3 Q0,14 4,25 Z M24,14 L44,3 Q48,14 44,25 Z" fill="#3b3443" {stroke(3)}/>'
    f'<rect x="19" y="8" width="10" height="12" rx="3" fill="#e8505b" {stroke(2.5)}/>'))
save("wear_pearls.svg", svg(74, 34,
    "".join(f'<circle cx="{37 + 30 * math.cos(math.radians(a)):.1f}" cy="{4 + 24 * math.sin(math.radians(a)):.1f}" r="5" '
            f'fill="#fbf6ee" stroke="#4f3d33" stroke-width="2"/>' for a in range(15, 170, 15))
    + '<circle cx="37" cy="31" r="3" fill="#ffffff" opacity="0.8"/>'))

ICONS_EXTRA = {
    "bug": f'<ellipse cx="32" cy="36" rx="16" ry="20" fill="#7a9a5a" {stroke(4)}/>'
           f'<circle cx="32" cy="14" r="8" fill="#5f7a44" {stroke(3)}/>'
           '<path d="M16,28 l-10,-6 M16,38 l-12,0 M16,48 l-10,6 M48,28 l10,-6 M48,38 l12,0 M48,48 l10,6" stroke="#4f3d33" stroke-width="3.5" stroke-linecap="round"/>'
           '<path d="M32,18 v36" stroke="#4f3d33" stroke-width="3"/>',
    "ladybug": f'<circle cx="32" cy="36" r="20" fill="#e8505b" {stroke(4)}/>'
               f'<path d="M14,26 a20,12 0 0 1 36,0 z" fill="#3b3443" {stroke(3)}/>'
               '<path d="M32,26 v30" stroke="#3b3443" stroke-width="3"/>'
               + "".join(f'<circle cx="{x}" cy="{y}" r="4" fill="#3b3443"/>' for x, y in ((22, 38), (42, 38), (25, 50), (39, 50))),
    "splat": f'<path d="M32,10 l6,12 l14,-6 l-6,14 l14,6 l-14,6 l6,14 l-14,-6 l-6,12 l-6,-12 l-14,6 l6,-14 l-14,-6 l14,-6 l-6,-14 l14,6z" fill="#b7d27d" {stroke(3)}/>',
    "card_back": f'<rect x="6" y="4" width="52" height="56" rx="8" fill="#e9a3a0" {stroke(4)}/>'
                 f'<rect x="12" y="10" width="40" height="44" rx="5" fill="none" stroke="#fff" stroke-width="3"/>'
                 '<ellipse cx="32" cy="38" rx="7" ry="6" fill="#fff"/>'
                 + "".join(f'<circle cx="{x}" cy="{y}" r="3" fill="#fff"/>' for x, y in ((23, 30), (28, 25), (36, 25), (41, 30))),
    "nod": f'<path d="M14,30 h10 v26 h-10z" fill="#f7cdb0" {stroke(3)}/>'
           f'<path d="M24,30 l10,-18 q6,-4 8,4 l-4,12 h14 q6,2 4,8 l-4,16 q-2,6 -8,6 h-20z" fill="#f7cdb0" {stroke(3)}/>',
    "mic": f'<rect x="22" y="6" width="20" height="32" rx="10" fill="#a7c0e8" {stroke(4)}/>'
           f'<path d="M14,30 q0,16 18,16 q18,0 18,-16 M32,46 v10 M22,58 h20" fill="none" {stroke(4)}/>',
    "laugh": f'<circle cx="32" cy="32" r="24" fill="#f6dc6e" {stroke(4)}/>'
             f'<path d="M20,26 q4,-6 8,0 M36,26 q4,-6 8,0" fill="none" {stroke(3)}/>'
             f'<path d="M18,36 q14,20 28,0 z" fill="#c9605f" {stroke(3)}/>',
    "chair": f'<rect x="18" y="4" width="28" height="28" rx="8" fill="#9cc5a1" {stroke(3)}/>'
             f'<rect x="12" y="34" width="40" height="10" rx="5" fill="#88b98d" {stroke(3)}/>'
             f'<path d="M32,44 v8 M18,58 L32,52 L46,58" fill="none" {stroke(3)}/>',
    "monitor": f'<rect x="6" y="8" width="52" height="34" rx="4" fill="#3b3f4a" {stroke(3)}/>'
               '<rect x="11" y="13" width="42" height="24" rx="2" fill="#9fd2e8"/>'
               f'<path d="M32,42 v10 M20,56 h24" {stroke(4)}/>',
    "coffee": f'<rect x="14" y="20" width="30" height="34" rx="6" fill="#fff8ee" {stroke(4)}/>'
              f'<path d="M44,28 q10,0 10,8 q0,8 -10,8" fill="none" {stroke(4)}/>'
              '<path d="M22,14 q4,-6 0,-10 M32,14 q4,-6 0,-10" stroke="#c9b6a0" stroke-width="3" fill="none"/>',
    "headphones": f'<path d="M12,40 v-8 a20,20 0 0 1 40,0 v8" fill="none" {stroke(5)}/>'
                  f'<rect x="6" y="36" width="14" height="20" rx="5" fill="#d8a7d0" {stroke(3)}/>'
                  f'<rect x="44" y="36" width="14" height="20" rx="5" fill="#d8a7d0" {stroke(3)}/>',
    "career": f'<rect x="8" y="20" width="48" height="34" rx="6" fill="#c99a6b" {stroke(4)}/>'
              f'<path d="M24,20 v-6 h16 v6" fill="none" {stroke(4)}/><path d="M8,34 h48" {stroke(3)}/>',
    "cozy": f'<path d="M8,30 L32,8 L56,30" fill="none" {stroke(5)}/>'
            f'<rect x="14" y="28" width="36" height="28" rx="3" fill="#f3cf7a" {stroke(4)}/>'
            '<path d="M26,42 q3,-4 6,0 q3,-4 6,0 q0,4 -6,8 q-6,-4 -6,-8z" fill="#e8505b"/>',
    "goal": f'<path d="M16,58 V6" {stroke(5)}/>'
            f'<path d="M16,8 h34 l-8,10 l8,10 h-34z" fill="#e9a3a0" {stroke(4)}/>',
    "gift": f'<rect x="10" y="26" width="44" height="30" rx="4" fill="#d8a7d0" {stroke(4)}/>'
            f'<rect x="6" y="18" width="52" height="12" rx="3" fill="#e9b8e0" {stroke(4)}/>'
            '<path d="M32,18 v38" stroke="#f6dc6e" stroke-width="6"/>'
            f'<path d="M32,18 q-14,-14 -16,-2 q2,4 16,2 q14,2 16,-2 q-2,-12 -16,2z" fill="#f6dc6e" {stroke(3)}/>',
    "lock": f'<path d="M20,28 v-8 a12,12 0 0 1 24,0 v8" fill="none" stroke="#8a8f99" stroke-width="6"/>'
            f'<rect x="12" y="28" width="40" height="30" rx="6" fill="#f3cf7a" {stroke(4)}/>'
            f'<circle cx="32" cy="41" r="4" fill="{INK}"/>',
}

# ---- you (the owner), for selfies ------------------------------------------------
SKIN = "#f4cba8"
HAIR = "#6b4a33"


def owner():
    """Head and shoulders, front view, one arm raised off-frame holding the phone."""
    p = [
        # raised arm (holding the phone, out of frame on the left)
        f'<path d="M70,420 L8,250 L-40,262 L20,430 Z" fill="#8fb8c9" {stroke(5)}/>',
        # shoulders / sweater
        f'<path d="M24,430 Q30,318 180,306 Q330,318 336,430 Z" fill="#8fb8c9" {stroke(5)}/>',
        f'<path d="M150,312 q30,26 60,0" fill="none" {stroke(4)}/>',
        f'<rect x="156" y="262" width="48" height="52" rx="18" fill="{SKIN}" {stroke(4)}/>',
        # hair behind
        wobble_ellipse(180, 178, 108, 112, 0, HAIR, seed=21),
        # ears
        f'<ellipse cx="84" cy="196" rx="14" ry="20" fill="{SKIN}" {stroke(4)}/>',
        f'<ellipse cx="276" cy="196" rx="14" ry="20" fill="{SKIN}" {stroke(4)}/>',
        wobble_ellipse(180, 192, 92, 98, 0, SKIN, seed=22),
        # bangs
        f'<path d="M88,170 Q96,82 180,80 Q266,82 272,168 Q236,120 196,128 Q150,112 120,140 Q100,150 88,170 Z" fill="{HAIR}" {stroke(4)}/>',
        # happy closed eyes, blush, big smile
        f'<path d="M126,196 q16,-16 32,0 M202,196 q16,-16 32,0" fill="none" {stroke(5)}/>',
        f'<ellipse cx="122" cy="226" rx="16" ry="9" fill="{BLUSH}" opacity="0.55"/>',
        f'<ellipse cx="238" cy="226" rx="16" ry="9" fill="{BLUSH}" opacity="0.55"/>',
        f'<path d="M156,236 q24,30 48,0 z" fill="#c9605f" {stroke(4)}/>',
        '<path d="M166,246 q14,10 28,0" fill="none" stroke="#f2a0a6" stroke-width="5" stroke-linecap="round"/>',
    ]
    return svg(360, 430, "\n".join(p))


def owner_hand():
    """The other arm, coming up from below to cradle Bubák."""
    p = [
        f'<path d="M30,200 Q36,120 92,96 L134,120 Q96,150 92,200 Z" fill="#8fb8c9" {stroke(5)}/>',
        f'<path d="M78,108 Q100,58 160,62 Q186,66 178,84 Q150,86 134,96 Q120,118 96,124 Z" fill="{SKIN}" {stroke(4)}/>',
        f'<path d="M150,64 q10,-12 22,-6 M160,72 q12,-8 20,0" fill="none" {stroke(3)}/>',
    ]
    return svg(200, 200, "\n".join(p))


save("owner.svg", owner())
save("owner_hand.svg", owner_hand())

# ---- icons (64x64) ---------------------------------------------------------
ICONS = {
    "coin": f'<circle cx="32" cy="32" r="24" fill="#f3cf7a" {stroke(4)}/><circle cx="32" cy="32" r="15" fill="none" stroke="#e0ad4a" stroke-width="4"/>'
            f'<path d="M26,26 q6,-6 12,0 q-12,8 0,12 q-6,6 -12,0" fill="none" stroke="#c48a2c" stroke-width="3" stroke-linecap="round"/>',
    "heart": f'<path d="M32,54 C8,38 8,14 22,12 C28,11 31,16 32,20 C33,16 36,11 42,12 C56,14 56,38 32,54Z" fill="#f08a9c" {stroke(4)}/>'
             '<ellipse cx="22" cy="22" rx="5" ry="3" fill="#fff" opacity="0.7"/>',
    "camera": f'<rect x="8" y="18" width="48" height="34" rx="8" fill="#a7c0e8" {stroke(4)}/>'
              f'<path d="M22,18 l4,-7 h12 l4,7" fill="#a7c0e8" {stroke(4)}/>'
              f'<circle cx="32" cy="35" r="10" fill="#fff" {stroke(4)}/><circle cx="32" cy="35" r="4" fill="{INK}"/>',
    "carrot": f'<path d="M16,50 L44,20 q8,6 4,14 z" fill="#f4a259" {stroke(4)}/>'
              '<path d="M44,20 l4,-12 M46,22 l12,-6 M45,21 l10,-10" stroke="#6aa86d" stroke-width="5" stroke-linecap="round"/>'
              '<path d="M28,40 l5,3 M34,33 l5,3" stroke="#d07f3a" stroke-width="3" stroke-linecap="round"/>',
    "apple": f'<path d="M8,30 a24,24 0 0 0 48,0 z" fill="#d9534f" {stroke(4)}/>'
             '<path d="M13,30 a19,19 0 0 0 38,0 z" fill="#fbf1d3"/>'
             '<ellipse cx="26" cy="38" rx="2.5" ry="4" fill="#6b4a33"/><ellipse cx="38" cy="38" rx="2.5" ry="4" fill="#6b4a33"/>'
             f'<path d="M8,30 h48" {stroke(4)}/>'
             '<path d="M32,28 q0,-8 3,-14" fill="none" stroke="#6b4a33" stroke-width="3" stroke-linecap="round"/>'
             '<ellipse cx="42" cy="14" rx="8" ry="4.5" transform="rotate(-20 42 14)" fill="#88c48a" stroke="#4f3d33" stroke-width="2.5"/>',
    "parsley": '<path d="M32,56 V28 M32,40 L18,24 M32,40 L46,24" stroke="#4f8a52" stroke-width="4" stroke-linecap="round"/>'
               f'<circle cx="32" cy="20" r="10" fill="#7cc27e" {stroke(3)}/><circle cx="17" cy="22" r="9" fill="#7cc27e" {stroke(3)}/>'
               f'<circle cx="47" cy="22" r="9" fill="#7cc27e" {stroke(3)}/>',
    "pellets": f'<path d="M12,22 h40 l-4,32 h-32z" fill="#c9b8e8" {stroke(4)}/>'
               '<ellipse cx="25" cy="34" rx="5" ry="3.5" fill="#9c7a45"/><ellipse cx="37" cy="40" rx="5" ry="3.5" fill="#9c7a45"/>'
               '<ellipse cx="30" cy="46" rx="5" ry="3.5" fill="#9c7a45"/>'
               f'<rect x="10" y="14" width="44" height="10" rx="4" fill="#b3a2d8" {stroke(4)}/>',
    "hay": ''.join(f'<path d="M{18 + i * 4},54 L{12 + i * 6},{12 + (i % 3) * 5}" stroke="{c}" stroke-width="5" stroke-linecap="round"/>'
                   for i, c in enumerate(["#e6cf7a", "#d4b95b", "#c7d27d", "#e6cf7a", "#d4b95b", "#c7d27d", "#e6cf7a"]))
           + f'<path d="M16,40 h34" {stroke(5)}/>',
    "food": f'<path d="M10,30 h44 q-3,20 -22,20 q-19,0 -22,-20z" fill="#f2b3bd" {stroke(4)}/>'
            '<ellipse cx="24" cy="26" rx="5" ry="3.5" fill="#9c7a45"/><ellipse cx="36" cy="25" rx="5" ry="3.5" fill="#9c7a45"/>'
            '<ellipse cx="30" cy="21" rx="5" ry="3.5" fill="#9c7a45"/>',
    "water": f'<path d="M32,8 C22,24 14,32 14,40 a18,18 0 0 0 36,0 C50,32 42,24 32,8Z" fill="#7fd0f0" {stroke(4)}/>'
             '<path d="M24,40 q0,8 8,10" stroke="#fff" stroke-width="4" fill="none" stroke-linecap="round"/>',
    "energy": f'<path d="M36,8 A24,24 0 1 0 56,40 A19,19 0 0 1 36,8Z" fill="#c9b8e8" {stroke(4)}/>'
              '<path d="M42,14 h9 l-9,10 h9" fill="none" stroke="#8f7cc8" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>',
    # fun: Bubák laughing, with a sparkle (happy = having fun)
    "fun": (f'<ellipse cx="22" cy="16" rx="6" ry="13" transform="rotate(-14 22 16)" fill="{FUR}" {stroke(3.5)}/>'
            f'<ellipse cx="22" cy="17" rx="2.6" ry="8" transform="rotate(-14 22 17)" fill="{PINK}"/>'
            f'<ellipse cx="41" cy="16" rx="6" ry="13" transform="rotate(16 41 16)" fill="{FUR}" {stroke(3.5)}/>'
            f'<ellipse cx="41" cy="17" rx="2.6" ry="8" transform="rotate(16 41 17)" fill="{PINK}"/>'
            f'<ellipse cx="32" cy="38" rx="21" ry="18" fill="{FUR}" {stroke(4)}/>'
            f'<ellipse cx="32" cy="46" rx="11" ry="7.5" fill="{CREAM}"/>'
            f'<path d="M20,34 q4,-6 8,0 M36,34 q4,-6 8,0" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>'
            f'<path d="M25,43 q7,11 14,0 z" fill="#c9566e" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>'
            f'<ellipse cx="17" cy="42" rx="4" ry="2.6" fill="{BLUSH}" opacity="0.85"/>'
            f'<ellipse cx="47" cy="42" rx="4" ry="2.6" fill="{BLUSH}" opacity="0.85"/>'
            f'<path d="M54,4 l2.5,6 l6,2.5 l-6,2.5 l-2.5,6 l-2.5,-6 l-6,-2.5 l6,-2.5z" fill="#f6d84a" stroke="{INK}" stroke-width="2"/>'),
    "clean": f'<path d="M32,8 l6,16 l16,6 l-16,6 l-6,16 l-6,-16 l-16,-6 l16,-6z" fill="#a7e0e0" {stroke(4)}/>'
             f'<path d="M50,44 l3,7 l7,3 l-7,3 l-3,7 l-3,-7 l-7,-3 l7,-3z" fill="#fff" {stroke(2)}/>',
    "shop": f'<path d="M12,24 h40 l-4,30 h-32z" fill="#e9a3a0" {stroke(4)}/>'
            f'<path d="M22,26 v-6 a10,10 0 0 1 20,0 v6" fill="none" {stroke(4)}/>',
    "journal": f'<rect x="12" y="8" width="40" height="48" rx="6" fill="#9cc5a1" {stroke(4)}/>'
               f'<path d="M20,8 v48" {stroke(3)}/>'
               '<path d="M33,30 q3,-4 6,0 q3,-4 6,0 q0,4 -6,8 q-6,-4 -6,-8z" fill="#fff"/>',
    "eye": f'<path d="M4,32 q28,-30 56,0 q-28,30 -56,0z" fill="#fff" {stroke(4)}/>'
           f'<circle cx="32" cy="32" r="10" fill="#7fb2d9" {stroke(3)}/><circle cx="32" cy="32" r="4" fill="{INK}"/>',
    "eye_off": f'<path d="M4,32 q28,-30 56,0 q-28,30 -56,0z" fill="#fff" {stroke(4)}/>'
               f'<circle cx="32" cy="32" r="10" fill="#7fb2d9" {stroke(3)}/><circle cx="32" cy="32" r="4" fill="{INK}"/>'
               '<path d="M12,52 L52,12" stroke="#e8505b" stroke-width="6" stroke-linecap="round"/>',
    "move": f'<path d="M32,6 l9,10 h-6 v13 h13 v-6 l10,9 l-10,9 v-6 h-13 v13 h6 l-9,10 l-9,-10 h6 v-13 h-13 v6 l-10,-9 l10,-9 v6 h13 v-13 h-6z" fill="#f3cf7a" {stroke(3)}/>',
    "treat": f'<path d="M16,50 L44,20 q8,6 4,14 z" fill="#f4a259" {stroke(4)}/>'
             '<path d="M44,20 l4,-12 M46,22 l12,-6" stroke="#6aa86d" stroke-width="5" stroke-linecap="round"/>'
             f'<path d="M10,14 q3,-4 6,0 q3,-4 6,0 q0,4 -6,8 q-6,-4 -6,-8z" fill="#f08a9c" {stroke(2)}/>',
    "work": f'<path d="M10,14 h44 v30 h-44z" fill="#cfd6e3" {stroke(4)}/><path d="M15,19 h34 v20 h-34z" fill="#9fd2e8"/>'
            f'<rect x="4" y="44" width="56" height="8" rx="4" fill="#b7c0cf" {stroke(4)}/>',
    "star": f'<path d="M32,6 l7,16 l17,2 l-13,11 l4,17 l-15,-9 l-15,9 l4,-17 l-13,-11 l17,-2z" fill="#f6dc6e" {stroke(3)}/>',
    "follower": f'<circle cx="32" cy="22" r="11" fill="#d8a7d0" {stroke(4)}/>'
                f'<path d="M12,54 q0,-20 20,-20 q20,0 20,20z" fill="#d8a7d0" {stroke(4)}/>',
    "close": f'<circle cx="32" cy="32" r="24" fill="#e9a3a0" {stroke(4)}/>'
             '<path d="M23,23 L41,41 M41,23 L23,41" stroke="#fff" stroke-width="6" stroke-linecap="round"/>',
    "paw": f'<ellipse cx="32" cy="40" rx="14" ry="12" fill="{FUR}" {stroke(3)}/>'
           + ''.join(f'<circle cx="{x}" cy="{y}" r="6" fill="{FUR}" {stroke(3)}/>' for x, y in ((16, 24), (27, 16), (38, 16), (49, 24)))
           + f'<ellipse cx="32" cy="42" rx="7" ry="5" fill="{PINK}"/>',
    "task": f'<rect x="10" y="10" width="44" height="44" rx="10" fill="#a7c0e8" {stroke(4)}/>'
            '<path d="M20,32 l8,8 l16,-18" stroke="#fff" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    "dandelion": '<path d="M32,58 V30 M32,46 q-12,-2 -16,-14 M32,40 q12,-2 16,-12" stroke="#6aa86d" stroke-width="4" fill="none" stroke-linecap="round"/>'
                 '<path d="M16,32 q-6,-8 -2,-14 q6,4 6,12z M48,28 q8,-6 6,-14 q-8,2 -9,10z" fill="#88c48a" stroke="#4f3d33" stroke-width="2.5"/>'
                 + "".join(f'<ellipse cx="{32 + 10 * math.cos(math.radians(a)):.1f}" cy="{18 + 10 * math.sin(math.radians(a)):.1f}" rx="5" ry="3" '
                           f'transform="rotate({a} {32 + 10 * math.cos(math.radians(a)):.1f} {18 + 10 * math.sin(math.radians(a)):.1f})" fill="#f6dc6e" stroke="#4f3d33" stroke-width="2"/>'
                           for a in range(0, 360, 40))
                 + '<circle cx="32" cy="18" r="6" fill="#f3b94a" stroke="#4f3d33" stroke-width="2.5"/>',
    "hay_cookie": f'<path d="M32,56 C6,40 6,16 20,12 C26,10 30,14 32,19 C34,14 38,10 44,12 C58,16 58,40 32,56Z" fill="#e2bd78" {stroke(4)}/>'
                  + "".join(f'<path d="M{x},{y} l6,{d}" stroke="#b58a45" stroke-width="2.5" stroke-linecap="round"/>'
                            for x, y, d in ((20, 24, 3), (30, 30, -3), (38, 24, 4), (24, 38, -2), (36, 40, 3), (44, 32, -3)))
                  + '<circle cx="27" cy="34" r="2.5" fill="#6aa86d"/><circle cx="40" cy="30" r="2.5" fill="#6aa86d"/>',
    "banana_chips": "".join(f'<circle cx="{x}" cy="{y}" r="13" fill="#f7e3a0" {stroke(3)}/><circle cx="{x}" cy="{y}" r="7" fill="none" stroke="#e0c070" stroke-width="2"/>'
                            f'<circle cx="{x - 2}" cy="{y - 1}" r="1.6" fill="#9c7a45"/><circle cx="{x + 2}" cy="{y + 2}" r="1.6" fill="#9c7a45"/>'
                            for x, y in ((22, 40), (42, 42), (32, 22))),
    "best_apples": f'<path d="M14,22 h36 l4,36 h-44z" fill="#e9d2a8" {stroke(3.5)}/>'
                   f'<path d="M14,22 l6,-8 h24 l6,8" fill="#f3e2c0" {stroke(3)}/>'
                   f'<circle cx="32" cy="40" r="11" fill="#f6d27a" {stroke(3)}/><circle cx="32" cy="40" r="7" fill="none" stroke="#c9534f" stroke-width="2.5"/>'
                   f'<circle cx="32" cy="40" r="3" fill="#fbf1d3" {stroke(2)}/>'
                   '<path d="M22,22 q10,8 20,0" fill="none" stroke="#c9534f" stroke-width="3"/>'
                   '<path d="M54,4 l2.5,6 l6,2.5 l-6,2.5 l-2.5,6 l-2.5,-6 l-6,-2.5 l6,-2.5z" fill="#ffd27a" stroke="#4f3d33" stroke-width="1.5"/>'
                   '<path d="M8,40 l1.5,3.5 l3.5,1.5 l-3.5,1.5 l-1.5,3.5 l-1.5,-3.5 l-3.5,-1.5 l3.5,-1.5z" fill="#ffd27a" stroke="#4f3d33" stroke-width="1.2"/>',
    "rose_petals": "".join(f'<path d="M{x},{y} q-10,-6 -6,-16 q10,0 12,10 q-2,6 -6,6z" transform="rotate({r} {x} {y})" fill="{c}" {stroke(2.5)}/>'
                           for x, y, r, c in ((24, 44, -20, "#e86f86"), (42, 46, 30, "#f08a9c"), (34, 30, 0, "#d9536f"), (18, 28, -60, "#f4a7b5"), (48, 28, 70, "#e86f86"))),
    "dried_apple": f'<circle cx="24" cy="38" r="17" fill="#f4dcb0" {stroke(3.5)}/><circle cx="24" cy="38" r="12" fill="none" stroke="#d98a5a" stroke-width="3"/>'
                   f'<circle cx="24" cy="38" r="5" fill="#fbf1d3" {stroke(2.5)}/>'
                   f'<circle cx="42" cy="24" r="17" fill="#f4dcb0" {stroke(3.5)}/><circle cx="42" cy="24" r="12" fill="none" stroke="#c9534f" stroke-width="3"/>'
                   f'<circle cx="42" cy="24" r="5" fill="#fbf1d3" {stroke(2.5)}/>'
                   '<path d="M50,6 l3,4 l4,-1 l-2,4 l3,3 l-4,1 l-1,4 l-3,-3 l-4,2 l1,-4 l-3,-3 l4,-1z" fill="#ffd27a" stroke="#4f3d33" stroke-width="1.5"/>',
    "wardrobe": f'<path d="M32,14 q0,-8 6,-8 q6,0 6,6 q0,5 -6,7 L32,22" fill="none" {stroke(4)}/>'
                f'<path d="M32,22 L6,44 q-3,4 2,4 h48 q5,0 2,-4 Z" fill="#f2b3bd" {stroke(4)}/>'
                '<path d="M14,48 h36" stroke="#e8505b" stroke-width="3"/>',
    "urgent": f'<rect x="10" y="10" width="44" height="44" rx="10" fill="#f08a7c" {stroke(4)}/>'
              '<path d="M32,19 v16" stroke="#fff" stroke-width="7" stroke-linecap="round"/><circle cx="32" cy="45" r="4.5" fill="#fff"/>',
    "spam": f'<rect x="6" y="16" width="52" height="36" rx="6" fill="#b9b4a8" {stroke(4)}/>'
            '<path d="M8,19 L32,38 L56,19" fill="none" stroke="#4f3d33" stroke-width="3.5" stroke-linejoin="round"/>'
            f'<circle cx="48" cy="16" r="11" fill="#7a9a4a" {stroke(3)}/>'
            '<path d="M44,12 l8,8 M52,12 l-8,8" stroke="#fff" stroke-width="3.5" stroke-linecap="round"/>',
    "crate": '<path d="M22,12 l-6,-7 M24,10 l0,-8 M26,11 l7,-6" stroke="#6aa86d" stroke-width="3.5" stroke-linecap="round"/>'
             f'<path d="M18,12 q6,-4 12,0 l-3,16 h-6z" fill="#f4a259" {stroke(3)}/>'
             f'<path d="M36,14 q6,-4 12,0 l-3,14 h-6z" fill="#f4a259" {stroke(3)}/>'
             '<path d="M40,14 l2,-7 M43,15 l4,-6" stroke="#6aa86d" stroke-width="3" stroke-linecap="round"/>'
             f'<rect x="8" y="20" width="48" height="36" rx="4" fill="#d9a46a" {stroke(4)}/>'
             '<path d="M10,32 h44 M10,44 h44" stroke="#b07a45" stroke-width="3"/>',
    "settings": "".join(f'<rect x="27" y="4" width="10" height="16" rx="3" transform="rotate({a} 32 32)" fill="#c9b8e8" {stroke(3)}/>'
                        for a in range(0, 360, 45))
                + f'<circle cx="32" cy="32" r="17" fill="#c9b8e8" {stroke(4)}/><circle cx="32" cy="32" r="7" fill="#fff8ef" {stroke(3)}/>',
    "hand": f'<path d="M12,58 v-22 q0,-6 6,-6 h26 q6,0 6,6 v4 q0,6 -6,6 h-12 v12z" fill="#f7cdb0" {stroke(4)}/>',
}
ICONS.update(ICONS_EXTRA)
for name, body in ICONS.items():
    save(f"icon_{name}.svg", svg(64, 64, body))

# ---- show club: training & grooming gear, rosettes, rivals -----------------------
CLUB_ICONS = {
    "clicker": f'<rect x="14" y="16" width="36" height="40" rx="12" fill="#a7c0e8" {stroke(4)}/>'
               f'<circle cx="32" cy="32" r="9" fill="#f3cf7a" {stroke(3)}/>'
               f'<path d="M32,16 q0,-10 12,-10" fill="none" {stroke(3)}/>',
    "pouch": f'<path d="M14,26 q-4,30 18,30 q22,0 18,-30z" fill="#c99a6b" {stroke(4)}/>'
             f'<path d="M12,26 h40" {stroke(4)}/>'
             f'<path d="M26,24 L36,6 q6,4 3,10z" fill="#f4a259" {stroke(3)}/>'
             '<path d="M37,8 l6,-4" stroke="#6aa86d" stroke-width="4" stroke-linecap="round"/>'
             '<path d="M24,40 q8,6 16,0" fill="none" stroke="#a87a4e" stroke-width="3" stroke-linecap="round"/>',
    "brush": f'<rect x="28" y="34" width="12" height="26" rx="5" fill="#c99a6b" {stroke(3.5)}/>'
             f'<ellipse cx="34" cy="22" rx="22" ry="16" fill="#d8a46a" {stroke(4)}/>'
             + "".join(f'<circle cx="{x}" cy="{y}" r="2.2" fill="{INK}"/>'
                       for x, y in ((24, 17), (34, 15), (44, 17), (20, 25), (30, 23), (40, 23), (48, 25), (26, 30), (36, 30), (44, 30))),
    "comb": f'<rect x="6" y="18" width="52" height="12" rx="5" fill="#d8a7d0" {stroke(4)}/>'
            + "".join(f'<path d="M{x},30 v18" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>' for x in range(11, 56, 6)),
    "clippers": f'<path d="M12,52 L30,30 M24,56 L34,32" {stroke(6)}/>'
                f'<path d="M12,52 L30,30 M24,56 L34,32" stroke="#e9a3a0" stroke-width="2.5" stroke-linecap="round"/>'
                f'<path d="M30,30 L46,10 q8,2 4,10 L34,32 z" fill="#cfd6e3" {stroke(3.5)}/>'
                f'<circle cx="32" cy="31" r="3.5" fill="#f3cf7a" {stroke(2)}/>',
    "spin": f'<path d="M50,30 a18,18 0 1 1 -8,-15" fill="none" {stroke(6)}/>'
            '<path d="M50,30 a18,18 0 1 1 -8,-15" fill="none" stroke="#f3cf7a" stroke-width="2.5" stroke-linecap="round"/>'
            f'<path d="M36,6 l12,8 l-12,8z" fill="#f3cf7a" {stroke(3)}/>',
    "condition": f'<path d="M12,46 q20,-44 40,-30 q-6,30 -40,30z" fill="#c9b8e8" {stroke(4)}/>'
                 '<path d="M14,44 q18,-14 30,-24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>'
                 f'<path d="M48,42 l3,7 l7,3 l-7,3 l-3,7 l-3,-7 l-7,-3 l7,-3z" fill="#fff" {stroke(2)}/>',
}


def rosette(fill, ribbon, w=64, h=96):
    """A show rosette: pleated ring, centre button, two ribbon tails."""
    cx, cy = w / 2, 30
    p = [f'<path d="M{cx - 14},{cy + 10} l-10,{h - 44} l10,-8 l8,10 l2,-{h - 50}z" fill="{ribbon}" {stroke(3)}/>',
         f'<path d="M{cx + 14},{cy + 10} l10,{h - 44} l-10,-8 l-8,10 l-2,-{h - 50}z" fill="{ribbon}" {stroke(3)}/>']
    pts = []
    for i in range(24):
        a = 2 * math.pi * i / 24
        r = 28 if i % 2 == 0 else 23
        pts.append(f"{cx + math.cos(a) * r:.1f},{cy + math.sin(a) * r:.1f}")
    p.append(f'<polygon points="{" ".join(pts)}" fill="{ribbon}" {stroke(3)}/>')
    p.append(f'<circle cx="{cx}" cy="{cy}" r="15" fill="{fill}" {stroke(3)}/>')
    p.append(f'<circle cx="{cx - 4}" cy="{cy - 5}" r="4" fill="#fff" opacity="0.6"/>')
    return svg(w, h, "\n".join(p))


save("rosette_1.svg", rosette("#f3cf7a", "#e8505b"))
save("rosette_2.svg", rosette("#dfe3ea", "#6f9fd8"))
save("rosette_3.svg", rosette("#e0a46a", "#9cc5a1"))
save("trophy.svg", svg(76, 96,
    f'<path d="M14,14 q-12,0 -10,14 q2,14 18,16 M62,14 q12,0 10,14 q-2,14 -18,16" fill="none" {stroke(5)}/>'
    f'<path d="M14,8 h48 q0,40 -24,44 q-24,-4 -24,-44z" fill="#f3cf7a" {stroke(4)}/>'
    f'<rect x="32" y="52" width="12" height="16" fill="#e0b250" {stroke(3)}/>'
    f'<rect x="18" y="68" width="40" height="22" rx="4" fill="#c99a6b" {stroke(4)}/>'
    '<path d="M24,16 q2,20 10,28" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity="0.6"/>'
    f'<path d="M38,22 l3,7 l7,1 l-5,5 l2,7 l-7,-4 l-7,4 l2,-7 l-5,-5 l7,-1z" fill="#fff4cf" {stroke(2)}/>'))
save("trophy_shelf.svg", svg(300, 44,
    f'<path d="M30,14 v24 h16 z M270,14 v24 h-16 z" fill="#a9825a" {stroke(3.5)}/>'
    f'<rect x="6" y="4" width="288" height="14" rx="5" fill="#c99a6b" {stroke(4)}/>'))
save("hoop.svg", svg(120, 160,
    f'<path d="M34,154 L60,112 L86,154" fill="none" {stroke(6)}/>'
    f'<path d="M34,154 L60,112 L86,154" fill="none" stroke="#c99a6b" stroke-width="2.5"/>'
    f'<ellipse cx="60" cy="62" rx="44" ry="54" fill="none" {stroke(15)}/>'
    '<ellipse cx="60" cy="62" rx="44" ry="54" fill="none" stroke="#e8505b" stroke-width="9" stroke-dasharray="16 14"/>'
    '<ellipse cx="60" cy="62" rx="44" ry="54" fill="none" stroke="#fff4cf" stroke-width="9" stroke-dasharray="14 16" stroke-dashoffset="15"/>'))
# a wisp of shed fur: soft overlapping puffs with stray hairs
save("fur_tuft.svg", svg(44, 32,
    '<path d="M6,20 q-4,-6 0,-10 M38,10 q6,-4 4,-8 M30,28 q4,4 10,2" fill="none" stroke="#8f8a99" stroke-width="1.6" stroke-linecap="round"/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#b5b0bf" stroke="#8f8a99" stroke-width="1.5"/>'
              for x, y, r in ((14, 18, 8), (24, 13, 9), (32, 19, 8), (22, 22, 8)))
    + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#b5b0bf"/>' for x, y, r in ((14, 18, 6.5), (24, 13, 7.5), (32, 19, 6.5), (22, 22, 6.5)))
    + '<path d="M17,15 q5,-4 9,-2" fill="none" stroke="#e4e0ea" stroke-width="2" stroke-linecap="round"/>'))
for name, body in CLUB_ICONS.items():
    save(f"icon_{name}.svg", svg(64, 64, body))
save("icon_club.svg", rosette("#f3cf7a", "#e8505b", 64, 64).replace('viewBox="0 0 64 64"', 'viewBox="-8 -4 80 80"'))

# Rival bunnies: Bubák's head recoloured, as round portraits. ears: perky angle, or "lop".
RIVALS = {
    "duchess": {"fur": "#f4f1ec", "dark": "#d9d2c8", "light": "#ffffff", "cream": "#ffffff", "ears": "lop", "bg": "#e9d4f0"},
    "pepik": {"fur": "#a0714f", "dark": "#7e5638", "light": "#b98b68", "cream": "#f1dcc4", "ears": -4, "bg": "#d6ecd2"},
    "pusinka": {"fur": "#f1d7b6", "dark": "#dcbb93", "light": "#fbe8d0", "cream": "#fff7ee", "ears": -20, "bg": "#f8d9dc"},
    "baron": {"fur": "#3e3a44", "dark": "#2c2932", "light": "#57525e", "cream": "#f6f0e8", "ears": -10, "bg": "#d4def0"},
    "clover": {"fur": "#d98a4a", "dark": "#b56c33", "light": "#eaa468", "cream": "#fbe9d6", "ears": "lop", "bg": "#f6e4b8"},
    "velvet": {"fur": "#b9bcc8", "dark": "#9599a8", "light": "#d4d7e0", "cream": "#f4f4f8", "ears": -16, "bg": "#2f3550"},
}
for rid, r in RIVALS.items():
    lop = r["ears"] == "lop"
    h = head(0, 0, 0, -160 if lop else r["ears"], "open", seed=sum(map(ord, rid)) % 50)
    for old, new in ((FUR_DARK, r["dark"]), (FUR_LIGHT, r["light"]), (FUR, r["fur"]), (CREAM, r["cream"])):
        h = h.replace(f'"{old}"', f'"{new}"')
    save(f"rival_{rid}.svg", svg(256, 256,
        f'<circle cx="128" cy="128" r="120" fill="{r["bg"]}" {stroke(8)}/>'
        f'<g transform="translate({118 if lop else 122},{150 if lop else 172}) scale(1.3)">{h}</g>'))

# ---- a mate for Bubák: the same bunny in other colours, plus the rescue's hutch ----
MATES = {
    "luna": {"fur": "#ece4da", "dark": "#d3c7b8", "light": "#f8f3ec", "cream": "#ffffff", "bg": "#f8d9dc"},
    "caramel": {"fur": "#e0a85e", "dark": "#c2873f", "light": "#efc283", "cream": "#fbecd6", "bg": "#f6e4b8"},
    "hazel": {"fur": "#8a6247", "dark": "#6c4932", "light": "#a37a5d", "cream": "#f3e3d0", "bg": "#d6ecd2"},
    "shadow": {"fur": "#45414c", "dark": "#322f38", "light": "#5d5866", "cream": "#e9e3ea", "bg": "#d4def0"},
}


def recolour(text, c):
    for old, new in ((FUR_DARK, c["dark"]), (FUR_LIGHT, c["light"]), (FUR, c["fur"]), (CREAM, c["cream"])):
        text = text.replace(f'"{old}"', f'"{new}"')
    return text


for mid, c in MATES.items():
    for pose in ("sit", "blink", "hop", "loaf", "sleep", "eat", "flop", "stand"):
        save(f"bunny_{pose}_{mid}.svg", recolour(bunny(pose), c))
        save(f"bunny_{pose}_body_{mid}.svg", recolour(bunny(pose, parts=False), c))
    save(f"bunny_ear_{mid}.svg", recolour(svg(60, 110, f'<g transform="translate(30,104)">{perky_ear()}</g>'), c))
    save(f"mate_{mid}.svg", svg(256, 256,
        f'<circle cx="128" cy="128" r="120" fill="{c["bg"]}" {stroke(8)}/>'
        + recolour(f'<g transform="translate(122,170) scale(1.3)">{head(0, 0, 0, -8, "open", seed=11)}</g>', c)))

# Foster bunnies: more coats, the same bunny underneath.
FOSTERS = {
    "pip": {"fur": "#9a9aa3", "dark": "#7c7c86", "light": "#b4b4bc", "cream": "#ecebef", "bg": "#e4e1f2"},
    "bramble": {"fur": "#7e6a52", "dark": "#62513e", "light": "#988369", "cream": "#e9dcc8", "bg": "#e2ecd2"},
    "tofu": {"fur": "#fbfaf6", "dark": "#e4e0d6", "light": "#ffffff", "cream": "#ffffff", "bg": "#dcebf3"},
    "poppy": {"fur": "#c9744a", "dark": "#a75a35", "light": "#dd9068", "cream": "#f6dfcf", "bg": "#f6dccd"},
    "ziggy": {"fur": "#3e3a40", "dark": "#2c292e", "light": "#58535a", "cream": "#f4f1ee", "bg": "#efe6d0"},
    "maple": {"fur": "#e3893a", "dark": "#c36d23", "light": "#f0a560", "cream": "#fbe7cf", "bg": "#f7e2c4"},
}
for mid, c in FOSTERS.items():
    for pose in ("sit", "blink", "hop", "loaf", "sleep", "eat", "flop", "stand"):
        save(f"bunny_{pose}_{mid}.svg", recolour(bunny(pose), c))
        save(f"bunny_{pose}_body_{mid}.svg", recolour(bunny(pose, parts=False), c))
    save(f"bunny_ear_{mid}.svg", recolour(svg(60, 110, f'<g transform="translate(30,104)">{perky_ear()}</g>'), c))
    save(f"mate_{mid}.svg", svg(256, 256,
        f'<circle cx="128" cy="128" r="120" fill="{c["bg"]}" {stroke(8)}/>'
        + recolour(f'<g transform="translate(122,170) scale(1.3)">{head(0, 0, 0, -8, "open", seed=11)}</g>', c)))

# The rescue's hutch: four compartments (40 + i * 205, 80, 190 x 220) behind a wire mesh.
HUTCH_W, HUTCH_H = 880, 360
hp = [f'<path d="M60,330 v26 M820,330 v26 M300,330 v26 M580,330 v26" {stroke(14)}/>',
      f'<path d="M60,330 v26 M820,330 v26 M300,330 v26 M580,330 v26" stroke="#a9825a" stroke-width="7" stroke-linecap="round"/>',
      f'<rect x="20" y="64" width="840" height="270" rx="10" fill="#c99a6b" {stroke(5)}/>',
      f'<path d="M6,74 L60,10 H820 L874,74 Z" fill="#e9a3a0" {stroke(5)}/>']
for x in range(80, 820, 60):
    hp.append(f'<path d="M{x},20 l-14,50" stroke="#d98d8b" stroke-width="5" stroke-linecap="round"/>')
for i in range(4):
    x = 40 + i * 205
    hp.append(f'<rect x="{x}" y="80" width="190" height="220" rx="8" fill="#5b4636" {stroke(4)}/>')
    hp.append(f'<rect x="{x + 4}" y="84" width="182" height="40" rx="6" fill="#4a382b"/>')
    hp.append(f'<path d="M{x + 2},270 q40,-14 90,-6 q50,-10 96,4 v28 h-186z" fill="#e6cf7a" {stroke(3)}/>')
    for k in range(9):
        hx = x + 14 + k * 20
        hp.append(f'<path d="M{hx},296 l{6 - (k % 3) * 5},-22" stroke="#d4b95b" stroke-width="3" stroke-linecap="round"/>')
hp.append(f'<rect x="20" y="300" width="840" height="34" rx="6" fill="#b5875a" {stroke(5)}/>')
save("hutch.svg", svg(HUTCH_W, HUTCH_H, "\n".join(hp)))
mesh = []
for i in range(4):
    x = 40 + i * 205
    for gx in range(x + 16, x + 190, 22):
        mesh.append(f'<path d="M{gx},84 V296" stroke="#e8e4ec" stroke-width="2" opacity="0.75"/>')
    for gy in range(98, 296, 22):
        mesh.append(f'<path d="M{x + 4},{gy} H{x + 186}" stroke="#e8e4ec" stroke-width="2" opacity="0.75"/>')
    mesh.append(f'<rect x="{x}" y="80" width="190" height="220" rx="8" fill="none" {stroke(5)}/>')
    mesh.append(f'<rect x="{x + 166}" y="170" width="12" height="34" rx="4" fill="#f3cf7a" {stroke(3)}/>')
save("hutch_mesh.svg", svg(HUTCH_W, HUTCH_H, "\n".join(mesh)))

# ---- walks: the leash, and the places Bubák visits ------------------------------------
WALK_W, WALK_H = 1600, 720
GROUND = 640   # where Bubák's feet go


def _sky(top, bottom, gid):
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{bottom}"/></linearGradient>'
            f'<rect width="{WALK_W}" height="{WALK_H}" fill="url(#{gid})"/>')


def _cloud(x, y, s=1.0):
    return "".join(f'<ellipse cx="{x + dx * s}" cy="{y + dy * s}" rx="{rx * s}" ry="{ry * s}" fill="#ffffff" opacity="0.9"/>'
                   for dx, dy, rx, ry in ((0, 0, 60, 26), (44, -14, 46, 30), (88, 2, 52, 24)))


def _tree(x, ground, h=200, crown="#8cc47e", seed=0):
    rnd = random.Random(seed)
    p = [f'<rect x="{x - 12}" y="{ground - h * 0.45}" width="24" height="{h * 0.45}" rx="6" fill="#a7774f" {stroke(4)}/>']
    for i in range(4):
        p.append(wobble_ellipse(x + rnd.uniform(-40, 40), ground - h * 0.6 - rnd.uniform(0, h * 0.3),
                                rnd.uniform(48, 66), rnd.uniform(40, 56), fill=crown, seed=seed * 10 + i))
    return "".join(p)


def _flower(x, y, col, r=7):
    petals = "".join(f'<circle cx="{x + r * math.cos(a):.1f}" cy="{y + r * math.sin(a):.1f}" r="{r * 0.75:.1f}" fill="{col}"/>'
                     for a in [i * math.pi * 2 / 5 for i in range(5)])
    return f'<path d="M{x},{y} v{r * 3}" stroke="#5f9d62" stroke-width="3"/>' + petals + f'<circle cx="{x}" cy="{y}" r="{r * 0.55:.1f}" fill="#f6d84a"/>'


def walk_park():
    rnd = random.Random(3)
    p = [_sky("#bfe3f5", "#eef7f0", "skyp"), _cloud(220, 110), _cloud(900, 80, 1.2), _cloud(1350, 140, 0.8)]
    p.append(f'<path d="M0,430 Q400,360 800,420 T1600,410 V{WALK_H} H0z" fill="#b6dba0"/>')
    p.append('<ellipse cx="1150" cy="470" rx="230" ry="38" fill="#9fd2e8" stroke="#7fb8cf" stroke-width="4"/>')
    p.append('<path d="M1010,468 q20,-8 40,0 M1180,480 q20,-8 40,0" stroke="#ffffff" stroke-width="3" fill="none" opacity="0.8"/>')
    for i, x in enumerate([90, 420, 700, 1480]):
        p.append(_tree(x, 470, 230, ["#8cc47e", "#7fb872", "#9ccf86"][i % 3], seed=i + 1))
    p.append(f'<rect x="0" y="470" width="{WALK_W}" height="{WALK_H - 470}" fill="#a5d48e"/>')
    p.append(f'<path d="M0,560 Q800,540 1600,570 V{WALK_H} H0z" fill="#ecd9ad" {stroke(4)}/>')
    for i in range(40):
        p.append(f'<circle cx="{rnd.uniform(0, WALK_W):.0f}" cy="{rnd.uniform(590, 710):.0f}" r="{rnd.uniform(2, 4):.1f}" fill="#d6c08f"/>')
    for i in range(26):
        x = rnd.uniform(20, WALK_W - 20)
        p.append(_flower(x, rnd.uniform(488, 530), rnd.choice(["#f39ab0", "#ffffff", "#f6d84a", "#c8a6f0"]), 6))
    # bench and lamp post
    p.append(f'<rect x="560" y="470" width="170" height="16" rx="5" fill="#c99a6b" {stroke(4)}/>'
             f'<rect x="560" y="440" width="170" height="14" rx="5" fill="#c99a6b" {stroke(4)}/>'
             f'<path d="M575,486 v30 M715,486 v30" {stroke(6)}/>')
    p.append(f'<path d="M980,540 V330" {stroke(8)}/><path d="M980,540 V330" stroke="#5b6170" stroke-width="4"/>'
             f'<path d="M958,330 h44 l-8,-34 h-28z" fill="#f6e7a8" {stroke(4)}/>')
    return svg(WALK_W, WALK_H, "\n".join(p))


def walk_field():
    rnd = random.Random(5)
    p = [_sky("#ffe9b8", "#fff7e6", "skyf"), f'<circle cx="1300" cy="140" r="70" fill="#ffd66e" opacity="0.9"/>',
         _cloud(300, 120, 0.9), _cloud(780, 90)]
    p.append(f'<path d="M0,400 Q300,330 650,390 T1300,370 T1600,380 V{WALK_H} H0z" fill="#c9e3a0"/>')
    p.append(f'<path d="M0,450 Q400,400 900,450 T1600,440 V{WALK_H} H0z" fill="#b2d88a"/>')
    # fence and hay bales on the hill
    for x in range(40, 1600, 90):
        p.append(f'<rect x="{x}" y="420" width="10" height="60" rx="3" fill="#c99a6b" {stroke(3)}/>')
    p.append(f'<path d="M0,438 H1600 M0,462 H1600" stroke="#c99a6b" stroke-width="6"/>')
    for x in (520, 1180):
        p.append(f'<ellipse cx="{x}" cy="520" rx="70" ry="48" fill="#e6c96a" {stroke(4)}/>'
                 f'<ellipse cx="{x - 40}" cy="520" rx="22" ry="40" fill="#d4b55a" {stroke(3)}/>')
    p.append(f'<rect x="0" y="540" width="{WALK_W}" height="{WALK_H - 540}" fill="#a7d07c"/>')
    for i in range(160):
        x = rnd.uniform(0, WALK_W)
        y = rnd.uniform(540, WALK_H)
        p.append(f'<path d="M{x:.0f},{y:.0f} q{rnd.uniform(-6, 6):.0f},-14 {rnd.uniform(-8, 8):.0f},-24" stroke="#8cbf68" stroke-width="3" fill="none"/>')
    for i in range(40):
        p.append(_flower(rnd.uniform(10, WALK_W - 10), rnd.uniform(470, 700),
                         rnd.choice(["#ffffff", "#f6d84a", "#e8505b", "#c8a6f0", "#f39ab0"]), rnd.uniform(5, 8)))
    return svg(WALK_W, WALK_H, "\n".join(p))


def walk_beach():
    rnd = random.Random(8)
    p = [_sky("#a9dcf3", "#eaf6fb", "skyb"), _cloud(400, 100), _cloud(1150, 130, 0.8)]
    p.append('<rect x="0" y="330" width="1600" height="200" fill="#6fbfdf"/>')
    p.append('<rect x="0" y="330" width="1600" height="40" fill="#8fd0ea"/>')
    for y in range(360, 520, 34):
        for x in range(0, 1600, 120):
            p.append(f'<path d="M{x + (y % 68)},{y} q20,-10 40,0" stroke="#ffffff" stroke-width="3" fill="none" opacity="0.7"/>')
    p.append('<path d="M1300,330 l40,-24 l10,24 z" fill="#ffffff" stroke="#9bb" stroke-width="2"/>')   # a sail
    p.append(f'<path d="M0,520 Q400,500 800,520 T1600,515 V{WALK_H} H0z" fill="#f3dca4"/>')
    p.append('<path d="M0,520 Q400,500 800,520 T1600,515" stroke="#ffffff" stroke-width="8" fill="none" opacity="0.8"/>')
    for i in range(70):
        p.append(f'<circle cx="{rnd.uniform(0, WALK_W):.0f}" cy="{rnd.uniform(540, 715):.0f}" r="2" fill="#dcc188"/>')
    # umbrella, towel, shells, starfish
    p.append(f'<path d="M1250,600 V420" {stroke(6)}/>'
             f'<path d="M1110,440 Q1250,330 1390,440 Z" fill="#e8505b" {stroke(4)}/>'
             f'<path d="M1160,440 Q1200,380 1250,350 Q1300,380 1340,440" fill="#fff8ee" opacity="0.9"/>')
    p.append(f'<rect x="1080" y="590" width="220" height="60" rx="8" fill="#9ccbe8" {stroke(4)}/>'
             '<path d="M1080,610 H1300 M1080,630 H1300" stroke="#ffffff" stroke-width="6"/>')
    p.append(f'<path d="M300,610 q14,-26 28,0 z" fill="#f7c6b6" {stroke(3)}/>')
    p.append(f'<path d="M520,660 l8,-18 l8,18 l18,2 l-14,10 l6,18 l-18,-10 l-18,10 l6,-18 l-14,-10z" fill="#f39a3d" {stroke(3)}/>')
    p.append(f'<path d="M180,250 q14,-10 26,0 q12,-10 26,0" stroke="{INK}" stroke-width="3" fill="none"/>')   # a gull
    return svg(WALK_W, WALK_H, "\n".join(p))


def walk_city():
    rnd = random.Random(11)
    p = [_sky("#cfe6f2", "#f6efe6", "skyc"), _cloud(600, 90, 0.9)]
    x = -20
    cols = ["#e9b9a0", "#f2d6a8", "#c9d6e8", "#e6c2d6", "#cfe0c4"]
    i = 0
    while x < WALK_W:
        w = rnd.randint(200, 280)
        top = rnd.randint(120, 220)
        c = cols[i % len(cols)]
        p.append(f'<rect x="{x}" y="{top}" width="{w}" height="{560 - top}" fill="{c}" {stroke(4)}/>')
        for wy in range(top + 30, 420, 60):
            for wx in range(x + 24, x + w - 40, 56):
                p.append(f'<rect x="{wx}" y="{wy}" width="30" height="38" rx="4" fill="#fff8ee" {stroke(3)}/>')
        # a shop at street level with a striped awning
        aw = ["#e8505b", "#4fa3e0", "#7cc96a", "#f39a3d"][i % 4]
        p.append(f'<rect x="{x + 20}" y="450" width="{w - 40}" height="110" fill="#fff8ee" {stroke(4)}/>')
        p.append(f'<path d="M{x + 10},450 h{w - 20} l-10,-30 h{-(w - 40)}z" fill="{aw}" {stroke(4)}/>')
        for sx in range(x + 30, x + w - 30, 30):
            p.append(f'<rect x="{sx}" y="422" width="14" height="27" fill="#ffffff" opacity="0.6"/>')
        x += w
        i += 1
    p.append(f'<rect x="0" y="560" width="{WALK_W}" height="{WALK_H - 560}" fill="#d9d2cc"/>')
    for y in range(590, WALK_H, 40):
        p.append(f'<path d="M0,{y} H{WALK_W}" stroke="#c4bcb5" stroke-width="3"/>')
    for x in range(0, WALK_W, 80):
        p.append(f'<path d="M{x},560 V{WALK_H}" stroke="#c4bcb5" stroke-width="3"/>')
    p.append(f'<rect x="0" y="556" width="{WALK_W}" height="10" fill="#bdb4ac" {stroke(3)}/>')
    # café tables, lamp posts, a potted tree
    for tx in (380, 1040):
        p.append(f'<ellipse cx="{tx}" cy="560" rx="46" ry="10" fill="#fff8ee" {stroke(4)}/><path d="M{tx},570 V610" {stroke(6)}/>'
                 f'<path d="M{tx - 22},612 h44" {stroke(5)}/>')
    for lx in (220, 820, 1420):
        p.append(f'<path d="M{lx},600 V300" {stroke(8)}/><path d="M{lx},600 V300" stroke="#5b6170" stroke-width="4"/>'
                 f'<circle cx="{lx}" cy="292" r="18" fill="#f6e7a8" {stroke(4)}/>')
    p.append(f'<rect x="1230" y="560" width="60" height="50" rx="6" fill="#c97b5a" {stroke(4)}/>' + _tree(1260, 560, 160, seed=9))
    return svg(WALK_W, WALK_H, "\n".join(p))


def walk_cinema():
    p = [f'<rect width="{WALK_W}" height="{WALK_H}" fill="#2c2438"/>']
    # curtains and the screen showing a carrot cartoon
    p.append('<rect x="0" y="0" width="1600" height="60" fill="#8e2f3f"/>')
    for x in range(0, 1600, 40):
        p.append(f'<path d="M{x},0 q20,40 0,60" stroke="#6e2230" stroke-width="4" fill="none"/>')
    p.append(f'<rect x="300" y="80" width="1000" height="340" rx="10" fill="#fdf6e3" stroke="#5a4a66" stroke-width="8"/>')
    p.append('<rect x="300" y="80" width="1000" height="340" rx="10" fill="#bfe3f5" opacity="0.6"/>')
    p.append('<path d="M300,330 Q800,290 1300,340 V420 H300z" fill="#a5d48e"/>')
    p.append(f'<g transform="translate(800,250) rotate(-20)"><path d="M-30,-60 q30,-8 60,0 l-24,150 q-6,10 -12,0z" fill="#f39a3d" {stroke(5)}/>'
             f'<path d="M-6,-62 q-20,-40 -30,-30 M6,-62 q0,-46 12,-44 M14,-60 q30,-30 34,-14" fill="none" stroke="#5f9d62" stroke-width="7" stroke-linecap="round"/></g>')
    p.append('<circle cx="560" cy="160" r="40" fill="#ffd66e"/>')
    # projector beam
    p.append('<path d="M800,0 L300,80 L1300,80 Z" fill="#fff6c0" opacity="0.06"/>')
    # rows of seats in the dark
    for row, (y, s, col) in enumerate([(470, 0.8, "#5b2a3a"), (540, 0.95, "#6a3045")]):
        for x in range(-40 + row * 50, 1640, int(110 * s)):
            p.append(f'<rect x="{x}" y="{y}" width="{90 * s:.0f}" height="{80 * s:.0f}" rx="{18 * s:.0f}" fill="{col}" stroke="#1e1828" stroke-width="4"/>')
    # front row: the seat Bubák sits on (centre), with popcorn on the next one
    p.append(f'<rect x="0" y="{GROUND - 10}" width="{WALK_W}" height="{WALK_H - GROUND + 10}" fill="#3a2d48"/>')
    for x in range(-60, 1640, 220):
        p.append(f'<rect x="{x}" y="{GROUND - 150}" width="200" height="150" rx="30" fill="#8e2f3f" stroke="#1e1828" stroke-width="5"/>'
                 f'<rect x="{x + 10}" y="{GROUND - 30}" width="180" height="40" rx="14" fill="#a8394c" stroke="#1e1828" stroke-width="4"/>')
    p.append(f'<path d="M1050,{GROUND - 30} l14,-70 h60 l14,70z" fill="#ffffff" {stroke(4)}/>'
             f'<path d="M1060,{GROUND - 80} h80 M1056,{GROUND - 60} h88" stroke="#e8505b" stroke-width="10"/>'
             + "".join(f'<circle cx="{1068 + i * 14}" cy="{GROUND - 104 + (i % 2) * 6}" r="11" fill="#fff4cc" {stroke(2.5)}/>' for i in range(5)))
    return svg(WALK_W, WALK_H, "\n".join(p))


save("walk_park.svg", walk_park())
save("walk_field.svg", walk_field())
save("walk_beach.svg", walk_beach())
save("walk_city.svg", walk_city())
save("walk_cinema.svg", walk_cinema())

# props for the walk cutscenes
save("walk_crab.svg", svg(120, 80,
    f'<path d="M20,40 l-14,-10 M20,50 l-16,2 M100,40 l14,-10 M100,50 l16,2 M30,60 l-8,14 M90,60 l8,14" {stroke(4)}/>'
    f'<path d="M22,28 q-16,-20 -2,-24 q10,-2 8,12 z" fill="#e8505b" {stroke(3.5)}/>'
    f'<path d="M98,28 q16,-20 2,-24 q-10,-2 -8,12 z" fill="#e8505b" {stroke(3.5)}/>'
    f'<ellipse cx="60" cy="48" rx="40" ry="24" fill="#f07060" {stroke(4)}/>'
    f'<path d="M50,26 v-12 M70,26 v-12" {stroke(3)}/><circle cx="50" cy="12" r="6" fill="#fff" {stroke(2.5)}/>'
    f'<circle cx="70" cy="12" r="6" fill="#fff" {stroke(2.5)}/><circle cx="51" cy="12" r="2.5" fill="{INK}"/><circle cx="71" cy="12" r="2.5" fill="{INK}"/>'
    f'<path d="M52,54 q8,6 16,0" fill="none" {stroke(3)}/>'))
save("walk_shell.svg", svg(60, 50,
    f'<path d="M30,46 L6,20 Q30,-6 54,20 Z" fill="#f7c6b6" {stroke(3.5)}/>'
    + "".join(f'<path d="M30,44 L{x},{y}" stroke="#e39c88" stroke-width="2.5"/>' for x, y in ((14, 16), (22, 8), (30, 6), (38, 8), (46, 16)))))
save("walk_wave.svg", svg(1000, 140,
    '<path d="M0,140 V60 Q120,20 240,60 T480,60 T720,60 T960,60 L1000,56 V140 Z" fill="#8fd0ea" opacity="0.85"/>'
    '<path d="M0,60 Q120,20 240,60 T480,60 T720,60 T960,60 L1000,56" fill="none" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>'
    + "".join(f'<circle cx="{x}" cy="{48 + (x % 3) * 6}" r="{6 + x % 5}" fill="#ffffff"/>' for x in range(30, 1000, 70))))
save("walk_popcorn.svg", svg(110, 140,
    "".join(f'<circle cx="{x}" cy="{y}" r="15" fill="#fff4cc" {stroke(3)}/>'
            for x, y in ((28, 40), (50, 30), (72, 34), (90, 44), (40, 22), (62, 16), (80, 26), (20, 52), (55, 46)))
    + f'<path d="M12,50 l12,86 h62 l12,-86 z" fill="#ffffff" {stroke(4)}/>'
    + "".join(f'<path d="M{x},52 l{(x - 55) * 0.12:.1f},84" stroke="#e8505b" stroke-width="10"/>' for x in (26, 46, 66, 86))
    + f'<path d="M12,50 l12,86 h62 l12,-86 z" fill="none" {stroke(4)}/>'))
save("walk_kernel.svg", svg(30, 26,
    f'<circle cx="11" cy="14" r="8" fill="#fff4cc" {stroke(2.5)}/><circle cx="19" cy="11" r="7" fill="#fff4cc" {stroke(2.5)}/>'))
save("walk_plate.svg", svg(130, 60,
    f'<ellipse cx="65" cy="40" rx="60" ry="16" fill="#ffffff" {stroke(4)}/><ellipse cx="65" cy="38" rx="40" ry="9" fill="#f3efe8"/>'
    f'<path d="M40,34 q24,-16 54,-6 q-24,14 -54,6z" fill="#f39a3d" {stroke(3)}/>'
    f'<path d="M92,28 q10,-14 18,-12 M92,30 q14,-4 18,2" fill="none" stroke="#5f9d62" stroke-width="4" stroke-linecap="round"/>'))

save("walk_gull.svg", svg(110, 80,
    f'<path d="M48,40 q-30,-34 -44,-20 q20,4 34,30z" fill="#dfe3ea" {stroke(3.5)}/>'
    f'<ellipse cx="58" cy="50" rx="34" ry="18" fill="#ffffff" {stroke(4)}/>'
    f'<circle cx="86" cy="36" r="13" fill="#ffffff" {stroke(4)}/>'
    f'<path d="M97,36 l12,4 l-12,4z" fill="#f6c84a" {stroke(2.5)}/>'
    f'<circle cx="89" cy="33" r="2.6" fill="{INK}"/>'
    f'<path d="M26,52 l-18,6 l18,4z" fill="#aab1bd" {stroke(3)}/>'
    f'<path d="M52,66 v12 M64,66 v12" stroke="#f6a84a" stroke-width="4" stroke-linecap="round"/>'))
WALK_ICONS = {
    "leash": f'<path d="M10,14 q30,-12 40,14 q6,18 -8,28" fill="none" stroke="#e8505b" stroke-width="6" stroke-linecap="round"/>'
             f'<rect x="34" y="50" width="14" height="10" rx="3" fill="#c9ccd6" {stroke(3)}/>'
             f'<circle cx="14" cy="14" r="8" fill="none" {stroke(4)}/><circle cx="14" cy="14" r="8" fill="none" stroke="#e8505b" stroke-width="3"/>',
    "park": f'<rect x="28" y="36" width="8" height="22" rx="3" fill="#a7774f" {stroke(3)}/>'
            + wobble_ellipse(24, 28, 14, 12, fill="#8cc47e", w=3, seed=1) + wobble_ellipse(40, 24, 15, 13, fill="#9ccf86", w=3, seed=2)
            + wobble_ellipse(32, 14, 13, 11, fill="#7fb872", w=3, seed=3) + f'<path d="M6,58 h52" {stroke(4)}/>',
    "field": _flower(22, 30, "#f39ab0", 8) + _flower(42, 22, "#f6d84a", 8) + f'<path d="M6,58 q26,-10 52,0" {stroke(4)} fill="none"/>',
    "beach": f'<path d="M32,58 V18" {stroke(4)}/><path d="M8,26 Q32,0 56,26 Z" fill="#e8505b" {stroke(3)}/>'
             f'<path d="M4,56 q14,-8 28,0 q14,-8 28,0" stroke="#4fa3e0" stroke-width="5" fill="none"/>',
    "city": f'<rect x="8" y="20" width="22" height="38" fill="#e9b9a0" {stroke(3)}/><rect x="30" y="8" width="26" height="50" fill="#c9d6e8" {stroke(3)}/>'
            + "".join(f'<rect x="{x}" y="{y}" width="6" height="7" fill="#fff8ee"/>' for x in (14, 36, 46) for y in (28, 40) ),
    "cinema": f'<path d="M14,26 l6,32 h24 l6,-32z" fill="#ffffff" {stroke(3)}/><path d="M17,36 h30 M18,46 h28" stroke="#e8505b" stroke-width="5"/>'
              + "".join(f'<circle cx="{18 + i * 7}" cy="{20 + (i % 2) * 4}" r="6" fill="#fff4cc" {stroke(2)}/>' for i in range(5)),
}
for name, body in WALK_ICONS.items():
    save(f"icon_{name}.svg", svg(64, 64, body))

# ---- exercise toys and the weight scale --------------------------------------------
def hurdles():
    p = [f'<rect x="6" y="92" width="308" height="16" rx="8" fill="#9cc5a1" {stroke(4)}/>']
    for x in (60, 160, 260):
        p.append(f'<rect x="{x - 34}" y="44" width="8" height="54" rx="3" fill="#fff8ee" {stroke(3)}/>'
                 f'<rect x="{x + 26}" y="44" width="8" height="54" rx="3" fill="#fff8ee" {stroke(3)}/>')
        p.append(f'<rect x="{x - 40}" y="50" width="80" height="12" rx="6" fill="#fff8ee" {stroke(3.5)}/>')
        for k in range(4):
            p.append(f'<rect x="{x - 36 + k * 20}" y="52" width="10" height="8" fill="#e8505b"/>')
        p.append(f'<ellipse cx="{x - 30}" cy="98" rx="10" ry="4" fill="#7aa87e"/><ellipse cx="{x + 30}" cy="98" rx="10" ry="4" fill="#7aa87e"/>')
    return svg(320, 112, "\n".join(p))


def treat_ball():
    p = [f'<circle cx="35" cy="35" r="30" fill="#a9dcd0" {stroke(4)}/>',
         '<path d="M8,30 Q35,20 62,30" fill="none" stroke="#7fbcae" stroke-width="3"/>']
    for x, y in ((22, 22), (44, 18), (30, 44), (50, 42), (14, 38)):
        p.append(f'<circle cx="{x}" cy="{y}" r="5" fill="#4f6b63"/>')
    p.append('<ellipse cx="24" cy="16" rx="8" ry="4" transform="rotate(-30 24 16)" fill="#fff" opacity="0.6"/>')
    p.append(f'<ellipse cx="62" cy="64" rx="5" ry="3.5" fill="#c99a6b" {stroke(2)}/><ellipse cx="8" cy="65" rx="4.5" ry="3" fill="#c99a6b" {stroke(2)}/>')
    return svg(72, 70, "\n".join(p))


save("hurdles.svg", hurdles())
save("treat_ball.svg", treat_ball())
save("icon_scale.svg", svg(64, 64,
    f'<rect x="8" y="14" width="48" height="42" rx="12" fill="#c9d6e8" {stroke(4)}/>'
    f'<path d="M20,30 A12,12 0 0 1 44,30 Z" fill="#fff8ee" {stroke(3)}/>'
    f'<path d="M32,30 L38,22" stroke="#e8505b" stroke-width="3" stroke-linecap="round"/>'
    f'<rect x="16" y="40" width="32" height="8" rx="4" fill="#a7b8d0"/>'))

# ---- special days -------------------------------------------------------------------

def xmas_tree():
    """A little Christmas tree in a red pot, with baubles, a garland and a star on top."""
    p = [f'<rect x="96" y="232" width="28" height="22" fill="#8a5a3c" {stroke(3.5)}/>',
         f'<path d="M72,252 L148,252 L140,292 L80,292 Z" fill="#d9534f" {stroke(4)}/>',
         f'<rect x="66" y="246" width="88" height="14" rx="5" fill="#e8706b" {stroke(3.5)}/>']
    tiers = [(110, 40, 46, 108), (110, 84, 70, 168), (110, 136, 96, 236)]
    for i, (cx, top, half, bottom) in enumerate(tiers):
        p.append(f'<path d="M{cx},{top} Q{cx + half * 0.5},{(top + bottom) / 2} {cx + half},{bottom} '
                 f'Q{cx + half * 0.5},{bottom - 10} {cx},{bottom - 4} Q{cx - half * 0.5},{bottom - 10} {cx - half},{bottom} '
                 f'Q{cx - half * 0.5},{(top + bottom) / 2} {cx},{top} Z" fill="{["#4f9a6a", "#4a9264", "#458a5e"][i]}" {stroke(4)}/>')
    # garlands
    for y0, y1, x0, x1 in ((96, 122, 82, 146), (150, 186, 64, 160), (200, 226, 46, 178)):
        p.append(f'<path d="M{x0},{y0} Q{(x0 + x1) / 2},{y1 + 12} {x1},{y1 - 14}" fill="none" stroke="#f3cf7a" stroke-width="5" stroke-linecap="round"/>')
    for x, y, c in ((92, 104, "#e8505b"), (128, 96, "#7fb0d8"), (78, 160, "#f3cf7a"), (112, 176, "#e8505b"),
                    (146, 154, "#d8a7d0"), (64, 214, "#7fb0d8"), (98, 230, "#f3cf7a"), (138, 222, "#e8505b"), (172, 208, "#d8a7d0")):
        p.append(f'<circle cx="{x}" cy="{y}" r="8" fill="{c}" {stroke(2.5)}/><circle cx="{x - 2.5}" cy="{y - 2.5}" r="2.5" fill="#fff" opacity="0.7"/>')
    star = "M110,4 L117,22 L136,23 L121,35 L126,54 L110,43 L94,54 L99,35 L84,23 L103,22 Z"
    p.append(f'<path d="{star}" fill="#f6dc6e" stroke="#4f3d33" stroke-width="3.5" stroke-linejoin="round"/>')
    return svg(220, 296, "\n".join(p))


def present(box, ribbon, dots=None):
    """A wrapped present with a big bow."""
    p = [f'<rect x="10" y="44" width="100" height="70" rx="6" fill="{box}" {stroke(4)}/>']
    if dots:
        for x, y in ((24, 60), (52, 74), (88, 58), (30, 98), (72, 100), (96, 90)):
            p.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{dots}"/>')
    p.append(f'<rect x="4" y="30" width="112" height="22" rx="6" fill="{box}" {stroke(4)}/>')
    p.append(f'<rect x="51" y="30" width="18" height="84" fill="{ribbon}" {stroke(3)}/>')
    p.append(f'<path d="M60,30 C40,2 18,14 34,30 Z" fill="{ribbon}" {stroke(3.5)}/>'
             f'<path d="M60,30 C80,2 102,14 86,30 Z" fill="{ribbon}" {stroke(3.5)}/>'
             f'<circle cx="60" cy="29" r="7" fill="{ribbon}" {stroke(3)}/>')
    return svg(120, 118, "\n".join(p))


def jingle_ball():
    p = [f'<circle cx="35" cy="35" r="30" fill="#e8505b" {stroke(4)}/>',
         '<path d="M7,40 Q35,52 63,40" fill="none" stroke="#f3cf7a" stroke-width="5"/>',
         '<path d="M10,24 Q35,34 60,24" fill="none" stroke="#f3cf7a" stroke-width="5"/>',
         '<ellipse cx="24" cy="15" rx="8" ry="4" transform="rotate(-30 24 15)" fill="#fff" opacity="0.6"/>',
         f'<circle cx="47" cy="56" r="8" fill="#f3cf7a" {stroke(2.5)}/>',
         '<path d="M43,58 L51,58" stroke="#4f3d33" stroke-width="2" stroke-linecap="round"/>']
    return svg(72, 70, "\n".join(p))


def garland():
    """A fir garland in two swags over the window, with red bows and fairy-light bulbs.
    The bulbs sit on GARLAND_BULBS in scripts/main.gd (keep the two in step)."""
    def q(x0, x1, t, dip=58):
        xm = (x0 + x1) / 2
        return ((1 - t) ** 2 * x0 + 2 * (1 - t) * t * xm + t * t * x1, (1 - t) ** 2 * 14 + 2 * (1 - t) * t * dip + t * t * 14)
    p = []
    for x0, x1 in ((14, 170), (170, 326)):
        xm = (x0 + x1) / 2
        p.append(f'<path d="M{x0},14 Q{xm},58 {x1},14" fill="none" stroke="#4f3d33" stroke-width="20" stroke-linecap="round"/>')
        p.append(f'<path d="M{x0},14 Q{xm},58 {x1},14" fill="none" stroke="#4a9264" stroke-width="13" stroke-linecap="round"/>')
        for k in range(1, 12):
            x, y = q(x0, x1, k / 12)
            p.append(f'<path d="M{x - 7:.1f},{y - 4:.1f} L{x + 7:.1f},{y + 4:.1f} M{x - 7:.1f},{y + 4:.1f} L{x + 7:.1f},{y - 4:.1f}" stroke="#5fae7a" stroke-width="2.5" stroke-linecap="round"/>')
        for k, c in zip((0.2, 0.4, 0.6, 0.8), ("#f3cf7a", "#e8505b", "#7fb0d8", "#f3cf7a")):
            x, y = q(x0, x1, k)
            p.append(f'<circle cx="{x:.1f}" cy="{y + 7:.1f}" r="5.5" fill="{c}" {stroke(2)}/>')
    for x in (14, 170, 326):
        p.append(f'<path d="M{x},14 C{x - 22},-2 {x - 24},26 {x},16 C{x + 24},26 {x + 22},-2 {x},14 Z" fill="#e8505b" {stroke(3)}/>'
                 f'<path d="M{x - 2},18 L{x - 10},38 M{x + 2},18 L{x + 10},38" stroke="#e8505b" stroke-width="6" stroke-linecap="round"/>'
                 f'<circle cx="{x}" cy="15" r="5" fill="#d9534f" {stroke(2.5)}/>')
    return svg(364, 76, '<g transform="translate(12,4)">' + "\n".join(p) + '</g>')


save("garland.svg", garland())
save("xmas_tree.svg", xmas_tree())
save("present_xmas.svg", present("#d9534f", "#f3cf7a"))
save("present_bday.svg", present("#8fb8e0", "#e98fae", dots="#fff4cf"))
save("jingle_ball.svg", jingle_ball())
save("wear_party_hat.svg", svg(52, 66,
    f'<path d="M26,6 L46,56 L6,56 Z" fill="#a7c0e8" {stroke(3.5)}/>'
    '<path d="M21,25 L31,23.5 M16,39 L36,36 M12,50 L40,46.5" stroke="#e98fae" stroke-width="5"/>'
    f'<path d="M26,6 L46,56 L6,56 Z" fill="none" {stroke(3.5)}/>'
    f'<rect x="3" y="52" width="46" height="10" rx="5" fill="#f6dc6e" {stroke(3)}/>'
    f'<circle cx="26" cy="7" r="6.5" fill="#f6dc6e" {stroke(3)}/>'))


# ---- more special days, the garden, visitors -------------------------------------------

def egg(fill, band, dots):
    p = [f'<path d="M30,4 C46,4 56,30 56,46 C56,62 44,72 30,72 C16,72 4,62 4,46 C4,30 14,4 30,4 Z" fill="{fill}" {stroke(3.5)}/>',
         f'<path d="M6,40 Q30,50 54,40 L55,50 Q30,60 5,50 Z" fill="{band}"/>']
    for x, y in ((20, 24), (38, 22), (30, 32), (16, 62), (42, 62)):
        p.append(f'<circle cx="{x}" cy="{y}" r="3.5" fill="{dots}"/>')
    p.append(f'<path d="M30,4 C46,4 56,30 56,46 C56,62 44,72 30,72 C16,72 4,62 4,46 C4,30 14,4 30,4 Z" fill="none" {stroke(3.5)}/>')
    return svg(60, 76, "\n".join(p))


def easter_decor():
    """A vase of pussy willow with painted eggs hanging from the twigs."""
    p = []
    for x0, x1, y1 in ((80, 40, 30), (84, 70, 8), (88, 108, 12), (92, 136, 40), (86, 60, 60), (90, 118, 64)):
        p.append(f'<path d="M{x0},170 Q{(x0 + x1) / 2 + 6},{(170 + y1) / 2} {x1},{y1}" fill="none" stroke="#6b4a36" stroke-width="4" stroke-linecap="round"/>')
        for k in range(1, 5):
            t = k / 5
            x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * ((x0 + x1) / 2 + 6) + t * t * x1
            y = (1 - t) ** 2 * 170 + 2 * (1 - t) * t * ((170 + y1) / 2) + t * t * y1
            p.append(f'<ellipse cx="{x + 4:.1f}" cy="{y:.1f}" rx="5" ry="3.5" fill="#f1ece4" stroke="#bfb3a6" stroke-width="1.5"/>')
    for x, y, c in ((52, 70, "#e98fae"), (112, 50, "#7fb0d8"), (126, 92, "#f3cf7a"), (66, 104, "#9cc5a1")):
        p.append(f'<path d="M{x},{y - 16} L{x},{y - 8}" stroke="#e8505b" stroke-width="2"/>'
                 f'<ellipse cx="{x}" cy="{y}" rx="8" ry="10" fill="{c}" {stroke(2.5)}/>'
                 f'<path d="M{x - 8},{y} Q{x},{y + 4} {x + 8},{y}" fill="none" stroke="#fff" stroke-width="2"/>')
    p.append(f'<path d="M62,166 L118,166 L110,232 Q90,240 70,232 Z" fill="#a7c0e8" {stroke(4)}/>'
             f'<path d="M66,190 Q90,198 114,190" fill="none" stroke="#fff" stroke-width="4"/>')
    return svg(176, 240, "\n".join(p))


def pumpkin():
    """A jack-o'-lantern with a friendly face (it glows at night)."""
    p = [f'<path d="M78,14 Q84,4 92,6" fill="none" stroke="#5a8a50" stroke-width="7" stroke-linecap="round"/>',
         f'<rect x="72" y="10" width="14" height="20" rx="4" fill="#6b8f4e" {stroke(3)}/>']
    for cx, rx in ((48, 34), (110, 34), (79, 36)):
        p.append(f'<ellipse cx="{cx}" cy="78" rx="{rx}" ry="54" fill="#f0913a" {stroke(4)}/>')
    p.append(f'<path d="M50,64 L62,48 L72,66 Z M88,66 L98,48 L110,64 Z" fill="#ffd56b" {stroke(3)}/>'
             f'<path d="M46,92 Q79,124 114,92 L104,96 L98,104 L88,98 L79,108 L70,98 L60,104 L54,96 Z" fill="#ffd56b" {stroke(3)}/>')
    return svg(160, 136, "\n".join(p))


def veg_patch():
    """A raised wooden bed with three rows of soil."""
    p = [f'<rect x="6" y="40" width="268" height="64" rx="8" fill="#b07d52" {stroke(4)}/>',
         f'<path d="M6,72 L274,72" stroke="#8f6240" stroke-width="3"/>',
         f'<path d="M14,40 Q140,18 266,40 Z" fill="#6f4a33" {stroke(3.5)}/>']
    for x in (52, 140, 228):
        p.append(f'<ellipse cx="{x}" cy="36" rx="34" ry="9" fill="#5b3b28"/>')
    p.append(f'<rect x="96" y="80" width="88" height="16" rx="4" fill="#f1e2c4" {stroke(2.5)}/>')
    return svg(280, 108, "\n".join(p))


def crop(kind):
    if kind == "sprout":
        return svg(60, 50, f'<path d="M30,48 L30,26" stroke="#4f9a6a" stroke-width="5" stroke-linecap="round"/>'
                           f'<ellipse cx="20" cy="22" rx="12" ry="7" transform="rotate(-25 20 22)" fill="#7fc48f" {stroke(2.5)}/>'
                           f'<ellipse cx="40" cy="20" rx="12" ry="7" transform="rotate(25 40 20)" fill="#7fc48f" {stroke(2.5)}/>')
    if kind == "carrot":
        leaves = "".join(f'<path d="M40,46 Q{40 + dx},{20} {40 + dx * 1.4},4" fill="none" stroke="#4f9a6a" stroke-width="6" stroke-linecap="round"/>'
                         for dx in (-14, -4, 6, 16))
        return svg(80, 76, leaves + f'<path d="M24,48 Q40,40 56,48 L48,72 Q40,76 32,72 Z" fill="#f08a3c" {stroke(3)}/>')
    if kind == "dandelion":
        p = [f'<path d="M40,72 L40,30" stroke="#4f9a6a" stroke-width="5"/>']
        for a in (-40, -10, 20, 50):
            p.append(f'<ellipse cx="40" cy="64" rx="22" ry="6" transform="rotate({a} 40 64)" fill="#6fae6a" {stroke(2)}/>')
        for a in range(0, 360, 30):
            p.append(f'<ellipse cx="{40 + 10 * math.cos(math.radians(a)):.1f}" cy="{24 + 10 * math.sin(math.radians(a)):.1f}" rx="8" ry="4" '
                     f'transform="rotate({a} {40 + 10 * math.cos(math.radians(a)):.1f} {24 + 10 * math.sin(math.radians(a)):.1f})" fill="#f6d33c" {stroke(1.5)}/>')
        p.append('<circle cx="40" cy="24" r="7" fill="#f2b632"/>')
        return svg(80, 76, "\n".join(p))
    # a little rose bush
    p = [f'<ellipse cx="40" cy="52" rx="34" ry="22" fill="#4f9a6a" {stroke(3)}/>']
    for x, y in ((24, 40), (52, 34), (40, 56), (60, 54)):
        p.append(f'<circle cx="{x}" cy="{y}" r="10" fill="#e8738a" {stroke(2.5)}/>'
                 f'<path d="M{x - 5},{y} Q{x},{y - 6} {x + 5},{y} Q{x},{y + 4} {x - 3},{y - 1}" fill="none" stroke="#b84a62" stroke-width="2"/>')
    return svg(80, 76, "\n".join(p))


def window_cat():
    """The neighbour's ginger cat, peeking over the windowsill: head and two paws."""
    p = [f'<path d="M24,30 L18,2 L46,18 Z M96,30 L102,2 L74,18 Z" fill="#f0a35a" {stroke(3.5)}/>',
         '<path d="M26,24 L22,10 L38,19 Z M94,24 L98,10 L82,19 Z" fill="#f6c6b0"/>',
         f'<ellipse cx="60" cy="50" rx="46" ry="38" fill="#f0a35a" {stroke(4)}/>',
         '<path d="M44,18 L50,30 M60,14 L60,28 M76,18 L70,30" stroke="#d9823a" stroke-width="4" stroke-linecap="round"/>',
         '<ellipse cx="42" cy="50" rx="8" ry="10" fill="#9ccf6a"/><ellipse cx="78" cy="50" rx="8" ry="10" fill="#9ccf6a"/>',
         '<ellipse cx="42" cy="51" rx="3" ry="8" fill="#2f2a2a"/><ellipse cx="78" cy="51" rx="3" ry="8" fill="#2f2a2a"/>',
         '<path d="M56,62 L64,62 L60,67 Z" fill="#e98fae"/>',
         '<path d="M60,67 Q54,74 48,70 M60,67 Q66,74 72,70" fill="none" stroke="#4f3d33" stroke-width="2.5" stroke-linecap="round"/>',
         '<path d="M14,64 L34,66 M14,72 L34,70 M106,64 L86,66 M106,72 L86,70" stroke="#4f3d33" stroke-width="1.8"/>',
         f'<ellipse cx="30" cy="88" rx="16" ry="10" fill="#f0a35a" {stroke(3.5)}/><ellipse cx="90" cy="88" rx="16" ry="10" fill="#f0a35a" {stroke(3.5)}/>']
    return svg(120, 100, "\n".join(p))


for i, (f, b, d) in enumerate((("#e98fae", "#fff4cf", "#fff"), ("#7fb0d8", "#f3cf7a", "#fff"), ("#9cc5a1", "#e8505b", "#fff4cf"))):
    save(f"egg_{i}.svg", egg(f, b, d))
save("easter_decor.svg", easter_decor())
save("pumpkin.svg", pumpkin())
save("present_easter.svg", present("#bfe3c4", "#f3cf7a", dots="#e98fae"))
save("present_halloween.svg", present("#f0913a", "#3b3443", dots="#3b3443"))
save("egg_rattle.svg", svg(60, 76, egg("#f3cf7a", "#e98fae", "#7fb0d8")[egg("#f3cf7a", "#e98fae", "#7fb0d8").index(">") + 1:egg("#f3cf7a", "#e98fae", "#7fb0d8").rindex("</svg>")]))
save("wear_witch_hat.svg", svg(64, 66,
    f'<path d="M30,4 Q40,30 50,48 L14,48 Q22,26 30,4 Z" fill="#4b3d5c" {stroke(3.5)}/>'
    f'<rect x="16" y="38" width="32" height="8" fill="#f0913a"/>'
    f'<ellipse cx="32" cy="52" rx="30" ry="8" fill="#4b3d5c" {stroke(3.5)}/>'
    f'<path d="M30,4 Q40,30 50,48" fill="none" {stroke(3.5)}/>'))
save("veg_patch.svg", veg_patch())
for k in ("sprout", "carrot", "dandelion", "rose_petals"):
    save(f"crop_{k}.svg", crop(k.replace("_petals", "")))
save("window_cat.svg", window_cat())
save("icon_wish.svg", svg(64, 64,
    f'<circle cx="12" cy="56" r="5" fill="#fff8ee" {stroke(2.5)}/><circle cx="20" cy="46" r="7" fill="#fff8ee" {stroke(2.5)}/>'
    f'<path d="M20,32 C10,32 10,14 24,14 C26,4 44,4 46,12 C58,10 62,26 54,30 C58,40 44,44 38,40 C32,46 20,42 20,32 Z" fill="#fff8ee" {stroke(3)}/>'
    '<path d="M37,32 C30,26 30,19 34,18 C36,17.5 37,19 37,20 C37,19 38,17.5 40,18 C44,19 44,26 37,32 Z" fill="#e98fae"/>'))
save("icon_vet.svg", svg(64, 64,
    f'<rect x="8" y="16" width="48" height="40" rx="8" fill="#fff8ee" {stroke(4)}/>'
    f'<path d="M24,16 L24,10 Q24,6 28,6 L36,6 Q40,6 40,10 L40,16" fill="none" {stroke(4)}/>'
    '<path d="M32,24 L32,48 M20,36 L44,36" stroke="#e8505b" stroke-width="8" stroke-linecap="round"/>'))

# ---- long-term rewards ---------------------------------------------------------------

GOLD = "#f3c94f"
save("wear_gold_bowtie.svg", svg(48, 28,
    f'<path d="M24,14 L4,3 Q0,14 4,25 Z M24,14 L44,3 Q48,14 44,25 Z" fill="{GOLD}" {stroke(3)}/>'
    '<path d="M8,9 L16,13 M8,19 L16,15 M40,9 L32,13 M40,19 L32,15" stroke="#fff4cf" stroke-width="2" stroke-linecap="round"/>'
    f'<rect x="19" y="8" width="10" height="12" rx="3" fill="#e8b93a" {stroke(2.5)}/>'))
save("wear_gold_crown.svg", svg(60, 44,
    f'<path d="M6,38 L4,10 L18,22 L30,4 L42,22 L56,10 L54,38 Z" fill="{GOLD}" {stroke(3.5)}/>'
    f'<circle cx="30" cy="27" r="5" fill="#e8505b" {stroke(2)}/><circle cx="15" cy="30" r="3.5" fill="#7fb0d8" {stroke(2)}/>'
    f'<circle cx="45" cy="30" r="3.5" fill="#9cc5a1" {stroke(2)}/>'
    f'<circle cx="4" cy="9" r="3.5" fill="{GOLD}" {stroke(2)}/><circle cx="30" cy="4" r="3.5" fill="{GOLD}" {stroke(2)}/>'
    f'<circle cx="56" cy="9" r="3.5" fill="{GOLD}" {stroke(2)}/>'))
save("royal_cushion.svg", svg(170, 80,
    f'<path d="M14,30 Q85,4 156,30 Q166,52 156,70 Q85,80 14,70 Q4,52 14,30 Z" fill="#8a4d9e" {stroke(4)}/>'
    '<path d="M30,40 Q85,26 140,40" fill="none" stroke="#a96bbd" stroke-width="5" stroke-linecap="round"/>'
    f'<circle cx="85" cy="48" r="7" fill="{GOLD}" {stroke(2.5)}/>'
    + "".join(f'<path d="M{x},{y} l{dx},10" stroke="{GOLD}" stroke-width="4" stroke-linecap="round"/>'
              f'<circle cx="{x + dx}" cy="{y + 12}" r="4" fill="{GOLD}" {stroke(2)}/>' for x, y, dx in ((14, 30, -6), (156, 30, 6), (14, 70, -6), (156, 70, 6)))))


def statue():
    """A little golden Bubák on a marble plinth."""
    p = [f'<rect x="20" y="150" width="120" height="44" rx="6" fill="#ece8e2" {stroke(4)}/>',
         f'<rect x="12" y="140" width="136" height="16" rx="5" fill="#f6f3ee" {stroke(4)}/>',
         f'<rect x="56" y="164" width="48" height="16" rx="3" fill="{GOLD}" {stroke(2)}/>',
         f'<g transform="translate(6,4) scale(0.72)">{bunny("sit", parts=True)[bunny("sit", parts=True).index(">") + 1:bunny("sit", parts=True).rindex("</svg>")]}</g>']
    body = "\n".join(p)
    # gild the bunny: swap the fur colours for gold
    for c, g in ((FUR, GOLD), (FUR_DARK, "#d9a92e"), (FUR_LIGHT, "#f8dc7c"), (CREAM, "#fbe9a6"), (PINK, "#f0c050"),
                 (NOSE, "#d9a92e"), (BLUSH, "#f3c94f")):
        body = body.replace(c, g)
    return svg(160, 196, body)


def curio():
    """A glass cabinet with the souvenirs from all the walks."""
    p = [f'<rect x="10" y="10" width="150" height="210" rx="10" fill="#c08a5c" {stroke(4)}/>',
         f'<rect x="22" y="22" width="126" height="170" rx="6" fill="#e9f3f6" {stroke(3)}/>',
         '<path d="M22,78 H148 M22,136 H148" stroke="#c08a5c" stroke-width="6"/>',
         '<path d="M40,30 L60,180" stroke="#ffffff" stroke-width="6" opacity="0.6"/>',
         f'<rect x="60" y="198" width="50" height="12" rx="4" fill="{GOLD}" {stroke(2)}/>']
    things = [(48, 64, "#b07d52", 9), (85, 62, "#f6f3ee", 8), (120, 64, "#e8505b", 9), (50, 122, "#f3a35a", 10),
              (88, 122, "#9cd3c8", 8), (124, 120, GOLD, 9), (52, 180, "#f2e4c9", 9), (90, 178, "#3b3443", 9), (124, 180, "#7fb0d8", 8)]
    for x, y, c, r in things:
        p.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" {stroke(2.5)}/>')
    return svg(170, 228, "\n".join(p))


save("statue.svg", statue())
save("curio.svg", curio())


def souvenir(kind):
    """Little keepsakes Bubák brings back from walks (64x64 icons)."""
    S = lambda w=3: stroke(w)
    if kind == "acorn":
        b = f'<ellipse cx="32" cy="38" rx="14" ry="18" fill="#c98a4b" {S()}/><path d="M14,26 Q32,8 50,26 Q32,32 14,26 Z" fill="#8a5a36" {S()}/><path d="M32,12 L34,4" {S(4)}/>'
    elif kind == "feather":
        b = f'<path d="M14,54 Q20,20 50,8 Q46,36 14,54 Z" fill="#a7c0e8" {S()}/><path d="M14,54 L44,16" stroke="#4f3d33" stroke-width="2.5"/>'
    elif kind == "conker":
        b = f'<circle cx="32" cy="34" r="20" fill="#8a4a2c" {S()}/><ellipse cx="32" cy="26" rx="12" ry="7" fill="#d9b48a"/><ellipse cx="24" cy="38" rx="4" ry="6" fill="#b06a44" opacity="0.7"/>'
    elif kind == "clover":
        b = f'<path d="M32,34 L36,58" stroke="#4f9a6a" stroke-width="5" stroke-linecap="round"/>' + "".join(
            f'<circle cx="{32 + 11 * math.cos(math.radians(a)):.1f}" cy="{30 + 11 * math.sin(math.radians(a)):.1f}" r="10" fill="#5fb36f" {S(2.5)}/>' for a in (45, 135, 225, 315)) \
            + f'<circle cx="32" cy="30" r="4" fill="{GOLD}"/>'
    elif kind == "poppy":
        b = f'<path d="M32,40 L32,60" stroke="#4f9a6a" stroke-width="4"/>' + "".join(
            f'<circle cx="{32 + 10 * math.cos(math.radians(a)):.1f}" cy="{26 + 10 * math.sin(math.radians(a)):.1f}" r="11" fill="#e8505b" {S(2.5)}/>' for a in (0, 90, 180, 270)) \
            + '<circle cx="32" cy="26" r="6" fill="#3b3443"/>'
    elif kind == "wheat":
        b = '<path d="M32,60 L32,14" stroke="#c99a4b" stroke-width="4"/>' + "".join(
            f'<ellipse cx="{32 + s * 7}" cy="{18 + i * 9}" rx="6" ry="4" transform="rotate({s * 35} {32 + s * 7} {18 + i * 9})" fill="#f0c86a" {S(2)}/>'
            for i in range(4) for s in (-1, 1))
    elif kind == "pebble":
        b = f'<ellipse cx="32" cy="36" rx="24" ry="16" fill="#b9b6c2" {S()}/><ellipse cx="24" cy="30" rx="8" ry="4" fill="#fff" opacity="0.5"/>'
    elif kind == "horseshoe":
        b = f'<path d="M14,12 L14,34 Q14,56 32,56 Q50,56 50,34 L50,12 L40,12 L40,34 Q40,46 32,46 Q24,46 24,34 L24,12 Z" fill="{GOLD}" {S()}/>' \
            + "".join(f'<circle cx="{x}" cy="{y}" r="2" fill="#4f3d33"/>' for x, y in ((19, 22), (19, 36), (45, 22), (45, 36)))
    elif kind == "shell":
        b = f'<path d="M32,54 L8,28 Q32,0 56,28 Z" fill="#f6c6b0" {S()}/>' + "".join(
            f'<path d="M32,54 L{x},{y}" stroke="#d99a86" stroke-width="2.5"/>' for x, y in ((16, 22), (24, 14), (32, 12), (40, 14), (48, 22)))
    elif kind == "starfish":
        pts = " ".join(f"{32 + (26 if i % 2 == 0 else 11) * math.cos(math.radians(-90 + i * 36)):.1f},"
                       f"{34 + (26 if i % 2 == 0 else 11) * math.sin(math.radians(-90 + i * 36)):.1f}" for i in range(10))
        b = f'<polygon points="{pts}" fill="#f3935a" stroke="#4f3d33" stroke-width="3" stroke-linejoin="round"/>' \
            + "".join(f'<circle cx="{32 + 10 * math.cos(math.radians(-90 + i * 72)):.1f}" cy="{34 + 10 * math.sin(math.radians(-90 + i * 72)):.1f}" r="2" fill="#fff4cf"/>' for i in range(5))
    elif kind == "seaglass":
        b = f'<path d="M14,30 L28,12 L50,20 L52,42 L30,54 L12,44 Z" fill="#8fd0b8" opacity="0.85" {S()}/><path d="M22,26 L34,20" stroke="#fff" stroke-width="3" opacity="0.7"/>'
    elif kind == "pearl":
        b = f'<path d="M8,40 Q32,62 56,40 Z" fill="#c9b6d8" {S()}/><circle cx="32" cy="32" r="12" fill="#fbf6ee" {S()}/><circle cx="28" cy="28" r="4" fill="#fff"/>'
    elif kind == "postcard":
        b = f'<rect x="6" y="14" width="52" height="36" rx="3" fill="#fff8ee" {S()}/><rect x="40" y="18" width="14" height="14" fill="#e98fae" {S(2)}/>' \
            '<path d="M12,26 H34 M12,34 H34 M12,42 H28" stroke="#a7c0e8" stroke-width="3"/>'
    elif kind == "ticket":
        b = f'<rect x="8" y="20" width="48" height="26" rx="3" fill="#f3cf7a" {S()}/><path d="M18,20 V46" stroke="#4f3d33" stroke-width="2" stroke-dasharray="3 3"/>' \
            '<path d="M24,30 H50 M24,37 H44" stroke="#4f3d33" stroke-width="2.5"/>'
    elif kind == "badge":
        b = f'<circle cx="32" cy="32" r="22" fill="#9cd3c8" {S()}/><path d="M22,28 L42,28 L40,42 L24,42 Z" fill="#fff8ee" {S(2.5)}/>' \
            '<path d="M42,31 Q48,33 42,38" fill="none" stroke="#4f3d33" stroke-width="2.5"/><path d="M28,24 Q30,18 28,14 M34,24 Q36,18 34,14" stroke="#fff" stroke-width="2" fill="none"/>'
    elif kind == "key":
        b = f'<circle cx="20" cy="32" r="12" fill="none" stroke="{GOLD}" stroke-width="7"/><circle cx="20" cy="32" r="12" fill="none" {S(2)}/>' \
            f'<path d="M31,32 H56 M48,32 V42 M54,32 V40" stroke="{GOLD}" stroke-width="6" stroke-linecap="round"/>'
    elif kind == "stub":
        b = f'<path d="M10,18 H54 V46 H10 L14,40 L10,34 L14,28 L10,22 Z" fill="#e8505b" {S()}/><path d="M22,26 H48 M22,34 H44" stroke="#fff4cf" stroke-width="3"/>'
    elif kind == "reel":
        b = f'<circle cx="32" cy="32" r="24" fill="#3b3443" {S()}/>' + "".join(
            f'<circle cx="{32 + 12 * math.cos(math.radians(a)):.1f}" cy="{32 + 12 * math.sin(math.radians(a)):.1f}" r="6" fill="#d9d4e0"/>' for a in range(0, 360, 72)) \
            + '<circle cx="32" cy="32" r="4" fill="#d9d4e0"/>'
    elif kind == "glasses3d":
        b = f'<rect x="6" y="22" width="52" height="22" rx="4" fill="#fff8ee" {S()}/><rect x="11" y="26" width="18" height="14" rx="3" fill="#e8505b"/>' \
            '<rect x="35" y="26" width="18" height="14" rx="3" fill="#7fb0d8"/>'
    else:   # autograph
        b = f'<rect x="8" y="10" width="48" height="44" rx="4" fill="#fff8ee" {S()}/>' \
            f'<path d="M32,16 L35,25 L44,25 L37,30 L40,39 L32,34 L24,39 L27,30 L20,25 L29,25 Z" fill="{GOLD}" stroke="#4f3d33" stroke-width="2"/>' \
            '<path d="M14,46 q6,-8 10,0 t10,0 t10,-2 t6,2" fill="none" stroke="#3b3443" stroke-width="2.5"/>'
    return svg(64, 64, b)


for _k in ("acorn", "feather", "conker", "clover", "poppy", "wheat", "pebble", "horseshoe", "shell", "starfish", "seaglass",
           "pearl", "postcard", "ticket", "badge", "key", "stub", "reel", "glasses3d", "autograph"):
    save(f"icon_souv_{_k}.svg", souvenir(_k))

# app icon: Bubák's face on a warm circle
icon = (f'<circle cx="128" cy="128" r="120" fill="#f7e6d0" {stroke(8)}/>'
        f'<g transform="translate(122,170) scale(1.3)">{head(0, 0, 0, -8, "open", seed=11)}</g>')
save("icon.svg", svg(256, 256, icon))
print("art written to", os.path.abspath(OUT))


# ---- the late game: merch products, the league cup ------------------------------------
save("icon_merch_stickers.svg", svg(64, 64,
    f'<rect x="8" y="8" width="48" height="48" rx="6" fill="#fff8ee" {stroke(3.5)}/>'
    f'<circle cx="23" cy="23" r="9" fill="#e98fae" {stroke(2.5)}/><circle cx="42" cy="24" r="8" fill="#f3c94f" {stroke(2.5)}/>'
    f'<path d="M14,48 L22,36 L30,48 Z" fill="#7fcfb8" {stroke(2.5)}/><circle cx="43" cy="43" r="8" fill="#a7c0e8" {stroke(2.5)}/>'))
save("icon_merch_mug.svg", svg(64, 64,
    f'<path d="M44,24 Q58,24 56,36 Q54,46 42,44" fill="none" {stroke(5)}/>'
    f'<path d="M10,14 H46 V50 Q46,58 38,58 H18 Q10,58 10,50 Z" fill="#fff8ee" {stroke(4)}/>'
    '<path d="M28,40 C21,34 21,27 25,26 C27,25.5 28,27 28,28 C28,27 29,25.5 31,26 C35,27 35,34 28,40 Z" fill="#e98fae"/>'))
save("icon_merch_calendar.svg", svg(64, 64,
    f'<rect x="8" y="12" width="48" height="46" rx="6" fill="#fff8ee" {stroke(4)}/>'
    f'<rect x="8" y="12" width="48" height="12" rx="6" fill="#e8505b" {stroke(4)}/>'
    '<path d="M20,6 V16 M44,6 V16" stroke="#4f3d33" stroke-width="4" stroke-linecap="round"/>'
    + "".join(f'<rect x="{14 + (i % 4) * 10}" y="{30 + (i // 4) * 9}" width="6" height="5" rx="1" fill="#c9b8a6"/>' for i in range(12))))
save("icon_merch_plush.svg", svg(64, 64,
    f'<ellipse cx="22" cy="16" rx="6" ry="13" fill="#b7a6c9" {stroke(3)}/><ellipse cx="40" cy="16" rx="6" ry="13" fill="#b7a6c9" {stroke(3)}/>'
    f'<ellipse cx="32" cy="44" rx="20" ry="16" fill="#b7a6c9" {stroke(3.5)}/><circle cx="32" cy="32" r="14" fill="#b7a6c9" {stroke(3.5)}/>'
    '<circle cx="27" cy="31" r="2.2" fill="#4f3d33"/><circle cx="37" cy="31" r="2.2" fill="#4f3d33"/>'
    '<circle cx="32" cy="36" r="2" fill="#e98fae"/><path d="M26,52 h12" stroke="#f3c94f" stroke-width="4" stroke-linecap="round"/>'))
save("icon_merch_hoodie.svg", svg(64, 64,
    f'<path d="M20,10 Q32,4 44,10 L58,22 L50,32 L46,28 V58 H18 V28 L14,32 L6,22 Z" fill="#7fa7d8" {stroke(3.5)}/>'
    f'<path d="M24,10 Q32,22 40,10" fill="#6a92c4" {stroke(3)}/>'
    '<path d="M32,46 C26,41 26,35 29,34 C31,33.5 32,35 32,36 C32,35 33,33.5 35,34 C38,35 38,41 32,46 Z" fill="#fff8ee"/>'))
save("icon_league.svg", svg(64, 64,
    f'<path d="M16,8 H48 V22 Q48,40 32,42 Q16,40 16,22 Z" fill="#f3c94f" {stroke(3.5)}/>'
    f'<path d="M16,14 Q4,14 6,24 Q8,32 18,30 M48,14 Q60,14 58,24 Q56,32 46,30" fill="none" {stroke(3.5)}/>'
    f'<rect x="28" y="42" width="8" height="8" fill="#e8b93a" {stroke(3)}/><rect x="18" y="50" width="28" height="8" rx="3" fill="#a9825a" {stroke(3)}/>'
    '<path d="M27,20 l5,-6 5,6 -5,6 z" fill="#fff4cf"/>'))
save("icon_foster.svg", svg(64, 64,
    f'<path d="M8,30 L32,10 L56,30 V56 H8 Z" fill="#f6dccd" {stroke(4)}/>'
    '<path d="M32,48 C22,40 22,30 27,29 C30,28.5 32,31 32,32 C32,31 34,28.5 37,29 C42,30 42,40 32,48 Z" fill="#e98fae"/>'))
save("icon_agility.svg", svg(64, 64,
    '<path d="M8,56 H56" stroke="#8fb466" stroke-width="5" stroke-linecap="round"/>'
    f'<rect x="30" y="36" width="5" height="20" fill="#8a6247" {stroke(2)}/><rect x="52" y="36" width="5" height="20" fill="#8a6247" {stroke(2)}/>'
    f'<rect x="27" y="36" width="33" height="6" rx="2" fill="#e8505b" {stroke(2)}/>'
    '<path d="M36,36 h6 M48,36 h6" stroke="#ffffff" stroke-width="4"/>'
    '<path d="M6,44 Q22,6 46,18" fill="none" stroke="#c9b8a6" stroke-width="3" stroke-dasharray="4 4" stroke-linecap="round"/>'
    f'<ellipse cx="36" cy="18" rx="11" ry="8" fill="#b7a6c9" {stroke(3)}/>'
    f'<ellipse cx="45" cy="9" rx="3.5" ry="8" fill="#b7a6c9" transform="rotate(35 45 9)" {stroke(2.5)}/>'
    '<circle cx="44" cy="17" r="1.8" fill="#4f3d33"/>'))


# ---- coming back for more: seasons, the dig box, the garden, personality -------------------
GOLD2 = "#f3c94f"
# seasonal finds, drawn like the other accessories
save("wear_blossom.svg", svg(36, 36,
    "".join(f'<ellipse cx="{18 + 8 * math.cos(math.radians(a)):.1f}" cy="{18 + 8 * math.sin(math.radians(a)):.1f}" rx="7" ry="6" '
            f'fill="#f6c1d0" {stroke(2)}/>' for a in range(-90, 270, 72))
    + f'<circle cx="18" cy="18" r="4.5" fill="#e98fae" {stroke(2)}/>'
    + "".join(f'<circle cx="{18 + 3 * math.cos(math.radians(a)):.1f}" cy="{18 + 3 * math.sin(math.radians(a)):.1f}" r="1.2" fill="{GOLD2}"/>'
              for a in range(0, 360, 72))))
save("wear_straw_hat.svg", svg(96, 50,
    f'<ellipse cx="48" cy="38" rx="45" ry="10" fill="#ead08a" {stroke(3.5)}/>'
    f'<path d="M24,38 Q24,8 48,8 Q72,8 72,38 Z" fill="#ead08a" {stroke(3.5)}/>'
    '<path d="M25,30 Q48,36 71,30 L71,36 Q48,42 25,36 Z" fill="#e8505b"/>'
    + "".join(f'<path d="M{30 + i * 9},14 L{28 + i * 9},30" stroke="#d2b46a" stroke-width="2"/>' for i in range(5))))
save("wear_scarf.svg", svg(76, 52,
    f'<path d="M4,10 Q38,26 72,10 L72,24 Q38,40 4,24 Z" fill="#e8505b" {stroke(3)}/>'
    + "".join(f'<path d="M{12 + i * 14},{14 + (3 if i in (1, 2, 3) else 0)} L{12 + i * 14},{28 + (3 if i in (1, 2, 3) else 0)}" stroke="#f6e9d6" stroke-width="5"/>'
              for i in range(5))
    + f'<path d="M50,26 L58,50 L68,46 L62,24 Z" fill="#e8505b" {stroke(3)}/>'
    '<path d="M57,46 v5 M61,45 v5 M65,44 v5" stroke="#4f3d33" stroke-width="2"/>'))
save("wear_snowflake.svg", svg(36, 36,
    "".join(f'<path d="M18,18 L{18 + 15 * math.cos(math.radians(a)):.1f},{18 + 15 * math.sin(math.radians(a)):.1f}" stroke="#7fb0d8" stroke-width="4" stroke-linecap="round"/>'
            f'<path d="M{18 + 9 * math.cos(math.radians(a)) + 4 * math.cos(math.radians(a + 60)):.1f},{18 + 9 * math.sin(math.radians(a)) + 4 * math.sin(math.radians(a + 60)):.1f} '
            f'L{18 + 9 * math.cos(math.radians(a)):.1f},{18 + 9 * math.sin(math.radians(a)):.1f} '
            f'L{18 + 9 * math.cos(math.radians(a)) + 4 * math.cos(math.radians(a - 60)):.1f},{18 + 9 * math.sin(math.radians(a)) + 4 * math.sin(math.radians(a - 60)):.1f}" '
            'fill="none" stroke="#7fb0d8" stroke-width="2.5" stroke-linecap="round"/>' for a in range(0, 360, 60))
    + '<circle cx="18" cy="18" r="3.5" fill="#ffffff" stroke="#7fb0d8" stroke-width="2"/>'))
# the golden carrot, its seed, the bigger patch, parsley
GC = (f'<path d="M24,30 Q40,22 56,30 L48,66 Q40,72 32,66 Z" fill="{GOLD2}" {stroke(3)}/>'
      '<path d="M32,38 h8 M36,48 h8 M34,58 h6" stroke="#d99a2a" stroke-width="3" stroke-linecap="round"/>'
      '<path d="M30,36 L33,32" stroke="#fff4cf" stroke-width="3" stroke-linecap="round"/>')
GC_LEAVES = "".join(f'<path d="M40,30 Q{40 + dx},{14} {40 + dx * 1.3},2" fill="none" stroke="#4f9a6a" stroke-width="5" stroke-linecap="round"/>'
                    for dx in (-12, 0, 12))
save("icon_golden_carrot.svg", svg(80, 76, GC_LEAVES + GC
    + "".join(f'<path d="M{x},{y} l2,-5 2,5 5,2 -5,2 -2,5 -2,-5 -5,-2z" fill="#fff4cf" stroke="#d99a2a" stroke-width="1"/>' for x, y in ((14, 40), (64, 52), (62, 22)))))
save("crop_golden_carrot.svg", svg(80, 76, GC_LEAVES.replace("2\" fill", "2\" fill") + GC))
save("icon_golden_seed.svg", svg(64, 64,
    f'<path d="M32,8 Q50,26 44,46 Q38,58 32,58 Q26,58 20,46 Q14,26 32,8 Z" fill="{GOLD2}" {stroke(3.5)}/>'
    '<path d="M32,16 Q38,30 34,48" fill="none" stroke="#d99a2a" stroke-width="3"/>'
    '<path d="M24,26 L27,22" stroke="#fff4cf" stroke-width="3" stroke-linecap="round"/>'))
save("icon_garden_beds.svg", svg(64, 64,
    f'<rect x="4" y="30" width="56" height="26" rx="5" fill="#b07d52" {stroke(3.5)}/>'
    '<path d="M4,43 H60" stroke="#8f6240" stroke-width="2.5"/>'
    + "".join(f'<path d="M{x},30 L{x},16 M{x},22 L{x - 6},14 M{x},22 L{x + 6},14" stroke="#4f9a6a" stroke-width="3.5" stroke-linecap="round"/>' for x in (14, 32, 50))
    + f'<circle cx="52" cy="10" r="8" fill="#9cc5a1" {stroke(2.5)}/><path d="M52,6 v8 M48,10 h8" stroke="#4f3d33" stroke-width="2.5"/>'))
save("crop_parsley.svg", svg(80, 76,
    "".join(f'<path d="M40,72 Q{40 + dx * 0.5},{50} {40 + dx},{28 + abs(dx) * 0.4}" fill="none" stroke="#4f8a52" stroke-width="4" stroke-linecap="round"/>'
            f'<circle cx="{40 + dx}" cy="{24 + abs(dx) * 0.4}" r="9" fill="#5fa85f" {stroke(2.5)}/>'
            f'<circle cx="{40 + dx - 6}" cy="{30 + abs(dx) * 0.4}" r="6" fill="#6fb86a" {stroke(2)}/>' for dx in (-20, 0, 20))))
# the treasure chest (a decor reward) and the things he digs up
save("treasure_chest.svg", svg(150, 120,
    f'<rect x="10" y="50" width="130" height="64" rx="8" fill="#a8693c" {stroke(4)}/>'
    f'<path d="M10,52 Q10,14 75,14 Q140,14 140,52 Z" fill="#c0804a" {stroke(4)}/>'
    f'<path d="M30,18 V112 M120,18 V112" stroke="{GOLD2}" stroke-width="9"/><path d="M30,18 V112 M120,18 V112" stroke="#4f3d33" stroke-width="2" stroke-dasharray="1 0"/>'
    f'<rect x="64" y="44" width="22" height="26" rx="4" fill="{GOLD2}" {stroke(3)}/><circle cx="75" cy="55" r="4" fill="#4f3d33"/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="7" fill="{GOLD2}" {stroke(2)}/>' for x, y in ((48, 12), (62, 8), (90, 9), (104, 13), (76, 4)))))
FIND_ART = {
    "button": f'<circle cx="32" cy="32" r="22" fill="#e98fae" {stroke(3.5)}/><circle cx="32" cy="32" r="15" fill="none" stroke="#c9668a" stroke-width="2.5"/>'
              + "".join(f'<circle cx="{x}" cy="{y}" r="3.2" fill="#4f3d33"/>' for x, y in ((27, 27), (37, 27), (27, 37), (37, 37))),
    "marble": f'<circle cx="32" cy="34" r="20" fill="#a7d8e8" opacity="0.9" {stroke(3.5)}/>'
              '<path d="M18,36 Q30,22 46,30 Q34,40 18,36 Z" fill="#e8505b" opacity="0.85"/><circle cx="25" cy="26" r="5" fill="#fff" opacity="0.8"/>',
    "cap": f'<circle cx="32" cy="34" r="20" fill="#7fb0d8" {stroke(3.5)}/>'
           + "".join(f'<path d="M{32 + 20 * math.cos(math.radians(a)):.1f},{34 + 20 * math.sin(math.radians(a)):.1f} '
                     f'L{32 + 24 * math.cos(math.radians(a + 10)):.1f},{34 + 24 * math.sin(math.radians(a + 10)):.1f}" stroke="#4f3d33" stroke-width="3"/>' for a in range(0, 360, 30))
           + '<circle cx="32" cy="34" r="10" fill="#fff8ee"/>',
    "coin": f'<circle cx="32" cy="32" r="22" fill="#c9a35a" {stroke(3.5)}/><circle cx="32" cy="32" r="15" fill="none" stroke="#a8823e" stroke-width="3"/>'
            '<path d="M26,26 Q32,20 38,26 Q38,32 32,34 Q26,36 26,42 Q32,48 38,42" fill="none" stroke="#7a5a2a" stroke-width="3"/>',
    "ring": f'<circle cx="32" cy="38" r="15" fill="none" stroke="{GOLD2}" stroke-width="7"/><circle cx="32" cy="38" r="15" fill="none" {stroke(2)}/>'
            f'<path d="M24,16 L32,6 L40,16 L32,26 Z" fill="#a7e0f0" {stroke(2.5)}/>',
    "map": f'<path d="M8,12 L36,8 L40,22 L56,26 L52,56 L12,52 Z" fill="#f1dfb4" {stroke(3.5)}/>'
           '<path d="M16,40 Q24,30 30,36 T44,30" fill="none" stroke="#c0804a" stroke-width="2.5" stroke-dasharray="4 3"/>',
}
for _k, _b in FIND_ART.items():
    save(f"icon_find_{_k}.svg", svg(64, 64, _b))
save("icon_treasure_map.svg", svg(64, 64,
    f'<path d="M6,10 L22,6 L42,12 L58,6 L58,54 L42,58 L22,52 L6,58 Z" fill="#f1dfb4" {stroke(3.5)}/>'
    '<path d="M22,6 V52 M42,12 V58" stroke="#d9c08a" stroke-width="2.5"/>'
    '<path d="M12,46 Q22,30 30,38 T44,24" fill="none" stroke="#c0804a" stroke-width="3" stroke-dasharray="4 3"/>'
    '<path d="M42,18 l8,8 M50,18 l-8,8" stroke="#e8505b" stroke-width="4" stroke-linecap="round"/>'))
# Bubák's ears sticking out from behind the furniture (hide and seek)
save("peek_ears.svg", svg(80, 90,
    f'<ellipse cx="26" cy="46" rx="12" ry="36" transform="rotate(-12 26 46)" fill="{FUR}" {stroke(4)}/>'
    '<ellipse cx="27" cy="50" rx="6" ry="26" transform="rotate(-12 27 50)" fill="#f2b3bd"/>'
    f'<path d="M50,84 Q48,36 62,20 Q74,10 76,28 Q72,48 64,84 Z" fill="{FUR}" {stroke(4)}/>'
    '<path d="M56,80 Q56,44 64,30 Q70,26 70,36 Q66,52 62,80 Z" fill="#f2b3bd"/>'))
# the autumn leaf pile on the balcony
save("leaf_pile.svg", svg(200, 80,
    f'<path d="M8,74 Q20,30 60,24 Q100,6 140,22 Q186,30 194,74 Z" fill="#c8562e" {stroke(4)}/>'
    + "".join(f'<ellipse cx="{x}" cy="{y}" rx="13" ry="7" transform="rotate({r} {x} {y})" fill="{c}" {stroke(2)}/>'
              for x, y, r, c in ((40, 50, 20, "#e8b04a"), (70, 34, -30, "#d9822b"), (104, 24, 10, "#e8b04a"), (138, 34, 40, "#9a5b2e"),
                                 (162, 54, -20, "#d9822b"), (90, 56, 60, "#9a5b2e"), (124, 58, -10, "#e8b04a"), (58, 64, 0, "#d9822b")))))
# personality, stickers, the album, a storm
save("icon_trait_athlete.svg", svg(64, 64,
    f'<path d="M8,48 Q8,36 20,36 L36,34 Q44,22 52,26 L58,40 Q58,50 48,50 L14,52 Q8,52 8,48 Z" fill="#7fb0d8" {stroke(3.5)}/>'
    '<path d="M8,50 H58" stroke="#fff8ee" stroke-width="4"/><path d="M30,36 l4,6 M36,34 l4,6" stroke="#4f3d33" stroke-width="2.5"/>'
    '<path d="M4,24 h12 M2,32 h10 M6,16 h10" stroke="#c9b8a6" stroke-width="3" stroke-linecap="round"/>'))
save("icon_trait_cuddler.svg", svg(64, 64,
    f'<path d="M6,58 V40 Q6,34 12,34 H40 Q46,34 46,40 V44 Q46,48 40,48 H28 V58 Z" fill="#f7cdb0" {stroke(3.5)}/>'
    '<path d="M38,30 C24,20 26,8 34,8 C38,8 40,12 40,14 C40,12 42,8 46,8 C54,8 56,20 42,30 Z" fill="#e98fae" stroke="#4f3d33" stroke-width="3"/>'))
save("icon_trait_showoff.svg", svg(64, 64,
    f'<path d="M32,6 l7,16 l17,2 l-13,11 l4,17 l-15,-9 l-15,9 l4,-17 l-13,-11 l17,-2z" fill="{GOLD2}" {stroke(3)}/>'
    '<path d="M54,6 l2,5 5,2 -5,2 -2,5 -2,-5 -5,-2 5,-2z M10,48 l2,5 5,2 -5,2 -2,5 -2,-5 -5,-2 5,-2z" fill="#e98fae"/>'))
save("icon_trait_explorer.svg", svg(64, 64,
    f'<circle cx="32" cy="32" r="24" fill="#fff8ee" {stroke(3.5)}/><circle cx="32" cy="32" r="18" fill="none" stroke="#c9b8a6" stroke-width="2"/>'
    '<path d="M32,12 L38,32 L32,52 L26,32 Z" fill="#e8505b" stroke="#4f3d33" stroke-width="2.5"/><path d="M32,32 L38,32 L32,52 L26,32 Z" fill="#a7c0e8"/>'
    '<circle cx="32" cy="32" r="3" fill="#4f3d33"/>'))
save("icon_sticker.svg", svg(64, 64,
    f'<circle cx="32" cy="32" r="26" fill="#9cd3c8" {stroke(3.5)}/>'
    f'<path d="M32,12 l5.5,12.5 l13.5,1.5 l-10,9 l3,13.5 l-12,-7 l-12,7 l3,-13.5 l-10,-9 l13.5,-1.5z" fill="{GOLD2}" {stroke(2.5)}/>'
    '<path d="M50,50 Q46,40 56,40" fill="#fff" stroke="#4f3d33" stroke-width="2"/>'))
save("icon_album.svg", svg(64, 64,
    f'<rect x="8" y="8" width="48" height="50" rx="5" fill="#d8a7d0" {stroke(4)}/>'
    f'<rect x="16" y="16" width="32" height="24" rx="2" fill="#fff8ee" {stroke(2.5)}/>'
    '<path d="M18,38 L28,28 L34,34 L38,30 L46,38 Z" fill="#9cc5a1"/><circle cx="40" cy="22" r="3" fill="#f3cf7a"/>'
    '<path d="M18,48 H46" stroke="#fff8ee" stroke-width="3"/>'))
save("icon_storm.svg", svg(64, 64,
    f'<path d="M14,40 C4,40 4,24 16,24 C18,12 36,10 40,20 C52,16 60,30 52,40 Z" fill="#9aa3b5" {stroke(3.5)}/>'
    f'<path d="M34,36 L26,50 L34,50 L28,62 L42,46 L34,46 L40,36 Z" fill="{GOLD2}" stroke="#4f3d33" stroke-width="2.5" stroke-linejoin="round"/>'))
save("icon_kid.svg", svg(64, 64,
    f'<circle cx="32" cy="24" r="14" fill="#f7cdb0" {stroke(3.5)}/>'
    f'<path d="M18,20 Q20,6 32,8 Q44,6 46,20 Q40,14 32,16 Q24,14 18,20 Z" fill="#8a5a36" {stroke(2.5)}/>'
    '<circle cx="27" cy="25" r="2" fill="#4f3d33"/><circle cx="37" cy="25" r="2" fill="#4f3d33"/><path d="M28,31 q4,3 8,0" fill="none" stroke="#4f3d33" stroke-width="2"/>'
    f'<path d="M14,60 Q14,40 32,40 Q50,40 50,60 Z" fill="#f3c94f" {stroke(3.5)}/>'))


# ---- the top of the game: advanced tricks, the Games, the advent calendar, ladders, the book ----
G3 = "#f3c94f"
save("icon_trick_bow.svg", svg(64, 64,
    f'<path d="M8,52 H58" stroke="#c9b8a6" stroke-width="4" stroke-linecap="round"/>'
    f'<ellipse cx="38" cy="38" rx="17" ry="12" fill="{FUR}" {stroke(3)}/><circle cx="20" cy="44" r="10" fill="{FUR}" {stroke(3)}/>'
    f'<ellipse cx="14" cy="30" rx="4" ry="11" transform="rotate(-30 14 30)" fill="{FUR}" {stroke(2.5)}/>'
    '<circle cx="17" cy="44" r="1.8" fill="#4f3d33"/><path d="M40,10 l2,5 5,2 -5,2 -2,5 -2,-5 -5,-2 5,-2z" fill="#e98fae"/>'))
save("icon_trick_high_five.svg", svg(64, 64,
    f'<path d="M44,8 v18 q0,8 8,8 h4 v-22 q0,-6 -6,-6 z" fill="#f7cdb0" {stroke(3)}/>'
    f'<ellipse cx="22" cy="44" rx="13" ry="15" fill="{FUR}" {stroke(3)}/><path d="M30,36 L42,24" stroke="{FUR}" stroke-width="7" stroke-linecap="round"/>'
    '<path d="M30,36 L42,24" fill="none" stroke="#4f3d33" stroke-width="2" stroke-linecap="round" stroke-dasharray="0"/>'
    '<path d="M36,14 l3,-6 M30,18 l-3,-5 M42,30 l6,1" stroke="#e0901c" stroke-width="3" stroke-linecap="round"/>'))
save("icon_trick_fetch.svg", svg(64, 64,
    '<path d="M6,54 H58" stroke="#c9b8a6" stroke-width="4" stroke-linecap="round"/>'
    f'<ellipse cx="22" cy="40" rx="15" ry="11" fill="{FUR}" {stroke(3)}/>'
    f'<circle cx="46" cy="44" r="10" fill="#f6dc6e" {stroke(3)}/><path d="M38,40 q8,-6 16,2" fill="none" stroke="#e8505b" stroke-width="3"/>'
    '<path d="M14,22 q14,-14 30,6" fill="none" stroke="#4f3d33" stroke-width="2.5" stroke-dasharray="4 3"/>'))
save("icon_trick_slalom.svg", svg(64, 64,
    f'<rect x="18" y="6" width="9" height="50" rx="4" fill="#5b78a8" {stroke(2.5)}/><rect x="38" y="6" width="9" height="50" rx="4" fill="#5b78a8" {stroke(2.5)}/>'
    '<path d="M4,46 Q18,30 32,46 T60,46" fill="none" stroke="#e98fae" stroke-width="4" stroke-dasharray="5 4" stroke-linecap="round"/>'))
save("icon_ladder.svg", svg(64, 64,
    f'<path d="M18,60 L26,4 M46,60 L38,4" stroke="#a8693c" stroke-width="6" stroke-linecap="round"/>'
    + "".join(f'<path d="M{19 + i * 1.2},{50 - i * 11} H{45 - i * 1.2}" stroke="#c0804a" stroke-width="5" stroke-linecap="round"/>' for i in range(4))
    + f'<path d="M32,2 l3,6 7,1 -5,5 1,7 -6,-3 -6,3 1,-7 -5,-5 7,-1z" fill="{G3}" {stroke(2)}/>'))
CUP = (f'<path d="M30,10 H90 V40 Q90,78 60,82 Q30,78 30,40 Z" fill="{G3}" {stroke(4)}/>'
       f'<path d="M30,20 Q8,20 10,40 Q12,56 32,54 M90,20 Q112,20 110,40 Q108,56 88,54" fill="none" {stroke(4)}/>'
       f'<rect x="52" y="82" width="16" height="16" fill="#e8b93a" {stroke(3)}/><rect x="34" y="98" width="52" height="16" rx="4" fill="#a9825a" {stroke(3)}/>'
       '<path d="M60,26 l6,12 13,1 -10,9 3,13 -12,-7 -12,7 3,-13 -10,-9 13,-1z" fill="#fff4cf"/>'
       '<ellipse cx="22" cy="12" rx="5" ry="12" transform="rotate(-20 22 12)" fill="#e98fae" stroke="#4f3d33" stroke-width="2.5"/>'
       '<ellipse cx="98" cy="12" rx="5" ry="12" transform="rotate(20 98 12)" fill="#e98fae" stroke="#4f3d33" stroke-width="2.5"/>')
save("games_cup.svg", svg(120, 118, CUP))
save("wear_santa_hat.svg", svg(64, 66,
    f'<path d="M12,48 Q18,14 44,8 Q56,6 58,26 Q50,18 44,22 Q36,30 50,48 Z" fill="#e8505b" {stroke(3.5)}/>'
    f'<rect x="6" y="42" width="50" height="12" rx="6" fill="#fdfbf6" {stroke(3)}/>'
    f'<circle cx="57" cy="28" r="7" fill="#fdfbf6" {stroke(3)}/>'))
save("snow_globe.svg", svg(110, 120,
    f'<circle cx="55" cy="50" r="44" fill="#d9ecf7" fill-opacity="0.85" {stroke(4)}/>'
    f'<ellipse cx="55" cy="78" rx="34" ry="9" fill="#ffffff"/>'
    f'<ellipse cx="55" cy="66" rx="14" ry="11" fill="{FUR}" {stroke(2.5)}/><circle cx="62" cy="56" r="8" fill="{FUR}" {stroke(2.5)}/>'
    f'<ellipse cx="64" cy="44" rx="3" ry="8" fill="{FUR}" {stroke(2)}/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="2.5" fill="#ffffff"/>' for x, y in ((30, 30), (44, 22), (72, 26), (80, 44), (36, 50), (58, 34)))
    + f'<path d="M22,88 H88 L96,112 H14 Z" fill="#a8693c" {stroke(4)}/><circle cx="40" cy="30" r="6" fill="#fff" opacity="0.6"/>'))
save("tulip_bed.svg", svg(170, 110,
    f'<path d="M6,104 Q6,74 85,72 Q164,74 164,104 Z" fill="#8a5a36" {stroke(4)}/>'
    + "".join(f'<path d="M{x},86 V{48 + (i % 2) * 8}" stroke="#4f9a6a" stroke-width="4"/>'
              f'<path d="M{x - 11},{44 + (i % 2) * 8} Q{x - 12},{24 + (i % 2) * 8} {x - 5},{30 + (i % 2) * 8} L{x},{22 + (i % 2) * 8} L{x + 5},{30 + (i % 2) * 8} Q{x + 12},{24 + (i % 2) * 8} {x + 11},{44 + (i % 2) * 8} Q{x},{56 + (i % 2) * 8} {x - 11},{44 + (i % 2) * 8} Z" '
              f'fill="{c}" {stroke(2.5)}/>' for i, (x, c) in enumerate(((30, "#e8505b"), (58, "#f3c94f"), (86, "#e98fae"), (114, "#d8a7d0"), (140, "#e8505b"))))))
save("paddling_pool.svg", svg(220, 90,
    f'<ellipse cx="110" cy="52" rx="104" ry="34" fill="#7fb0d8" {stroke(4)}/>'
    f'<ellipse cx="110" cy="48" rx="86" ry="24" fill="#a7e0f0"/>'
    '<path d="M60,46 q10,-6 20,0 M120,40 q10,-6 20,0 M90,56 q10,-6 20,0" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>'
    f'<circle cx="160" cy="44" r="10" fill="{G3}" {stroke(2.5)}/><path d="M154,44 h12" stroke="#e8505b" stroke-width="3"/>'))
save("hay_bale.svg", svg(150, 110,
    f'<rect x="8" y="22" width="134" height="80" rx="12" fill="#e2bd78" {stroke(4)}/>'
    + "".join(f'<path d="M{20 + i * 14},{30 + (i % 3) * 3} L{24 + i * 14},{94 - (i % 2) * 4}" stroke="#c99a4b" stroke-width="3"/>' for i in range(9))
    + '<path d="M44,22 V102 M106,22 V102" stroke="#a8693c" stroke-width="6"/>'
    + "".join(f'<path d="M{x},22 l{d},-12" stroke="#d9b060" stroke-width="3" stroke-linecap="round"/>' for x, d in ((30, -4), (70, 2), (120, 5)))))
save("snowman.svg", svg(110, 150,
    f'<circle cx="55" cy="112" r="34" fill="#fdfbf6" {stroke(4)}/><circle cx="55" cy="58" r="25" fill="#fdfbf6" {stroke(4)}/>'
    '<circle cx="46" cy="52" r="3" fill="#4f3d33"/><circle cx="64" cy="52" r="3" fill="#4f3d33"/>'
    f'<path d="M55,60 L78,66 L55,66 Z" fill="#f08a3c" stroke="#4f3d33" stroke-width="2"/>'
    f'<rect x="32" y="76" width="46" height="10" rx="5" fill="#e8505b" {stroke(2.5)}/><path d="M68,82 L74,104" stroke="#e8505b" stroke-width="8" stroke-linecap="round"/>'
    f'<rect x="38" y="20" width="34" height="14" rx="3" fill="#3b3443" {stroke(3)}/><rect x="30" y="32" width="50" height="6" rx="3" fill="#3b3443" {stroke(2.5)}/>'
    + "".join(f'<circle cx="55" cy="{y}" r="3" fill="#4f3d33"/>' for y in (100, 114, 128))))
BOOKART = (f'<path d="M10,14 H90 Q96,14 96,20 V100 Q96,106 90,106 H10 Z" fill="#7fa7d8" {stroke(4)}/>'
           f'<rect x="10" y="14" width="12" height="92" fill="#5b82b8" {stroke(3)}/>'
           f'<circle cx="58" cy="52" r="20" fill="#fdfbf6" {stroke(3)}/>'
           f'<ellipse cx="54" cy="56" rx="9" ry="7" fill="{FUR}" {stroke(2)}/><ellipse cx="58" cy="44" rx="3" ry="8" fill="{FUR}" {stroke(2)}/>'
           f'<path d="M34,84 H84 M40,92 H78" stroke="{G3}" stroke-width="4" stroke-linecap="round"/>')
save("bubak_book.svg", svg(106, 120, BOOKART))
save("icon_merch_book.svg", svg(106, 120, BOOKART))
# the advent calendar: a board with 24 little doors
door_cols = ["#e8505b", "#7fcfb8", "#f3c94f", "#7fa7d8", "#e98fae", "#9cc5a1"]
doors = "".join(f'<rect x="{14 + (i % 6) * 30}" y="{40 + (i // 6) * 30}" width="24" height="24" rx="4" fill="{door_cols[(i * 5) % 6]}" {stroke(2)}/>'
                f'<text x="{26 + (i % 6) * 30}" y="{57 + (i // 6) * 30}" font-family="sans-serif" font-weight="bold" font-size="11" text-anchor="middle" fill="#4f3d33">{i + 1}</text>'
                for i in range(24))
save("advent_calendar.svg", svg(200, 170,
    f'<rect x="4" y="10" width="192" height="156" rx="10" fill="#fdf3e0" {stroke(4)}/>'
    f'<path d="M4,34 H196" stroke="#e8505b" stroke-width="16"/><path d="M100,0 V18" stroke="#4f3d33" stroke-width="3"/>'
    f'<circle cx="100" cy="4" r="4" fill="{G3}" {stroke(2)}/>' + doors))
