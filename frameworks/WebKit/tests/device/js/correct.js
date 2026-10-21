var fail = 0;
function ck(name, got, want) { if (String(got) !== String(want)) { print("FAIL " + name + ": got " + got + " want " + want); fail++; } }
function hot(f, n) { var r; for (var i = 0; i < n; i++) r = f(i); return r; }

function arith(i){ return ((i*3 + 7) % 11) - (i>>2) + (i|0) * 2; }
hot(arith, 60000); ck("arith", arith(12345), ((12345*3+7)%11)-(12345>>2)+12345*2);

function dbl(i){ return (i*1.5 + 0.25) / 3.0; }
hot(dbl, 60000); ck("double", dbl(8).toFixed(6), ((8*1.5+0.25)/3.0).toFixed(6));

function streq(i){ var a = "hello"+(i%3); return a === "hello1"; }
hot(streq, 60000); ck("strEq true", streq(1), true); ck("strEq false", streq(2), false);

function slice(i){ return ("abcdefghij").slice(i%12, 8); }
hot(slice, 60000);
ck("slice 0", slice(0), "abcdefgh"); ck("slice 9", slice(9), ""); ck("slice 11", slice(11), "");

function neg(i){ return ("abcdefghij").slice(-4, -1); }
hot(neg, 60000); ck("slice neg", neg(0), "ghi");

var arr = [];
for (var i = 0; i < 200; i++) arr.push((i * 37) % 101);
function srt(){ var a = arr.slice(); a.sort(function(x,y){return x-y;}); return a[0]+","+a[199]; }
hot(srt, 3000); ck("sort", srt(), "0,100");

var sparse = [5,,3,undefined,1,,9];
function ssrt(){ var a = sparse.slice(); a.sort(); return a.join("|"); }
hot(ssrt, 3000); ck("sparse sort", ssrt(), [5,,3,undefined,1,,9].slice().sort().join("|"));

function props(i){ var o = {a:i, b:i*2, c:"x"+i}; return o.a + o.b + o.c.length; }
hot(props, 60000); ck("props", props(10), 10+20+3);

function arr2(i){ var a = [i,i+1,i+2]; a[1] = a[0] + a[2]; return a[1]; }
hot(arr2, 60000); ck("array", arr2(5), 12);

function big(i){ return (i * 1000000) + 2147483000; }
hot(big, 60000); ck("int overflow", big(3), 3000000+2147483000);

function str2(i){ return ("v" + i).charCodeAt(0) + ("q"+i).indexOf("q"); }
hot(str2, 60000); ck("charCode", str2(7), 118);

function cmp(i){ return (i < 100) ? "lo" : (i > 50000 ? "hi" : "mid"); }
hot(cmp, 60000); ck("cmp", cmp(200), "mid"); ck("cmp2", cmp(60000), "hi");

print(fail === 0 ? "ALL OK" : (fail + " FAILURES"));
function mfloor(i){ return Math.floor(i/7 + 0.5); }
hot(mfloor, 60000); ck("Math.floor", mfloor(100), Math.floor(100/7+0.5));
function mceil(i){ return Math.ceil(i/7 + 0.5); }
hot(mceil, 60000); ck("Math.ceil", mceil(100), Math.ceil(100/7+0.5));
function mround(i){ return Math.round(i/7 + 0.5); }
hot(mround, 60000); ck("Math.round", mround(100), Math.round(100/7+0.5));
function mpow(i){ return Math.pow(1.0001, i%50); }
hot(mpow, 60000); ck("Math.pow", mpow(10).toFixed(8), Math.pow(1.0001,10).toFixed(8));
function radix(i){ return (i*1234567).toString(16) + "/" + (i/3).toString(2).slice(0,10); }
hot(radix, 60000); ck("toString radix", radix(9), (9*1234567).toString(16)+"/"+(9/3).toString(2).slice(0,10));
function pint(i){ return parseInt(String(i/7)) + parseFloat(String(i/7)).toFixed(4); }
hot(pint, 60000); ck("parseInt/Float", pint(100), parseInt(String(100/7))+parseFloat(String(100/7)).toFixed(4));
function fmod2(i){ return (i % 11) + "," + (i % 7) + "," + (i % 256) + "," + (i % 1); }
hot(fmod2, 60000); ck("mod variants", fmod2(37042), (37042%11)+","+(37042%7)+","+(37042%256)+","+(37042%1));
function fdiv(i){ return ((i/3)|0) + "," + (i/4) + "," + ((i/7)|0); }
hot(fdiv, 60000); ck("div", fdiv(1000), ((1000/3)|0)+","+(1000/4)+","+((1000/7)|0));
function negmod(i){ return (-i % 11) + "," + (i % -11); }
hot(negmod, 60000); ck("neg mod", negmod(37042), (-37042%11)+","+(37042%-11));
function pushd(i){ var a=[]; a.push(i/3); a.push(i/7); return a[0].toFixed(4)+","+a[1].toFixed(4); }
hot(pushd, 60000); ck("array push double", pushd(100), (100/3).toFixed(4)+","+(100/7).toFixed(4));
print(fail === 0 ? "ALL OK (extended)" : (fail + " FAILURES (extended)"));
