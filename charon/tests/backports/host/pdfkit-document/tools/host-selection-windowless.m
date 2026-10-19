#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <PDFKit/PDFKit.h>
#include <stdio.h>
// The rect and the point are DERIVED from the page's own text position rather than typed in, because a
// fixed coordinate silently covers one fixture's text and misses another's - measured: the two
// fixtures draw at y=360 and y=752, and a rect at y=360 answers "page 1" on one and empty on the other.
int main(int argc, char **argv) { @autoreleasepool {
  for (int i = 1; i < argc; i++) {
    NSString *path = @(argv[i]);
    CFURLRef u = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGPDFDocumentRef doc = CGPDFDocumentCreateWithURL(u);
    CGPDFPageRef pg = doc ? CGPDFDocumentGetPage(doc, 1) : NULL;
    CGPDFDictionaryRef pd = pg ? CGPDFPageGetDictionary(pg) : NULL;
    // the text matrix of the first BT..Tj, read from the page's own content stream
    double tx = 0, ty = 0;
    if (pd) {
        CGPDFStreamRef st = NULL;
        if (CGPDFDictionaryGetStream(pd, "Contents", &st) && st) {
            CFDataRef data = CGPDFStreamCopyData(st, NULL);
            if (data) {
                NSString *s = [[NSString alloc] initWithData:(__bridge NSData *)data encoding:NSASCIIStringEncoding];
                NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"([-\\d.]+) ([-\\d.]+) ([-\\d.]+) ([-\\d.]+) ([-\\d.]+) ([-\\d.]+) Tm" options:0 error:nil];
                NSTextCheckingResult *m = [re firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
                if (m) tx = [[s substringWithRange:[m rangeAtIndex:5]] doubleValue],
                         ty = [[s substringWithRange:[m rangeAtIndex:6]] doubleValue];
            }
        }
    }
    PDFDocument *d = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
    if (d == nil || d.pageCount == 0) continue;
    PDFPage *p = [d pageAtIndex:0];
    CGRect around = CGRectMake(tx - 5, ty - 5, 100, 25);
    printf("  %-22s text at (%.0f,%.0f)  rect=%.0f,%.0f,%.0f,%.0f\n",
           [path.lastPathComponent UTF8String], tx, ty,
           around.origin.x, around.origin.y, around.size.width, around.size.height);
    PDFSelection *r = [p selectionForRect:around];
    printf("    rect  -> %s\n", r ? (r.string.length ? r.string.UTF8String : "(empty)") : "nil");
    PDFSelection *w = [p selectionForWordAtPoint:CGPointMake(tx + 2, ty + 4)];
    printf("    word  -> %s   ranges=%lu   bounds=%.4f,%.4f,%.4f,%.4f\n",
           w ? (w.string.length ? w.string.UTF8String : "(empty)") : "nil",
           w ? (unsigned long)[w numberOfTextRangesOnPage:p] : 0,
           w ? [w boundsForPage:p].origin.x : 0, w ? [w boundsForPage:p].origin.y : 0,
           w ? [w boundsForPage:p].size.width : 0, w ? [w boundsForPage:p].size.height : 0);
    PDFSelection *l = [p selectionForLineAtPoint:CGPointMake(tx + 2, ty + 4)];
    printf("    line  -> %s   selectionsByLine=%lu\n",
           l ? (l.string.length ? l.string.UTF8String : "(empty)") : "nil",
           l ? (unsigned long)l.selectionsByLine.count : 0);
  }
} return 0; }
