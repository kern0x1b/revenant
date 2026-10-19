#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// The port under a name of its own (CharonHostNSJSONSerialization) against the host's own NSJSONSerialization, on the
// same inputs. Every comparison is between what the two produced for one input, not between a recorded answer.
@interface CharonHostNSJSONSerialization : NSObject
+ (BOOL)isValidJSONObject:(id)obj;
+ (nullable NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error;
+ (nullable id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error;
+ (NSInteger)writeJSONObject:(id)obj toStream:(NSOutputStream *)stream options:(NSJSONWritingOptions)opt error:(NSError **)error;
+ (nullable id)JSONObjectWithStream:(NSInputStream *)stream options:(NSJSONReadingOptions)opt error:(NSError **)error;
@end

static int failures;
static int checks;

// Two answers that may both be absent, compared as such (sending a message to nil is not a comparison).
static BOOL sameText(NSString *ours, NSString *theirs)
{
    if ((ours == nil) != (theirs == nil))
        return NO;
    return ours == nil || [ours isEqualToString:theirs];
}

static void expect(BOOL ok, NSString *what, NSString *detail)
{
    checks++;
    if (ok)
        return;
    failures++;
    printf("FAIL %s: %s\n", what.UTF8String, detail.UTF8String);
}

// What a failed parse is: the reason the host words it with, without the " around line L, column C." it appends, and
// the index it carries. Returns nil for a parse that succeeded.
static NSString *reason(NSError *error)
{
    if (!error)
        return nil;
    NSString *debug = error.userInfo[NSDebugDescriptionErrorKey];
    NSRange at = [debug rangeOfString:@" around line "];
    NSString *text = at.location == NSNotFound ? debug : [debug substringToIndex:at.location];
    NSNumber *index = error.userInfo[@"NSJSONSerializationErrorIndex"];
    return [NSString stringWithFormat:@"%@ [%@ %@ %@]", text, error.domain, @(error.code),
            index ? [index stringValue] : @"no-index"];
}

static NSString *position(NSError *error)
{
    NSString *debug = error.userInfo[NSDebugDescriptionErrorKey];
    NSRange at = [debug rangeOfString:@" around line "];
    return at.location == NSNotFound ? @"no-position" : [debug substringFromIndex:at.location];
}

static NSError *withoutIndex(NSError *error)
{
    if (!error)
        return nil;
    NSMutableDictionary *info = [error.userInfo mutableCopy] ?: [NSMutableDictionary dictionary];
    [info removeObjectForKey:@"NSJSONSerializationErrorIndex"];
    return [NSError errorWithDomain:error.domain code:error.code userInfo:info];
}

// The two answers of one reading, compared where they can be and named where they cannot. comparePosition and
// compareIndex are off only for the one failure whose position and index are an internal offset of the host (the
// nesting limit, see run.sh); its wording and whether it happens at all are still compared.
static void expectSameNumbers(id ours, id theirs, NSString *what);

static void sameReadIn(NSString *what, NSData *data, NSJSONReadingOptions opt, BOOL comparePosition, BOOL compareIndex)
{
    NSError *ours = nil, *theirs = nil;
    id mine = [CharonHostNSJSONSerialization JSONObjectWithData:data options:opt error:&ours];
    id host = [NSJSONSerialization JSONObjectWithData:data options:opt error:&theirs];
    if (!compareIndex) {
        ours = withoutIndex(ours);
        theirs = withoutIndex(theirs);
    }
    NSString *ourReason = reason(ours), *theirReason = reason(theirs);
    // The two sides are compared on the reason where they refused and on the value where they read,
    // and neither comparison may be skipped for the other: returning as soon as either side had an
    // answer made every comparison below unreachable in the one case where a value exists - a read-side
    // change that is not also a round-trip write case, a repeated key keeping the other value, an
    // integer coming back as a decimal, a container coming back mutable unasked, was green.
    expect((ourReason == nil) == (theirReason == nil), what,
           [NSString stringWithFormat:@"ours %@, host %@", ourReason ?: @"ok", theirReason ?: @"ok"]);
    if (ourReason == nil && theirReason == nil)
        goto read;
    if ((ourReason == nil) != (theirReason == nil)) {
        expect(NO, what, [NSString stringWithFormat:@"one side read it and the other did not: ours %@, host %@",
                          ourReason ?: @"ok", theirReason ?: @"ok"]);
        return;
    }
    if ([ourReason isEqualToString:theirReason]) {
        if (comparePosition)
            expect([position(ours) isEqualToString:position(theirs)], what,
                   [NSString stringWithFormat:@"position ours %@, host %@", position(ours), position(theirs)]);
    } else {
        expect(NO, what, [NSString stringWithFormat:@"ours %@, host %@", ourReason, theirReason]);
        return;
    }
    expect((mine == nil) == (ourReason != nil), what, @"a result that is not the failure the reason says");
    return;
read:
    expect((mine == nil) == (ourReason != nil), what, @"a result that is not the failure the reason says");
    if (mine == nil || host == nil)
        return;
    expect([mine isEqual:host], what, [NSString stringWithFormat:@"ours %@, host %@", mine, host]);
    // Equality alone would not see a container that came back mutable when the caller did not ask for one.
    expect([mine isKindOfClass:[NSMutableArray class]] == [host isKindOfClass:[NSMutableArray class]] &&
           [mine isKindOfClass:[NSMutableDictionary class]] == [host isKindOfClass:[NSMutableDictionary class]],
           what, @"container mutability");
    NSArray *ourElements = [mine isKindOfClass:[NSArray class]] ? mine : nil;
    NSArray *theirElements = [host isKindOfClass:[NSArray class]] ? host : nil;
    if (ourElements && theirElements && ourElements.count == theirElements.count)
        for (NSUInteger i = 0; i < ourElements.count; i++)
            expect([ourElements[i] isEqual:theirElements[i]], what,
                   [NSString stringWithFormat:@"element %lu: ours %@, host %@", (unsigned long)i,
                    ourElements[i], theirElements[i]]);
    // The class of a number is part of the answer: a long long, an unsigned long long, a double and an
    // NSDecimalNumber are four different answers to the same literal, and a caller asks
    // [n isKindOfClass:[NSDecimalNumber class]] or strcmp([n objCType], "i") of it. The comparison is
    // made wherever both sides are numbers and it does not go behind a value comparison, which is what
    // left it unreachable: a literal that came back as a decimal where the host's is a long long is
    // [isEqual:] to it, and every earlier version of this check sat inside a !CFEqual guard. The
    // elements of a nested container are walked too, not only those of a single-element array.
    expectSameNumbers(mine, host, what);
}

static void expectSameNumbers(id ours, id theirs, NSString *what)
{
    if ([ours isKindOfClass:[NSNumber class]] && [theirs isKindOfClass:[NSNumber class]]) {
        // A boolean is a number to isKindOfClass: and its class and its type are its own.
        const char *ta = [ours isKindOfClass:[NSDecimalNumber class]] ? "dec" : [ours objCType];
        const char *tb = [theirs isKindOfClass:[NSDecimalNumber class]] ? "dec" : [theirs objCType];
        expect(strcmp(ta, tb) == 0 && [[ours description] isEqualToString:[theirs description]], what,
               [NSString stringWithFormat:@"number ours %s %@, host %s %@", ta, [ours description], tb, [theirs description]]);
        return;
    }
    BOOL oursArray = [ours isKindOfClass:[NSArray class]], theirsArray = [theirs isKindOfClass:[NSArray class]];
    if (oursArray && theirsArray) {
        NSArray *a = ours, *b = theirs;
        if (a.count != b.count)
            return;
        for (NSUInteger index = 0; index < a.count; index++)
            expectSameNumbers(a[index], b[index], what);
        return;
    }
    BOOL oursDict = [ours isKindOfClass:[NSDictionary class]], theirsDict = [theirs isKindOfClass:[NSDictionary class]];
    if (oursDict && theirsDict) {
        NSDictionary *a = ours, *b = theirs;
        if (a.count != b.count)
            return;
        for (id key in a)
            if (b[key])
                expectSameNumbers(a[key], b[key], what);
    }
}

static void sameRead(NSString *what, NSData *data, NSJSONReadingOptions opt, BOOL comparePosition)
{
    sameReadIn(what, data, opt, comparePosition, YES);
}

static void expectSameNumbers(id ours, id theirs, NSString *what);

static NSData *text(NSString *s) { return [s dataUsingEncoding:NSUTF8StringEncoding]; }

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    NSArray<NSString *> *texts = @[
        @"{}", @"[]", @"{\"a\":1}", @"[1,2,3]", @" \n {\"a\" : [ 1 , 2 ] } \t ",
        @"[1,]", @"{\"a\":1,}", @"[[[[1]]]]", @"{\"a\":{\"b\":{\"c\":[1,2,{\"d\":null}]}}}",
        @"nul", @"1 2", @"1.2.3", @"[1 2]", @"{\"a\"}", @"\"abc", @"tru", @"[truex]", @"[TRUE]", @"[None]",
        @"[\"a\", \"b\\u00e9\\n\\t\"]", @"[\"\\ud83d\\ude00\"]", @"[\"\\ud83d\"]", @"[\"\\ude00\"]",
        @"[\"\\x41\"]", @"[\"\\0\"]", @"[\"a\\\nb\"]", @"[\"\\' \"]", @"[\"\\u00zz\"]", @"[\"a", @"[\"a\nb\"]", @"[\"\\u00\"]", @"[\"\\u\"]", @"[\"\\u0\"]",
        @"[", @"{", @"{\"a\"", @"{\"a\":", @"{\"a\":1", @"[1", @"  {  ", @"\n\n{", @"{\"a\":[1", @"   ", @"\n",
        @"[1] 2", @"{\"a\":1} x", @"[1,2,,3]", @"{,}", @"[:]", @"{:1}", @"{\"a\"::1}", @"[[]", @"{]",
        @"[1,2}", @"{\"a\":1]", @"}", @"]", @",", @":", @"@", @"\t\t\t",
        @"[0]", @"[-0]", @"[1]", @"[1.0]", @"[1.5]", @"[0.1]", @"[12345678901234567890]", @"[18446744073709551615]",
        @"[18446744073709551616]", @"[1.2345678901234567]", @"[1.23456789012345678]", @"[1.2345678901234567890123]",
        @"[1e10]", @"[1e400]", @"[-1e400]", @"[1e-400]", @"[-1e-400]", @"[0.30000000000000004]",
        @"[1.0000000000000000000000001]", @"[100000000000000000000]", @"[1.5e3]", @"[0001]", @"[00]", @"[-]",
        @"[0.0000000000000000000001]", @"[1234567890123456.7]", @"[12345678901234567.8]", @"[9223372036854775808]",
        @"[-9223372036854775809]", @"[1.7976931348623157e308]", @"[1.8e308]", @"[1e308]", @"[1e309]", @"[1e327]",
        @"[1.0e0]", @"[1.5E+3]", @"[1.5e]", @"[1e+]", @"[1.8e308]", @"[0e999999]", @"[1e1000]", @"[1e-1000]",
        @"[1e-999]", @"[1e-0999]", @"[1e-099]", @"[1e-0099]", @"[1e-00]", @"[1e-0001]", @"[1e0000]", @"[1e-0]",
        @"[1.2.3]", @"[12e400]", @"[-1e999]", @"[1.5e-1000]", @"[0.1e1]", @"[123]", @"[1.]", @"[1.0]",
    ];
    for (NSString *t in texts) {
        sameRead([@"opt 0 " stringByAppendingString:t], text(t), 0, YES);
        sameRead([@"fragments " stringByAppendingString:t], text(t), NSJSONReadingFragmentsAllowed, YES);
        sameRead([@"mutable " stringByAppendingString:t], text(t), NSJSONReadingMutableContainers, YES);
        sameRead([@"leaves " stringByAppendingString:t], text(t), NSJSONReadingMutableLeaves, YES);
        sameRead([@"json5 " stringByAppendingString:t], text(t), NSJSONReadingJSON5Allowed, YES);
        sameRead([@"json5+assume " stringByAppendingString:t], text(t),
                 NSJSONReadingJSON5Allowed | NSJSONReadingTopLevelDictionaryAssumed, YES);
        sameRead([@"assume " stringByAppendingString:t], text(t), NSJSONReadingTopLevelDictionaryAssumed, YES);
        sameRead([@"deprecated alias " stringByAppendingString:t], text(t), NSJSONReadingAllowFragments, YES);
    }

    // json5's own grammar, where the same text means two different things with and without the option
    for (NSString *t in @[@"{a:1, /*c*/ b:'x',}", @"[+1, 0x10, .5]", @"[NaN, Infinity, -Infinity]",
                          @"{//c\n a:1}", @"['a':1]", @"[.5]", @"[01]", @"[1_000]", @"[+]", @"[0x]", @"[-1]",
                          @"[1.]", @"['a' \"b\"]", @"[\\/]", @"[Infinityx]", @"[+Infinity]", @"[-Infinity]",
                          @"[0X10]", @"[/*x", @"{a:1,/*x", @"{a:1 b:2}", @"{a:}", @"{a", @"{",
                          @"[0x1p3]", @"[1e1e1]", @"[--1]", @"[1..2]", @"[a:1]", @"[1 /*c", @"{/*c"])
    {
        sameRead([@"json5 " stringByAppendingString:t], text(t), NSJSONReadingJSON5Allowed, YES);
        sameRead([@"opt 0 " stringByAppendingString:t], text(t), 0, YES);
    }

    // NSJSONReadingTopLevelDictionaryAssumed, whose text is the body of an object
    for (NSString *t in @[@"", @" ", @"[1,2]", @"{a:1}", @"{'a':1}", @"1", @"a:1,",
                          @"a:1 b:2", @"null", @"a:", @"a", @"a:1", @"{\"a\":1}", @"{\"a\":1,}", @"{,}",
                          @"a:1, b:2,", @"  a:1  ", @"[", @"{\"a\":{\"b\":1}}", @"a:[1]", @"a:{b:1}"])
    {
        sameRead([@"assume " stringByAppendingString:t], text(t), NSJSONReadingTopLevelDictionaryAssumed, YES);
        sameRead([@"json5+assume " stringByAppendingString:t], text(t),
                 NSJSONReadingJSON5Allowed | NSJSONReadingTopLevelDictionaryAssumed, YES);
    }

    // A key the object already carries: the host reads the first value and keeps it, and says so for a first value
    // that is null, false, 0 or the empty string, so this is a test for the key and not for the value.
    for (NSString *t in @[@"{\"a\":1,\"a\":2}", @"{\"a\":1,\"a\":2,\"a\":3}", @"{\"b\":0,\"a\":1,\"b\":2}",
                          @"{\"a\":{\"b\":1,\"b\":2}}", @"{\"\":1,\"\":2}", @"{\"a\":null,\"a\":1}",
                          @"{\"a\":[1],\"a\":[2]}", @"{\"a\":1,\"a\":false}", @"{\"a\":{\"x\":1},\"a\":1}",
                          @"{\"a\":false,\"a\":1}", @"{\"a\":0,\"a\":1}", @"{\"a\":\"\",\"a\":\"x\"}",
                          @"{\"a\":1.0,\"a\":2.0}", @"{\"a\":true,\"a\":false}", @"{\"a\":1,\"a\":null}",
                          @"[{\"a\":1,\"a\":2}]", @"{\"a\":[{\"b\":1,\"b\":2},{\"c\":1,\"c\":2}]}"])
    {
        sameRead([@"repeat opt 0 " stringByAppendingString:t], text(t), 0, YES);
        sameRead([@"repeat fragments " stringByAppendingString:t], text(t), NSJSONReadingFragmentsAllowed, YES);
        sameRead([@"repeat mutable " stringByAppendingString:t], text(t), NSJSONReadingMutableContainers, YES);
        sameRead([@"repeat leaves " stringByAppendingString:t], text(t), NSJSONReadingMutableLeaves, YES);
        sameRead([@"repeat json5 " stringByAppendingString:t], text(t), NSJSONReadingJSON5Allowed, YES);
    }
    for (NSString *t in @[@"{a:1,a:2}", @"{a:1, a:2}", @"{'a':1,a:2}", @"{a:1,a:2,a:3}"]) {
        sameRead([@"repeat json5 " stringByAppendingString:t], text(t), NSJSONReadingJSON5Allowed, YES);
    }

    // The exponent field is a field and not a value: three digits are read under any sign, four are read only without
    // one, and five or more are refused however small the value. The overflow of the value is a separate matter and
    // both sides already hold it (1e309 is refused, 1e-309 is a 0).
    for (NSString *field in @[@"e0", @"e1", @"e9", @"e99", @"e300", @"e308", @"e309", @"e999",
                              @"e-0", @"e-1", @"e-9", @"e-99", @"e-300", @"e-308", @"e-309", @"e-999", @"e-400",
                              @"e+0", @"e+1", @"e+9", @"e+99", @"e+300", @"e+309", @"e+999",
                              @"e0000", @"e0001", @"e0009", @"e0010", @"e0099", @"e0100", @"e0123", @"e0200", @"e0300",
                              @"e0308", @"e0309", @"e0400", @"e0001", @"e0011", @"e0099", @"e0101", @"e0110", @"e0123",
                              @"e-0000", @"e-0001", @"e-0010", @"e-0100", @"e-0300", @"e-0309",
                              @"e+0000", @"e+0001", @"e+0010", @"e+0100", @"e+0309",
                              @"e00000", @"e000000", @"e0000000", @"e00000000", @"e000000000", @"e0000000000",
                              @"e-00000", @"e+00000", @"E1", @"E0001", @"E00000", @"E-1", @"E+1"])
    {
        for (NSString *mantissa in @[@"1", @"1.5", @"0", @"0.0", @"0.00001", @"12345", @"10", @"-1"]) {
            NSString *t = [NSString stringWithFormat:@"[%@%@]", mantissa, field];
            sameRead([@"exponent " stringByAppendingString:t], text(t), NSJSONReadingFragmentsAllowed, YES);
        }
        for (NSString *tail in @[@"e1", @".5", @",", @"x", @"e00000e1"]) {
            NSString *t = [NSString stringWithFormat:@"[1%@%@]", field, tail];
            sameRead([@"exponent tail " stringByAppendingString:t], text(t), NSJSONReadingFragmentsAllowed, YES);
        }
        NSString *top = [NSString stringWithFormat:@"1%@", field];
        sameRead([@"exponent top " stringByAppendingString:top], text(top), NSJSONReadingFragmentsAllowed, YES);
        sameRead([@"exponent opt 0 " stringByAppendingString:top], text(top), 0, YES);
    }

    // A JSON5 container whose only content is a comment is the empty container: the emptiness test has to skip
    // comments the way the rest of the reader does, not whitespace alone.
    // A backslash before a line terminator, the one rule whose shape depends on what follows it: a lone
    // CR and a lone LF are one newline each, a CRLF pair is one while anything follows it and two where
    // it ends the string, and without JSON5 the pair is a continuation whose LF is then refused as the
    // unescaped control character it is (measured on both sides).
    for (NSString *t in @[@"[\"a\\\r\nb\"]", @"[\"a\\\r\n\"]", @"[\"\\\r\n\"]", @"[\"\\\r\nb\"]",
                          @"[\"a\\\rb\"]", @"[\"a\\\r\"]", @"[\"\\\rb\"]", @"[\"\\\r\"]",
                          @"[\"a\\\nb\"]", @"[\"a\\\n\"]", @"[\"\\\n\"]", @"[\"a\\\r\nbb\"]",
                          @"[\"\\\r\n\",\"x\"]", @"[\"a\\\r\n\",1]"])
    {
        sameRead([@"crlf json5 " stringByAppendingString:t], text(t), NSJSONReadingJSON5Allowed, YES);
        sameRead([@"crlf opt 0 " stringByAppendingString:t], text(t), 0, YES);
    }
    for (NSString *t in @[@"[/*c*/]", @"{/*c*/}", @"[ //c\n]", @"{ //c\n}", @"[/****/]", @"[/*a*//*b*/]",
                          @"[/*c*/\n]", @"{/*c*/\n}", @"[/*c*/1]", @"{/*c*/\"a\":1}", @"[/**/]",
                          @"/*c*/[1]", @"[/*c*/*/]", @"{/*a*/ /*b*/}"])
    {
        sameRead([@"comment only json5 " stringByAppendingString:t], text(t), NSJSONReadingJSON5Allowed, YES);
        sameRead([@"comment only opt 0 " stringByAppendingString:t], text(t), 0, YES);
    }
    for (NSString *t in @[@"/*c*/", @"//c\n", @"[/*c*/]", @"/*c*/ ", @"/*a*//*b*/"]) {
        sameRead([@"comment only body " stringByAppendingString:t], text(t),
                 NSJSONReadingJSON5Allowed | NSJSONReadingTopLevelDictionaryAssumed, YES);
        sameRead([@"comment only body alone " stringByAppendingString:t], text(t), NSJSONReadingTopLevelDictionaryAssumed, YES);
    }
    // The one divergence the facts name, pinned rather than passed over: a body of an assumed top level object whose
    // key is followed by "=" and not by ":" is where the port and the host part company, and both answers are held
    // here so that a change in either is a failure. Both refuse, so no caller reads a different value.
    for (NSString *t in @[@"a=1", @"a=1;b=2", @"a=\"x\"", @"/*c*/a=1", @"//c\na=1"]) {
        NSData *data = text(t);
        NSError *ours = nil, *theirs = nil;
        id mine = [CharonHostNSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingJSON5Allowed | NSJSONReadingTopLevelDictionaryAssumed
                                                               error:&ours];
        id host = [NSJSONSerialization JSONObjectWithData:data
                                                  options:NSJSONReadingJSON5Allowed | NSJSONReadingTopLevelDictionaryAssumed
                                                    error:&theirs];
        NSString *what = [NSString stringWithFormat:@"declared divergence %@", t];
        expect(mine == nil && host == nil
                   && [ours.userInfo[NSDebugDescriptionErrorKey] hasPrefix:@"No value for key in object"]
                   && [theirs.userInfo[NSDebugDescriptionErrorKey] hasPrefix:@"Unterminated string"]
                   && ours.code == theirs.code, what,
               [NSString stringWithFormat:@"ours %@ / %@, host %@ / %@", mine,
                ours.userInfo[NSDebugDescriptionErrorKey], host, theirs.userInfo[NSDebugDescriptionErrorKey]]);
    }

    // how deep a container may be: the wording and the verdict are compared, the position is not (see run.sh)
    for (int n = 510; n <= 515; n++) {
        NSMutableString *open = [NSMutableString string], *empty = [NSMutableString string], *full = [NSMutableString string];
        for (int i = 0; i < n; i++) { [open appendString:@"["]; [empty appendString:@"]"]; [full appendString:@"]"]; }
        NSString *e = [NSString stringWithFormat:@"%@%@", open, empty];
        NSString *f = [NSString stringWithFormat:@"%@1%@", open, empty];
        NSMutableString *dopen = [NSMutableString string], *dclose = [NSMutableString string];
        for (int i = 0; i < n; i++) { [dopen appendString:@"{\"a\":"]; [dclose appendString:@"}"]; }
        (void)full;
        sameReadIn([NSString stringWithFormat:@"depth %d empty", n], text(e), 0, NO, NO);
        sameReadIn([NSString stringWithFormat:@"depth %d full", n], text(f), 0, NO, NO);
        sameReadIn([NSString stringWithFormat:@"depth %d dicts", n],
                   text([NSString stringWithFormat:@"%@1%@", dopen, dclose]), 0, NO, NO);
    }

    // the five encodings the header documents, with and without their mark, and text that is none of them
    {
        NSString *doc = @"{\"k\":\"héllo\"}";
        struct { const char *name; NSStringEncoding enc; int bom; const unsigned char *mark; } cases[] = {
            {"utf8", NSUTF8StringEncoding, 3, (const unsigned char *)"\xef\xbb\xbf"},
            {"utf16le", NSUTF16LittleEndianStringEncoding, 2, (const unsigned char *)"\xff\xfe"},
            {"utf16be", NSUTF16BigEndianStringEncoding, 2, (const unsigned char *)"\xfe\xff"},
            {"utf32le", NSUTF32LittleEndianStringEncoding, 4, (const unsigned char *)"\xff\xfe\x00\x00"},
            {"utf32be", NSUTF32BigEndianStringEncoding, 4, (const unsigned char *)"\x00\x00\xfe\xff"},
        };
        for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
            NSData *plain = [doc dataUsingEncoding:cases[i].enc];
            NSMutableData *withMark = [NSMutableData dataWithBytes:cases[i].mark length:(NSUInteger)cases[i].bom];
            [withMark appendData:plain];
            sameRead([NSString stringWithFormat:@"%s without its mark", cases[i].name], plain, 0, YES);
            sameRead([NSString stringWithFormat:@"%s with its mark", cases[i].name], withMark, 0, YES);
        }
        const unsigned char utf32be[] = {0x00, 0x00, 0x00, 0x7b, 0x00, 0x00, 0x00, 0x7d};
        const unsigned char utf32le[] = {0x7b, 0x00, 0x00, 0x00, 0x7d, 0x00, 0x00, 0x00};
        const unsigned char utf16le[] = {0x7b, 0x00, 0x5b, 0x00, 0x5d, 0x00, 0x7d, 0x00};
        const unsigned char utf16be[] = {0x00, 0x7b, 0x00, 0x5b, 0x00, 0x5d, 0x00, 0x7d};
        const unsigned char broken[] = {'[', '"', 0xff, 0xfe, '"', ']'};
        const unsigned char latin[] = {'[', '"', 'a', 0xe9, '"', ']'};
        sameRead(@"utf32be without a mark", [NSData dataWithBytes:utf32be length:8], 0, YES);
        sameRead(@"utf32le without a mark", [NSData dataWithBytes:utf32le length:8], 0, YES);
        sameRead(@"utf16le without a mark", [NSData dataWithBytes:utf16le length:8], 0, YES);
        sameRead(@"utf16be without a mark", [NSData dataWithBytes:utf16be length:8], 0, YES);
        sameRead(@"bytes that are not text", [NSData dataWithBytes:broken length:6], 0, YES);
        sameRead(@"latin-1 bytes", [NSData dataWithBytes:latin length:5], 0, YES);
    }

    // +isValidJSONObject:
    for (id v in @[@"s", @1, [NSNull null], @[@1], @{}, @{@"a": @1}, @[@(NAN)], @[@(INFINITY)], @[@(-INFINITY)],
                   [NSDictionary dictionaryWithObject:@1 forKey:@2], [NSDecimalNumber notANumber], [NSObject new],
                   @[[NSObject new]], @[@{@"a": [NSObject new]}], @[@[[NSObject new]]],
                   [NSDecimalNumber decimalNumberWithString:@"1.5"], @[@(YES)], @[@(1.0)], @[@"x"]])
    {
        BOOL ours = [CharonHostNSJSONSerialization isValidJSONObject:v];
        BOOL theirs = [NSJSONSerialization isValidJSONObject:v];
        expect(ours == theirs, [NSString stringWithFormat:@"isValidJSONObject %@", v],
               [NSString stringWithFormat:@"ours %d, host %d", ours, theirs]);
    }

    // +dataWithJSONObject:options:error: - the text is compared exactly wherever the order of keys is the caller's to
    // choose (sorted, pretty, or a single key), and by parsing it back where it is not.
    NSMutableString *escapes = [NSMutableString stringWithString:@"s/las\\h\"x\ny\rz\t\b\f"];
    [escapes appendFormat:@"%C%C%C", (unichar)0x01, (unichar)0x1F, (unichar)0x7F];
    NSArray *written = @[@{}, @[], @[@1, @2], @[@"x"], @{@"a": @1}, @{@"a": @1, @"b": @2, @"c": @3},
                         @{@"a": @{@"b": @1}}, @[@[@1]], @[@(YES), @(NO)], [NSNull null], @[@(0.1)], @[@(1.0)],
                         @[@(1.0 / 3.0)], @[@(1e30)], @[@(1e-7)], @[@(1e20)], @[@(-0.0)], @[@((float)0.1)],
                         @[@(18446744073709551615ULL)], @[@(-9223372036854775807LL - 1)], @[@(3.0)],
                         @[escapes], @[@"a/b"], @[@1, @"two", @YES, [NSNull null]],
                         [NSDecimalNumber decimalNumberWithString:@"1.5"],
                         [NSDecimalNumber decimalNumberWithString:@"123456789012345678901234567890"],
                         [NSArray array], [NSDictionary dictionary],
                         [NSArray arrayWithObject:[NSArray array]],
                         [NSArray arrayWithObject:[NSDictionary dictionary]],
                         @[@[], @{}], @{@"a": [NSArray array]}, @{@"a": [NSDictionary dictionary]},
                         @[[NSDecimalNumber notANumber]], @{@"k": [NSDecimalNumber notANumber]},
                         @[@[[NSDecimalNumber notANumber]]],
                         [NSDecimalNumber notANumber],
                         [NSDecimalNumber decimalNumberWithMantissa:1 exponent:400 isNegative:NO],
                         [NSDecimalNumber decimalNumberWithMantissa:1 exponent:-400 isNegative:NO]];
    for (id v in written) {
        for (NSNumber *opt in @[@(0), @(NSJSONWritingPrettyPrinted), @(NSJSONWritingSortedKeys),
                                @(NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted),
                                @(NSJSONWritingWithoutEscapingSlashes), @(NSJSONWritingFragmentsAllowed)]) {
            NSJSONWritingOptions o = (NSJSONWritingOptions)opt.unsignedIntegerValue;
            NSError *ours = nil, *theirs = nil;
            NSData *mine = nil, *host = nil;
            NSString *ourThrow = nil, *theirThrow = nil;
            @try { mine = [CharonHostNSJSONSerialization dataWithJSONObject:v options:o error:&ours]; }
            @catch (NSException *e) { ourThrow = [NSString stringWithFormat:@"%@ %@", e.name, e.reason]; }
            @try { host = [NSJSONSerialization dataWithJSONObject:v options:o error:&theirs]; }
            @catch (NSException *e) { theirThrow = [NSString stringWithFormat:@"%@ %@", e.name, e.reason]; }
            NSString *what = [NSString stringWithFormat:@"write %@ options %@", v, opt];
            expect(sameText(ourThrow, theirThrow) && ((mine == nil) == (host == nil)), what,
                   [NSString stringWithFormat:@"ours %@ %@, host %@ %@", ourThrow, mine, theirThrow, host]);
            if (!mine || !host)
                continue;
            NSString *ourText = [[NSString alloc] initWithData:mine encoding:NSUTF8StringEncoding];
            NSString *theirText = [[NSString alloc] initWithData:host encoding:NSUTF8StringEncoding];
            // A key order nobody asked for is the dictionary's own, so it is compared by what it parses back to.
            BOOL compareText = (o & NSJSONWritingSortedKeys) != 0 || [v isKindOfClass:[NSArray class]] ||
                              ![v isKindOfClass:[NSDictionary class]] ||
                              (o & NSJSONWritingFragmentsAllowed) != 0;
            if (compareText)
                expect([ourText isEqualToString:theirText], what,
                       [NSString stringWithFormat:@"ours %@, host %@", ourText, theirText]);
            NSError *a = nil, *b = nil;
            id back1 = [CharonHostNSJSONSerialization JSONObjectWithData:mine options:0 error:&a];
            id back2 = [NSJSONSerialization JSONObjectWithData:host options:0 error:&b];
            expect(sameText(reason(a), reason(b)) && (a == nil) == (b == nil) &&
                   (a != nil || [back1 isEqual:back2]), what,
                   [NSString stringWithFormat:@"round trip ours %@ / %@, host %@ / %@", back1, reason(a), back2, reason(b)]);
        }
    }
    // the key order the caller's, spelled out
    {
        NSDictionary *mixed = @{@"B": @1, @"a": @2, @"A": @3, @"b": @4, @"é": @5, @"1": @6, @"_": @7};
        NSError *ours = nil, *theirs = nil;
        NSString *a = [[NSString alloc] initWithData:[CharonHostNSJSONSerialization dataWithJSONObject:mixed options:NSJSONWritingSortedKeys error:&ours] encoding:NSUTF8StringEncoding];
        NSString *b = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:mixed options:NSJSONWritingSortedKeys error:&theirs] encoding:NSUTF8StringEncoding];
        expect([a isEqualToString:b], @"sorted keys", [NSString stringWithFormat:@"ours %@, host %@", a, b]);
    }

    // the exceptions a write raises
    for (id v in @[@"str", @1, [NSNull null], [NSDictionary dictionaryWithObject:@2 forKey:@1], @[@(INFINITY)],
                   @[@(-INFINITY)], @[@(NAN)], [NSObject new], @[@[@[@(INFINITY)]]], @[[NSDictionary dictionaryWithObject:@2 forKey:@1]],
                   @[[NSDecimalNumber notANumber]], @{@"k": [NSDecimalNumber notANumber]},
                   @[@[[NSDecimalNumber notANumber]]], [NSDecimalNumber notANumber]]) {
        NSString *what = [NSString stringWithFormat:@"throw %@", v];
        NSString *ourName = nil, *ourReason = nil, *theirName = nil, *theirReason = nil;
        @try { [CharonHostNSJSONSerialization dataWithJSONObject:v options:NSJSONWritingFragmentsAllowed error:NULL]; }
        @catch (NSException *e) { ourName = e.name; ourReason = e.reason; }
        @try { [NSJSONSerialization dataWithJSONObject:v options:NSJSONWritingFragmentsAllowed error:NULL]; }
        @catch (NSException *e) { theirName = e.name; theirReason = e.reason; }
        expect(sameText(ourName, theirName) && sameText(ourReason, theirReason), what,
               [NSString stringWithFormat:@"ours %@ %@, host %@ %@", ourName, ourReason, theirName, theirReason]);
    }
    for (id v in @[@"str", @1, [NSNull null], @(42)]) {
        NSString *what = [NSString stringWithFormat:@"throw top level %@", v];
        NSString *ourName = nil, *ourReason = nil, *theirName = nil, *theirReason = nil;
        @try { [CharonHostNSJSONSerialization dataWithJSONObject:v options:0 error:NULL]; }
        @catch (NSException *e) { ourName = e.name; ourReason = e.reason; }
        @try { [NSJSONSerialization dataWithJSONObject:v options:0 error:NULL]; }
        @catch (NSException *e) { theirName = e.name; theirReason = e.reason; }
        expect(sameText(ourName, theirName) && sameText(ourReason, theirReason), what,
               [NSString stringWithFormat:@"ours %@ %@, host %@ %@", ourName, ourReason, theirName, theirReason]);
    }
    {
        NSString *ourName = nil, *ourReason = nil, *theirName = nil, *theirReason = nil;
        NSJSONReadingOptions both = NSJSONReadingTopLevelDictionaryAssumed | NSJSONReadingFragmentsAllowed;
        @try { [CharonHostNSJSONSerialization JSONObjectWithData:text(@"[1]") options:both error:NULL]; }
        @catch (NSException *e) { ourName = e.name; ourReason = e.reason; }
        @try { [NSJSONSerialization JSONObjectWithData:text(@"[1]") options:both error:NULL]; }
        @catch (NSException *e) { theirName = e.name; theirReason = e.reason; }
        expect(sameText(ourName, theirName) && sameText(ourReason, theirReason),
               @"throw on both options",
               [NSString stringWithFormat:@"ours %@ %@, host %@ %@", ourName, ourReason, theirName, theirReason]);
    }

    // the two 7.0 stream methods
    {
        NSString *path = @"/tmp/charon-json1-stream.json";
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        NSError *ours = nil, *theirs = nil;
        NSOutputStream *ourOut = [NSOutputStream outputStreamToFileAtPath:path append:NO];
        NSOutputStream *theirOut = [NSOutputStream outputStreamToFileAtPath:path append:NO];
        [ourOut open];
        [theirOut open];
        NSInteger a = [CharonHostNSJSONSerialization writeJSONObject:@{@"a": @1} toStream:ourOut options:0 error:&ours];
        NSInteger b = [NSJSONSerialization writeJSONObject:@{@"a": @1} toStream:theirOut options:0 error:&theirs];
        [ourOut close];
        [theirOut close];
        expect(a == b && sameText(reason(ours), reason(theirs)) && (ours == nil) == (theirs == nil), @"writeJSONObject:toStream:",
               [NSString stringWithFormat:@"ours %ld %@, host %ld %@", (long)a, ours, (long)b, theirs]);
        NSInputStream *ourIn = [NSInputStream inputStreamWithFileAtPath:path];
        NSInputStream *theirIn = [NSInputStream inputStreamWithFileAtPath:path];
        [ourIn open];
        [theirIn open];
        NSError *e1 = nil, *e2 = nil;
        id mine = [CharonHostNSJSONSerialization JSONObjectWithStream:ourIn options:0 error:&e1];
        id host = [NSJSONSerialization JSONObjectWithStream:theirIn options:0 error:&e2];
        [ourIn close];
        [theirIn close];
        expect(sameText(reason(e1), reason(e2)) && (e1 == nil) == (e2 == nil) &&
               (e1 != nil || [mine isEqual:host]), @"JSONObjectWithStream:",
               [NSString stringWithFormat:@"ours %@ %@, host %@ %@", mine, e1, host, e2]);

        NSString *missing = @"/tmp/charon-json1-absent.json";
        [[NSFileManager defaultManager] removeItemAtPath:missing error:NULL];
        NSInputStream *ourMiss = [NSInputStream inputStreamWithFileAtPath:missing];
        NSInputStream *theirMiss = [NSInputStream inputStreamWithFileAtPath:missing];
        [ourMiss open];
        [theirMiss open];
        NSError *f1 = nil, *f2 = nil;
        id m1 = [CharonHostNSJSONSerialization JSONObjectWithStream:ourMiss options:0 error:&f1];
        id m2 = [NSJSONSerialization JSONObjectWithStream:theirMiss options:0 error:&f2];
        expect(m1 == nil && m2 == nil && sameText(reason(f1), reason(f2)), @"JSONObjectWithStream: of nothing",
               [NSString stringWithFormat:@"ours %@ %@, host %@ %@", m1, reason(f1), m2, reason(f2)]);

        NSOutputStream *ourBad = [NSOutputStream outputStreamToFileAtPath:@"/nonexistent-charon-dir/x.json" append:NO];
        NSOutputStream *theirBad = [NSOutputStream outputStreamToFileAtPath:@"/nonexistent-charon-dir/x.json" append:NO];
        [ourBad open];
        [theirBad open];
        NSError *g1 = nil, *g2 = nil;
        NSInteger c = [CharonHostNSJSONSerialization writeJSONObject:@{@"a": @1} toStream:ourBad options:0 error:&g1];
        NSInteger d = [NSJSONSerialization writeJSONObject:@{@"a": @1} toStream:theirBad options:0 error:&g2];
        expect(c == d, @"writeJSONObject:toStream: of nowhere",
               [NSString stringWithFormat:@"ours %ld %@, host %ld %@", (long)c, g1, (long)d, g2]);
        expect(sameText(g1.domain, g2.domain) && g1.code == g2.code &&
               (g1 == nil) == (g2 == nil), @"writeJSONObject:toStream: error",
               [NSString stringWithFormat:@"ours %@, host %@", g1, g2]);
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }

    printf("checks=%d failures=%d\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
