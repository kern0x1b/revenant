#import <UIKit/UIKit.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

static int failures, checks;

static NSString *directional(NSDirectionalEdgeInsets insets)
{
    return [NSString stringWithFormat:@"{%g, %g, %g, %g}", insets.top, insets.leading, insets.bottom, insets.trailing];
}

static NSString *edges(UIEdgeInsets insets)
{
    return [NSString stringWithFormat:@"{%g, %g, %g, %g}", insets.top, insets.left, insets.bottom, insets.right];
}

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static NSDirectionalEdgeInsets ours_directional(UIView *view)
{
    return ((NSDirectionalEdgeInsets (*)(id, SEL))objc_msgSend)(view, NSSelectorFromString(@"charonHost_directionalLayoutMargins"));
}

static void set_ours_directional(UIView *view, NSDirectionalEdgeInsets insets)
{
    ((void (*)(id, SEL, NSDirectionalEdgeInsets))objc_msgSend)(view, NSSelectorFromString(@"charonHost_setDirectionalLayoutMargins:"), insets);
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        for (NSNumber *attribute in @[@(UISemanticContentAttributeForceLeftToRight), @(UISemanticContentAttributeForceRightToLeft)]) {
            NSString *tag = attribute.integerValue == UISemanticContentAttributeForceRightToLeft ? @"right to left" : @"left to right";
            UIView *system = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
            UIView *ours = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
            system.semanticContentAttribute = attribute.integerValue;
            ours.semanticContentAttribute = attribute.integerValue;

            compare([tag stringByAppendingString:@": the default margins"],
                    directional(system.directionalLayoutMargins), directional(ours_directional(ours)));

            system.layoutMargins = UIEdgeInsetsMake(1, 2, 3, 4);
            ours.layoutMargins = UIEdgeInsetsMake(1, 2, 3, 4);
            compare([tag stringByAppendingString:@": directional margins read plain ones"],
                    directional(system.directionalLayoutMargins), directional(ours_directional(ours)));

            system.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(5, 6, 7, 8);
            set_ours_directional(ours, NSDirectionalEdgeInsetsMake(5, 6, 7, 8));
            compare([tag stringByAppendingString:@": plain margins follow directional ones"],
                    edges(system.layoutMargins), edges(ours.layoutMargins));
            compare([tag stringByAppendingString:@": directional margins come back"],
                    directional(system.directionalLayoutMargins), directional(ours_directional(ours)));

            system.layoutMargins = UIEdgeInsetsMake(9, 10, 11, 12);
            ours.layoutMargins = UIEdgeInsetsMake(9, 10, 11, 12);
            compare([tag stringByAppendingString:@": plain margins win when set last"],
                    directional(system.directionalLayoutMargins), directional(ours_directional(ours)));
        }

        UIView *system = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        UIView *ours = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        system.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(5, 6, 7, 8);
        set_ours_directional(ours, NSDirectionalEdgeInsetsMake(5, 6, 7, 8));
        system.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        ours.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        compare(@"a direction change afterwards keeps the directional margins",
                directional(system.directionalLayoutMargins), directional(ours_directional(ours)));
        printf("note the plain margins after a direction change: the system answers %s, the backport answers %s;\n"
               "     mirroring them needs -layoutMargins itself, which belongs to the iOS 8 backport, and on iOS 6\n"
               "     the direction cannot change after launch at all: semanticContentAttribute arrived in iOS 9.\n",
               edges(system.layoutMargins).UTF8String, edges(ours.layoutMargins).UTF8String);

        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
