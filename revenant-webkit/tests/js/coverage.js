var fail=0;
function ck(n,g,w){ if(String(g)!==String(w)){print("FAIL "+n+": "+g+" != "+w);fail++;} }
function hot(f,n){var r;for(var i=0;i<n;i++)r=f(i);return r;}

var m=new Map();
function mput(i){ m.set("k"+(i&15), i); return m.size; }
hot(mput,60000); ck("Map.set", m.size, 16);
function mget(i){ return m.get("k"+(i&15)); }
hot(mget,60000); ck("Map.get", typeof mget(0), "number");
function mhas(i){ return m.has("k"+(i&15)); }
hot(mhas,60000); ck("Map.has", mhas(0), true);
function miter(i){ var n=0; m.forEach(function(v,k){n++;}); return n; }
hot(miter,3000); ck("Map.forEach", miter(0), 16);
function mkeys(i){ var n=0; var it=m.keys(); var e; while(!(e=it.next()).done) n++; return n; }
hot(mkeys,3000); ck("Map iterator", mkeys(0), 16);
function mdel(i){ var t=new Map(); t.set(1,1); t.delete(1); return t.size; }
hot(mdel,20000); ck("Map.delete", mdel(0), 0);

var st=new Set();
function sput(i){ st.add(i&31); return st.size; }
hot(sput,60000); ck("Set.add", st.size, 32);
function shas(i){ return st.has(i&31); }
hot(shas,60000); ck("Set.has", shas(0), true);
function siter(i){ var n=0; st.forEach(function(){n++;}); return n; }
hot(siter,3000); ck("Set.forEach", siter(0), 32);
function sspread(i){ return Array.from(st).length; }
hot(sspread,3000); ck("Set spread", sspread(0), 32);

var wm=new WeakMap(); var keyobj={};
function wput(i){ wm.set(keyobj, i); return wm.get(keyobj); }
hot(wput,60000); ck("WeakMap", typeof wput(7), "number");

function shiftq(i){ var a=[1,2,3,4,5]; a.shift(); a.shift(); return a.join(","); }
hot(shiftq,60000); ck("Array.shift", shiftq(0), "3,4,5");
function unshiftq(i){ var a=[3,4]; a.unshift(1,2); return a.join(","); }
hot(unshiftq,60000); ck("Array.unshift", unshiftq(0), "1,2,3,4");
function popq(i){ var a=[1,2,3]; a.pop(); return a.join(","); }
hot(popq,60000); ck("Array.pop", popq(0), "1,2");
function spliceq(i){ var a=[1,2,3,4,5]; a.splice(1,2); return a.join(","); }
hot(spliceq,60000); ck("Array.splice", spliceq(0), "1,4,5");
function concatq(i){ return [1,2].concat([3,4]).join(","); }
hot(concatq,60000); ck("Array.concat", concatq(0), "1,2,3,4");
function mapq(i){ return [1,2,3].map(function(x){return x*2;}).join(","); }
hot(mapq,30000); ck("Array.map", mapq(0), "2,4,6");
function filterq(i){ return [1,2,3,4].filter(function(x){return x%2===0;}).join(","); }
hot(filterq,30000); ck("Array.filter", filterq(0), "2,4");
function reduceq(i){ return [1,2,3,4].reduce(function(a,b){return a+b;},0); }
hot(reduceq,30000); ck("Array.reduce", reduceq(0), 10);

var shapes=[];
for (var k=0;k<24;k++){ var o={}; for(var j=0;j<=k;j++) o["p"+j]=j; o.mark=k; shapes.push(o); }
function megaget(i){ return shapes[i%24].mark; }
var mg=0; for(var i=0;i<300000;i++) mg+=megaget(i);
ck("megamorphic get", mg, (function(){var q=0;for(var i=0;i<300000;i++)q+=(i%24);return q;})());
function megaput(i){ var o=shapes[i%24]; o.mark=i&15; return o.mark; }
var mp=0; for(var i=0;i<300000;i++) mp+=megaput(i);
ck("megamorphic put", mp, (function(){var q=0;for(var i=0;i<300000;i++)q+=(i&15);return q;})());
function megain(i){ return ("mark" in shapes[i%24]) ? 1 : 0; }
var mi=0; for(var i=0;i<300000;i++) mi+=megain(i);
ck("megamorphic in", mi, 300000);

function jsonq(i){ return JSON.parse(JSON.stringify({a:i,b:[1,2],c:"x"})).b.length; }
hot(jsonq,20000); ck("JSON", jsonq(0), 2);
function req(i){ return /a(b+)c/.exec("xabbbc")[1]; }
hot(req,30000); ck("RegExp", req(0), "bbb");
function tmpl(i){ return `v${i%3}-${i%5}`; }
hot(tmpl,60000); ck("template", tmpl(7), "v1-2");
function spread(i){ var a=[1,2,3]; return Math.max.apply(null,a)+Math.min.apply(null,a); }
hot(spread,30000); ck("apply", spread(0), 4);
function destr(i){ var {x,y}={x:i,y:i+1}; var [p,q]=[i,i+2]; return x+y+p+q; }
hot(destr,60000); ck("destructuring", destr(1), 1+2+1+3);
function cls(i){ return new (class { constructor(){ this.v=5; } get double(){ return this.v*2; } })().double; }
hot(cls,20000); ck("class", cls(0), 10);
function genf(i){ function* g(){ yield 1; yield 2; } var s=0; for (var v of g()) s+=v; return s; }
hot(genf,20000); ck("generator", genf(0), 3);

print(fail===0 ? "COVERAGE ALL OK" : fail+" COVERAGE FAILURES");
function forinwrite(o){ var n=0; for (var k in o) { o[k] = o[k]; n++; } return n; }
var fio={a:1,b:2,c:3,d:4}; var fir=0; for (var i=0;i<200000;i++) fir=forinwrite(fio);
ck("for-in write", fir, 4);
function forinread(o){ var s=0; for (var k in o) s+=o[k]; return s; }
var frr=0; for (var i=0;i<200000;i++) frr=forinread(fio);
ck("for-in read", frr, 10);
var SET=new Set([1,2,3,4,5]);
function setof(s){ var n=0; for (var v of s) n+=v; return n; }
var so=0; for (var i=0;i<50000;i++) so=setof(SET);
ck("Set for-of", so, 15);
var MAP=new Map([[1,'a'],[2,'b'],[3,'c']]);
function mapent(m){ var n=0; for (var e of m.entries()) n++; return n; }
var me=0; for (var i=0;i<50000;i++) me=mapent(MAP);
ck("Map.entries", me, 3);
function mapval(m){ var n=""; for (var v of m.values()) n+=v; return n; }
var mv=""; for (var i=0;i<50000;i++) mv=mapval(MAP);
ck("Map.values", mv, "abc");
function mapkey(m){ var n=0; for (var k of m.keys()) n+=k; return n; }
var mk=0; for (var i=0;i<50000;i++) mk=mapkey(MAP);
ck("Map.keys", mk, 6);
function mapfrom(m){ return Array.from(m).length; }
var mf=0; for (var i=0;i<50000;i++) mf=mapfrom(MAP);
ck("Array.from(map)", mf, 3);
function setfrom(s){ return Array.from(s).length; }
var sf=0; for (var i=0;i<50000;i++) sf=setfrom(SET);
ck("Array.from(set)", sf, 5);
print(fail===0 ? "COVERAGE2 ALL OK" : fail+" COVERAGE2 FAILURES");
