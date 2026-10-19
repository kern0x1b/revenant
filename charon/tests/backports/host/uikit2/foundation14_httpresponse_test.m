#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static uint64_t state = 0x4EAD3245ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *mangle(NSString *text)
{
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger index = 0; index < text.length; index++) {
        NSString *c = [text substringWithRange:NSMakeRange(index, 1)];
        [out appendString:next() % 3 == 0 ? c.uppercaseString : (next() % 2 ? c.lowercaseString : c)];
    }
    return out;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSArray *names = @[@"Content-Type", @"X-Foo", @"Set-Cookie", @"Etag", @"Cache-Control", @"Ünï", @"café", @"İstanbul", @"straße", @"Kız", @"中文", @"a", @"Content-Length", @"x-request-id", @"", @"K", @"Σίσυφος"];
        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 40000, wrong = 0;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < cases; index++) {
            NSMutableDictionary *fields = [NSMutableDictionary dictionary];
            NSUInteger count = next() % 5;
            for (NSUInteger item = 0; item < count; item++)
                fields[mangle(names[next() % names.count])] = next() % 6 == 0 ? @"" : [NSString stringWithFormat:@"v%u", next() % 100];
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com"] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:next() % 9 == 0 ? nil : fields];
            NSString *asked = mangle(names[next() % names.count]);
            NSString *a = ((id (*)(id, SEL, id))objc_msgSend)(response, NSSelectorFromString(@"charonHostValueForHTTPHeaderField:"), asked);
            NSString *b = [response valueForHTTPHeaderField:asked];
            if (!(a == b || [a isEqualToString:b])) {
                wrong++;
                if (samples.count < 8)
                    [samples addObject:[NSString stringWithFormat:@"asked %@ of %@\n     port %@ system %@", asked, response.allHeaderFields, a, b]];
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        charon_check(wrong == 0, "a header is found under any spelling of its name as the system finds it", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)cases]);
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com"] statusCode:200 HTTPVersion:nil headerFields:@{@"A": @"1"}];
        CHECK(((id (*)(id, SEL, id))objc_msgSend)(response, NSSelectorFromString(@"charonHostValueForHTTPHeaderField:"), nil) == nil, "no name has no value, where the system crashes");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
