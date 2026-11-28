"""Adds glitch bursts to the chasing-light logo frames (see logo-chase.py).

The loop is the chase repeated <repeat> times. Most frames stay clean; a
short burst near the end of the loop, and a single-frame flicker earlier,
look like a corrupted video signal: horizontal slices tear sideways, the red
and cyan channels split apart, scanlines show, and a few blocks flash neon
cyan or pink. Same seed every build, so the frames don't change between
rebuilds.

Every frame is padded on both sides by the same amount (so torn slices have
room to move) and flattened onto black, which is what Plymouth draws behind
it anyway. All frames stay the same size, since the script centers the
sprite using the first frame's size.

Usage: python3 logo-glitch.py <in-dir> <out-dir> <repeat>
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

in_dir, out_dir, repeat = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])

# --- Knobs ---
TEAR = 0.12          # max slice shift, as a share of the logo width
SPLIT = 0.025        # max red/cyan channel split, as a share of the logo width
SCANLINES = 0.45     # how dark the scanlines get at full strength
NEON = [(0, 170, 255), (255, 42, 109)]  # #00aaff, #ff2a6d
# Burst strengths, frame by frame: hits hard, stutters, fades out.
BURST = [1.0, 0.45, 0.85, 0.3, 0.12]
BURST_AT = 0.62      # where in the loop the burst starts (0 to 1)
FLICKER_AT = 0.25    # a single weaker glitch frame here
FLICKER = 0.5

src = sorted(in_dir.glob("frame-*.png"), key=lambda p: int(p.stem.split("-")[1]))
if not src:
    sys.exit(f"no frame-*.png in {in_dir}")
total = len(src) * repeat

strength = {int(total * FLICKER_AT): FLICKER}
start = int(total * BURST_AT)
for i, k in enumerate(BURST):
    strength[(start + i) % total] = k


def glitch(img, k, rng, logo_x, logo_w):
    w, h = img.size

    # Channel split: red one way, cyan (green + blue) the other.
    s = max(1, round(logo_w * SPLIT * k))
    r, g, b = img.split()
    img = Image.merge("RGB", (ImageChops.offset(r, s, 0),
                              ImageChops.offset(g, -s, 0),
                              ImageChops.offset(b, -s, 0)))

    # Tearing: uneven horizontal bands, some shifted sideways.
    y = 0
    while y < h:
        bh = rng.randint(4, 28)
        if rng.random() < 0.45 * k:
            dx = round((rng.random() * 2 - 1) * logo_w * TEAR * k)
            band = img.crop((0, y, w, min(y + bh, h)))
            img.paste(ImageChops.offset(band, dx, 0), (0, y))
        y += bh

    # Corrupted blocks in neon, over the logo's area.
    draw = ImageDraw.Draw(img)
    for _ in range(rng.randint(0, round(8 * k))):
        bw, bhh = rng.randint(20, 70), rng.randint(6, 16)
        x0 = rng.randint(logo_x, max(logo_x, logo_x + logo_w - bw))
        y0 = rng.randint(0, max(0, h - bhh))
        draw.rectangle((x0, y0, x0 + bw, y0 + bhh), fill=rng.choice(NEON))

    # Scanlines: 2 dark rows out of every 4.
    dark = img.point(lambda v: int(v * (1 - SCANLINES * k)))
    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    for row in range(0, h, 4):
        mdraw.rectangle((0, row, w, row + 1), fill=255)
    return Image.composite(dark, img, mask)


out_dir.mkdir(parents=True, exist_ok=True)
for i in range(total):
    logo = Image.open(src[i % len(src)]).convert("RGBA")
    lw, lh = logo.size
    pad = round(lw * (TEAR + SPLIT)) + 2
    frame = Image.new("RGB", (lw + 2 * pad, lh), (0, 0, 0))
    frame.paste(logo, (pad, 0), logo)
    if i in strength:
        frame = glitch(frame, strength[i], random.Random(i), pad, lw)
    # 1-indexed, like the chase frames
    frame.save(out_dir / f"frame-{i + 1}.png")
