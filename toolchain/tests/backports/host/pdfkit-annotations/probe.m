#import <Foundation/Foundation.h>
#ifdef REVENANT_PORT
#import "RevenantPDFKit.h"
#else
#import <PDFKit/PDFKit.h>
#endif
#include <stdio.h>

int main(int argc, char **argv)
{
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *name = @(argv[i]).lastPathComponent;
            PDFDocument *doc = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:@(argv[i])]];
            if (doc == nil) {
                printf("%s.open=nil\n", name.UTF8String);
                continue;
            }
            PDFPage *page = [doc pageAtIndex:0];
            NSArray *annotations = page.annotations;
            printf("%s.annotations=%lu\n", name.UTF8String, (unsigned long)annotations.count);
            for (PDFAnnotation *annotation in annotations) {
                printf("%s.type=%s\n", name.UTF8String, annotation.type.UTF8String);
                printf("%s.hasAppearanceStream=%d\n", name.UTF8String, (int)annotation.hasAppearanceStream);
                printf("%s.open=%d\n", name.UTF8String, (int)annotation.open);
                NSURL *url = annotation.URL;
                printf("%s.URL=%s\n", name.UTF8String, url ? url.absoluteString.UTF8String : "nil");
                PDFAction *action = annotation.action;
                printf("%s.action=%s\n", name.UTF8String, action ? NSStringFromClass([action class]).UTF8String : "nil");
                printf("%s.actionType=%s\n", name.UTF8String, action ? action.type.UTF8String : "nil");
            }
        }
    }
    return 0;
}
