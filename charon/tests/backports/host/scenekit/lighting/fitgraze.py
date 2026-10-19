import math
exec(open("fitpbr.py").read().split("best = []")[0].replace('rows = []', 'rows0 = []').replace('rows.append', 'rows0.append'))
rows = []
for l in open("grazing.txt"):
    p = l.split(); rows.append(tuple(float(x.split("=")[1]) for x in p[1:6]) + (float(p[6]),))
def rotx(v, t):
    return [v[0], v[1] * math.cos(t) - v[2] * math.sin(t), v[1] * math.sin(t) + v[2] * math.cos(t)]
def pix(t, sy):
    # centre pixel of an 8x8 ortho frame, scale 1: world y of the ray at pixel 4 is -0.125 (row 4 of 8 from the top)
    y = sy * 0.125; x = 0.125
    # ray along -z from (x, y, 5) hits the plane rotated by t about x: plane normal n = rotx((0,0,1), t)
    n = rotx([0, 0, 1], t)
    d = (n[1] * y + n[2] * 5) / n[2]
    P = [x, y, 5 - d]
    return P, n
for fk in ["schlick", "f0"]:
  for sy in (1, -1):
    for sx in (1, -1):
        err = 0; worst = 0; n = 0; bad = []
        for t, r, met, alb, la, v in rows:
            if v >= 254: continue
            P, N = pix(t, sy); P[0] *= sx
            V = norm([-P[0], -P[1], 5 - P[2]])
            L = rotx([0, 0, 1], t + la)
            H = norm([L[i] + V[i] for i in range(3)])
            nl = max(dot(N, L), 0); nv = max(dot(N, V), 1e-4); nh = max(dot(N, H), 0); vh = max(dot(V, H), 0)
            albl = lin(alb * 255); alpha = r * r; a2 = alpha * alpha
            f0 = 0.04 * (1 - met) + albl * met
            F = f0 + (1 - f0) * (1 - vh) ** 5 if fk == "schlick" else f0
            G = G_smith_corr(nl, nv, a2)
            spec = D_ggx(nh, a2) * G * F / max(4 * nl * nv, 1e-4) * nl * math.pi if nl > 0 else 0
            p = enc((albl * (1 - met) * nl + spec) * 0.25)
            e = abs(p - v); err += e * e; n += 1; worst = max(worst, e)
            if e > 2: bad.append((t, r, met, alb, la, v, p))
        print(fk, "sy", sy, "sx", sx, "rms %.2f worst %d n %d" % ((err / n) ** 0.5, worst, n), bad[:4])
