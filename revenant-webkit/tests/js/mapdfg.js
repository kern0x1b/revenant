// Map and Set through the DFG. These intrinsics needed a 32-bit implementation
// written by hand, so wrong answers here are the expected shape of a
// regression, not crashes.
var fail = 0;
function ck(n, g, w) { if (String(g) !== String(w)) { print("FAIL " + n + ": " + g + " != " + w); fail++; } }

var m = new Map(); for (var i = 0; i < 32; i++) m.set(i, i * 2);
function mg(map, k) { return map.get(k); }
function mh(map, k) { return map.has(k); }
function ms(map, k, v) { map.set(k, v); return map.size; }

var s = 0; for (var i = 0; i < 300000; i++) s += mg(m, i & 31);
ck("Map.get hot", s, 300000 / 32 * 2 * (31 * 32 / 2));

var h = 0; for (var i = 0; i < 300000; i++) h += mh(m, i & 31) ? 1 : 0;
ck("Map.has hot", h, 300000);

var miss = 0; for (var i = 0; i < 100000; i++) miss += mh(m, 1000 + (i & 31)) ? 1 : 0;
ck("Map.has miss", miss, 0);
ck("Map.get miss", mg(m, 99999), undefined);

var z = 0; for (var i = 0; i < 300000; i++) z = ms(m, i & 31, i);
ck("Map.set existing keeps size", z, 32);
ck("Map.set overwrote", mg(m, 5), 299973);

var st = new Set(); for (var i = 0; i < 32; i++) st.add(i);
function sh(set, k) { return set.has(k); }
var q = 0; for (var i = 0; i < 300000; i++) q += sh(st, i & 31) ? 1 : 0;
ck("Set.has hot", q, 300000);
ck("Set.has miss", sh(st, 77), false);

function it(map) { var n = 0; for (var e of map) n++; return n; }
var t = 0; for (var i = 0; i < 20000; i++) t = it(m);
ck("Map iteration", t, 32);

var mixed = new Map();
mixed.set("k", 1); mixed.set(2, "v"); mixed.set(null, 3); mixed.set(undefined, 4); mixed.set(NaN, 5);
function mixedGet(k) { return mixed.get(k); }
for (var i = 0; i < 60000; i++) mixedGet("k");
ck("Map string key", mixedGet("k"), 1);
ck("Map number key", mixedGet(2), "v");
ck("Map null key", mixedGet(null), 3);
ck("Map undefined key", mixedGet(undefined), 4);
ck("Map NaN key", mixedGet(NaN), 5);

print(fail === 0 ? "MAPDFG ALL OK" : fail + " MAPDFG FAILURES");
