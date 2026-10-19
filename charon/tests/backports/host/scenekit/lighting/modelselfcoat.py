# Holds selfcoat.txt (selfcoat.swift) to the published split-sum model: the energy that a physically based surface's
# specular coat takes from its diffuse term is F = f0 * A + B (Karis, "Real Shading in Unreal Engine 4"; "Physically Based
# Shading on Mobile", EnvBRDFApprox; Filament, "Energy conservation"), so the term is D * selfIllumination * (1 - F).
# f0 = mix(0.04, albedo, metalness); the smooth (roughness 0) and the rough end are what it must reproduce. Prints the
# error in levels of the pixel for the approximation, and for A and B integrated (GGX, Smith, k = alpha / 2), by roughness
# and by angle. The model does not converge (facts/SceneKit/SCNView.md, "Lighting"): fitselfcoat.py's form is what the port draws.
import math, sys
import numpy as np
def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def enc(l):
    l = min(max(l, 0), 1); return 255 * (l * 12.92 if l <= 0.0031308 else 1.055 * l ** (1 / 2.4) - 0.055)
rows = []
for line in open(sys.argv[1] if len(sys.argv) > 1 else "selfcoat.txt"):
    if line.startswith("#"): continue
    p = line.split()
    rows.append((lin(float(p[0])), float(p[1]), float(p[2]), float(p[3]), float(p[4]), int(p[5])))
def approx(f0, rough, nov):
    c0 = (-1, -0.0275, -0.572, 0.022); c1 = (1, 0.0425, 1.04, -0.04)
    r = [rough * a + b for a, b in zip(c0, c1)]
    a004 = min(r[0] * r[0], 2 ** (-9.28 * nov)) * r[0] + r[1]
    return f0 * (-1.04 * a004 + r[2]) + (1.04 * a004 + r[3])
def integrated(f0, rough, nov, n=20000):
    a = max(rough, 0.02) ** 2; nov = max(nov, 1e-3)
    v = np.array([math.sqrt(1 - nov * nov), 0, nov])
    i = np.arange(n); u2 = (i * 0.6180339887) % 1; phi = 2 * math.pi * (i + 0.5) / n
    ct = np.sqrt((1 - u2) / (1 + (a * a - 1) * u2)); st = np.sqrt(1 - ct * ct)
    h = np.stack([st * np.cos(phi), st * np.sin(phi), ct], 1)
    voh = h @ v; nol = 2 * voh * h[:, 2] - nov; k = a / 2
    g = lambda x: x / (x * (1 - k) + k)
    vis = g(nov) * g(np.maximum(nol, 0)) * voh / np.maximum(h[:, 2] * nov, 1e-9)
    fc = (1 - voh) ** 5; ok = nol > 0
    return f0 * np.sum(np.where(ok, (1 - fc) * vis, 0)) / n + np.sum(np.where(ok, fc * vis, 0)) / n
def hold(name, model):
    errs = []
    for d0, rough, theta, metal, si, px in rows:
        d = d0 * (1 - metal); f0 = 0.04 * (1 - metal) + d0 * metal
        errs.append((enc(d * si * (1 - model(f0, rough, math.cos(math.radians(theta))))) - px, rough, theta))
    e = sorted(abs(x[0]) for x in errs)
    print("%-28s worst %4.1f, 95th %4.1f, rms %.2f, within one level %d of %d" % (
        name, e[-1], e[int(0.95 * (len(e) - 1))], math.sqrt(sum(x[0] ** 2 for x in errs) / len(errs)), sum(x <= 1 for x in e), len(e)))
    for label, i in (("roughness", 1), ("angle", 2)):
        by = {}
        for x in errs: by[x[i]] = max(by.get(x[i], 0), abs(x[0]))
        print("    worst by %-9s %s" % (label, "  ".join("%g: %.1f" % kv for kv in sorted(by.items()))))
hold("EnvBRDFApprox", approx)
hold("A and B integrated", integrated)
