#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface GuideItemDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation GuideItemDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"guideitem.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"guideitem.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *root = self.window.rootViewController.view;
        NSArray *selectors = @[
            @"constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:",
            @"constraintWithItem:attribute:relatedBy:toItem:attribute:constant:",
            @"constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:",
            @"constraintWithItem:attribute:relatedBy:toItem:attribute:",
            @"constraintWithItem:attribute:relatedBy:constant:",
        ];
        for (NSString *name in selectors) {
            UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
            [root addSubview:host];
            UILayoutGuide *guide = [[UILayoutGuide alloc] init];
            [host addLayoutGuide:guide];
            UIView *other = [[UIView alloc] init];
            other.translatesAutoresizingMaskIntoConstraints = NO;
            [host addSubview:other];
            SEL selector = NSSelectorFromString(name);
            NSString *why = nil;
            NSLayoutConstraint *constraint = nil;
            @try {
                if ([name hasSuffix:@"multiplier:constant:"])
                    constraint = ((id (*)(id, SEL, id, NSInteger, NSInteger, id, NSInteger, CGFloat, CGFloat))objc_msgSend)([NSLayoutConstraint class], selector, guide, NSLayoutAttributeWidth, NSLayoutRelationEqual, other, NSLayoutAttributeWidth, 1.0, 10.0);
                else if ([name hasSuffix:@"toItem:attribute:constant:"])
                    constraint = ((id (*)(id, SEL, id, NSInteger, NSInteger, id, NSInteger, CGFloat))objc_msgSend)([NSLayoutConstraint class], selector, guide, NSLayoutAttributeWidth, NSLayoutRelationEqual, other, NSLayoutAttributeWidth, 10.0);
                else if ([name hasSuffix:@"toItem:attribute:multiplier:"])
                    constraint = ((id (*)(id, SEL, id, NSInteger, NSInteger, id, NSInteger, CGFloat))objc_msgSend)([NSLayoutConstraint class], selector, guide, NSLayoutAttributeWidth, NSLayoutRelationEqual, other, NSLayoutAttributeWidth, 1.0);
                else if ([name hasSuffix:@"toItem:attribute:"])
                    constraint = ((id (*)(id, SEL, id, NSInteger, NSInteger, id, NSInteger))objc_msgSend)([NSLayoutConstraint class], selector, guide, NSLayoutAttributeWidth, NSLayoutRelationEqual, other, NSLayoutAttributeWidth);
                else
                    constraint = ((id (*)(id, SEL, id, NSInteger, NSInteger, CGFloat))objc_msgSend)([NSLayoutConstraint class], selector, guide, NSLayoutAttributeWidth, NSLayoutRelationEqual, 30.0);
            } @catch (NSException *e) {
                why = [NSString stringWithFormat:@"raised on creation: %@", e.reason];
            }
            if (!why && !constraint) {
                why = @"nil";
            } else if (!why) {
                BOOL guideItem = constraint.firstItem == guide || constraint.secondItem == guide;
                if (guideItem)
                    why = @"the guide itself is an item";
            }
            if (!why) {
                @try {
                    [host addConstraint:constraint];
                    [other addConstraint:[NSLayoutConstraint constraintWithItem:other attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:50]];
                    [host layoutIfNeeded];
                    (void)constraint.description;
                } @catch (NSException *e) {
                    why = [NSString stringWithFormat:@"raised on use: %@", e.reason];
                }
            }
            charon_check(why == nil, [[NSString stringWithFormat:@"a guide as an item through +%@", name] UTF8String], why);
        }
        {
            UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
            [root addSubview:host];
            UILayoutGuide *guide = [[UILayoutGuide alloc] init];
            [host addLayoutGuide:guide];
            UIView *other = [[UIView alloc] init];
            other.translatesAutoresizingMaskIntoConstraints = NO;
            [host addSubview:other];
            NSString *why = nil;
            @try {
                NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:[guide]-10-[other]" options:0 metrics:nil views:@{@"guide": guide, @"other": other}];
                for (NSLayoutConstraint *constraint in constraints)
                    if (constraint.firstItem == guide || constraint.secondItem == guide)
                        why = @"the guide itself is an item";
                if (!why) {
                    [host addConstraints:constraints];
                    [host layoutIfNeeded];
                    for (NSLayoutConstraint *constraint in constraints)
                        (void)constraint.description;
                }
            } @catch (NSException *e) {
                why = [NSString stringWithFormat:@"raised: %@", e.reason];
            }
            charon_check(why == nil, "a guide in the views of a visual format", why);
        }
        {
            UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
            [root addSubview:host];
            UILayoutGuide *guide = [[UILayoutGuide alloc] init];
            [host addLayoutGuide:guide];
            NSString *why = nil;
            @try {
                NSLayoutConstraint *constraint = [guide.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:5];
                (void)constraint.description;
                constraint.active = YES;
                [host layoutIfNeeded];
                [host.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor].active = YES;
                [host layoutIfNeeded];
                for (NSLayoutConstraint *c in host.constraints)
                    (void)c.description;
            } @catch (NSException *e) {
                why = [NSString stringWithFormat:@"raised: %@", e.reason];
            }
            charon_check(why == nil, "anchors of a guide", why);
        }
        {
            UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
            [root addSubview:host];
            UILayoutGuide *guide = [[UILayoutGuide alloc] init];
            [host addLayoutGuide:guide];
            UIView *other = [[UIView alloc] init];
            other.translatesAutoresizingMaskIntoConstraints = NO;
            [host addSubview:other];
            NSString *why = nil;
            @try {
                NSLayoutConstraint *made = [NSLayoutConstraint constraintWithItem:[guide valueForKey:@"charon_view"] attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:host attribute:NSLayoutAttributeLeft multiplier:1 constant:7];
                NSLayoutConstraint *direct = made;
                ((void (*)(id, SEL, id))objc_msgSend)(direct, NSSelectorFromString(@"_setFirstItem:"), guide);
                if (direct.firstItem != guide)
                    why = @"the constraint could not be made to hold the guide itself";
                if (!why) {
                    [host addConstraint:direct];
                    [host addConstraint:[guide.widthAnchor constraintEqualToConstant:30]];
                    [host addConstraint:[guide.topAnchor constraintEqualToAnchor:host.topAnchor]];
                    [host addConstraint:[guide.heightAnchor constraintEqualToConstant:12]];
                    [host addConstraint:[NSLayoutConstraint constraintWithItem:other attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20]];
                    [host layoutIfNeeded];
                    (void)direct.description;
                    for (NSLayoutConstraint *c in host.constraints)
                        (void)c.description;
                    if (fabs([guide layoutFrame].origin.x - 7) > 0.5 || fabs([guide layoutFrame].size.width - 30) > 0.5)
                        why = [NSString stringWithFormat:@"the guide is at %@ and not at 7", NSStringFromCGRect([guide layoutFrame])];
                }
            } @catch (NSException *e) {
                why = [NSString stringWithFormat:@"raised: %@", e.reason];
            }
            charon_check(why == nil, "a constraint that holds the guide itself, made past the constructors, is solved by the engine", why);
        }
        {
            UILayoutGuide *guide = [[UILayoutGuide alloc] init];
            UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
            [host addLayoutGuide:guide];
            NSString *why = nil;
            NSUInteger engine = 0;
            for (NSString *name in @[@"nsli_autoresizingMask", @"nsli_boundsHeightVariable", @"nsli_boundsWidthVariable", @"nsli_contentHeightVariable", @"nsli_contentWidthVariable", @"nsli_description", @"nsli_descriptionIncludesPointer", @"nsli_engineToUserScalingCoefficients", @"nsli_isFlipped", @"nsli_layoutEngine", @"nsli_minXVariable", @"nsli_minYVariable", @"nsli_superitem"]) {
                SEL selector = NSSelectorFromString(name);
                if ([host respondsToSelector:selector]) {
                    engine++;
                    if (![guide respondsToSelector:selector])
                        why = [NSString stringWithFormat:@"a view answers %@ and a guide does not", name];
                }
            }
            charon_check(why == nil, "a guide answers the engine's item selectors that a view answers", why);
            NSString *described = nil;
            @try { described = [(id)guide performSelector:NSSelectorFromString(@"nsli_description")]; } @catch (NSException *e) { described = [NSString stringWithFormat:@"raised: %@", e.reason]; }
            charon_check([described isKindOfClass:[NSString class]] && ![described hasPrefix:@"raised"], "and answers them as the view behind it does", described);
            printf("view answers %lu of the probed selectors\n", (unsigned long)engine);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"guideitem.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([GuideItemDelegate class]));
    }
}
