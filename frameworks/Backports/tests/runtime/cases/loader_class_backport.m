#import "../app/revenant_check.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *revenant_image_of(Class cls)
{
    for (Class current = cls; current; current = class_getSuperclass(current)) {
        const char *image = class_getImageName(current);
        if (image)
            return [NSString stringWithUTF8String:image];
    }
    return @"";
}

static BOOL revenant_contains(NSString *text, NSString *part)
{
    return [text rangeOfString:part].location != NSNotFound;
}

REVENANT_CASE(loader_class_backport)
{
    NSString *components = revenant_image_of([NSURLComponents class]);
    revenant_expect_true(@"NSURLComponents, which iOS 6 lacks, resolves to libFoundationBackports",
                         revenant_contains(components, @"libFoundationBackports") != (BOOL)negative,
                         components);

    NSString *stack = revenant_image_of([UIStackView class]);
    revenant_expect_true(@"UIStackView, which iOS 6 lacks, resolves to libUIKitBackports",
                         revenant_contains(stack, @"libUIKitBackports") != (BOOL)negative,
                         stack);

    NSString *url = revenant_image_of([NSURL class]);
    revenant_expect_true(@"NSURL, which iOS 6 has, stays the system's Foundation",
                         (revenant_contains(url, @"Backports") == NO && revenant_contains(url, @"Foundation.framework") == YES) != (BOOL)negative,
                         url);
}
