#define OSLOG_BATTERY(CASE) \
    CASE("plain text no args") \
    CASE("percent %% sign") \
    CASE("d %d i %i u %u x %x X %X o %o", i, i, u, 255, 255, 8) \
    CASE("long %lu %lx", 4000000000UL, 4000000000UL) \
    CASE("width [%5d] [%-5d] [%05d] [%+d] [% d]", 42, 42, 42, 42, 42) \
    CASE("hex %08x %#08x %#X %#.4x %#o", 255, 255, 255, 255, 8) \
    CASE("float %f %.2f %10.3f %e %g %G %a", d, d, d, d, d, d, d) \
    CASE("float arg %f", f) \
    CASE("f: %5.1f|%-8.3e|%+g", 3.14159, 31415.9, 0.0001) \
    CASE("star [%*d] [%.*f] [%*d] [%.*d]", 6, 42, 2, d, -5, 42, -1, 5) \
    CASE("char %c ptr %p null ptr %p", c, p, (void *)0) \
    CASE("str [%s] null [%s] prec [%.2s] width [%6s] [%-6s]", s, nul, s, s, s) \
    CASE("null width [%8s] null prec [%.2s] str prec zero [%.0s]", nul, nul, s) \
    CASE("empty str [%s] concat %s%s%s", "", "a", "b", "c") \
    CASE("obj %@ nil %@ number %@ array %@", o, nilo, @42, @[@1, @"a"]) \
    CASE("class %@ %@", [NSString class], [NSObject class]) \
    CASE("url %@", [NSURL URLWithString:@"http://a/b"]) \
    CASE("obj width [%10@] [%-10@] [%.2@] [%010@] [%8@]", o, o, o, o, nilo) \
    CASE("obj utf8 %@ width [%10@]", @"日本語", @"日本語") \
    CASE("obj multiline [%@]", @"line1\nline2") \
    CASE("two objs %@ %@ empty [%@]", o, @"second", @"") \
    CASE("pub %{public}s priv %{private}s pubobj %{public}@ privobj %{private}@ pubint %{public}d privint %{private}d", s, s, o, o, 1, 2) \
    CASE("width dec [%{public}10s] [%{public}-6d] ptr %{public}p", "ab", 42, (void *)0x10) \
    CASE("mask %{private, mask.hash}s and %{public}d", "sec", 5) \
    CASE("bool %{bool}d %{bool}d %{bool}d %{bool}d BOOL %{BOOL}d %{BOOL}d %{BOOL}d", 0, 1, 2, 256, 0, 2, -1) \
    CASE("bool as char %{bool}c BOOL hh %{BOOL}hhd", 1, 1) \
    CASE("errno %{errno}d %{errno}d %{errno}d %{errno}d %{darwin.errno}d %{errno}hhd", 0, 999, -1, 1, 13, 2) \
    CASE("time %{time_t}d %{time_t}d", 0, 1700000000) \
    CASE("signal %{darwin.signal}d %{darwin.signal}d %{darwin.signal}d", 1, 11, 99) \
    CASE("mode %{darwin.mode}d %{darwin.mode}d %{darwin.mode}d %{darwin.mode}d", 0100644, 040755, 0177, 04755) \
    CASE("uuid %{uuid_t}.16P", uu) \
    CASE("bytes %.*P and %.0P and %.1P", 3, uu, uu, uu) \
    CASE("raw %.4P", "abcd") \
    CASE("unknown decorator %{unknown_thing}d and %{name=x}d spaced %{ public , bool }d empty %{}d", 7, 8, 1, 5) \
    CASE("in_addr %{in_addr}d odtypes %{odtypes:mdns_addrmv}d", 16777343, 1) \
    CASE("unknown conv %y") \
    CASE("trailing percent %") \
    CASE("m is %m and again %m") \
    CASE("d then m %d then %m", 1) \
    CASE("utf8 char* [%s] ctrl [%s] high [%s] invalid [%s]", "h\xc3\xa9llo \xe2\x9c\x93", "a\tb\nc\x01" "d\x7f", "\x80", "ok\xc3") \
    CASE("ctrl obj [%@]", @"a\tb\nc\x01" "d") \
    CASE("newline in fmt\nsecond line %d", 1) \
    CASE("tab\t%d", 3) \
    CASE("neg width str [%*s]", -5, "ab") \
    CASE("ends with space ") \
    CASE("ends with spaces   ") \
    CASE("ends with newline\n") \
    CASE("ends with tab\t") \
    CASE("pad end %-5d", 1) \
    CASE("obj pad end %-8@", @"ab") \
    CASE("   leading spaces %d", 1) \
    CASE(" ") \
    CASE("a\n b\n") \
    CASE("percent-space % ") \
    CASE("percent-space-d % d", 5) \
    CASE("hh %hhd h %hd ll %lld z %zu", ch, sh, ll, z) \
    CASE("ll %llx %llu", 0xdeadbeefcafeLL, 18446744073709551615ULL) \
    CASE("dict %@", @{@"k": @"v"})

#define OSLOG_BATTERY_HOST(CASE) \
    CASE("j %jd t %td q %qd", (intmax_t)-5, (ptrdiff_t)7, (long long)-9) \
    CASE("data %@", [NSData dataWithBytes:"ab" length:2]) \
    CASE("neg 64 %ld", -9223372036854775807L) \
    CASE("time 64 %{time_t}lld", 4102444800LL)
