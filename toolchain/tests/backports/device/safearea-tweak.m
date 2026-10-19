#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#import "check.h"

static NSMutableString *charon_report;

static void note(NSString *line)
{
    [charon_report appendFormat:@"%@\n", line];
    [charon_report writeToFile:@"/private/var/backports/safearea.log" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#undef CHECK
#define CHECK(condition, name) do { \
        BOOL charon_passed = (condition) ? YES : NO; \
        charon_check(charon_passed, name, @#condition); \
        note([NSString stringWithFormat:@"%s %s%@", charon_passed ? "ok  " : "FAIL", name, \
              charon_passed ? @"" : [NSString stringWithFormat:@" (%s)", #condition]]); \
    } while (0)



static NSString *const results_folder = @"/private/var/backports";

static NSString *text(UIEdgeInsets insets)
{
    return [NSString stringWithFormat:@"{%g, %g, %g, %g}", insets.top, insets.left, insets.bottom, insets.right];
}

static void expect(UIView *view, UIEdgeInsets wanted, const char *name)
{
    note([NSString stringWithFormat:@"> %s", name]);
    UIEdgeInsets found = view.safeAreaInsets;
    BOOL passed = UIEdgeInsetsEqualToEdgeInsets(found, wanted);
    charon_check(passed, name, [NSString stringWithFormat:@"%@ != %@", text(found), text(wanted)]);
    note([NSString stringWithFormat:@"%@ %s: %@ wanted %@", passed ? @"ok  " : @"FAIL", name, text(found), text(wanted)]);
}

static NSString *image_of(void *pointer)
{
    Dl_info info;
    if (!pointer || !dladdr(pointer, &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static void check_sources(void)
{
    NSString *library = @"libUIKitBackports.dylib";
    CHECK_EQUAL(image_of((void *)method_getImplementation(class_getInstanceMethod([UIView class], @selector(safeAreaInsets)))),
                library, "-[UIView safeAreaInsets] comes from the backports");
    CHECK_EQUAL(image_of((void *)method_getImplementation(class_getInstanceMethod([UIViewController class], @selector(additionalSafeAreaInsets)))),
                library, "-[UIViewController additionalSafeAreaInsets] comes from the backports");
}

static void check_absent(void)
{
    CHECK(![[UIView new] respondsToSelector:@selector(safeAreaInsetsDidChange)], "UIView does not claim -safeAreaInsetsDidChange");
    CHECK(![[UIViewController new] respondsToSelector:@selector(viewSafeAreaInsetsDidChange)], "UIViewController does not claim -viewSafeAreaInsetsDidChange");
    CHECK(![[UIView new] respondsToSelector:@selector(safeAreaLayoutGuide)], "UIView does not claim -safeAreaLayoutGuide");
}

static void run(void)
{
    check_sources();
    check_absent();

    UIApplication *application = [UIApplication sharedApplication];
    CGFloat statusBar = CGRectGetHeight(application.statusBarFrame);
    CHECK(statusBar > 0, "the status bar has a height");

    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *controller = [UIViewController new];
    window.rootViewController = controller;
    window.hidden = NO;
    window.windowLevel = UIWindowLevelNormal - 1;

    expect(window, UIEdgeInsetsMake(statusBar, 0, 0, 0), "the window is inset by the status bar");

    UIView *root = controller.view;
    root.frame = CGRectMake(0, statusBar, CGRectGetWidth(window.bounds), CGRectGetHeight(window.bounds) - statusBar);
    expect(root, UIEdgeInsetsZero, "a view below the status bar is not inset");

    root.frame = window.bounds;
    expect(root, UIEdgeInsetsMake(statusBar, 0, 0, 0), "a view under the status bar is inset by it");

    controller.additionalSafeAreaInsets = UIEdgeInsetsMake(10, 5, 15, 20);
    UIEdgeInsets full = UIEdgeInsetsMake(statusBar + 10, 5, 15, 20);
    expect(root, full, "the additional insets add to what the bars give");

    UIView *middle = [[UIView alloc] initWithFrame:CGRectMake(60, 80, 100, 100)];
    [root addSubview:middle];
    expect(middle, UIEdgeInsetsZero, "a subview away from every edge is not inset");

    CGRect bounds = root.bounds;
    UIView *top = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(bounds), 100)];
    [root addSubview:top];
    expect(top, UIEdgeInsetsMake(full.top, full.left, 0, full.right), "a subview at the top carries three of the insets");

    UIView *bottom = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(bounds) - 100, CGRectGetWidth(bounds), 100)];
    [root addSubview:bottom];
    expect(bottom, UIEdgeInsetsMake(0, full.left, full.bottom, full.right), "a subview at the bottom carries the other three");

    UIView *nested = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(bounds), 10)];
    [top addSubview:nested];
    expect(nested, UIEdgeInsetsMake(MIN(full.top, 10), full.left, 0, full.right), "a nested subview keeps what its own frame still covers");

    CHECK(![[UIScrollView new] respondsToSelector:@selector(adjustedContentInsetDidChange)],
          "UIScrollView does not claim -adjustedContentInsetDidChange");
    CHECK(![[UIViewController new] respondsToSelector:@selector(systemMinimumLayoutMargins)],
          "UIViewController does not claim -systemMinimumLayoutMargins");
    CHECK(![[UIViewController new] respondsToSelector:@selector(viewRespectsSystemMinimumLayoutMargins)],
          "UIViewController does not claim -viewRespectsSystemMinimumLayoutMargins");

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:root.bounds];
    [root addSubview:scroll];
    UIEdgeInsets area = scroll.safeAreaInsets;
    note([NSString stringWithFormat:@"scroll safe area %@", text(area)]);

    scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.adjustedContentInset, UIEdgeInsetsZero),
          "never adjusting leaves the content inset alone");

    scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.adjustedContentInset, area),
          "always adjusting adds the whole safe area");

    scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentScrollableAxes;
    scroll.contentSize = CGSizeMake(10, 10);
    CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.adjustedContentInset, UIEdgeInsetsZero),
          "content that does not scroll gets no safe area at all");

    scroll.contentSize = CGSizeMake(10, CGRectGetHeight(scroll.bounds) * 2);
    CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.adjustedContentInset, UIEdgeInsetsMake(area.top, 0, area.bottom, 0)),
          "content taller than the frame takes the vertical safe area");

    scroll.contentSize = CGSizeMake(10, 10);
    scroll.alwaysBounceVertical = YES;
    CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.adjustedContentInset, UIEdgeInsetsMake(area.top, 0, area.bottom, 0)),
          "bouncing vertically counts as scrolling");
    scroll.alwaysBounceVertical = NO;

    scroll.contentSize = CGSizeMake(CGRectGetWidth(scroll.bounds) * 2, CGRectGetHeight(scroll.bounds) * 2);
    CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.adjustedContentInset, area),
          "content larger both ways takes the whole safe area");

    scroll.contentInset = UIEdgeInsetsMake(5, 6, 7, 8);
    CHECK(UIEdgeInsetsEqualToEdgeInsets(scroll.adjustedContentInset,
                                        UIEdgeInsetsMake(5 + area.top, 6 + area.left, 7 + area.bottom, 8 + area.right)),
          "the content inset and the safe area add up");
    scroll.contentInset = UIEdgeInsetsZero;
    [scroll removeFromSuperview];

    UIFontMetrics *body = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
    CGFloat screen = [UIScreen mainScreen].scale;
    note([NSString stringWithFormat:@"screen scale %g", screen]);
    CHECK([body scaledValueForValue:10] == 10, "a whole value is left alone");
    CHECK([body scaledValueForValue:10.3] == round(10.3 * screen) / screen, "a value is rounded to the screen scale");
    CHECK([body scaledValueForValue:-3.3] == round(-3.3 * screen) / screen, "a negative value rounds the same way");
    UIFont *seventeen = [UIFont systemFontOfSize:17];
    CHECK([body scaledFontForFont:seventeen].pointSize == 17, "a font keeps its size where one category exists");
    CHECK([body scaledFontForFont:seventeen maximumPointSize:12].pointSize == 12, "a maximum point size caps the font");
    UIFont *same_size = [body scaledFontForFont:seventeen];
    CHECK([same_size.fontName isEqual:seventeen.fontName] && same_size.pointSize == seventeen.pointSize,
          "the scaled font keeps the family and the size");
    CHECK(same_size == seventeen, "this release hands back the very font it was given when the size does not change");
    CHECK([body scaledFontForFont:seventeen maximumPointSize:12] != seventeen,
          "a font of another size is another object");
    CGFloat fromDefault = [[UIFontMetrics defaultMetrics] scaledValueForValue:10.3];
    CGFloat fromBody = [body scaledValueForValue:10.3];
    note([NSString stringWithFormat:@"default %g body %g", fromDefault, fromBody]);
    CHECK(fromDefault == fromBody, "the default metrics scale like the body");
    BOOL raised = NO;
    @try { [body scaledFontForFont:nil]; } @catch (NSException *exception) { raised = YES; }
    CHECK(raised, "a nil font is refused");

    UIView *loose = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    expect(loose, UIEdgeInsetsZero, "a view with no superview and no controller is not inset");

    UIView *margins = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    BOOL reversed = application.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    NSDirectionalEdgeInsets defaults = margins.directionalLayoutMargins;
    CHECK(defaults.top == 8 && defaults.leading == 8 && defaults.bottom == 8 && defaults.trailing == 8,
          "the directional margins start at eight on every edge");
    margins.layoutMargins = UIEdgeInsetsMake(1, 2, 3, 4);
    NSDirectionalEdgeInsets read = margins.directionalLayoutMargins;
    CHECK(read.top == 1 && read.bottom == 3 && read.leading == (reversed ? 4 : 2) && read.trailing == (reversed ? 2 : 4),
          "the directional margins read the plain ones by direction");
    margins.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(5, 6, 7, 8);
    UIEdgeInsets written = margins.layoutMargins;
    CHECK(written.top == 5 && written.bottom == 7 && written.left == (reversed ? 8 : 6) && written.right == (reversed ? 6 : 8),
          "the plain margins follow the directional ones by direction");
    NSDirectionalEdgeInsets back = margins.directionalLayoutMargins;
    CHECK(back.top == 5 && back.leading == 6 && back.bottom == 7 && back.trailing == 8,
          "the directional margins come back as they were set");
    margins.layoutMargins = UIEdgeInsetsMake(9, 10, 11, 12);
    NSDirectionalEdgeInsets last = margins.directionalLayoutMargins;
    CHECK(last.top == 9 && last.bottom == 11 && last.leading == (reversed ? 12 : 10) && last.trailing == (reversed ? 10 : 12),
          "the plain margins win when they are set last");

    UIView *left = [[UIView alloc] initWithFrame:CGRectZero], *right = [[UIView alloc] initWithFrame:CGRectZero];
    left.translatesAutoresizingMaskIntoConstraints = NO;
    right.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:left];
    [root addSubview:right];
    NSDictionary *pair = [NSDictionary dictionaryWithObjectsAndKeys:left, @"a", right, @"b", nil];
    NSArray *plain = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[a]-[b]" options:0 metrics:nil views:pair];
    NSArray *spaced = nil;
    NSString *complaint = nil;
    @try {
        spaced = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[a]-[b]" options:(1 << 19) metrics:nil views:pair];
    } @catch (NSException *exception) {
        complaint = exception.name;
    }
    note([NSString stringWithFormat:@"visual format with the baseline spacing option: raised %@, %lu constraints against %lu",
          complaint ?: @"nothing", (unsigned long)spaced.count, (unsigned long)plain.count]);
    CHECK(complaint == nil, "a visual format takes the iOS 11 spacing option without raising");
    CHECK(spaced.count == plain.count, "and makes the same number of constraints");
    if (spaced.count && plain.count) {
        NSLayoutConstraint *one = [spaced objectAtIndex:0], *other = [plain objectAtIndex:0];
        note([NSString stringWithFormat:@"the first constraint: %g against %g, attributes %ld/%ld against %ld/%ld",
              one.constant, other.constant, (long)one.firstAttribute, (long)one.secondAttribute,
              (long)other.firstAttribute, (long)other.secondAttribute]);
        CHECK(one.constant == other.constant && one.firstAttribute == other.firstAttribute
              && one.secondAttribute == other.secondAttribute,
              "and the option changes nothing about them");
    }
    [left removeFromSuperview];
    [right removeFromSuperview];

    controller.additionalSafeAreaInsets = UIEdgeInsetsMake(-10, 0, 0, 0);
    expect(root, UIEdgeInsetsMake(MAX(0, statusBar - 10), 0, 0, 0), "a negative additional inset takes away from what the bars give");

    controller.additionalSafeAreaInsets = UIEdgeInsetsMake(-100, -100, -100, -100);
    expect(root, UIEdgeInsetsZero, "and never takes the safe area below nothing");

    UIView *unheld = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    CHECK(UIEdgeInsetsEqualToEdgeInsets(unheld.safeAreaInsets, UIEdgeInsetsZero),
          "a view in no window at all has no safe area");

    controller.additionalSafeAreaInsets = UIEdgeInsetsZero;
    expect(root, UIEdgeInsetsMake(statusBar, 0, 0, 0), "clearing the additional insets restores what the bars alone give");

    window.hidden = YES;

    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"safearea.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

__attribute__((constructor)) static void safearea_tweak(void)
{
    charon_report = [NSMutableString string];
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    note(@"loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @autoreleasepool {
            @try {
                run();
            } @catch (NSException *exception) {
                note([NSString stringWithFormat:@"raised %@: %@", exception.name, exception.reason]);
                charon_check(NO, "the run raises no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
                NSString *summary = [NSString stringWithFormat:@"FAIL checks=%d failures=%d %@\n", charon_checks, charon_failures, exception.name];
                [summary writeToFile:[results_folder stringByAppendingPathComponent:@"safearea.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            }
        }
    });
}
