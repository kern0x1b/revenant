# Holds selfcoat.txt (selfcoat.swift) to what the port draws for selfIllumination in the physically based model, no light:
#   D * selfIllumination * ((1 - alpha) * max(1 - kf * g^5, 0) + alpha * (p0 + p1 * g^2 + q * D))
# with D = albedo * (1 - metalness), g = 1 - N.V and alpha = roughness^2: the smooth surface loses a share of the light
# to its specular coat by Fresnel, the rough one draws a diffuse of its own plus an interreflection term in D. The
# form was found from the pixels (T = pixel / (D * selfIllumination) does not depend on the albedo at roughness 0, and
# is linear in it above; linear in alpha at every angle); the four constants are searched here, and the last line is
# what SceneKit/CharonSCNRenderer.m holds. The error is in levels of the pixel. This is a fit: the published split-sum model
# (1 - F) does not reproduce the pixels, modelselfcoat.py shows by how much and where.
import math, sys
def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def enc(l):
    l = min(max(l, 0), 1); return 255 * (l * 12.92 if l <= 0.0031308 else 1.055 * l ** (1 / 2.4) - 0.055)
rows = []
for line in open(sys.argv[1] if len(sys.argv) > 1 else "selfcoat.txt"):
    if line.startswith("#"): continue
    p = line.split()
    rows.append((lin(float(p[0])), float(p[1]) ** 2, math.cos(math.radians(float(p[2]))), float(p[3]), float(p[4]), int(p[5])))
def predict(k, row):
    a, alpha, nv, m, si, _ = row
    d = a * (1 - m); g = 1 - nv
    return enc(d * si * ((1 - alpha) * max(1 - k[0] * g ** 5, 0) + alpha * (k[1] + k[2] * g * g + k[3] * d)))
def cost(k): return sum((predict(k, r) - r[5]) ** 2 for r in rows)
k = [1.1, 0.7, 0.1, 0.35]; step = [0.1, 0.05, 0.05, 0.05]; best = cost(k)
for _ in range(200):
    for i in range(4):
        for d in (-step[i], step[i]):
            t = list(k); t[i] += d
            if cost(t) < best: k, best = t, cost(t)
    step = [s * 0.9 for s in step]
errs = sorted(abs(round(predict(k, r)) - r[5]) for r in rows)
print("%d pixels; constants kf %.3f p0 %.3f p1 %.3f q %.3f; error in levels: worst %d, 95th %d, rms %.2f" % (
    len(rows), k[0], k[1], k[2], k[3], errs[-1], errs[int(0.95 * (len(errs) - 1))], math.sqrt(best / len(rows))))
