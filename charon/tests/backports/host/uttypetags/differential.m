#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

CFArrayRef CharonPortUTTypeCopyAllTagsWithClass(CFStringRef inUTI, CFStringRef inTagClass);

static NSArray *classes(void)
{
    return @[@"public.filename-extension", @"public.mime-type", @"com.apple.ostype", @"public.pathname", @"com.apple.nspboard-type", @"public.url-name", @"com.apple.nspboard-type.x"];
}

static NSString *encodeBytes(const unsigned char *bytes, NSUInteger count)
{
    static const char alphabet[] = "abcdefghkmnpqrstuvwxyz0123456789";
    NSMutableString *out = [NSMutableString stringWithString:@"dyn.a"];
    unsigned int accumulator = 0;
    int bits = 0;
    for (NSUInteger index = 0; index < count; index++) {
        accumulator = (accumulator << 8) | bytes[index];
        bits += 8;
        while (bits >= 5) {
            bits -= 5;
            [out appendFormat:@"%c", alphabet[(accumulator >> bits) & 31]];
        }
        accumulator &= (1u << bits) - 1;
    }
    if (bits > 0)
        [out appendFormat:@"%c", alphabet[(accumulator << (5 - bits)) & 31]];
    return out;
}

static NSString *encodeText(NSString *text)
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    return encodeBytes(data.bytes, data.length);
}

static NSString *describe(CFArrayRef array)
{
    if (!array)
        return @"NULL";
    NSMutableString *out = [NSMutableString stringWithString:@"["];
    for (id item in (__bridge NSArray *)array) {
        [out appendFormat:@"<%@>", [item isKindOfClass:[NSString class]] ? [item stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] : item];
    }
    [out appendString:@"]"];
    return out;
}

static NSUInteger mismatches = 0;
static NSUInteger cases = 0;

static void compare(NSString *label, NSString *uti, NSString *tagClass)
{
    CFArrayRef host = UTTypeCopyAllTagsWithClass((__bridge CFStringRef)uti, (__bridge CFStringRef)tagClass);
    CFArrayRef port = CharonPortUTTypeCopyAllTagsWithClass((__bridge CFStringRef)uti, (__bridge CFStringRef)tagClass);
    BOOL same = (host == NULL) == (port == NULL) && (host == NULL || CFEqual(host, port));
    cases++;
    if (!same) {
        mismatches++;
        if (mismatches <= 40)
            printf("MISMATCH %s uti=%s class=%s host=%s port=%s\n", [label UTF8String], [uti UTF8String], [tagClass UTF8String], [describe(host) UTF8String], [describe(port) UTF8String]);
    }
    if (host) CFRelease(host);
    if (port) CFRelease(port);
}

static void compareAllClasses(NSString *label, NSString *uti)
{
    for (NSString *tagClass in classes()) compare(label, uti, tagClass);
}

static void compareText(NSString *label, NSString *text)
{
    compareAllClasses(label, encodeText(text));
}

static void compareBytes(NSString *label, const unsigned char *bytes, NSUInteger count)
{
    compareAllClasses(label, encodeBytes(bytes, count));
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        NSArray *declared = @[@"public.jpeg", @"public.png", @"public.plain-text", @"public.mpeg-4", @"com.adobe.pdf",
                              @"public.data", @"public.folder", @"public.item", @"public.url", @"public.image",
                              @"public.movie", @"public.html", @"public.json", @"public.zip-archive", @"public.mp3",
                              @"public.swift-source", @"public.text", @"public.tiff", @"public.content", @"com.example.nonexistent", @""];
        for (NSString *uti in declared) compareAllClasses(@"declared", uti);
        if (argc > 1) {
            NSString *table = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] encoding:NSUTF8StringEncoding error:NULL];
            for (NSString *line in [table componentsSeparatedByString:@"\n"]) {
                NSArray *columns = [line componentsSeparatedByString:@"\t"];
                if (columns.count >= 2) compareAllClasses(@"constant", columns[1]);
            }
        }
        compare(@"declared upper", @"PUBLIC.JPEG", @"public.filename-extension");

        compare(@"writeup", @"dyn.ah62d4r3qkk7dgtpyqz6hkp42fzxhe55cfvy042phqy1zuppgsm10esvvhzxhe55c", @"public.mime-type");
        compareAllClasses(@"writeup multi", @"dyn.ah62d4r3qkk7dgtpyqz6hkp42fzxhe55cfvy042phqy1zuppgsm10esvvhzxhe55c");
        compareAllClasses(@"writeup literal", @"dyn.ah62d4r34qr104pxftbu046dqqy1fg6dfqry0c5cytf2gntpgr710e2pw");
        compareAllClasses(@"writeup borked", @"dyn.ah62d425try1gn8dbrz2g23mskm11e45fqu7gg55rf3w1u2prsb0gnpwxsbw0g4pbrvnhw6dfhzxg855cqf3a");
        compareAllClasses(@"upper body", @"dyn.age80Q6XTQK");
        compareAllClasses(@"upper prefix", @"DYN.age80q6xtqk");
        compareAllClasses(@"mixed prefix", @"Dyn.age80q6xtqk");
        compareAllClasses(@"upper format letter", @"DYN.AGE80Q6XTQK");
        compareAllClasses(@"format b", @"dyn.bge80q6xtqk");
        compareAllClasses(@"bad digit", @"dyn.age80i");
        compareAllClasses(@"hyphen", @"dyn.age80q6xtqk-");
        compareAllClasses(@"prefix only", @"dyn.a");
        compareAllClasses(@"short tail", @"dyn.age");
        compareAllClasses(@"conformance only", @"dyn.ah62d4r34");
        compareAllClasses(@"host frob ext", @"dyn.age80q6xtqk");
        compareAllClasses(@"host ostype", @"dyn.agk80q6xtqk");
        compareAllClasses(@"host nspboard", @"dyn.agu80q6xtqk");
        compareAllClasses(@"host mime", @"dyn.agq81k3p2su11uppgsm10e");
        compareAllClasses(@"host pathname", @"dyn.asb40e5dmqq1ha2pyrb1gc5pfhzxhe55c");
        compareAllClasses(@"host conformance apk", @"dyn.ah62d4rv4ge80c6dp");

        NSArray *texts = @[@"1=frob", @"1=a,b", @"1=a:b", @"1=a\\,b", @"1=a\\:b", @"1=a\\\\b", @"1=a\\=b", @"1=", @"1",
                           @"1=a:1=b", @"1=a:3=b", @"1=a,,b", @"1=,a", @"1=a,", @"com.apple.ostype=ABCD", @"public.pathname=/tmp/x",
                           @"2=ABCD,EFGH", @"3=text/a,image/b", @"1=a\\", @"1=a\\x", @"?0=public.data:1=a", @"9=abc:1=q",
                           @"=x", @"1==x", @"1=A", @":1=a", @"1=a::1=b", @"1=a:", @"1=a:1=a", @"1=a\\:b,c", @"x:1=a",
                           @"1=a:x:1=b", @"1\\=frob", @"COM.APPLE.OSTYPE=ABCD", @"public.filename-extension=frob",
                           @"public.mime-type=a/b", @"1=,,,a", @"1=,", @"1=,,", @"?0=7:3=text/X-frob:1=frob", @"1=a\\\\", @"1=\\"];
        for (NSString *text in texts) compareText(@"text", text);

        const unsigned char latin[] = {'1', '=', 0xE9};
        compareBytes(@"latin1 alone", latin, 3);
        const unsigned char badThenValue[] = {'1', '=', 0xE9, ',', 'a'};
        compareBytes(@"bad then value", badThenValue, 5);
        const unsigned char badThenRecord[] = {'1', '=', 0xE9, ':', '1', '=', 'a'};
        compareBytes(@"bad then record", badThenRecord, 7);
        const unsigned char valueThenBad[] = {'1', '=', 'a', ',', 0xE9};
        compareBytes(@"value then bad", valueThenBad, 5);
        const unsigned char onlyBadMime[] = {'3', '=', 0xE9};
        compareBytes(@"only bad mime", onlyBadMime, 3);
        const unsigned char truncated[] = {'1', '=', 0xC3};
        compareBytes(@"truncated utf8", truncated, 3);
        const unsigned char utf8[] = {'1', '=', 0xC3, 0xA9};
        compareBytes(@"utf8 e-acute", utf8, 4);
        const unsigned char nul[] = {'1', '=', 'a', 0, 'b'};
        compareBytes(@"nul in value", nul, 5);
        const unsigned char badKey[] = {0xE9, '=', 'a'};
        compareBytes(@"bad key", badKey, 3);

        srand(20261017);
        const char pool[] = "1234b=:,\\ax\xC3\xA9\xE9-0000AFfCcdg\x80\x00";
        NSUInteger poolCount = sizeof(pool) - 1;
        for (int round = 0; round < 200000; round++) {
            NSUInteger length = 1 + (rand() % 16);
            unsigned char bytes[16];
            for (NSUInteger index = 0; index < length; index++) bytes[index] = (unsigned char)pool[rand() % poolCount];
            compareBytes(@"generated record", bytes, length);
        }
        const char digits[] = "abcdefghkmnpqrstuvwxyz0123456789ABCDEFGHKMNPQRSTUVWXYZiloj-.";
        NSUInteger digitCount = sizeof(digits) - 1;
        for (int round = 0; round < 4000; round++) {
            NSMutableString *uti = [NSMutableString stringWithString:@"dyn.a"];
            NSUInteger length = rand() % 30;
            for (NSUInteger index = 0; index < length; index++) [uti appendFormat:@"%c", digits[rand() % digitCount]];
            compareAllClasses(@"generated tail", uti);
        }
    }
    printf("DIFFERENTIAL cases %lu mismatches %lu\n", (unsigned long)cases, (unsigned long)mismatches);
    return mismatches == 0 ? 0 : 1;
}
