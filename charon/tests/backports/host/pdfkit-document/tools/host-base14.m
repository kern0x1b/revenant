#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *path = @(argv[i]);
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            if (document == nil || document.pageCount == 0) {
                printf("%s NO DOCUMENT\n", [path.lastPathComponent UTF8String]);
                continue;
            }
            PDFPage *page = [document pageAtIndex:0];
            NSString *text = page.string;
            if (text.length == 0) {
                printf("%s EMPTY\n", [path.lastPathComponent UTF8String]);
                continue;
            }
            CGRect whole = [[document findString:text withOptions:0].firstObject boundsForPage:page];
            printf("%s text-len=%lu whole=%.4f,%.4f,%.4f,%.4f\n", [path.lastPathComponent UTF8String],
                   (unsigned long)text.length, whole.origin.x, whole.origin.y, whole.size.width,
                   whole.size.height);
            for (NSUInteger c = 0; c < text.length; c++) {
                NSString *needle = [text substringWithRange:NSMakeRange(c, 1)];
                NSArray<PDFSelection *> *found = [document findString:needle withOptions:0];
                if (found.count == 0) {
                    printf("%3lu NO MATCH\n", (unsigned long)[needle characterAtIndex:0]);
                    continue;
                }
                CGRect b = [found.firstObject boundsForPage:page];
                printf("%3lu %s x=%.4f w=%.4f\n", (unsigned long)[needle characterAtIndex:0],
                       [needle UTF8String], b.origin.x, b.size.width);
            }
        }
    }
    return 0;
}
