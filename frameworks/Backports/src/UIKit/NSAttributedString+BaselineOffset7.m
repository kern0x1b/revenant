#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

// iOS 6's string drawing ignores NSBaselineOffsetAttributeName: the probe in tests/emulate/baseline measures the same ink box
// with and without the offset. The replacement below draws each run of the string on its own, moved by its offset, and
// draws runs without an offset through the system's implementation, which is kept here so the replacement can call it.
IMP revenant_baseline_draw_at_point_original = NULL;

// A positive offset raises the text. UIKit's coordinates run down from the top, so raising is a smaller y; the host's
// AppKit coordinates run up, so it is a larger one.
#if TARGET_OS_IPHONE
static const CGFloat revenant_baseline_direction = -1;
#else
static const CGFloat revenant_baseline_direction = 1;
#endif

static BOOL revenant_has_baseline_offset(NSAttributedString *text)
{
    __block BOOL found = NO;
    [text enumerateAttribute:NSBaselineOffsetAttributeName inRange:NSMakeRange(0, text.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value) {
            found = YES;
            *stop = YES;
        }
    }];
    return found;
}

@implementation NSAttributedString (RevenantBaselineOffset7)

+ (void)load
{
    Method method = class_getInstanceMethod(self, @selector(drawAtPoint:));
    if (!method)
        return;
    revenant_baseline_draw_at_point_original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(^(NSAttributedString *text, CGPoint point) {
        if (!revenant_has_baseline_offset(text)) {
            ((void (*)(id, SEL, CGPoint))revenant_baseline_draw_at_point_original)(text, @selector(drawAtPoint:), point);
            return;
        }
        __block CGFloat x = point.x;
        [text enumerateAttributesInRange:NSMakeRange(0, text.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
            NSMutableAttributedString *run = [[text attributedSubstringFromRange:range] mutableCopy];
            NSNumber *offset = attributes[NSBaselineOffsetAttributeName];
            [run removeAttribute:NSBaselineOffsetAttributeName range:NSMakeRange(0, run.length)];
            CGPoint at = CGPointMake(x, point.y + revenant_baseline_direction * offset.doubleValue);
            ((void (*)(id, SEL, CGPoint))revenant_baseline_draw_at_point_original)(run, @selector(drawAtPoint:), at);
            x += run.size.width;
        }];
    });
    method_setImplementation(method, replacement);
}

@end
