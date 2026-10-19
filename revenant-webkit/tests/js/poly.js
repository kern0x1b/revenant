var fail=0;
function ck(n,g,w){ if(String(g)!==String(w)){print("FAIL "+n+": "+g+" != "+w);fail++;} }
function A(){this.x=1;} function B(){this.x=2;this.y=9;} function C(){this.z=3;this.x=4;}
function D(){this.a=1;this.b=2;this.c=3;this.x=5;}
var objs=[new A(),new B(),new C(),new D()];
function getx(o){ return o.x; }
var s=0; for(var i=0;i<200000;i++) s+=getx(objs[i&3]);
ck("polymorphic getx", s, 50000*(1+2+4+5));

function setx(o,v){ o.x=v; return o.x; }
var t=0; for(var i=0;i<200000;i++) t+=setx(objs[i&3], i&7);
ck("polymorphic setx", t, (function(){var q=0;for(var i=0;i<200000;i++)q+=(i&7);return q;})());

var mixed=[ "str", [1,2,3], {x:7}, new A() ];
function getlen(o){ return o.length; }
var u=0; for(var i=0;i<200000;i++){ var v=getlen(mixed[i&1]); u+=(v===undefined?0:v); }
ck("mixed length", u, 100000*3+100000*3);

function proto(o){ return o.toString; }
var p=0; for(var i=0;i<200000;i++) p+= (proto(objs[i&3])?1:0);
ck("proto lookup", p, 200000);

var many=[]; for(var k=0;k<12;k++){ var o={}; for(var j=0;j<=k;j++) o["f"+j]=j; o.tgt=k; many.push(o); }
function gettgt(o){ return o.tgt; }
var m=0; for(var i=0;i<300000;i++) m+=gettgt(many[i%12]);
ck("megamorphic", m, 25000*(0+1+2+3+4+5+6+7+8+9+10+11));

function callm(o){ return o.f(); }
var cs=[{f:function(){return 1;}},{f:function(){return 2;}},{f:function(){return 3;}}];
var c=0; for(var i=0;i<200000;i++) c+=callm(cs[i%3]);
ck("polymorphic call", c, (function(){var q=0;for(var i=0;i<200000;i++)q+=(i%3)+1;return q;})());

var strs=["alpha","beta","gamma","delta"];
function sm(x){ return x.slice(1)+x.charAt(0)+x.indexOf("a"); }
var r=""; for(var i=0;i<200000;i++) r=sm(strs[i&3]);
ck("string methods", r, "elta"+"d"+"4");

print(fail===0 ? "POLY ALL OK" : fail+" POLY FAILURES");
