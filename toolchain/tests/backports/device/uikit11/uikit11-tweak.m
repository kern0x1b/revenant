#import <UIKit/UIKit.h>
#import "check.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "uikit11-expectations.h"

int charon_main_interactions(void);
int charon_main_systemspacing(void);
int charon_main_gesturename(void);
int charon_main_batchupdates(void);
int charon_main_contentsize(void);
void host_attach_prefixed(const char *prefix);

static NSString *const results_folder = @"/private/var/backports";
static NSMutableString *charon_report;
static NSMutableArray *charon_lines;
static NSMutableString *charon_pending;

static void note(NSString *line)
{
    [charon_report appendFormat:@"%@\n", line];
    [charon_report writeToFile:[results_folder stringByAppendingPathComponent:@"uikit11.log"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

int charon_printf(const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:@(format) arguments:arguments];
    va_end(arguments);
    [charon_pending appendString:text];
    NSRange end;
    while ((end = [charon_pending rangeOfString:@"\n"]).location != NSNotFound) {
        NSString *line = [charon_pending substringToIndex:end.location];
        [charon_pending deleteCharactersInRange:NSMakeRange(0, end.location + 1)];
        [charon_lines addObject:line];
        note([@"| " stringByAppendingString:line]);
    }
    return (int)text.length;
}

static NSDictionary *answers_of(NSArray *lines)
{
    NSMutableDictionary *answers = [NSMutableDictionary dictionary];
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^(?:  |ok   )(.+?): (.*)$" options:0 error:NULL];
    for (NSString *line in lines) {
        NSTextCheckingResult *match = [pattern firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!match)
            continue;
        NSString *name = [line substringWithRange:[match rangeAtIndex:1]];
        if (!answers[name])
            answers[name] = [line substringWithRange:[match rangeAtIndex:2]];
    }
    return answers;
}

static void run_test(NSString *test, int (*body)(void))
{
    note([NSString stringWithFormat:@"== %@", test]);
    charon_lines = [NSMutableArray array];
    charon_pending = [NSMutableString string];
    int before = charon_failures;
    int failed = -1;
    @try {
        body();
        failed = charon_failures - before;
    } @catch (NSException *exception) {
        charon_check(NO, [[test stringByAppendingString:@" raises nothing"] UTF8String], exception.reason);
        note([NSString stringWithFormat:@"FAIL %@ raised %@: %@", test, exception.name, exception.reason]);
    }
    NSUInteger ownFailures = 0;
    for (NSString *line in charon_lines)
        if ([line hasPrefix:@"FAIL"])
            ownFailures++;
    NSDictionary *answers = answers_of(charon_lines);
    for (unsigned index = 0; index < charon_expected_count; index++) {
        if (![@(charon_expected[index][0]) isEqualToString:test])
            continue;
        NSString *name = @(charon_expected[index][1]);
        NSString *wanted = @(charon_expected[index][2]);
        NSString *found = answers[name] ?: @"<not answered>";
        BOOL passed = [found isEqualToString:wanted];
        NSString *label = [NSString stringWithFormat:@"%@: %@", test, name];
        charon_check(passed, label.UTF8String, [NSString stringWithFormat:@"%@ != %@", found, wanted]);
        note([NSString stringWithFormat:@"%@ %@ = %@%@", passed ? @"ok  " : @"FAIL", label, found,
              passed ? @"" : [NSString stringWithFormat:@"  (host: %@)", wanted]]);
    }
    BOOL clean = failed == 0 && ownFailures == 0;
    NSString *label = [NSString stringWithFormat:@"%@ passes its own checks on this release", test];
    charon_check(clean, label.UTF8String, [NSString stringWithFormat:@"returned %d, %lu FAIL lines", failed, (unsigned long)ownFailures]);
    note([NSString stringWithFormat:@"%@ %@ (returned %d, %lu FAIL lines)", clean ? @"ok  " : @"FAIL", label, failed, (unsigned long)ownFailures]);
}


static void expect(NSString *found, NSString *wanted, NSString *name)
{
    BOOL passed = [found isEqualToString:wanted];
    charon_check(passed, name.UTF8String, [NSString stringWithFormat:@"%@ != %@", found, wanted]);
    note([NSString stringWithFormat:@"%@ %@ = %@%@", passed ? @"ok  " : @"FAIL", name, found, passed ? @"" : [NSString stringWithFormat:@"  (wanted %@)", wanted]]);
}

static NSString *image_of(IMP implementation)
{
    Dl_info info;
    if (!implementation || !dladdr((void *)implementation, &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static NSString *constraint_shape(NSLayoutConstraint *constraint)
{
    return [NSString stringWithFormat:@"constant %g attributes %ld %ld", constraint.constant, (long)constraint.firstAttribute, (long)constraint.secondAttribute];
}

static CGFloat baseline_formula(UIFont *below, UIFont *above)
{
    CGFloat value = below.lineHeight + below.descender - above.descender;
    CGFloat scale = [UIScreen mainScreen].scale;
    return ceil(value * scale) / scale;
}

static void release_system_spacing(void)
{
    note(@"== systemspacing on this release");
    UILabel *body = [UILabel new], *big = [UILabel new], *tiny = [UILabel new];
    body.font = [UIFont systemFontOfSize:17];
    big.font = [UIFont systemFontOfSize:40];
    tiny.font = [UIFont systemFontOfSize:9];
    note([NSString stringWithFormat:@"fonts: %@ 17 lineHeight %g descender %g; 40 lineHeight %g descender %g; 9 lineHeight %g descender %g; scale %g",
          body.font.fontName, body.font.lineHeight, body.font.descender, big.font.lineHeight, big.font.descender,
          tiny.font.lineHeight, tiny.font.descender, [UIScreen mainScreen].scale]);
    NSArray *pairs = @[@[body, body], @[tiny, big], @[big, tiny], @[body, big], @[big, body]];
    for (NSArray *pair in pairs) {
        UILabel *below = pair[0], *above = pair[1];
        NSLayoutConstraint *plain = [below.firstBaselineAnchor constraintEqualToAnchor:above.lastBaselineAnchor];
        NSString *wanted = [NSString stringWithFormat:@"constant %g attributes %ld %ld", baseline_formula(below.font, above.font),
                            (long)plain.firstAttribute, (long)plain.secondAttribute];
        expect(constraint_shape([below.firstBaselineAnchor constraintEqualToSystemSpacingBelowAnchor:above.lastBaselineAnchor multiplier:1]), wanted,
               [NSString stringWithFormat:@"%g point baseline below %g point baseline follows the formula with this release's fonts",
                below.font.pointSize, above.font.pointSize]);
    }
    NSLayoutConstraint *mixed = [body.firstBaselineAnchor constraintEqualToAnchor:big.bottomAnchor];
    expect(constraint_shape([body.firstBaselineAnchor constraintEqualToSystemSpacingBelowAnchor:big.bottomAnchor multiplier:1]),
           [NSString stringWithFormat:@"constant %g attributes %ld %ld", baseline_formula(body.font, big.font), (long)mixed.firstAttribute, (long)mixed.secondAttribute],
           @"a baseline below an edge follows the formula with this release's fonts");
    mixed = [body.topAnchor constraintEqualToAnchor:big.lastBaselineAnchor];
    expect(constraint_shape([body.topAnchor constraintEqualToSystemSpacingBelowAnchor:big.lastBaselineAnchor multiplier:1]),
           [NSString stringWithFormat:@"constant %g attributes %ld %ld", baseline_formula(body.font, big.font), (long)mixed.firstAttribute, (long)mixed.secondAttribute],
           @"an edge below a baseline follows the formula with this release's fonts");
    UIView *plainView = [UIView new], *another = [UIView new];
    NSLayoutConstraint *textless = [plainView.firstBaselineAnchor constraintEqualToAnchor:another.lastBaselineAnchor];
    expect(constraint_shape([plainView.firstBaselineAnchor constraintEqualToSystemSpacingBelowAnchor:another.lastBaselineAnchor multiplier:1]),
           [NSString stringWithFormat:@"constant 8 attributes %ld %ld", (long)textless.firstAttribute, (long)textless.secondAttribute],
           @"baselines of views with no text keep the plain spacing and the anchors' attributes");
}

static NSString *drawn_back_title(UINavigationItem *item)
{
    SEL current = NSSelectorFromString(@"currentBackButtonTitle");
    return [item respondsToSelector:current] ? (((id (*)(id, SEL))objc_msgSend)(item, current) ?: @"nil") : @"<no currentBackButtonTitle>";
}

static void collect_texts(UIView *view, NSMutableArray *into)
{
    if ([view isKindOfClass:[UILabel class]] && [(UILabel *)view text])
        [into addObject:[(UILabel *)view text]];
    SEL title = NSSelectorFromString(@"title");
    if (![view isKindOfClass:[UILabel class]] && [view respondsToSelector:title]) {
        id text = ((id (*)(id, SEL))objc_msgSend)(view, title);
        if ([text isKindOfClass:[NSString class]])
            [into addObject:text];
    }
    for (UIView *subview in view.subviews)
        collect_texts(subview, into);
}

static NSString *drawn_back_button(void (^configure)(UINavigationItem *home))
{
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    UINavigationItem *home = [[UINavigationItem alloc] initWithTitle:@"Home"];
    UINavigationItem *next = [[UINavigationItem alloc] initWithTitle:@"Next"];
    configure(home);
    [bar pushNavigationItem:home animated:NO];
    [bar pushNavigationItem:next animated:NO];
    [bar layoutIfNeeded];
    NSMutableArray *texts = [NSMutableArray array];
    collect_texts(bar, texts);
    [texts removeObject:@"Next"];
    return texts.count ? [texts componentsJoinedByString:@" | "] : @"nothing";
}

static void release_back_button(void)
{
    note(@"== backbuttontitle on this release");
    note([NSString stringWithFormat:@"-[UINavigationItem setBackButtonTitle:] comes from %@",
          image_of(class_getMethodImplementation([UINavigationItem class], @selector(setBackButtonTitle:)))]);
    note([NSString stringWithFormat:@"-[UINavigationItem backButtonTitle] comes from %@",
          image_of(class_getMethodImplementation([UINavigationItem class], @selector(backButtonTitle)))]);
    expect(drawn_back_button(^(UINavigationItem *home) { home.backButtonTitle = @"Up"; }), @"Up",
           @"the back button reads the back button title");
    expect(drawn_back_button(^(UINavigationItem *home) {
               home.backButtonTitle = @"Up";
               home.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Item" style:UIBarButtonItemStyleBordered target:nil action:NULL];
           }), @"Item", @"an application's own back item wins over the title");
    expect(drawn_back_button(^(UINavigationItem *home) {
               home.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Item" style:UIBarButtonItemStyleBordered target:nil action:NULL];
               home.backButtonTitle = @"Up";
           }), @"Item", @"and it wins whichever came first");
    expect(drawn_back_button(^(UINavigationItem *home) {
               home.backButtonTitle = @"Up";
               home.backButtonTitle = nil;
           }), @"Home", @"a title set to nil gives the item's own title back");
    expect(drawn_back_button(^(UINavigationItem *home) { }), @"Home", @"with neither, the item's own title is drawn");
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Home"];
    item.backButtonTitle = @"Up";
    expect(item.backBarButtonItem ? @"an item" : @"nil", @"nil", @"a back button title leaves backBarButtonItem alone on this release");
}

static NSMutableArray *batch_order;

static void release_batch_updates(void)
{
    note(@"== batchupdates on this release");
    static UITableView *table;
    static id source;
    table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400) style:UITableViewStylePlain];
    batch_order = [NSMutableArray array];
    [batch_order addObject:@"before"];
    [table performBatchUpdates:^{
        [batch_order addObject:@"inside"];
    } completion:^(BOOL finished) {
        [batch_order addObject:[NSString stringWithFormat:@"completion finished %d", finished]];
    }];
    [batch_order addObject:@"after the call"];
    (void)source;
}

static void run(void)
{
    host_attach_prefixed("charonHost_");
    run_test(@"interactions", charon_main_interactions);
    run_test(@"systemspacing", charon_main_systemspacing);
    run_test(@"gesturename", charon_main_gesturename);
    run_test(@"batchupdates", charon_main_batchupdates);
    run_test(@"contentsize", charon_main_contentsize);
    release_system_spacing();
    release_back_button();
    release_batch_updates();
}

__attribute__((constructor)) static void charon_uikit11_start(void)
{
    charon_report = [NSMutableString string];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @autoreleasepool {
            note(@"start");
            @try {
                run();
            } @catch (NSException *exception) {
                charon_check(NO, "the run raises no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
                note([NSString stringWithFormat:@"FAIL the run raised %@: %@", exception.name, exception.reason]);
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                expect([batch_order componentsJoinedByString:@" | "], @"before | inside | after the call | completion finished 1",
                       @"batch updates: the completion comes once, after the call, once the handler has returned");
                note([NSString stringWithFormat:@"%@ checks=%d failures=%d", charon_failures ? @"FAIL" : @"PASS", charon_checks, charon_failures]);
                [@"done" writeToFile:[results_folder stringByAppendingPathComponent:@"uikit11.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            });
        }
    });
}
