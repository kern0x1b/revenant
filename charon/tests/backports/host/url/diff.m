#import <Foundation/Foundation.h>
#import <objc/message.h>

static int failures;
static int checks;
static NSMutableDictionary *expectations;
static NSMutableDictionary *divergences;

static NSCountedSet *failuresBySection;

static void check(BOOL passed, NSString *section, NSString *detail)
{
    checks++;
    if (!passed) {
        failures++;
        [failuresBySection addObject:section];
        if ([failuresBySection countForObject:section] <= 10)
            printf("FAIL %s: %s\n", section.UTF8String, detail.UTF8String);
    }
}

static void observe(NSString *kind, NSString *example)
{
    NSMutableArray *examples = divergences[kind];
    if (!examples)
        divergences[kind] = examples = [NSMutableArray array];
    if (examples.count < 6)
        [examples addObject:example];
    else if (examples.count == 6)
        [examples addObject:@"..."];
    NSString *counter = [kind stringByAppendingString:@" (count)"];
    divergences[counter] = @([divergences[counter] integerValue] + 1);
}

static void expect(NSString *section, id record)
{
    NSMutableArray *records = expectations[section];
    if (!records)
        expectations[section] = records = [NSMutableArray array];
    [records addObject:record];
}

static BOOL same(id first, id second)
{
    return first == second || [first isEqual:second];
}

static id value(id object)
{
    return object ? object : [NSNull null];
}

static BOOL wellFormed(NSString *string)
{
    NSUInteger length = string.length;
    for (NSUInteger index = 0; index < length; index++) {
        unichar character = [string characterAtIndex:index];
        if (character >= 0xD800 && character <= 0xDBFF) {
            if (index + 1 >= length)
                return NO;
            unichar next = [string characterAtIndex:index + 1];
            if (next < 0xDC00 || next > 0xDFFF)
                return NO;
            index++;
        } else if (character >= 0xDC00 && character <= 0xDFFF) {
            return NO;
        }
    }
    return YES;
}

static id portable(NSString *string)
{
    if (!string)
        return [NSNull null];
    if (wellFormed(string))
        return string;
    NSMutableArray *units = [NSMutableArray array];
    for (NSUInteger index = 0; index < string.length; index++)
        [units addObject:@([string characterAtIndex:index])];
    return @{@"u16": units};
}

static NSString *show(id object)
{
    if (!object)
        return @"nil";
    if ([object isKindOfClass:[NSString class]]) {
        NSMutableString *shown = [NSMutableString stringWithString:@"\""];
        for (NSUInteger index = 0; index < [object length]; index++) {
            unichar character = [object characterAtIndex:index];
            if (character < 0x20 || character > 0x7E)
                [shown appendFormat:@"\\u%04X", character];
            else
                [shown appendFormat:@"%C", character];
        }
        [shown appendString:@"\""];
        return shown;
    }
    return [object description];
}

static id send(id target, NSString *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(selector));
}

static NSString *oursEncode(NSString *string, NSCharacterSet *set)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(string, NSSelectorFromString(@"charonHost_stringByAddingPercentEncodingWithAllowedCharacters:"), set);
}

static NSString *oursDecode(NSString *string)
{
    return send(string, @"charonHost_stringByRemovingPercentEncoding");
}

static NSArray *setNames(void)
{
    return @[@"User", @"Password", @"Host", @"Path", @"Query", @"Fragment"];
}

static NSCharacterSet *systemSet(NSString *name)
{
    return send([NSCharacterSet class], [NSString stringWithFormat:@"URL%@AllowedCharacterSet", name]);
}

static NSCharacterSet *oursSet(NSString *name)
{
    return send([NSCharacterSet class], [NSString stringWithFormat:@"charonHost_URL%@AllowedCharacterSet", name]);
}

static Class Ours(void)
{
    return NSClassFromString(@"CharonHostNSURLComponents");
}

static uint64_t seed = 0x9E3779B97F4A7C15ull;

static uint32_t randomNumber(uint32_t bound)
{
    seed ^= seed << 13;
    seed ^= seed >> 7;
    seed ^= seed << 17;
    return (uint32_t)(seed % bound);
}

static NSString *randomString(NSArray *pieces, uint32_t maximum)
{
    NSMutableString *string = [NSMutableString string];
    uint32_t count = randomNumber(maximum + 1);
    for (uint32_t index = 0; index < count; index++)
        [string appendString:pieces[randomNumber((uint32_t)pieces.count)]];
    return string;
}

static NSString *stringWithUnits(const unichar *units, NSUInteger count)
{
    return [NSString stringWithCharacters:units length:count];
}

static void testSets(void)
{
    for (NSString *name in setNames()) {
        NSCharacterSet *system = systemSet(name);
        NSCharacterSet *documented = systemSet(name);
        NSCharacterSet *ours = oursSet(name);
        NSMutableArray *members = [NSMutableArray array];
        NSUInteger mismatches = 0;
        for (UTF32Char character = 0; character <= 0x10FFFF; character++) {
            BOOL expected = character < 128 && [documented longCharacterIsMember:character];
            BOOL actual = [ours longCharacterIsMember:character];
            if (expected != actual)
                mismatches++;
            check(expected == actual, @"set", [NSString stringWithFormat:@"URL%@AllowedCharacterSet U+%04X expected %d", name, (unsigned)character, expected]);
            if (expected)
                [members addObject:@(character)];
        }
        check(mismatches == 0, @"set", [NSString stringWithFormat:@"URL%@AllowedCharacterSet all 0x110000 scalars", name]);
        expect(@"sets", @[name, members]);
    }
}

static NSDictionary *encodingSets(void)
{
    NSMutableDictionary *sets = [NSMutableDictionary dictionary];
    for (NSString *name in setNames())
        sets[name] = @[systemSet(name), oursSet(name)];
    NSCharacterSet *empty = [NSCharacterSet characterSetWithCharactersInString:@""];
    sets[@"empty"] = @[empty, empty];
    sets[@"alphanumeric"] = @[[NSCharacterSet alphanumericCharacterSet], [NSCharacterSet alphanumericCharacterSet]];
    NSCharacterSet *mixed = [NSCharacterSet characterSetWithCharactersInString:@"%\u00E9 /\u4E2D"];
    sets[@"mixed"] = @[mixed, mixed];
    return sets;
}

static void testEncoding(void)
{
    NSMutableArray *inputs = [NSMutableArray array];
    NSMutableIndexSet *device = [NSMutableIndexSet indexSet];
    for (UTF32Char start = 0; start <= 0x10FFFF; start += 64) {
        NSMutableString *string = [NSMutableString string];
        for (UTF32Char character = start; character < start + 64 && character <= 0x10FFFF; character++) {
            if (character >= 0xD800 && character <= 0xDFFF)
                continue;
            UTF32Char swapped = NSSwapHostIntToLittle(character);
            [string appendString:[[NSString alloc] initWithBytes:&swapped length:4 encoding:NSUTF32LittleEndianStringEncoding]];
        }
        if (start < 0x800 || start % 0x4000 == 0)
            [device addIndex:inputs.count];
        [inputs addObject:string];
    }
    NSArray *explicit = @[@"", @"a b", @"100%", @"%41", @"\u00E9\U0001F600", @"e\u0301", @"\0", @"a;b/c?d#e[f]g@h:i", @"~-._", @"\uFFFF\U0010FFFF"];
    for (NSString *string in explicit) {
        [device addIndex:inputs.count];
        [inputs addObject:string];
    }
    unichar high = 0xD800, low = 0xDC00;
    unichar pair[] = {'a', 0xD83D, 0xDE00, 'b'};
    unichar reversed[] = {0xDC00, 0xD800};
    for (NSString *string in @[stringWithUnits(&high, 1), stringWithUnits(&low, 1), stringWithUnits(pair, 4), stringWithUnits(pair, 2), stringWithUnits(reversed, 2)]) {
        [device addIndex:inputs.count];
        [inputs addObject:string];
    }
    NSDictionary *sets = encodingSets();
    for (NSString *name in [sets.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSCharacterSet *reference = sets[name][0];
        NSCharacterSet *ours = sets[name][1];
        [inputs enumerateObjectsUsingBlock:^(NSString *input, NSUInteger index, BOOL *stop) {
            NSString *expected = [input stringByAddingPercentEncodingWithAllowedCharacters:reference];
            NSString *actual = oursEncode(input, ours);
            check(same(expected, actual), @"encode", [NSString stringWithFormat:@"%@ %@ -> %@, expected %@", name, show(input), show(actual), show(expected)]);
            if ([device containsIndex:index])
                expect(@"encode", @[name, portable(input), value(expected)]);
        }];
    }
}

static void testDecoding(void)
{
    NSMutableArray *inputs = [NSMutableArray array];
    NSMutableIndexSet *device = [NSMutableIndexSet indexSet];
    for (int first = 0; first < 256; first++) {
        [device addIndex:inputs.count];
        [inputs addObject:[NSString stringWithFormat:@"%%%02X", first]];
        [inputs addObject:[NSString stringWithFormat:@"%%%02x", first]];
    }
    for (int first = 0xC0; first < 0x100; first++) {
        for (int second = 0; second < 256; second++) {
            if (second % 17 == 0 || (second >= 0x7E && second <= 0xC1))
                [device addIndex:inputs.count];
            [inputs addObject:[NSString stringWithFormat:@"%%%02X%%%02X", first, second]];
        }
    }
    for (int first = 0xE0; first < 0xF0; first++) {
        for (int second = 0x70; second < 0xD0; second++) {
            for (int third = 0x70; third < 0xD0; third += 3) {
                if ((second % 16 == 0 || second == 0x9F || second == 0xA0) && third % 5 == 0)
                    [device addIndex:inputs.count];
                [inputs addObject:[NSString stringWithFormat:@"%%%02X%%%02X%%%02X", first, second, third]];
            }
        }
    }
    for (int first = 0xF0; first < 0xF8; first++) {
        for (int second = 0x70; second < 0xD0; second++) {
            int thirds[] = {0x7F, 0x80, 0xBF, 0xC0};
            for (int third = 0; third < 4; third++) {
                for (int fourth = 0; fourth < 4; fourth++) {
                    if (second % 8 == 0 || second == 0x8F || second == 0x90)
                        [device addIndex:inputs.count];
                    [inputs addObject:[NSString stringWithFormat:@"%%%02X%%%02X%%%02X%%%02X", first, second, thirds[third], thirds[fourth]]];
                }
            }
        }
    }
    NSArray *explicit = @[@"", @"%", @"%4", @"%4G", @"%G4", @"a%", @"%%41", @"%c3%a9", @"\u00E9%41", @"a+b", @"%2B", @"%20%", @"%E2%82", @"%E2%82%AC%E2", @"x%00y", @"%F0%9F%98%80", @"%ED%A0%80", @"%ED%9F%BF", @"%EF%BF%BF", @"%F4%8F%BF%BF", @"%F4%90%80%80", @"%C0%80", @"%E0%80%80", @"%F0%80%80%80", @"%%", @"100%25"];
    for (NSString *string in explicit) {
        [device addIndex:inputs.count];
        [inputs addObject:string];
    }
    unichar lone[] = {'%', '4', '1', 0xD800};
    [device addIndex:inputs.count];
    [inputs addObject:stringWithUnits(lone, 4)];
    NSString *random = @"%41%zz%C3%A9%E2%82%AC%FF%2 +\u00E9aZ";
    NSMutableArray *pieces = [NSMutableArray array];
    for (NSUInteger index = 0; index < random.length; index++)
        [pieces addObject:[random substringWithRange:NSMakeRange(index, 1)]];
    [pieces addObjectsFromArray:@[@"%C3", @"%A9", @"%E2", @"%82", @"%AC", @"%F0", @"%9F", @"%98", @"%80"]];
    for (int index = 0; index < 20000; index++) {
        if (index % 40 == 0)
            [device addIndex:inputs.count];
        [inputs addObject:randomString(pieces, 12)];
    }
    [inputs enumerateObjectsUsingBlock:^(NSString *input, NSUInteger index, BOOL *stop) {
        NSString *expected = input.stringByRemovingPercentEncoding;
        NSString *actual = oursDecode(input);
        check(same(expected, actual), @"decode", [NSString stringWithFormat:@"%@ -> %@, expected %@", show(input), show(actual), show(expected)]);
        if ([device containsIndex:index])
            expect(@"decode", @[portable(input), portable(expected)]);
    }];
}

static id rangesOf(NSURLComponents *components)
{
    NSRange ranges[] = {components.rangeOfScheme, components.rangeOfUser, components.rangeOfPassword, components.rangeOfHost,
                        components.rangeOfPort, components.rangeOfPath, components.rangeOfQuery, components.rangeOfFragment};
    NSMutableArray *list = [NSMutableArray array];
    for (int index = 0; index < 8; index++)
        [list addObject:@[@(ranges[index].location == NSNotFound ? -1 : (long long)ranges[index].location), @(ranges[index].length)]];
    return list;
}

static id itemsOf(NSArray *items)
{
    if (!items)
        return [NSNull null];
    NSMutableArray *list = [NSMutableArray array];
    for (NSURLQueryItem *item in items)
        [list addObject:@[value(item.name), value(item.value)]];
    return list;
}

static NSArray *dumpNames(void)
{
    return @[@"scheme", @"percentEncodedUser", @"percentEncodedPassword", @"percentEncodedHost", @"port", @"percentEncodedPath", @"percentEncodedQuery",
             @"percentEncodedFragment", @"user", @"password", @"host", @"path", @"query", @"fragment", @"string", @"URL", @"ranges", @"queryItems"];
}

static id dump(NSURLComponents *components)
{
    if (!components)
        return [NSNull null];
    return @[value(components.scheme), value(components.percentEncodedUser), value(components.percentEncodedPassword), value(components.percentEncodedHost),
             value(components.port), value(components.percentEncodedPath), value(components.percentEncodedQuery), value(components.percentEncodedFragment),
             value(components.user), value(components.password), value(components.host), value(components.path), value(components.query), value(components.fragment),
             value(components.string), value(components.URL.absoluteString), rangesOf(components), itemsOf(components.queryItems)];
}

static NSString *textOf(id object)
{
    return [object isKindOfClass:[NSNull class]] ? nil : object;
}

static id oracle(NSURLComponents *system, NSString *input)
{
    if (!system)
        return [NSNull null];
    NSMutableArray *expected = [dump(system) mutableCopy];
    NSURLComponents *normalized = [system copy];
    normalized.port = system.port;
    NSArray *encodedIndex = @[@1, @2, @3, @5, @6, @7];
    for (NSUInteger offset = 0; offset < 6; offset++) {
        NSString *encoded = textOf(expected[[encodedIndex[offset] unsignedIntegerValue]]);
        id documented = value(encoded.stringByRemovingPercentEncoding);
        if (!same(expected[8 + offset], documented)) {
            observe([NSString stringWithFormat:@"-%@: macOS 27 does not return the percent-decoded component", dumpNames()[8 + offset]],
                    [NSString stringWithFormat:@"%@ -> %@, decoded %@", input, show(textOf(expected[8 + offset])), show(textOf(documented))]);
            expected[8 + offset] = documented;
        }
    }
    NSArray *normalizedDump = dump(normalized);
    for (NSUInteger index = 14; index <= 16; index++) {
        if (!same(expected[index], normalizedDump[index])) {
            observe(@"port: macOS 27 keeps the port text as written, the backport writes the port number", [NSString stringWithFormat:@"%@ -> %@", input, show(textOf(normalizedDump[14]))]);
            expected[index] = normalizedDump[index];
        }
    }
    return expected;
}

static void compareDumps(NSString *section, NSString *input, id expected, id actual)
{
    if ([expected isKindOfClass:[NSNull class]] || [actual isKindOfClass:[NSNull class]]) {
        check(same(expected, actual), section, [NSString stringWithFormat:@"%@ -> %@, expected %@", show(input), actual, expected]);
        return;
    }
    for (NSUInteger index = 0; index < [expected count]; index++)
        check(same(expected[index], actual[index]), section, [NSString stringWithFormat:@"%@ %@ -> %@, expected %@", show(input), dumpNames()[index], actual[index], expected[index]]);
}

static NSArray *parseInputs(NSMutableIndexSet *device)
{
    NSMutableArray *inputs = [NSMutableArray array];
    NSArray *explicit = @[
        @"ftp://ftp.is.co.za/rfc/rfc1808.txt", @"http://www.ietf.org/rfc/rfc2396.txt", @"ldap://[2001:db8::7]/c=GB?objectClass?one", @"mailto:John.Doe@example.com",
        @"news:comp.infosystems.www.servers.unix", @"tel:+1-816-555-1212", @"telnet://192.0.2.16:80/", @"urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
        @"foo://example.com:8042/over/there?name=ferret#nose", @"urn:example:animal:ferret:nose", @"http://a/b/c/d;p?q", @"g;x=1/../y", @"../g", @"//g", @"?y#s",
        @"", @"a", @"//h", @"http:", @"http://", @"http:///p", @"http://u@h", @"http://u:@h", @"http://:p@h", @"http://@h", @"http://h?#", @"1http://x", @"+a://x",
        @"http://a b", @"http://h/p%2", @"http://h/p%", @"http://h/%zz", @"http://h:abc/", @"http://h:8a", @"http://[::1]:80/p", @"http://[::1/p", @"http://[zz]/",
        @"http://[v1.x]/", @"http://[::ffff:1.2.3.4]/", @"http://[fe80::1%25en0]/", @"http://[fe80::1%en0]/", @"http://[%41]/", @"http://[]/", @"http://[::1]x/",
        @"http://h]/", @"http://a@b@c/", @"http://u:p:q@h", @"http://h:1:2/", @"http://host:/", @"http://h:0080/", @"http://h:99999999999999999999/",
        @"http://h:9223372036854775807/", @"http://h:9223372036854775808/", @"http://[::1]:/", @"//:80", @"//@", @"//[]", @"a:b", @"1a:b", @":b", @"./a:b", @"a/b:c",
        @"?a:b", @"#", @"?", @"HTTP://H/", @"HtTp://h", @"http://%41.com/", @"http://%C3%A9.com/", @"http://%FF/", @"http://%FF@h/", @"http://h/a%FF",
        @"http://h/?%FF#%FF", @"http://h/%C3%A9?%E2%82%AC#%F0%9F%98%80", @"http://h/p#f#g", @"http://h/p?q?/", @"http://h/p?q#f?/", @"http://h/{}", @"http://h/[x]",
        @"http://u[@h", @"http://h/?a=1&b=2+3", @"http://h/?a&&b=&=c&%41=%42", @"s://h/p;x", @"http://\u00E9.com/", @"http://h/\u00E9", @"http://h/p q",
        @"http://xn--9ca.com/", @"http://1.2.3.4/", @"http://[1.2.3.4]/", @"file:///tmp/a%20b", @"file://localhost/etc", @"data:text/plain,a%20b",
        @"javascript:void(0)", @"http://h/a//b/./c/../d", @"//u:p@h:1/p", @"a:", @"a+b-c.d:x", @"a_b:x", @"http://h\\p", @"http://h/\"", @"http://h/`", @"http://h/^",
        @"http://h/|", @"http://h/<>", @"http://h/%7C", @"http://h/!$&'()*+,;=:@", @"http://h/?!$&'()*+,;=:@/?", @"http://h/#!$&'()*+,;=:@/?",
        @"http://!$&'()*+,;=-._~@h", @"http://u:!$&'()*+,;=-._~@h", @"http://!$&'()*+,;=-._~/"
    ];
    for (NSString *input in explicit) {
        [device addIndex:inputs.count];
        [inputs addObject:input];
    }
    NSArray *schemes = @[@"", @"http:", @"a+b.c-d:", @"1a:", @":"];
    NSArray *authorities = @[@"", @"//", @"//h", @"//u@h", @"//u:p@h:80", @"//[::1]", @"//[::1]:8", @"//h:", @"//@", @"//%41", @"//u%20@h", @"//h h", @"//h:x"];
    NSArray *paths = @[@"", @"/", @"/a/b", @"a", @"a:b", @"/p%20q", @"/%zz", @"/a b", @"//x", @"/;p", @"/%FF", @"/@:"];
    NSArray *queries = @[@"", @"?", @"?a=b&c", @"?%26=%3D", @"?a+b", @"?#", @"?[", @"?/?"];
    NSArray *fragments = @[@"", @"#", @"#f", @"#f#g", @"#%FF", @"#/?:@"];
    NSUInteger counter = 0;
    for (NSString *scheme in schemes)
        for (NSString *authority in authorities)
            for (NSString *path in paths)
                for (NSString *query in queries)
                    for (NSString *fragment in fragments) {
                        if (counter++ % 23 == 0)
                            [device addIndex:inputs.count];
                        [inputs addObject:[NSString stringWithFormat:@"%@%@%@%@%@", scheme, authority, path, query, fragment]];
                    }
    NSArray *pieces = @[@"a", @"Z", @"0", @"9", @":", @"/", @"?", @"#", @"[", @"]", @"@", @"%", @"%4", @"%41", @"%C3%A9", @"!", @"$", @"&", @"'", @"(", @")",
                        @"*", @"+", @",", @";", @"=", @"-", @".", @"_", @"~", @" ", @"\"", @"<", @">", @"\\", @"^", @"`", @"{", @"|", @"}", @"\u00E9",
                        @"//", @"http:", @"::1", @"80", @"v1.", @"%25"];
    for (int index = 0; index < 60000; index++) {
        if (index % 100 == 0)
            [device addIndex:inputs.count];
        [inputs addObject:randomString(pieces, 14)];
    }
    return inputs;
}

static void testParsing(void)
{
    NSMutableIndexSet *device = [NSMutableIndexSet indexSet];
    NSArray *inputs = parseInputs(device);
    NSUInteger valid = 0;
    for (NSUInteger index = 0; index < inputs.count; index++) {
        NSString *input = inputs[index];
        NSURLComponents *system = [NSURLComponents componentsWithString:input encodingInvalidCharacters:NO];
        NSURLComponents *ours = [Ours() componentsWithString:input];
        id expected = oracle(system, input);
        if ([input hasPrefix:@"http://xn--"] && system) {
            observe(@"-host/-percentEncodedHost: macOS 27 decodes IDNA (punycode) host names, iOS 7-9 return the host as written", [NSString stringWithFormat:@"%@ -> %@ / %@", input, system.host, system.percentEncodedHost]);
            expected = [expected mutableCopy];
            expected[3] = @"xn--9ca.com";
            expected[10] = @"xn--9ca.com";
        }
        NSRange segment = [input rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
        NSString *first = segment.location == NSNotFound ? input : [input substringToIndex:segment.location];
        if (system && !system.scheme && [first rangeOfString:@":"].location != NSNotFound) {
            observe(@"+componentsWithString: macOS 27 accepts a relative reference whose first path segment contains ':' (e.g. an empty or non-scheme prefix), RFC 3986 section 4.2 forbids it", input);
            expected = [NSNull null];
        }
        valid += system != nil;
        compareDumps(@"parse", input, expected, dump(ours));
        if ([device containsIndex:index])
            expect(@"parse", @[input, expected]);
    }
    printf("parse inputs=%lu valid=%lu\n", (unsigned long)inputs.count, (unsigned long)valid);
    NSURLComponents *lenient = [NSURLComponents componentsWithString:@"http://h/p q"];
    if (lenient)
        observe(@"+componentsWithString: macOS 27 (linked on or after macOS 14) percent-encodes invalid characters; iOS 7-9 and encodingInvalidCharacters:NO return nil", lenient.string);
    check([Ours() componentsWithString:@"http://h/p q"] == nil, @"parse", @"invalid characters return nil");
    check([Ours() componentsWithString:(NSString *)nil] == nil, @"parse", @"nil string returns nil");
}

static NSArray *setterValues(void)
{
    NSMutableArray *values = [NSMutableArray array];
    for (unichar character = 0; character < 128; character++)
        [values addObject:[NSString stringWithCharacters:&character length:1]];
    [values addObjectsFromArray:@[@"", @"a b:c@d", @"[::1]", @"\u00E9.com", @"%41", @"%", @"u:@ ser", @"a;b/c?d#e[f]g", @"\U0001F600", @"a=b&c d?/#%+", @"f #?/%", @"//x", @"a:b", @"/a:b"]];
    unichar lone = 0xDC00;
    [values addObject:[NSString stringWithCharacters:&lone length:1]];
    return values;
}

static void testSetters(void)
{
    NSDictionary *setNamesByProperty = @{@"user": @"User", @"password": @"Password", @"host": @"Host", @"path": @"Path", @"query": @"Query", @"fragment": @"Fragment"};
    for (NSString *property in [setNamesByProperty.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *capitalized = [[[property substringToIndex:1] uppercaseString] stringByAppendingString:[property substringFromIndex:1]];
        SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@:", capitalized]);
        SEL encoded = NSSelectorFromString([@"percentEncoded" stringByAppendingString:capitalized]);
        NSCharacterSet *set = systemSet(setNamesByProperty[property]);
        for (NSString *input in [setterValues() arrayByAddingObject:[NSNull null]]) {
            NSString *given = textOf(input);
            NSURLComponents *system = [NSURLComponents new];
            NSURLComponents *ours = [Ours() new];
            ((void (*)(id, SEL, id))objc_msgSend)(system, setter, given);
            ((void (*)(id, SEL, id))objc_msgSend)(ours, setter, given);
            NSString *expected = [given stringByAddingPercentEncodingWithAllowedCharacters:set];
            NSString *systemValue = ((id (*)(id, SEL))objc_msgSend)(system, encoded);
            NSString *actual = ((id (*)(id, SEL))objc_msgSend)(ours, encoded);
            if (!same(systemValue, expected))
                observe([NSString stringWithFormat:@"-set%@: macOS 27 differs from percent-encoding with URL%@AllowedCharacterSet", capitalized, setNamesByProperty[property]],
                        [NSString stringWithFormat:@"%@ -> %@, documented %@", show(given), show(systemValue), show(expected)]);
            check(same(expected, actual), @"setter", [NSString stringWithFormat:@"set%@:%@ -> %@, expected %@", capitalized, show(given), show(actual), show(expected)]);
            expect(@"setters", @[property, portable(given), value(expected)]);
        }
    }
    NSURLComponents *ours = [Ours() new];
    check(ours.path == nil, @"setter", @"-init leaves the path undefined");
    if ([NSURLComponents new].path)
        observe(@"-init: macOS 27 returns an empty path, the backport leaves it nil like the other undefined components", @"path = \"\"");
    ours.path = @"/p";
    ours.path = nil;
    check(ours.path == nil && ours.percentEncodedPath == nil, @"setter", @"setPath:nil removes the path");
}

static NSArray *encodedValues(NSString *property)
{
    NSMutableArray *values = [NSMutableArray array];
    for (unichar character = 0; character < 128; character++) {
        [values addObject:[NSString stringWithCharacters:&character length:1]];
        [values addObject:[NSString stringWithFormat:@"%%%C", character]];
        [values addObject:[NSString stringWithFormat:@"%%4%C", character]];
        [values addObject:[NSString stringWithFormat:@"a%C", character]];
    }
    [values addObjectsFromArray:@[@"", @"%41", @"%zz", @"%2", @"\u00E9", @"%C3%A9", @"[::1]", @"[x", @"a:b", @"[v1.a]", @"[zz]", @"[::1]:80", @"x]", @"%5B::1%5D",
                                  @"[fe80::1%25en0]", @"[fe80::1%en0]", @"[%41]", @"[]", @"[::1%25]", @"[::1%25%41]", @"[::1%25a:b]", @"[::1%2541]", @"[[]]", @"[:]",
                                  @"a[b]", @"[a]b", @"!$&'()*+,;=-._~", @"/a:b@c", @"?/", @"a#b"]];
    NSArray *pieces = @[@"a", @"%", @"4", @"1", @"[", @"]", @":", @"@", @"/", @"?", @"#", @"%25", @"%41", @";", @"=", @" ", @"\u00E9", @"v", @"."];
    for (int index = 0; index < 1500; index++)
        [values addObject:randomString(pieces, 6)];
    return values;
}

static void testEncodedSetters(void)
{
    for (NSString *property in @[@"User", @"Password", @"Host", @"Path", @"Query", @"Fragment"]) {
        SEL setter = NSSelectorFromString([NSString stringWithFormat:@"setPercentEncoded%@:", property]);
        SEL getter = NSSelectorFromString([@"percentEncoded" stringByAppendingString:property]);
        NSUInteger index = 0;
        for (NSString *input in encodedValues(property)) {
            NSURLComponents *system = [NSURLComponents new];
            NSURLComponents *ours = [Ours() new];
            BOOL systemThrew = NO, oursThrew = NO;
            NSString *name = nil;
            @try {
                ((void (*)(id, SEL, id))objc_msgSend)(system, setter, input);
            } @catch (NSException *exception) {
                systemThrew = YES;
            }
            @try {
                ((void (*)(id, SEL, id))objc_msgSend)(ours, setter, input);
            } @catch (NSException *exception) {
                oursThrew = YES;
                name = exception.name;
            }
            check(systemThrew == oursThrew, @"percentEncoded setter", [NSString stringWithFormat:@"setPercentEncoded%@:%@ threw %d, expected %d", property, show(input), oursThrew, systemThrew]);
            if (oursThrew)
                check([name isEqualToString:NSInvalidArgumentException], @"percentEncoded setter", [NSString stringWithFormat:@"exception name %@", name]);
            else
                check(same(((id (*)(id, SEL))objc_msgSend)(ours, getter), input), @"percentEncoded setter", [NSString stringWithFormat:@"setPercentEncoded%@:%@ keeps the value", property, show(input)]);
            if (index++ < 520 || index % 10 == 0)
                expect(@"encodedSetters", @[property, portable(input), @(!systemThrew)]);
        }
        NSURLComponents *ours = [Ours() new];
        ((void (*)(id, SEL, id))objc_msgSend)(ours, setter, @"a");
        ((void (*)(id, SEL, id))objc_msgSend)(ours, setter, nil);
        check(((id (*)(id, SEL))objc_msgSend)(ours, getter) == nil, @"percentEncoded setter", [NSString stringWithFormat:@"setPercentEncoded%@:nil removes the component", property]);
    }
}

static void testScheme(void)
{
    NSMutableArray *values = [NSMutableArray array];
    for (unichar first = 32; first < 127; first++) {
        [values addObject:[NSString stringWithCharacters:&first length:1]];
        for (unichar second = 32; second < 127; second++) {
            unichar pair[] = {first, second};
            [values addObject:[NSString stringWithCharacters:pair length:2]];
        }
    }
    [values addObjectsFromArray:@[@"", @"http", @"a+b-c.d", @"\u00E9", @"a\u00E9", @"HTTP", @"a\0", @"\0"]];
    NSUInteger index = 0;
    for (NSString *input in values) {
        BOOL systemThrew = NO, oursThrew = NO;
        NSURLComponents *system = [NSURLComponents new], *ours = [Ours() new];
        @try {
            system.scheme = input;
        } @catch (NSException *exception) {
            systemThrew = YES;
        }
        @try {
            ours.scheme = input;
        } @catch (NSException *exception) {
            oursThrew = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        check(systemThrew == oursThrew && (oursThrew || [ours.scheme isEqualToString:input]), @"scheme", [NSString stringWithFormat:@"setScheme:%@ threw %d, expected %d", show(input), oursThrew, systemThrew]);
        if (input.length < 2 || index % 37 == 0 || !systemThrew)
            expect(@"schemes", @[input, @(!systemThrew)]);
        index++;
    }
    NSURLComponents *ours = [Ours() new];
    ours.scheme = @"a";
    ours.scheme = nil;
    check(ours.scheme == nil, @"scheme", @"setScheme:nil removes the scheme");
}

static void testPorts(void)
{
    NSArray *ports = @[@0, @1, @80, @(-1), @(-80), @1.5, @65535, @65536, @70000, @(LLONG_MAX), @YES, [NSDecimalNumber decimalNumberWithString:@"8080"], @(2147483648u)];
    for (NSNumber *port in ports) {
        BOOL systemThrew = NO, oursThrew = NO;
        NSURLComponents *system = [NSURLComponents componentsWithString:@"http://h/p"], *ours = [Ours() componentsWithString:@"http://h/p"];
        @try {
            system.port = port;
        } @catch (NSException *exception) {
            systemThrew = YES;
        }
        @try {
            ours.port = port;
        } @catch (NSException *exception) {
            oursThrew = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        check(systemThrew == oursThrew, @"port", [NSString stringWithFormat:@"setPort:%@ threw %d", port, oursThrew]);
        check(same(system.string, ours.string) && same(system.port, ours.port), @"port", [NSString stringWithFormat:@"setPort:%@ -> %@ %@, expected %@ %@", port, ours.string, ours.port, system.string, system.port]);
        expect(@"ports", @[port.stringValue, @(!systemThrew), value(system.string)]);
    }
}

static NSDictionary *randomComponents(void)
{
    NSArray *schemes = @[[NSNull null], @"http", @"s"];
    NSArray *users = @[[NSNull null], @"", @"u", @"u%20v"];
    NSArray *passwords = @[[NSNull null], @"", @"p"];
    NSArray *hosts = @[[NSNull null], @"", @"h", @"[::1]", @"a-b.c"];
    NSArray *ports = @[[NSNull null], @0, @8080];
    NSArray *paths = @[[NSNull null], @"", @"/", @"/a/b", @"a", @"a:b", @"a:b/c:d", @"//x", @"/a:b", @"a%20b", @"@:", @"./a:b", @"a/b:c", @"::", @"a:%41:b"];
    NSArray *queries = @[[NSNull null], @"", @"a=b", @"?/:@"];
    NSArray *fragments = @[[NSNull null], @"", @"f", @"?/"];
    return @{@"scheme": schemes[randomNumber(3)], @"percentEncodedUser": users[randomNumber(4)], @"percentEncodedPassword": passwords[randomNumber(3)],
             @"percentEncodedHost": hosts[randomNumber(5)], @"port": ports[randomNumber(3)], @"percentEncodedPath": paths[randomNumber(15)],
             @"percentEncodedQuery": queries[randomNumber(4)], @"percentEncodedFragment": fragments[randomNumber(4)]};
}

static void apply(NSURLComponents *components, NSDictionary *values)
{
    for (NSString *key in values)
        [components setValue:textOf(values[key]) forKey:key];
}

static void testComposition(void)
{
    NSMutableSet *seen = [NSMutableSet set];
    for (int index = 0; index < 20000; index++) {
        NSDictionary *values = randomComponents();
        if ([seen containsObject:values])
            continue;
        [seen addObject:values];
        NSURLComponents *system = [NSURLComponents new], *ours = [Ours() new];
        apply(system, values);
        apply(ours, values);
        NSString *path = textOf(values[@"percentEncodedPath"]);
        NSString *expected = system.string;
        id expectedRanges = rangesOf(system);
        if (!path && expected) {
            observe(@"-init: macOS 27 returns an empty path, the backport leaves it nil like the other undefined components", [NSString stringWithFormat:@"string %@", expected]);
            NSURLComponents *filled = [system copy];
            filled.percentEncodedPath = @"";
            expectedRanges = rangesOf(filled);
        }
        if ([path isEqualToString:@"::"] && !values[@"scheme"] && expected) {
            BOOL authority = textOf(values[@"percentEncodedUser"]) || textOf(values[@"percentEncodedPassword"]) || textOf(values[@"percentEncodedHost"]) || textOf(values[@"port"]);
            if (!authority && [expected hasPrefix:@"::"]) {
                observe(@"-string: macOS 27 percent-encodes ':' in a first path segment only when the segment has other characters", expected);
                NSString *fixed = [@"%3A%3A" stringByAppendingString:[expected substringFromIndex:2]];
                expected = fixed;
                expectedRanges = rangesOf([NSClassFromString(@"NSURLComponents") componentsWithString:fixed]);
            }
        }
        check(same(expected, ours.string), @"compose", [NSString stringWithFormat:@"%@ -> %@, expected %@", values, ours.string, expected]);
        check(same(expectedRanges, rangesOf(ours)), @"compose", [NSString stringWithFormat:@"%@ ranges %@, expected %@", values, rangesOf(ours), expectedRanges]);
        check(same(system.URL.absoluteString, ours.URL.absoluteString) || !same(expected, system.string), @"compose", [NSString stringWithFormat:@"%@ URL %@, expected %@", values, ours.URL, system.URL]);
        NSMutableDictionary *record = [NSMutableDictionary dictionary];
        for (NSString *key in values)
            record[key] = values[key];
        if (seen.count % 10 == 1)
            expect(@"compose", @[record, value(expected), expectedRanges]);
    }
}

static void testResolution(void)
{
    NSString *baseString = @"http://a/b/c/d;p?q";
    NSArray *references = @[@"g:h", @"g", @"./g", @"g/", @"/g", @"//g", @"?y", @"g?y", @"#s", @"g#s", @"g?y#s", @";x", @"g;x", @"g;x?y#s", @"", @".", @"./", @"..", @"../",
                            @"../g", @"../..", @"../../", @"../../g", @"../../../g", @"../../../../g", @"/./g", @"/../g", @"g.", @".g", @"g..", @"..g", @"./../g", @"./g/.",
                            @"g/./h", @"g/../h", @"g;x=1/./y", @"g;x=1/../y", @"g?y/./x", @"g?y/../x", @"g#s/./x", @"g#s/../x", @"http:g"];
    for (NSString *baseText in @[baseString, @"http://u:p@a:8/b/c?q#f", @"file:///tmp/dir/"]) {
        NSURL *base = [NSURL URLWithString:baseText];
        for (NSString *reference in references) {
            NSURL *url = [NSURL URLWithString:reference relativeToURL:base];
            if (!url)
                continue;
            id yes = oracle([NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES], reference);
            id no = oracle([NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO], reference);
            compareDumps(@"resolve YES", reference, yes, dump([Ours() componentsWithURL:url resolvingAgainstBaseURL:YES]));
            compareDumps(@"resolve NO", reference, no, dump([Ours() componentsWithURL:url resolvingAgainstBaseURL:NO]));
            NSURLComponents *relative = [NSURLComponents componentsWithString:reference];
            NSURLComponents *oursRelative = [Ours() componentsWithString:reference];
            NSURL *expected = [relative URLRelativeToURL:base], *actual = [oursRelative URLRelativeToURL:base];
            check(same(expected.absoluteString, actual.absoluteString) && same(expected.relativeString, actual.relativeString) && same(expected.baseURL, actual.baseURL),
                  @"URLRelativeToURL", [NSString stringWithFormat:@"%@ against %@ -> %@, expected %@", reference, baseText, actual.absoluteString, expected.absoluteString]);
            expect(@"resolve", @[baseText, reference, url.absoluteString, yes, no, value(expected.absoluteString)]);
        }
    }
    check([[Ours() componentsWithString:@"../g"] URLRelativeToURL:nil].baseURL == nil, @"URLRelativeToURL", @"nil base");
    check([Ours() componentsWithURL:(NSURL *)nil resolvingAgainstBaseURL:YES] == nil, @"resolve", @"nil URL returns nil");
}

static void testQueryItems(void)
{
    NSArray *pieces = @[@"a", @"=", @"&", @"+", @"%41", @"%26", @"%3D", @"%FF", @"%C3%A9", @"?", @"/", @":", @"@", @"%20", @"b"];
    NSMutableArray *queries = [NSMutableArray arrayWithArray:@[@"", @"&", @"a", @"a=", @"=b", @"a=b=c", @"a&&b", @"a+b=c+d", @"%FF=1", @"a=%FF", @"%41=%42", @"==", @"&=&"]];
    for (int index = 0; index < 4000; index++)
        [queries addObject:randomString(pieces, 8)];
    NSUInteger index = 0;
    for (NSString *query in queries) {
        NSURLComponents *system = [NSURLComponents new], *ours = [Ours() new];
        system.percentEncodedQuery = query;
        ours.percentEncodedQuery = query;
        check(same(itemsOf(system.queryItems), itemsOf(ours.queryItems)), @"queryItems", [NSString stringWithFormat:@"%@ -> %@, expected %@", query, itemsOf(ours.queryItems), itemsOf(system.queryItems)]);
        if (index++ < 13 || index % 20 == 0)
            expect(@"queryGet", @[query, itemsOf(system.queryItems)]);
    }
    NSURLComponents *none = [Ours() new];
    check(none.queryItems == nil, @"queryItems", @"no query gives nil");
    NSArray *names = @[@"a", @"", @"a&=b+ #?/", @"\u00E9", @"%", @"a b", @";,", @"\U0001F600", @"[]"];
    NSArray *values = @[[NSNull null], @"", @"c&=d+ #?/\u00E9", @"x=y&z", @"%41", @"+"];
    NSMutableArray *lists = [NSMutableArray arrayWithObject:@[]];
    for (NSString *name in names)
        for (id item in values)
            [lists addObject:@[@[name, item]]];
    for (int count = 0; count < 300; count++) {
        NSMutableArray *list = [NSMutableArray array];
        uint32_t length = randomNumber(4) + 1;
        for (uint32_t item = 0; item < length; item++)
            [list addObject:@[names[randomNumber((uint32_t)names.count)], values[randomNumber((uint32_t)values.count)]]];
        [lists addObject:list];
    }
    for (NSArray *list in lists) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSArray *pair in list)
            [items addObject:[NSURLQueryItem queryItemWithName:pair[0] value:textOf(pair[1])]];
        NSURLComponents *system = [NSURLComponents componentsWithString:@"http://h/"], *ours = [Ours() componentsWithString:@"http://h/"];
        system.queryItems = items;
        ours.queryItems = items;
        check(same(system.percentEncodedQuery, ours.percentEncodedQuery) && same(system.string, ours.string), @"setQueryItems", [NSString stringWithFormat:@"%@ -> %@, expected %@", list, ours.percentEncodedQuery, system.percentEncodedQuery]);
        check(same(itemsOf(system.queryItems), itemsOf(ours.queryItems)), @"setQueryItems", [NSString stringWithFormat:@"%@ round trip %@", list, itemsOf(ours.queryItems)]);
        expect(@"querySet", @[list, value(system.percentEncodedQuery), itemsOf(system.queryItems)]);
    }
    NSURLComponents *ours = [Ours() componentsWithString:@"http://h/?a"];
    ours.queryItems = nil;
    check(ours.percentEncodedQuery == nil && [ours.string isEqualToString:@"http://h/"], @"setQueryItems", @"nil removes the query");
}

static void testObject(void)
{
    NSURLComponents *first = [Ours() componentsWithString:@"http://u:p@h:8/p?q#f"];
    NSURLComponents *copy = [first copy];
    check(copy != first && [copy isKindOfClass:Ours()] && [copy isEqual:first] && copy.hash == first.hash, @"object", @"copy is an equal, separate object");
    copy.host = @"other";
    check([first.host isEqualToString:@"h"] && ![copy isEqual:first], @"object", @"changing the copy leaves the original");
    check(![[Ours() componentsWithString:@"http://h/%41"] isEqual:[Ours() componentsWithString:@"http://h/A"]], @"object", @"equality compares percent-encoded components");
    check([[Ours() componentsWithString:@"http://h/p"] isEqual:[Ours() componentsWithString:@"http://h/p"]], @"object", @"equal strings give equal components");
    check(![[Ours() new] isEqual:@"x"] && ![[Ours() new] isEqual:nil], @"object", @"other objects are not equal");
    check([[Ours() new] isEqual:[Ours() new]], @"object", @"empty components are equal");
    NSString *description = first.description;
    NSString *pattern = @"^<CharonHostNSURLComponents 0x[0-9a-f]+> \\{scheme = http, user = u, password = p, host = h, port = 8, path = /p, query = q, fragment = f\\}$";
    check([description rangeOfString:pattern options:NSRegularExpressionSearch].location == 0, @"object", description);
    observe(@"-description: macOS 27 prints the URL string, the backport prints the iOS 7-9 component list", [[NSURLComponents componentsWithString:@"http://u:p@h:8/p?q#f"] description]);
    NSURLComponents *encodedHost = [Ours() new], *systemEncodedHost = [NSURLComponents new];
    encodedHost.percentEncodedHost = systemEncodedHost.percentEncodedHost = @"%41";
    check([encodedHost.string isEqualToString:@"//%41"], @"object", @"percent-encoded host is kept as written");
    observe(@"-string: macOS 27 decodes percent-encoded unreserved characters in a host set with setPercentEncodedHost:", systemEncodedHost.string);
    NSURLComponents *host = [Ours() new];
    host.host = @"\u00E9.com";
    check([host.string isEqualToString:@"//%C3%A9.com"], @"object", [NSString stringWithFormat:@"non-ASCII host stays percent-encoded: %@", host.string]);
    NSURLComponents *systemHost = [NSURLComponents new];
    systemHost.host = @"\u00E9.com";
    observe(@"-string: macOS 27 converts a non-ASCII host to IDNA (punycode), iOS 7-9 keep it percent-encoded", systemHost.string);
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        expectations = [NSMutableDictionary dictionary];
        failuresBySection = [NSCountedSet set];
        divergences = [NSMutableDictionary dictionary];
        testSets();
        printf("sets checks=%d failures=%d\n", checks, failures);
        testEncoding();
        printf("encoding checks=%d failures=%d\n", checks, failures);
        testDecoding();
        printf("decoding checks=%d failures=%d\n", checks, failures);
        testParsing();
        printf("parsing checks=%d failures=%d\n", checks, failures);
        testSetters();
        testEncodedSetters();
        testScheme();
        testPorts();
        printf("setters checks=%d failures=%d\n", checks, failures);
        testComposition();
        printf("composition checks=%d failures=%d\n", checks, failures);
        testResolution();
        testQueryItems();
        testObject();
        printf("divergences between macOS 27 and the iOS 7-9 behaviour the backport follows:\n");
        for (NSString *kind in [divergences.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([kind hasSuffix:@" (count)"])
                continue;
            printf("  %s: %ld case(s), e.g. %s\n", kind.UTF8String, (long)[divergences[[kind stringByAppendingString:@" (count)"]] integerValue],
                   [[divergences[kind] componentsJoinedByString:@" | "] UTF8String]);
        }
        if (argc > 1) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:expectations options:NSJSONWritingSortedKeys error:NULL];
            [data writeToFile:@(argv[1]) atomically:YES];
            NSMutableArray *sizes = [NSMutableArray array];
            for (NSString *section in [expectations.allKeys sortedArrayUsingSelector:@selector(compare:)])
                [sizes addObject:[NSString stringWithFormat:@"%@=%lu", section, (unsigned long)[expectations[section] count]]];
            printf("expectations %s (%lu bytes): %s\n", argv[1], (unsigned long)data.length, [sizes componentsJoinedByString:@" "].UTF8String);
        }
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
