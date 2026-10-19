# Holds selfillumination.txt to diffuse * (ambient + sum of N.L + selfIllumination), linear light, written sRGB-encoded;
# the sum is 1, and selfIllumination left out, when no light but ambient ones is there. Constant: the diffuse colour.
import math
def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def enc(l):
    l = min(max(l, 0), 1); return l * 12.92 if l <= 0.0031308 else 1.055 * l ** (1 / 2.4) - 0.055
sets = {"none": (0, None), "dir0": (0, [1.0]), "dir1": (0, [math.cos(1)]), "away": (0, [0.0]), "amb": (1, None),
        "amb+dir1": (1, [math.cos(1)]), "dir1x0.5": (0, [0.5 * math.cos(1)])}
def model(name, d, s, al, dl, emission=0.0):
    if name == "Constant": return d + emission
    return d * al + d * (1.0 if dl is None else sum(dl) + s) + emission
worst = {}; count = 0; base = {}
for line in open("selfillumination.txt"):
    p = line.split()
    if p[1] in ("specular", "emission", "intensity0.5", "unlockedambient"):
        name, term, s, px = p[0], p[1], lin(float(p[2])), int(p[3]); d = lin(0.5)
        if term == "specular":
            if name in ("Blinn", "Phong"):
                # the specular lobe is fitspec.py's: selfIllumination must add d * s to the pixel without it
                if s == 0: base[name] = lin(px / 255); continue
                c = base[name] + d * s
            else:
                c = model(name, d, s, 0, [math.cos(0.2)])
            e = abs(px - round(enc(c) * 255)); count += 1; worst[name] = max(worst.get(name, 0), e)
            if e > 1: print("off by", e, line.strip())
            continue
        if term == "emission": c = model(name, d, s, 0, [math.cos(1)], lin(0.25))
        if term == "intensity0.5": c = model(name, d, 0.5 * s, 0, [math.cos(1)])
        if term == "unlockedambient": c = d if name == "Constant" else lin(0.25) + d * (math.cos(1) + s)
    else:
        name, d, s, lights, px = p[0], lin(float(p[1])), lin(float(p[2])), p[3], int(p[4])
        c = model(name, d, s, *sets[lights])
    e = abs(px - round(enc(c) * 255)); count += 1
    worst[name] = max(worst.get(name, 0), e)
    if e > 1: print("off by", e, line.strip())
print(count, "pixels; worst per model", worst)
