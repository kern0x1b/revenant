#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

@interface RevenantProbeURL : NSURL
@property (nonatomic, copy) NSString *raw;
@end

@implementation RevenantProbeURL
- (NSString *)absoluteString { return self.raw; }
- (NSString *)host { return @"overridden"; }
@end

static const char *revenant_text(NSString *text)
{
    return text ? [text UTF8String] : "(nil)";
}

static void revenant_report(const char *label, NSString *absolute, NSString *host, NSString *path, NSString *relative)
{
    printf("  %-28s abs=%s host=%s path=%s rel=%s\n", label, revenant_text(absolute), revenant_text(host), revenant_text(path), revenant_text(relative));
}

static void revenant_cf(CFURLRef url, const char *label)
{
    if (!url) {
        printf("  %-28s (null)\n", label);
        return;
    }
    CFStringRef host = CFURLCopyHostName(url);
    revenant_report(label, (__bridge NSString *)CFURLGetString(url), (__bridge NSString *)host, nil, nil);
    if (host)
        CFRelease(host);
    CFRelease(url);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSURL *base = [NSURL URLWithString:@"https://base.example/docs/"];
        NSArray *strings = @[@"http://a b", @"http://a ", @"http://a|", @"http://a[", @"-a:b", @"+a:b", @".mailto:a@b.c", @"http://aé", @"http://a.é/p q"];
        for (NSString *text in strings) {
            printf("%s\n", [[text stringByReplacingOccurrencesOfString:@" " withString:@"<NBSP>"] UTF8String]);
            NSURL *plain = [NSURL URLWithString:text];
            revenant_report("URLWithString:", plain.absoluteString, plain.host, plain.path, plain.relativeString);
            NSURL *relative = [NSURL URLWithString:text relativeToURL:base];
            revenant_report("URLWithString:relativeToURL:", relative.absoluteString, relative.host, relative.path, relative.relativeString);
            revenant_cf(CFURLCreateWithString(NULL, (__bridge CFStringRef)text, NULL), "CFURLCreateWithString");
            NSData *bytes = [text dataUsingEncoding:NSUTF8StringEncoding];
            revenant_cf(CFURLCreateWithBytes(NULL, bytes.bytes, bytes.length, kCFStringEncodingUTF8, NULL), "CFURLCreateWithBytes");
            revenant_cf(CFURLCreateAbsoluteURLWithBytes(NULL, bytes.bytes, bytes.length, kCFStringEncodingUTF8, (__bridge CFURLRef)base, true), "AbsoluteURLWithBytes yes");
            revenant_cf(CFURLCreateAbsoluteURLWithBytes(NULL, bytes.bytes, bytes.length, kCFStringEncodingUTF8, (__bridge CFURLRef)base, false), "AbsoluteURLWithBytes no");
        }
        for (NSString *opaque in @[@"a:b#f", @"a:b?x#f", @"mailto:a@b.c#f", @"a:b?%7B%7D#f%23g", @"a:b#%25", @"a:b/c#f", @"a://h#f"]) {
            printf("%s\n", [opaque UTF8String]);
            NSURL *url = [NSURL URLWithString:opaque];
            printf("  abs=%s fragment=%s query=%s specifier=%s\n", revenant_text(url.absoluteString), revenant_text(url.fragment), revenant_text(url.query), revenant_text(url.resourceSpecifier));
            NSData *opaqueBytes = [opaque dataUsingEncoding:NSUTF8StringEncoding];
            revenant_cf(CFURLCreateWithBytes(NULL, opaqueBytes.bytes, opaqueBytes.length, kCFStringEncodingUTF8, NULL), "CFURLCreateWithBytes");
        }
        RevenantProbeURL *sub = [[RevenantProbeURL alloc] initWithString:@"http://a%20b"];
        sub.raw = @"http://a b";
        printf("subclass\n");
        revenant_report("subclass ObjC", sub.absoluteString, sub.host, sub.path, sub.relativeString);
        revenant_report("subclass description", [sub description], nil, nil, nil);
        revenant_cf((CFURLRef)CFRetain((__bridge CFURLRef)sub), "subclass through CF");
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"t"];
        [text addAttribute:@"NSLink" value:sub range:NSMakeRange(0, 1)];
        id stored = [text attribute:@"NSLink" atIndex:0 effectiveRange:NULL];
        printf("  attribute keeps the subclass: %s, class %s\n", stored == sub ? "yes" : "no", object_getClassName(stored));
    }
    return 0;
}
