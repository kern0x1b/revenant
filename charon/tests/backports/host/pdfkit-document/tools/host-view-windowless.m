// The iOS PDFView's own members, answered by the host with NO WINDOW.  The plan's cases
// (pageCount, canDisplayPage:, usePageViewController:, scaleToFit, goToPage:) are macOS-only or not
// this API at all: the iOS header declares none of them, and the host's PDFView has no -pageCount, so
// a comparison on them would be a comparison of things neither side is asked for.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <PDFKit/PDFKit.h>
#include <stdio.h>
int main(int argc, char **argv) { @autoreleasepool {
  for (int i = 1; i < argc; i++) {
    NSString *name = @(argv[i]).lastPathComponent;
    PDFDocument *d = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:@(argv[i])]];
    PDFView *v = [[PDFView alloc] init];
    printf("  %-24s window=%s document=%s\n", name.UTF8String,
           v.window ? "a window" : "(nil)", v.document ? "an-object" : "(nil)");
    v.document = d;
    printf("      document=%s  currentPage=%s  scaleFactor=%g  min=%g  max=%g  autoScales=%d\n",
           v.document ? "an-object" : "(nil)", v.currentPage ? "an-object" : "(nil)",
           v.scaleFactor, v.minScaleFactor, v.maxScaleFactor, (int)v.autoScales);
    printf("      displayMode=%ld  displayBox=%ld  displayDirection=%ld  pageShadowsEnabled=%d\n",
           (long)v.displayMode, (long)v.displayBox, (long)v.displayDirection, (int)v.pageShadowsEnabled);
    v.displayMode = kPDFDisplayTwoUpContinuous;
    v.displayBox = kPDFDisplayBoxCropBox;
    v.displayDirection = kPDFDisplayDirectionVertical;
    v.pageShadowsEnabled = YES;
    printf("      after setting them: displayMode=%ld displayBox=%ld displayDirection=%ld shadows=%d\n",
           (long)v.displayMode, (long)v.displayBox, (long)v.displayDirection, (int)v.pageShadowsEnabled);
    v.document = nil;
    printf("      document=nil: document=%s currentPage=%s\n",
           v.document ? "an-object" : "(nil)", v.currentPage ? "an-object" : "(nil)");
    printf("      canDisplayPage: supported=%d  goToPage: supported=%d  scaleToFit: supported=%d\n",
           (int)[v respondsToSelector:sel_registerName("canDisplayPage:")],
           (int)[v respondsToSelector:sel_registerName("goToPage:")],
           (int)[v respondsToSelector:sel_registerName("scaleToFit")]);
  }
} return 0; }
