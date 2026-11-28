// /.dotfiles/modules/desktop/ghostty/bloom.glsl
// Neon bloom for Ghostty (hooked up in ../ghostty.nix): bright text gets a
// soft glow in its own color, like neon tubes. Dark background pixels
// don't glow, so the see-through background stays as it was.
//
// Ghostty custom shaders use Shadertoy conventions: iChannel0 is the
// rendered terminal, iResolution its size in pixels.

// --- Knobs ---
// Text strokes cover only a small part of each glow disc, so STRENGTH
// needs to be well above 1 for the halo to show.
const float RADIUS = 3.0;       // glow spread, in pixels
const float STRENGTH = 0.85;    // glow brightness; 0.0 turns bloom off
const float THRESHOLD = 0.3;    // brightness where glow starts (0-1)
const float SATURATION = 1.4;   // >1 makes colored text glow more vividly
const float SCANLINES = 0.18;   // how dark the scanlines get; 0.0 is off
const float SCANLINE_PERIOD = 4.0; // pixels from one scanline to the next
const int SAMPLES = 32;         // more = smoother glow, more GPU work
// No glow on solid bright blocks (labels, selections): lower these if
// text on light backgrounds still looks washed out.
const float FILL_START = 0.25;  // share of nearby pixels that are bright
const float FILL_END = 0.5;     // ...where glow is fully gone

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    // Sample a disc around the pixel in a golden-angle spiral (even
    // coverage without a grid pattern), keeping only bright samples and
    // weighting nearer ones more.
    vec3 glow = vec3(0.0);
    float coverage = 0.0;
    float total = 0.0;
    for (int i = 0; i < SAMPLES; i++) {
        float fi = float(i);
        float r = sqrt((fi + 0.5) / float(SAMPLES)) * RADIUS;
        float a = fi * 2.39996323;
        vec2 offset = vec2(cos(a), sin(a)) * r;

        vec3 s = texture(iChannel0, uv + offset / iResolution.xy).rgb;
        float bright = smoothstep(THRESHOLD, 1.0, luma(s));
        float w = exp(-2.0 * (r * r) / (RADIUS * RADIUS));

        glow += s * bright * w;
        coverage += bright * w;
        total += w;
    }
    glow /= total;
    coverage /= total;

    // Only thin bright things (text strokes) glow. Where most of the disc
    // is bright, the pixel sits inside a solid bright block (a highlighted
    // label, a selection, a prompt segment), and glow there would wash out
    // the dark text drawn on it. Fades out between FILL_START and FILL_END.
    glow *= 1.0 - smoothstep(FILL_START, FILL_END, coverage);

    // Push the glow's color away from gray so cyan stays cyan.
    float g = luma(glow);
    glow = max(mix(vec3(g), glow, SATURATION), 0.0);

    vec3 rgb = color.rgb + glow * STRENGTH;

    // Scanlines: a soft dark band every SCANLINE_PERIOD pixels. A smooth
    // wave rather than hard 1-pixel lines, which were too fine to see and
    // can shimmer against the text.
    float wave = 0.5 + 0.5 * cos(6.2831853 * fragCoord.y / SCANLINE_PERIOD);
    rgb *= 1.0 - SCANLINES * wave;

    // Alpha unchanged: the glow adds light without making the
    // see-through background more solid.
    fragColor = vec4(min(rgb, vec3(1.0)), color.a);
}
