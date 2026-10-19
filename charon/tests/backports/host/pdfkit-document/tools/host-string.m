// What the HOST's -[PDFPage string] answers for each fixture, with the control characters VISIBLE: a
// trailing newline or a space between two runs is the whole question and %s would hide both.
//
//   xcrun clang -fobjc-arc -Wall host-string.m -framework Foundation -framework PDFKit -o host-string
//   ./host-string <fixtures-dir>/<name>.pdf ...
//
// Prints  <row name>\t<the string, controls shown>  so tools/verify-table.sh can diff it against the
// table in facts/PDFKit/Document11.md.
#import <Foundation/Foundation.h>
#import <PDFKit/PDFKit.h>
#include <stdio.h>

static NSString *visible(NSString *text)
{
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '\n') [out appendString:@"\\n"];
        else if (c == '\r') [out appendString:@"\\r"];
        else if (c == '\t') [out appendString:@"\\t"];
        else [out appendFormat:@"%C", c];
    }
    return out;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *path = @(argv[i]);
            NSString *name = [[path.lastPathComponent stringByDeletingPathExtension] copy];
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            PDFPage *page = document.pageCount ? [document pageAtIndex:0] : nil;
            NSString *text = page ? [page string] : nil;
            printf("%s\t%s\n", name.UTF8String, text ? [visible(text) UTF8String] : "(nil)");
        }
    }
    return 0;
}
