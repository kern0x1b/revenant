#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <PDFKit/PDFKit.h>
#include <stdio.h>
int main(int argc, char **argv) { @autoreleasepool {
  for (int i = 1; i < argc; i++) {
    PDFDocument *d = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:@(argv[i])]];
    printf("  %-18s opened=%d", [@(argv[i]).lastPathComponent UTF8String], d != nil);
    if (d == nil) { printf("\n"); continue; }
    PDFPage *p = d.pageCount ? [d pageAtIndex:0] : nil;
    printf("  pages=%lu  annotations=%lu\n", (unsigned long)d.pageCount,
           (unsigned long)(p ? p.annotations.count : 0));
    for (PDFAnnotation *a in p.annotations) {
      printf("      type=%ld subtype=%s bounds=%s contents=%s userName=%s color=%s\n",
             (long)a.type, [a valueForAnnotationKey:@"Subtype"] ? [[a valueForAnnotationKey:@"Subtype"] description].UTF8String : "(nil)",
             NSStringFromRect(a.bounds).UTF8String,
             a.contents ? a.contents.UTF8String : "(nil)",
             a.userName ? a.userName.UTF8String : "(nil)",
             a.color ? [[a.color description] UTF8String] : "(nil)");
      // The TYPED flags and appearance properties, read as properties and NOT derived from the /F key:
      // the line above reads /F through the key API, and it is a separate question whether PDFKit's own
      // -shouldPrint and -shouldDisplay answer that bit.
      printf("      shouldDisplay=%d shouldPrint=%d appearanceStream=%d highlighted=%d\n",
             a.shouldDisplay, a.shouldPrint, a.hasAppearanceStream, a.isHighlighted);
      printf("      modificationDate=%s border=%s flags=%lu page=%s\n",
             a.modificationDate ? [[a.modificationDate description] UTF8String] : "(nil)",
             [a valueForAnnotationKey:@"Border"] ? [[a valueForAnnotationKey:@"Border"] description].UTF8String : "(nil)",
             (unsigned long)[[a valueForAnnotationKey:@"F"] unsignedLongValue], a.page ? "an-object" : "(nil)");
    }
  }
} return 0; }
