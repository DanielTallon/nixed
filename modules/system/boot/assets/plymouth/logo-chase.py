"""Writes the frames of a "chasing light" NixOS logo as SVGs.

The official logo SVG draws the snowflake as six <polygon> lambdas, in clockwise order (rotate 0, 60, … 300).
Each frame dims every lambda except a moving "head", which is at full brightness, with a short trail fading
behind it. The "NixOS" text stays as it is.

Usage: python3 logo-chase.py <logo.svg> <out-dir> <steps-per-lambda> <trail> <dim>
  steps-per-lambda  frames for the light to move from one lambda to the next (more = smoother)
  trail             how many lambdas behind the head still glow, fading out
  dim               opacity of an unlit lambda (0 to 1)
"""
import re
import sys
from pathlib import Path

svg_path, out_dir, steps, trail, dim = sys.argv[1], Path(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
svg = Path(svg_path).read_text()

lambdas = list(re.finditer(r"<polygon\b", svg))
if len(lambdas) != 6:
    sys.exit(f"expected 6 lambda <polygon>s in {svg_path}, found {len(lambdas)}")

out_dir.mkdir(parents=True, exist_ok=True)
frames = 6 * steps
for f in range(frames):
    head = f / steps  # 0 to 6: which lambda the light is on
    parts, last = [], 0
    for k, m in enumerate(lambdas):
        behind = (head - k) % 6  # how far the head has moved past lambda k
        glow = max(0.0, 1 - behind / trail) if trail > 0 else float(behind < 1)
        opacity = dim + (1 - dim) * glow
        parts += [svg[last:m.end()], f' opacity="{opacity:.3f}"']
        last = m.end()
    parts.append(svg[last:])
    # 1-indexed like ffmpeg's output, which the Plymouth script expects
    (out_dir / f"frame-{f + 1}.svg").write_text("".join(parts))
