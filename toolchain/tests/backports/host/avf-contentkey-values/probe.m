#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

static void raised(const char *label, NSException *e)
{
    printf("%s raised %s: %s\n", label, [e.name UTF8String], [[e reason] UTF8String]);
}

static void spec(const char *label, NSString *system, id identifier, NSDictionary *options)
{
    @try {
        AVContentKeySpecifier *s = [AVContentKeySpecifier contentKeySpecifierForKeySystem:system identifier:identifier options:options];
        if (!s) { printf("%s nil\n", label); return; }
        printf("%s specifier=%d keySystem=%s identifier=%s(%s) options=%s\n", label, [s isKindOfClass:[AVContentKeySpecifier class]],
               [[s.keySystem description] UTF8String], [[s.identifier description] UTF8String],
               [[[s.identifier class] description] UTF8String], [[s.options description] UTF8String]);
    } @catch (NSException *e) { raised(label, e); }
}

static void response(const char *label, id r)
{
    if (!r) { printf("%s nil\n", label); return; }
    printf("%s response=%d\n", label, [r isKindOfClass:[AVContentKeyResponse class]]);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        spec("S1 clear", @"ClearKeySystem", @"skd://example", nil);
        spec("S2 clear options", @"ClearKeySystem", @"skd://example", @{ @"k": @"v" });
        spec("S3 nil system", nil, @"skd://example", nil);
        spec("S4 empty system", @"", @"skd://example", nil);
        spec("S5 nil identifier", @"ClearKeySystem", nil, nil);
        spec("S6 data identifier", @"ClearKeySystem", [@"skd://example" dataUsingEncoding:NSUTF8StringEncoding], nil);
        spec("S7 number identifier", @"ClearKeySystem", @1, nil);
        spec("S8 unknown system", @"NoSuchSystem", @"skd://example", nil);
        spec("S9 fairplay", @"com.apple.fps.1_0", @"skd://example", nil);
        spec("S10 empty identifier", @"ClearKeySystem", @"", nil);
        spec("S11 non-string option key", @"ClearKeySystem", @"skd://example", @{ @1: @"v" });

        NSMutableString *system = [NSMutableString stringWithString:@"ClearKeySystem"];
        NSMutableString *identifier = [NSMutableString stringWithString:@"skd://x"];
        NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:@{ @"k": @"v" }];
        AVContentKeySpecifier *m = [AVContentKeySpecifier contentKeySpecifierForKeySystem:system identifier:identifier options:options];
        printf("M1 same system object %d\n", m.keySystem == system);
        printf("M2 same identifier object %d\n", m.identifier == identifier);
        printf("M3 same options object %d\n", m.options == options);
        [system appendString:@"-changed"];
        [identifier appendString:@"-changed"];
        [options setObject:@"w" forKey:@"j"];
        printf("M4 after mutation system=%s identifier=%s options=%s\n", [m.keySystem UTF8String], [m.identifier UTF8String],
               [[m.options description] UTF8String]);

        AVContentKeySpecifier *c = [m copy];
        printf("C1 copy is same object %d\n", c == m);
        printf("C2 copy keeps keySystem %d identifier %d options %d\n", [c.keySystem isEqual:m.keySystem],
               [c.identifier isEqual:m.identifier], [c.options isEqual:m.options]);
        printf("C3 specifier is NSCopying %d\n", [m conformsToProtocol:@protocol(NSCopying)]);

        AVContentKeySpecifier *n = [AVContentKeySpecifier contentKeySpecifierForKeySystem:@"ClearKeySystem" identifier:@"a" options:nil];
        printf("N1 nil options %s\n", [[n.options description] UTF8String]);
        AVContentKeySpecifier *i = [[AVContentKeySpecifier alloc] initForKeySystem:@"ClearKeySystem" identifier:@"b" options:@{ @"x": @1 }];
        printf("I1 initializer keySystem=%s identifier=%s options=%s\n", [i.keySystem UTF8String], [i.identifier UTF8String],
               [[i.options description] UTF8String]);

        NSData *key16 = [NSMutableData dataWithLength:16];
        NSData *iv16 = [NSMutableData dataWithLength:16];
        NSData *blob = [@"ckc" dataUsingEncoding:NSUTF8StringEncoding];
        response("R1 fairplay blob", [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:blob]);
        response("R2 fairplay nil", [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:nil]);
        response("R3 fairplay empty", [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:[NSData data]]);
        response("R4 clear 16/16", [AVContentKeyResponse contentKeyResponseWithClearKeyData:key16 initializationVector:iv16]);
        response("R5 clear nil iv", [AVContentKeyResponse contentKeyResponseWithClearKeyData:key16 initializationVector:nil]);
        response("R6 clear nil key", [AVContentKeyResponse contentKeyResponseWithClearKeyData:nil initializationVector:iv16]);
        response("R7 clear short iv", [AVContentKeyResponse contentKeyResponseWithClearKeyData:key16 initializationVector:[NSMutableData dataWithLength:4]]);
        response("R8 clear empty key", [AVContentKeyResponse contentKeyResponseWithClearKeyData:[NSData data] initializationVector:iv16]);
        response("R9 clear short key", [AVContentKeyResponse contentKeyResponseWithClearKeyData:[NSMutableData dataWithLength:4] initializationVector:iv16]);
        response("R10 token", [AVContentKeyResponse contentKeyResponseWithAuthorizationTokenData:blob]);
        response("R11 token nil", [AVContentKeyResponse contentKeyResponseWithAuthorizationTokenData:nil]);
        response("R12 token empty", [AVContentKeyResponse contentKeyResponseWithAuthorizationTokenData:[NSData data]]);
    }
    return 0;
}
