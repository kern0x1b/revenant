// probe.m - +[INImage systemImageNamed:] against +[UIImage systemImageNamed:], name by name.
//
// Reads one name per line from the file given as the argument, and prints one line per name:
//   name <TAB> UIImage YES|NO <TAB> INImage YES|NO
// The UIImage column is the host's UIKit in both builds, so it is the same in both. The INImage column is the
// class under test: the host's own in the host build, the port's (renamed CharonHost*) in the port build. The two
// runs must print the same lines. The INImage class is looked up by name and sent the selector at run time, so the
// header of the framework does not decide the answer.
//
//   xcrun clang -fno-objc-arc -framework Foundation -framework UIKit -framework Intents probe.m -o probe
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>

#ifdef PORT
#define PREFIX "CharonHost"
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
