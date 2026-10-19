#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

Boolean CharonHostUTTypeIsDynamic(CFStringRef);
Boolean CharonHostUTTypeIsDeclared(CFStringRef);

// UTTypeIsDynamic and UTTypeIsDeclared of the port against the host's, over generated identifiers
// around the "dyn." prefix and over declared, undeclared and dynamic ones.
int main(void)
{
    @autoreleasepool {
        NSArray *prefixes = @[@"dyn.", @"DYN.", @"Dyn.", @"dYn.", @"dyn", @"", @"dy.", @"dyn..", @"public."];
        NSArray *pieces = @[@"d", @"y", @"n", @"D", @".", @"-", @"a", @"Z", @"0", @"9", @"_", @" ", @"/", @":", @"+", @"é"];
        srandom(7);
        long checks = 0, different = 0, dynamic = 0;
        for (int n = 0; n < 200000; n++) {
            NSMutableString *identifier = [prefixes[random() % prefixes.count] mutableCopy];
            int length = random() % 9;
            for (int i = 0; i < length; i++)
                [identifier appendString:pieces[random() % pieces.count]];
            Boolean host = UTTypeIsDynamic((__bridge CFStringRef)identifier), port = CharonHostUTTypeIsDynamic((__bridge CFStringRef)identifier);
            checks++;
            dynamic += host;
            if (host != port && different++ < 20)
                printf("UTTypeIsDynamic(%s): host %d, port %d\n", identifier.UTF8String, host, port);
        }
        CFStringRef made = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, CFSTR("zzqq"), NULL);
        NSArray *declared = @[@"public.jpeg", @"public.JPEG", @"Public.jpeg", @"public.png", @"public.data", @"public.item", @"public.content",
                              @"com.apple.quicktime-movie", @"public.mpeg-4", @"com.adobe.pdf", @"com.example.undeclared", @"",
                              @"dyn.ah62d4rv4ge80e5pe", (__bridge NSString *)made];
        for (NSString *identifier in declared) {
            checks += 2;
            if (UTTypeIsDeclared((__bridge CFStringRef)identifier) != CharonHostUTTypeIsDeclared((__bridge CFStringRef)identifier)) {
                different++;
                printf("UTTypeIsDeclared(%s) differs\n", identifier.UTF8String);
            }
            if (UTTypeIsDynamic((__bridge CFStringRef)identifier) != CharonHostUTTypeIsDynamic((__bridge CFStringRef)identifier)) {
                different++;
                printf("UTTypeIsDynamic(%s) differs\n", identifier.UTF8String);
            }
        }
        CFRelease(made);
        checks += 2;
        if (UTTypeIsDynamic(NULL) != CharonHostUTTypeIsDynamic(NULL) || UTTypeIsDeclared(NULL) != CharonHostUTTypeIsDeclared(NULL)) {
            different++;
            printf("NULL differs\n");
        }
        printf("uttype: %ld checks, %ld different, %ld dynamic by the host\n", checks, different, dynamic);
        if (dynamic == 0)
            printf("uttype: the generator made no dynamic identifier, so the run proves nothing\n");
        return different || dynamic == 0 ? 1 : 0;
    }
}
