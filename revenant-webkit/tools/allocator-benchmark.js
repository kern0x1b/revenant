(function(){
  function run(){
    var t = Date.now();
    // Strings and objects of varied sizes: what a page actually allocates.
    var sink = 0;
    for (var round = 0; round < 40; round++) {
      var a = [];
      for (var i = 0; i < 3000; i++) {
        a.push({id: i, name: 'item-' + i, tags: [i, i+1, i+2], text: ('x').repeat((i % 64) + 8)});
      }
      for (var j = 0; j < a.length; j++) sink += a[j].tags[1] + a[j].text.length;
      a = null;
    }
    return [Date.now() - t, sink];
  }
  run();
  var best = 1e9, times = [];
  for (var k = 0; k < 3; k++) { var r = run(); times.push(r[0]); if (r[0] < best) best = r[0]; }
  return JSON.stringify({runs: times, best: best});
})()
