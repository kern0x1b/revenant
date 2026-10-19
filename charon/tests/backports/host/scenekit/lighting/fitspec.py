import math, re
def lin(b):
    c = b / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
rows = [l.split() for l in open("dense.txt") if l.startswith("spec ")]
data = {}
for r in rows:
    model = r[1].replace("SCNLightingModel", ""); sh = float(r[2][5:]); a = float(r[3][2:]); v = float(r[4])
    data.setdefault((model, sh), []).append((a, v))
S = lin(0.5 * 255)  # specular .5 sRGB -> linear
for (model, sh), pts in sorted(data.items()):
    # try pow(x, k) with x = cos(a/2) (blinn) or cos(a) (phong) and a free k; also check an N.L factor
    best = None
    for k in [x * 0.5 for x in range(1, 2000)]:
        for nl in (0, 1):
            err = 0; n = 0
            for a, v in pts:
                if v >= 254 or v <= 1: continue
                x = math.cos(a / 2) if model == "Blinn" else math.cos(a)
                pred = S * x ** k * (math.cos(a) if nl else 1)
                err += (lin(v) - pred) ** 2; n += 1
            if n and (best is None or err < best[0]): best = (err, k, nl, n)
    print(model, "shininess", sh, "-> exponent", best[1], "NdotL" if best[2] else "", "rms", (best[0] / best[3]) ** 0.5, "n", best[3])
print("--- free scale")
for (model, sh), pts in sorted(data.items()):
    best = None
    for k in [x * 0.5 for x in range(1, 800)]:
        for nl in (0, 1):
            num = den = 0
            use = [(a, v) for a, v in pts if 1 < v < 254]
            for a, v in use:
                x = math.cos(a / 2) if model == "Blinn" else math.cos(a)
                f = S * x ** k * (math.cos(a) if nl else 1)
                num += lin(v) * f; den += f * f
            c = num / den
            err = sum((lin(v) - c * S * (math.cos(a / 2) if model == "Blinn" else math.cos(a)) ** k * (math.cos(a) if nl else 1)) ** 2 for a, v in use)
            if best is None or err < best[0]: best = (err, k, nl, c, len(use))
    print(model, sh, "k", best[1], "nl", best[2], "scale %.4f" % best[3], "rms %.5f" % (best[0] / best[4]) ** 0.5)
    for a, v in pts[:8]:
        print("    a=%.2f measured %.4f" % (a, lin(v)))
print("--- the renderer's model: exponent 128 * shininess, times N.L, the view vector from the pixel to the camera")
# the sampled pixel sits 0.125 off centre in x and y, the camera 5 away along z; its view vector leans toward the
# light (the other sign costs Blinn 8 to 21 levels and Phong 16 to 42)
V = [0.125, -0.125, 5.0]
n = math.sqrt(sum(x * x for x in V)); V = [x / n for x in V]
def enc(l):
    l = max(0.0, min(1.0, l))
    return round((l * 12.92 if l <= 0.0031308 else 1.055 * l ** (1 / 2.4) - 0.055) * 255)
for (model, sh), pts in sorted(data.items()):
    worst = 0; err = 0; count = 0
    for a, v in pts:
        L = [0.0, math.sin(a), math.cos(a)]
        NdotL = L[2]
        if model == "Blinn":
            H = [L[i] + V[i] for i in range(3)]; h = math.sqrt(sum(x * x for x in H))
            x = H[2] / h
        else:
            R = [-L[0], -L[1], L[2]]  # reflect(-L, N) with N = z
            x = max(0.0, sum(R[i] * V[i] for i in range(3)))
        pred = enc(S * x ** (128 * sh) * NdotL)
        e = abs(pred - v); worst = max(worst, e); err += e * e; count += 1
    print(model, "shininess", sh, "rms %.2f levels, worst %d, over %d angles" % ((err / count) ** 0.5, worst, count))
