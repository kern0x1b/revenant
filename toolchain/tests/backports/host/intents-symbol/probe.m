#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>

#ifdef PORT
#define PREFIX "RevenantHost"
#else
#define PREFIX ""
#endif

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: probe <names file>\n");
            return 2;
        }
        NSString *text = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:NULL];
        if (!text) {
            fprintf(stderr, "cannot read %s\n", argv[1]);
            return 2;
        }
        Class imageClass = NSClassFromString([NSString stringWithFormat:@"%sINImage", PREFIX]);
        if (!imageClass) {
            fprintf(stderr, "no INImage class\n");
            return 2;
        }
        SEL selector = NSSelectorFromString(@"systemImageNamed:");
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            NSString *name = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (!name.length) {
                continue;
            }
            BOOL uiYES = [UIImage systemImageNamed:name] != nil;
            id image = ((id (*)(id, SEL, id))objc_msgSend)(imageClass, selector, name);
            printf("%s\tUIImage %s\tINImage %s\n", [name UTF8String], uiYES ? "YES" : "NO", image ? "YES" : "NO");
        }
    }
    return 0;
}
