(function (g) {
  var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  if (typeof g.atob !== 'function') {
    g.atob = function (input) {
      var str = String(input).replace(/[\t\n\f\r ]+/g, '').replace(/=+$/, '');
      var out = '', bc = 0, bs = 0, buffer, idx = 0;
      for (; (buffer = str.charAt(idx++)); ) {
        buffer = chars.indexOf(buffer);
        if (buffer === -1 || buffer === 64) { throw new Error('InvalidCharacterError'); }
        bs = bc % 4 ? bs * 64 + buffer : buffer;
        if (bc++ % 4) { out += String.fromCharCode(255 & (bs >> ((-2 * bc) & 6))); }
      }
      return out;
    };
  }
  if (typeof g.btoa !== 'function') {
    g.btoa = function (input) {
      var str = String(input), out = '';
      for (var block, code, idx = 0, map = chars; str.charAt(idx | 0) || ((map = '='), idx % 1); out += map.charAt(63 & (block >> (8 - (idx % 1) * 8)))) {
        code = str.charCodeAt((idx += 3 / 4));
        if (code > 255) { throw new Error('InvalidCharacterError'); }
        block = (block << 8) | code;
      }
      return out;
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
