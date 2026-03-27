#!/usr/bin/env python3
"""Generate App Store screenshots for BetBuddy."""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = "/Users/swarn/BetBuddy/screenshots"

# Sizes: iPhone 6.7" and iPad Pro 12.9"
SIZES = {
    "iphone": (1290, 2796),
    "ipad": (2048, 2732),
}

# Colors
BG = (6, 6, 10)
CARD_BG = (20, 20, 28)
ACCENT = (99, 102, 241)
ACCENT2 = (139, 92, 246)
GREEN = (34, 197, 94)
RED = (239, 68, 68)
WARNING = (245, 158, 11)
WHITE = (250, 250, 250)
GRAY = (255, 255, 255, 115)
MUTED = (255, 255, 255, 70)
BORDER = (255, 255, 255, 18)
CHIP_COLORS = [
    (52, 199, 89), (255, 59, 48), (0, 122, 255),
    (255, 159, 10), (175, 82, 222), (90, 200, 250),
]

def get_font(size, bold=False):
    paths = [
        "/System/Library/Fonts/SFNSText.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    if bold:
        paths = [
            "/System/Library/Fonts/SFNSTextBold.ttf",
            "/System/Library/Fonts/HelveticaBold.ttf",
            "/System/Library/Fonts/SFNS.ttf",
        ] + paths
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except:
            continue
    return ImageFont.load_default()

def rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

def gradient_rect(img, xy, colors, radius=0):
    x1, y1, x2, y2 = xy
    w, h = x2 - x1, y2 - y1
    for i in range(w):
        t = i / max(w - 1, 1)
        r = int(colors[0][0] + (colors[1][0] - colors[0][0]) * t)
        g = int(colors[0][1] + (colors[1][1] - colors[0][1]) * t)
        b = int(colors[0][2] + (colors[1][2] - colors[0][2]) * t)
        draw = ImageDraw.Draw(img)
        draw.line([(x1 + i, y1), (x1 + i, y2)], fill=(r, g, b))

def draw_chip(draw, x, y, text, color, scale=1):
    s = scale
    font = get_font(int(24 * s))
    tw = draw.textlength(text, font=font)
    pw, ph = int(tw + 40 * s), int(44 * s)
    rounded_rect(draw, (x, y, x + pw, y + ph), radius=int(22 * s),
                 fill=(*color, 30))
    # dot
    r = int(7 * s)
    draw.ellipse((x + int(14*s), y + ph//2 - r, x + int(14*s) + 2*r, y + ph//2 + r), fill=color)
    draw.text((x + int(28*s), y + int(8*s)), text, fill=WHITE, font=font)
    return pw

def make_screenshot(device, screen_num, title, subtitle, draw_content_fn):
    w, h = SIZES[device]
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)

    s = w / 1290  # scale factor

    # Title area at top
    title_font = get_font(int(64 * s), bold=True)
    sub_font = get_font(int(36 * s))

    # Title
    tw = draw.textlength(title, font=title_font)
    draw.text(((w - tw) / 2, int(160 * s)), title, fill=WHITE, font=title_font)

    # Subtitle
    sw = draw.textlength(subtitle, font=sub_font)
    draw.text(((w - sw) / 2, int(250 * s)), subtitle, fill=(*WHITE[:3], 120), font=sub_font)

    # Content area
    draw_content_fn(img, draw, w, h, s)

    fname = f"{device}_{screen_num}.png"
    img.save(os.path.join(OUT, fname))
    print(f"  Created {fname} ({w}x{h})")

# ===================== SCREEN 1: Home Feed =====================
def draw_home(img, draw, w, h, s):
    y = int(380 * s)
    mx = int(60 * s)
    cw = w - 2 * mx
    cr = int(28 * s)

    bets = [
        ("🏀", "Who wins the game tonight?", "Live", ["Lakers", "Celtics"], 250, GREEN),
        ("🌮", "Best taco spot downtown?", "Live", ["El Pastor", "Taqueria", "La Casita"], 180, GREEN),
        ("🌧️", "Will it rain tomorrow?", "Settled", ["Yes", "No"], 420, (129, 140, 248)),
    ]

    for emoji, title, status, outcomes, pool, status_color in bets:
        ch = int(280 * s)
        # Card bg
        rounded_rect(draw, (mx, y, mx + cw, y + ch), radius=cr, fill=CARD_BG,
                     outline=(*BORDER[:3],), width=1)

        # Emoji box
        ex, ey = mx + int(20*s), y + int(20*s)
        esize = int(60*s)
        rounded_rect(draw, (ex, ey, ex+esize, ey+esize), radius=int(12*s),
                     fill=(255, 255, 255, 15))
        efont = get_font(int(36*s))
        draw.text((ex + int(12*s), ey + int(8*s)), emoji, font=efont)

        # Title
        tfont = get_font(int(28*s), bold=True)
        draw.text((ex + esize + int(16*s), ey + int(4*s)), title, fill=WHITE, font=tfont)

        # Status pill
        sfont = get_font(int(20*s), bold=True)
        stw = draw.textlength(status, font=sfont)
        spx = mx + cw - int(20*s) - int(stw) - int(24*s)
        spy = ey + int(4*s)
        rounded_rect(draw, (spx, spy, spx + int(stw) + int(24*s), spy + int(32*s)),
                     radius=int(16*s), fill=(*status_color[:3], 40))
        draw.text((spx + int(12*s), spy + int(4*s)), status, fill=status_color, font=sfont)

        # Outcome chips
        cx = mx + int(20*s)
        cy = ey + esize + int(20*s)
        for i, outcome in enumerate(outcomes):
            pw = draw_chip(draw, cx, cy, outcome, CHIP_COLORS[i % len(CHIP_COLORS)], s)
            cx += pw + int(10*s)

        # Pool
        py = cy + int(60*s)
        pfont = get_font(int(26*s), bold=True)
        draw.text((mx + int(20*s), py), "💰", font=pfont)
        draw.text((mx + int(52*s), py), f"${pool}", fill=GREEN, font=pfont)
        lfont = get_font(int(22*s))
        draw.text((mx + int(52*s) + draw.textlength(f"${pool}", font=pfont) + int(8*s), py + int(4*s)),
                  "pool", fill=(*WHITE[:3], 100), font=lfont)

        # Stacked avatars
        for i in range(min(4, len(outcomes) + 1)):
            ax = mx + cw - int(40*s) - i * int(22*s)
            colors = [ACCENT, GREEN, RED, WARNING, ACCENT2]
            draw.ellipse((ax, py - int(2*s), ax + int(32*s), py + int(30*s)),
                        fill=colors[i % len(colors)], outline=CARD_BG, width=2)
            ifont = get_font(int(14*s), bold=True)
            draw.text((ax + int(10*s), py + int(4*s)), ["S", "M", "J", "A"][i],
                     fill=WHITE, font=ifont)

        y += ch + int(16*s)

def draw_bet_detail(img, draw, w, h, s):
    y = int(380 * s)
    mx = int(60 * s)
    cw = w - 2 * mx
    cr = int(28 * s)

    # Emoji + title
    efont = get_font(int(64*s))
    draw.text((w//2 - int(32*s), y), "🏀", font=efont)
    y += int(90*s)
    tfont = get_font(int(40*s), bold=True)
    title = "Who wins the game?"
    tw = draw.textlength(title, font=tfont)
    draw.text(((w-tw)/2, y), title, fill=WHITE, font=tfont)
    y += int(60*s)

    # Status pill
    sfont = get_font(int(22*s), bold=True)
    st = "Live"
    stw = draw.textlength(st, font=sfont)
    spx = (w - stw - int(28*s)) / 2
    rounded_rect(draw, (int(spx), y, int(spx + stw + 28*s), y + int(36*s)),
                 radius=int(18*s), fill=(*GREEN, 40))
    draw.text((int(spx + 14*s), y + int(5*s)), st, fill=GREEN, font=sfont)
    y += int(70*s)

    # CTA button
    gradient_rect(img, (mx, y, mx+cw, y+int(70*s)), [ACCENT, ACCENT2])
    draw = ImageDraw.Draw(img)
    rounded_rect(draw, (mx, y, mx+cw, y+int(70*s)), radius=int(18*s), fill=None)
    bfont = get_font(int(28*s), bold=True)
    bt = "Place a Bet"
    btw = draw.textlength(bt, font=bfont)
    draw.text(((w-btw)/2, y+int(18*s)), bt, fill=WHITE, font=bfont)
    y += int(100*s)

    # Stats row
    rounded_rect(draw, (mx, y, mx+cw, y+int(100*s)), radius=cr, fill=CARD_BG,
                 outline=(*BORDER[:3],), width=1)
    cols = [("POOL", "$450", ACCENT), ("DEADLINE", "2d left", (*WHITE[:3],)), ("WAGERS", "6", WARNING)]
    col_w = cw // 3
    for i, (label, val, color) in enumerate(cols):
        cx = mx + col_w * i + col_w // 2
        lfont = get_font(int(18*s))
        vfont = get_font(int(30*s), bold=True)
        lw = draw.textlength(label, font=lfont)
        vw = draw.textlength(val, font=vfont)
        draw.text((cx - lw/2, y + int(12*s)), label, fill=(*WHITE[:3], 80), font=lfont)
        draw.text((cx - vw/2, y + int(42*s)), val, fill=color, font=vfont)
    y += int(130*s)

    # Outcome rows
    lfont = get_font(int(20*s))
    draw.text((mx, y), "RESULTS", fill=(*WHITE[:3], 80), font=lfont)
    y += int(40*s)

    outcomes = [("Lakers", 280, 62, CHIP_COLORS[0]), ("Celtics", 170, 38, CHIP_COLORS[1])]
    for name, amt, pct, color in outcomes:
        rounded_rect(draw, (mx, y, mx+cw, y+int(110*s)), radius=cr, fill=CARD_BG,
                     outline=(*BORDER[:3],), width=1)
        # Dot + name
        draw.ellipse((mx+int(20*s), y+int(20*s), mx+int(38*s), y+int(38*s)), fill=color)
        nfont = get_font(int(28*s), bold=True)
        draw.text((mx+int(50*s), y+int(16*s)), name, fill=WHITE, font=nfont)
        # Amount
        afont = get_font(int(30*s), bold=True)
        at = f"${amt}"
        atw = draw.textlength(at, font=afont)
        draw.text((mx+cw-int(20*s)-atw, y+int(12*s)), at, fill=color, font=afont)
        pt = f"{pct}%"
        pfont = get_font(int(22*s))
        ptw = draw.textlength(pt, font=pfont)
        draw.text((mx+cw-int(20*s)-ptw, y+int(48*s)), pt, fill=(*WHITE[:3], 120), font=pfont)
        # Progress bar
        bar_y = y + int(78*s)
        bar_w = cw - int(40*s)
        rounded_rect(draw, (mx+int(20*s), bar_y, mx+int(20*s)+bar_w, bar_y+int(12*s)),
                     radius=int(6*s), fill=(255,255,255,15))
        fill_w = int(bar_w * pct / 100)
        if fill_w > 0:
            rounded_rect(draw, (mx+int(20*s), bar_y, mx+int(20*s)+fill_w, bar_y+int(12*s)),
                         radius=int(6*s), fill=color)
        y += int(126*s)

def draw_create_bet(img, draw, w, h, s):
    y = int(380 * s)
    mx = int(60 * s)
    cw = w - 2 * mx
    cr = int(18 * s)

    # Photo area
    rounded_rect(draw, (mx, y, mx+cw, y+int(180*s)), radius=int(24*s),
                 fill=(255,255,255,12), outline=(*BORDER[:3],), width=1)
    pfont = get_font(int(26*s))
    pt = "📷  Add a photo (optional)"
    ptw = draw.textlength(pt, font=pfont)
    draw.text(((w-ptw)/2, y+int(72*s)), pt, fill=(*WHITE[:3], 100), font=pfont)
    y += int(210*s)

    # Emoji grid
    lfont = get_font(int(20*s))
    draw.text((mx, y), "EMOJI", fill=(*WHITE[:3], 80), font=lfont)
    y += int(36*s)
    emojis = ["🎲", "🌮", "🌧️", "⏰", "📚", "☕", "🏀", "🎬"]
    efont = get_font(int(36*s))
    esize = int(60*s)
    gap = int(12*s)
    for i, e in enumerate(emojis):
        ex = mx + i * (esize + gap)
        fill = (*ACCENT, 50) if i == 6 else (255,255,255,15)
        rounded_rect(draw, (ex, y, ex+esize, y+esize), radius=int(12*s), fill=fill)
        if i == 6:
            rounded_rect(draw, (ex, y, ex+esize, y+esize), radius=int(12*s),
                         fill=None, outline=ACCENT, width=2)
        draw.text((ex+int(12*s), y+int(8*s)), e, font=efont)
    y += esize + int(30*s)

    # Title field
    draw.text((mx, y), "WHAT'S THE BET?", fill=(*WHITE[:3], 80), font=lfont)
    y += int(36*s)
    rounded_rect(draw, (mx, y, mx+cw, y+int(64*s)), radius=cr,
                 fill=(255,255,255,8), outline=(*BORDER[:3],), width=1)
    ifont = get_font(int(24*s))
    draw.text((mx+int(20*s), y+int(18*s)), "Who wins the game tonight?", fill=WHITE, font=ifont)
    y += int(90*s)

    # Outcomes
    draw.text((mx, y), "OUTCOMES", fill=(*WHITE[:3], 80), font=lfont)
    y += int(36*s)
    for i, outcome in enumerate(["Lakers", "Celtics"]):
        rounded_rect(draw, (mx, y, mx+cw, y+int(64*s)), radius=cr,
                     fill=(255,255,255,8), outline=(*BORDER[:3],), width=1)
        r = int(8*s)
        draw.ellipse((mx+int(20*s), y+int(22*s), mx+int(20*s)+2*r, y+int(22*s)+2*r),
                     fill=CHIP_COLORS[i])
        draw.text((mx+int(44*s), y+int(18*s)), outcome, fill=WHITE, font=ifont)
        y += int(80*s)

    # Create button
    y += int(20*s)
    gradient_rect(img, (mx, y, mx+cw, y+int(70*s)), [ACCENT, ACCENT2])
    draw = ImageDraw.Draw(img)
    bfont = get_font(int(28*s), bold=True)
    bt = "Create Bet"
    btw = draw.textlength(bt, font=bfont)
    draw.text(((w-btw)/2, y+int(18*s)), bt, fill=WHITE, font=bfont)

def draw_leaderboard(img, draw, w, h, s):
    y = int(380 * s)
    mx = int(60 * s)
    cw = w - 2 * mx
    cr = int(28 * s)

    users = [
        ("🥇", "swarn", "$1,450", GREEN, True),
        ("🥈", "jessica", "$1,280", GREEN, False),
        ("🥉", "mike_t", "$1,100", GREEN, False),
        ("4", "alex99", "$920", RED, False),
        ("5", "priya_k", "$780", RED, False),
    ]

    for medal, name, balance, color, highlight in users:
        ch = int(90*s)
        outline = ACCENT if highlight else (*BORDER[:3],)
        ow = 2 if highlight else 1
        rounded_rect(draw, (mx, y, mx+cw, y+ch), radius=cr, fill=CARD_BG,
                     outline=outline, width=ow)

        # Medal/rank
        mfont = get_font(int(32*s)) if medal.startswith("🥇") or medal.startswith("🥈") or medal.startswith("🥉") else get_font(int(24*s), bold=True)
        draw.text((mx+int(20*s), y+int(22*s)), medal,
                 fill=WHITE if not medal[0].isdigit() else (*WHITE[:3], 120), font=mfont)

        # Avatar circle
        ax = mx + int(70*s)
        colors_list = [ACCENT, GREEN, RED, WARNING, ACCENT2]
        ci = hash(name) % len(colors_list)
        draw.ellipse((ax, y+int(16*s), ax+int(56*s), y+int(72*s)), fill=colors_list[ci])
        nifont = get_font(int(22*s), bold=True)
        draw.text((ax+int(18*s), y+int(28*s)), name[0].upper(), fill=WHITE, font=nifont)

        # Name
        nfont = get_font(int(26*s), bold=True)
        draw.text((ax+int(70*s), y+int(28*s)), name, fill=WHITE, font=nfont)

        # Balance
        bfont = get_font(int(26*s), bold=True)
        bw = draw.textlength(balance, font=bfont)
        draw.text((mx+cw-int(20*s)-bw, y+int(28*s)), balance, fill=color, font=bfont)

        y += ch + int(12*s)

def draw_profile(img, draw, w, h, s):
    y = int(380 * s)
    mx = int(60 * s)
    cw = w - 2 * mx
    cr = int(28 * s)

    # Avatar
    asize = int(80*s)
    ax = (w - asize) // 2
    draw.ellipse((ax, y, ax+asize, y+asize), fill=ACCENT)
    afont = get_font(int(36*s), bold=True)
    draw.text((ax+int(24*s), y+int(18*s)), "S", fill=WHITE, font=afont)
    y += asize + int(16*s)

    # Name
    nfont = get_font(int(28*s), bold=True)
    n = "@swarn"
    nw = draw.textlength(n, font=nfont)
    draw.text(((w-nw)/2, y), n, fill=WHITE, font=nfont)
    y += int(36*s)
    sfont = get_font(int(24*s))
    sn = "Swarn Singh"
    sw = draw.textlength(sn, font=sfont)
    draw.text(((w-sw)/2, y), sn, fill=(*WHITE[:3], 120), font=sfont)
    y += int(60*s)

    # Balance card
    rounded_rect(draw, (mx, y, mx+cw, y+int(140*s)), radius=cr, fill=CARD_BG,
                 outline=(*BORDER[:3],), width=1)
    lfont = get_font(int(18*s))
    lt = "BALANCE"
    lw = draw.textlength(lt, font=lfont)
    draw.text(((w-lw)/2, y+int(20*s)), lt, fill=(*WHITE[:3], 80), font=lfont)
    bfont = get_font(int(42*s), bold=True)
    bt = "$1,450"
    bw = draw.textlength(bt, font=bfont)
    draw.text(((w-bw)/2, y+int(56*s)), bt, fill=GREEN, font=bfont)
    y += int(170*s)

    # Stats
    half = (cw - int(16*s)) // 2
    for i, (label, val, color) in enumerate([("TOTAL WON", "$620", GREEN), ("TOTAL LOST", "$170", RED)]):
        sx = mx + i * (half + int(16*s))
        rounded_rect(draw, (sx, y, sx+half, y+int(110*s)), radius=cr, fill=CARD_BG,
                     outline=(*BORDER[:3],), width=1)
        lw2 = draw.textlength(label, font=lfont)
        draw.text((sx + (half-lw2)/2, y+int(18*s)), label, fill=(*WHITE[:3], 80), font=lfont)
        vfont = get_font(int(30*s), bold=True)
        vw = draw.textlength(val, font=vfont)
        draw.text((sx + (half-vw)/2, y+int(52*s)), val, fill=color, font=vfont)

# Generate all screenshots
screens = [
    (1, "Your Bets, Your Way", "Track all bets in one place", draw_home),
    (2, "Bet on Anything", "Pick your side and wager", draw_bet_detail),
    (3, "Create in Seconds", "Set up a bet with friends", draw_create_bet),
    (4, "Climb the Ranks", "Group leaderboard", draw_leaderboard),
    (5, "Track Your Stats", "Your profile at a glance", draw_profile),
]

for device in SIZES:
    print(f"\n{device.upper()} screenshots:")
    for num, title, sub, fn in screens:
        make_screenshot(device, num, title, sub, fn)

print(f"\nAll screenshots saved to {OUT}/")
