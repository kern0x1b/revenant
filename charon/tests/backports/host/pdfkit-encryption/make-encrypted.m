// The encrypted fixtures, written with CGPDFContext's own encryption: the release's writer makes the
// /Encrypt dictionary, so neither side is asked about a file it could not produce. Built and run by
// run.sh on the host only, and the three files are the same bytes on both sides.
//
//   plain.pdf       no password, no /Encrypt
//   owner-only.pdf  an OWNER password and no user password: /Encrypt present, opens without a password
//   user-locked.pdf a USER password "secret": /Encrypt present, and nothing reads a page until it is given
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>

static void draw(NSString *path, NSDictionary *aux)
{
    CGRect box = CGRectMake(0, 0, 300, 300);
    CGContextRef context = CGPDFContextCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], &box,
                                                    (__bridge CFDictionaryRef)aux);
    if (context == NULL) {
        fprintf(stderr, "could not make a PDF context for %s\n", path.UTF8String);
        return;
    }
    for (int page = 1; page <= 2; page++) {
        CGPDFContextBeginPage(context, NULL);
        // a font is selected before any text is shown, or the page carries no text to read back
        CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);
        NSString *text = [NSString stringWithFormat:@"encrypted page %d", page];
        CGContextShowTextAtPoint(context, 20, 260, text.UTF8String, (int)text.length);
        CGPDFContextEndPage(context);
    }
    CGPDFContextClose(context);
    CGContextRelease(context);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *directory = argc > 1 ? @(argv[1]) : NSTemporaryDirectory();
        draw([directory stringByAppendingPathComponent:@"plain.pdf"], nil);
        draw([directory stringByAppendingPathComponent:@"owner-only.pdf"],
             @{ (id)kCGPDFContextOwnerPassword : @"owner", (id)kCGPDFContextEncryptionKeyLength : @128 });
        draw([directory stringByAppendingPathComponent:@"user-locked.pdf"],
             @{ (id)kCGPDFContextUserPassword : @"secret", (id)kCGPDFContextOwnerPassword : @"owner",
                (id)kCGPDFContextEncryptionKeyLength : @128 });
        for (NSString *name in @[ @"plain.pdf", @"owner-only.pdf", @"user-locked.pdf" ])
            printf("%s %s\n", name.UTF8String,
                   [[NSFileManager defaultManager] fileExistsAtPath:[directory stringByAppendingPathComponent:name]]
                       ? "written" : "MISSING");
    }
    return 0;
}
