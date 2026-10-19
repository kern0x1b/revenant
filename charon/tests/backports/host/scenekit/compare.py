#!/usr/bin/env python3
"""compare.py A.png B.png : coverage IoU of alpha >= 0.5, the mean and 95th percentile of the largest |dRGB| of each
pixel covered in both, and B minus A per channel, averaged over those pixels (the bias)."""
import sys, zlib, struct

def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, w = 8, b"", None
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8]); body = data[pos + 8:pos + 8 + n]; pos += 12 + n
        if kind == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and ctype in (2, 6), (path, depth, ctype)
            ch = 4 if ctype == 6 else 3
        elif kind == b"IDAT":
            idat += body
    raw = zlib.decompress(idat); stride = w * ch; out = bytearray(); prev = bytearray(stride); i = 0
    for _ in range(h):
        f = raw[i]; line = bytearray(raw[i + 1:i + 1 + stride]); i += 1 + stride
        for x in range(stride):
            a = line[x - ch] if x >= ch else 0; b = prev[x]; c = prev[x - ch] if x >= ch else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += line; prev = line
    px = [tuple(out[j:j + ch]) + ((255,) if ch == 3 else ()) for j in range(0, len(out), ch)]
    return w, h, px

def compare(a_path, b_path):
    # PNG keeps straight (not premultiplied) alpha, whoever wrote it
    wa, ha, A = read_png(a_path); wb, hb, B = read_png(b_path)
    assert (wa, ha) == (wb, hb), (wa, ha, wb, hb)
    inter = union = 0; diffs = []; signed = [0, 0, 0]
    for pa, pb in zip(A, B):
        ia, ib = pa[3] >= 128, pb[3] >= 128
        union += ia or ib; inter += ia and ib
        if ia and ib:
            diffs.append(max(abs(pa[k] - pb[k]) for k in range(3)))
            for k in range(3): signed[k] += pb[k] - pa[k]
    diffs.sort()
    iou = inter / union if union else 1.0
    mean = sum(diffs) / len(diffs) if diffs else 0.0
    p95 = diffs[int(0.95 * (len(diffs) - 1))] if diffs else 0
    bias = tuple(v / len(diffs) for v in signed) if diffs else (0.0, 0.0, 0.0)
    return iou, mean, p95, len(diffs), bias

if __name__ == "__main__":
    iou, mean, p95, n, bias = compare(sys.argv[1], sys.argv[2])
    print("iou=%.4f mean=%.2f p95=%d n=%d bias=%+.2f/%+.2f/%+.2f" % ((iou, mean, p95, n) + bias))
