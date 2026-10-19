#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>

static void draw(NSString *path, int pages, CGRect box)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[(id)kCGPDFContextTitle] = @"the port's own fixture";
    info[(id)kCGPDFContextAuthor] = @"registry-shape";
    info[(id)kCGPDFContextCreator] = @"CGPDFContext";
    CGContextRef context = CGPDFContextCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], &box,
                                                    (__bridge CFDictionaryRef)info);
    if (context == NULL) {
        fprintf(stderr, "could not make a PDF context\n");
        return;
    }
    for (int page = 1; page <= pages; page++) {
        CGPDFContextBeginPage(context, NULL);
        CGContextSelectFont(context, "Helvetica", 12.0, kCGEncodingMacRoman);
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);
        NSString *text = [NSString stringWithFormat:@"page %d", page];
        CGContextShowTextAtPoint(context, 20, box.size.height - 40, text.UTF8String, (int)text.length);
        CGPDFContextEndPage(context);
    }
    CGPDFContextClose(context);
    CGContextRelease(context);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *directory = argc > 1 ? @(argv[1]) : NSTemporaryDirectory();
        NSString *three = [directory stringByAppendingPathComponent:@"revenant-fixture-3.pdf"];
        NSString *one = [directory stringByAppendingPathComponent:@"revenant-fixture-1.pdf"];
        NSString *none = [directory stringByAppendingPathComponent:@"revenant-fixture-0.pdf"];
        draw(three, 3, CGRectMake(0, 0, 612, 792));
        draw(one, 1, CGRectMake(0, 0, 200, 400));
        draw(none, 0, CGRectMake(0, 0, 100, 100));
        for (NSString *path in @[ three, one, none ])
            printf("%s %s\n", path.UTF8String,
                   [[NSFileManager defaultManager] fileExistsAtPath:path] ? "written" : "MISSING");
        NSMutableString *manifest = [NSMutableString string];
        [manifest appendFormat:@"%@\t3\tpage N\n", three.lastPathComponent];
        [manifest appendFormat:@"%@\t1\tpage N\n", one.lastPathComponent];
        [manifest appendFormat:@"%@\t0\t\n", none.lastPathComponent];
        [manifest appendFormat:@"%@\t1\tgeometry-only\n", @"box-all.pdf"];
        [manifest appendFormat:@"%@\t1\tgeometry-only\n", @"box-nocrop.pdf"];
        [manifest appendFormat:@"%@\t1\tgeometry-only\n", @"box-rotated.pdf"];
        [manifest writeToFile:[directory stringByAppendingPathComponent:@"drew.txt"]
                  atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
