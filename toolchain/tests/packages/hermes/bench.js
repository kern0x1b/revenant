(function () {
    var out = [];
    function measure(name, body) {
        var start = Date.now();
        var result = body();
        out.push(name + " " + (Date.now() - start) + "ms " + result);
    }
    measure("loop20M", function () {
        var s = 0;
        for (var i = 0; i < 20000000; i++) {
            s = (s + i * 3) | 0;
        }
        return s;
    });
    measure("alloc500k", function () {
        var a = [];
        for (var i = 0; i < 500000; i++) {
            a.push({a: i, b: "x", c: [i]});
        }
        return a.length;
    });
    measure("str200k", function () {
        var s = "";
        for (var i = 0; i < 200000; i++) {
            s += i;
        }
        return s.length;
    });
    measure("sortmap200k", function () {
        var a = [];
        for (var i = 0; i < 200000; i++) {
            a.push((i * 7919) % 100003);
        }
        a.sort(function (x, y) {
            return x - y;
        });
        return a.map(function (x) {
            return x * 2;
        }).length;
    });
    measure("closure2M", function () {
        var n = 0;
        function make(i) {
            return function () {
                n += i;
            };
        }
        for (var i = 0; i < 2000000; i++) {
            make(i)();
        }
        return n;
    });
    measure("json", function () {
        var o = {};
        for (var i = 0; i < 20000; i++) {
            o["k" + i] = {v: i, s: "abc" + i};
        }
        return JSON.parse(JSON.stringify(o)) ? 1 : 0;
    });
    measure("loop20M-again", function () {
        var s = 0;
        for (var i = 0; i < 20000000; i++) {
            s = (s + i * 3) | 0;
        }
        return s;
    });
    return out.join(" | ");
})();
