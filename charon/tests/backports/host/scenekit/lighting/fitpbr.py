import math, itertools
def lin(b):
    c = b / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def enc(l):
    l = max(0.0, min(1.0, l))
    c = l * 12.92 if l <= 0.0031308 else 1.055 * l ** (1 / 2.4) - 0.055
    return round(c * 255)
rows = []
for l in open("dense.txt"):
    if not l.startswith("pbr "): continue
    p = l.split()
    rows.append((float(p[1][6:]), float(p[2][4:]), float(p[3][4:]), float(p[4][2:]), float(p[5])))
def norm(v):
    n = math.sqrt(sum(x * x for x in v)); return [x / n for x in v]
def dot(a, b): return sum(x * y for x, y in zip(a, b))
I = 0.25
Vs = {"ortho": [0, 0, 1], "cam": norm([-0.125, -0.125, 5]), "cam2": norm([0.125, 0.125, 5]), "cam3": norm([-0.125, 0.125, 5]), "cam4": norm([0.125, -0.125, 5])}
def D_ggx(nh, a2): d = nh * nh * (a2 - 1) + 1; return a2 / (math.pi * d * d)
def G_schlick(nl, nv, k): return (nl / (nl * (1 - k) + k)) * (nv / (nv * (1 - k) + k))
def G_smith_corr(nl, nv, a2):
    lv = nl * math.sqrt(nv * nv * (1 - a2) + a2); ll = nv * math.sqrt(nl * nl * (1 - a2) + a2)
    return 0.5 / (lv + ll) * (4 * nl * nv)
def model(r, met, alb, a, V, alpha_map, gkind, fkind, diffkind, piscale):
    N = [0, 0, 1]; L = [0, -math.sin(a), math.cos(a)]
    H = norm([L[i] + V[i] for i in range(3)])
    nl = max(dot(N, L), 0); nv = max(dot(N, V), 1e-4); nh = max(dot(N, H), 0); vh = max(dot(V, H), 0)
    albl = lin(alb * 255)
    alpha = {"r2": r * r, "r": r, "r2min": max(r * r, 0.002)}[alpha_map]; a2 = alpha * alpha
    f0 = 0.04 * (1 - met) + albl * met
    F = f0 + (1 - f0) * (1 - vh) ** 5 if fkind == "schlick" else f0
    if gkind == "schlick_k2": G = G_schlick(nl, nv, alpha / 2)
    elif gkind == "schlick_direct": G = G_schlick(nl, nv, (r + 1) ** 2 / 8)
    else: G = G_smith_corr(nl, nv, a2)
    spec = D_ggx(nh, a2) * G * F / max(4 * nl * nv, 1e-4) * nl
    if piscale: spec *= math.pi
    kd = (1 - met) * ((1 - F) if diffkind == "1-F" else 1)
    diff = albl * kd * nl
    return (diff + spec) * I
best = []
for vname, V in Vs.items():
    for combo in itertools.product(["r2", "r"], ["schlick_k2", "schlick_direct", "smith_corr"], ["schlick", "f0"], ["1-F", "plain"], [True, False]):
        err = 0; n = 0; worst = 0
        for r, met, alb, a, v in rows:
            if v >= 254: continue
            p = enc(model(r, met, alb, a, V, *combo))
            e = abs(p - v); err += e * e; n += 1; worst = max(worst, e)
        best.append(((err / n) ** 0.5, worst, vname, combo, n))
best.sort()
for b in best[:8]: print("rms %.2f worst %d V=%s %s n=%d" % b)
