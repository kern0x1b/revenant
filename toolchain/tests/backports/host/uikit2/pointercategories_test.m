#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

extern NSInteger CharonHostUIEventButtonMaskForButtonNumber(NSInteger buttonNumber);
extern NSInteger CharonHostUIEventButtonMaskForButtonNumber(NSInteger buttonNumber);

void charon_windowed_run(UIWindow *window);

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
}

static NSString *raised(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@ %@", exception.name, norm(exception.reason)];
    }
}

static void agree(NSString *name, NSArray *ours, NSArray *system)
{
    NSMutableString *detail = [NSMutableString string];
    for (NSUInteger index = 0; index < MAX(ours.count, system.count); index++) {
        NSString *a = index < ours.count ? ours[index] : @"<none>", *b = index < system.count ? system[index] : @"<none>";
        if (![a isEqual:b])
            [detail appendFormat:@"\n    port   %@\n    system %@", a, b];
    }
    charon_check(detail.length == 0, name.UTF8String, detail);
}

static NSString *line(NSString *label, id value)
{
    return [NSString stringWithFormat:@"%@ %@", label, norm(value)];
}

static NSString *yes(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static NSArray *button_lines(UIView *window)
{
    NSMutableArray *lines = [NSMutableArray array];
    SEL enabled = NSSelectorFromString(@"charonHostIsPointerInteractionEnabled"), set_enabled = NSSelectorFromString(@"charonHostSetPointerInteractionEnabled:"),
        get_selector = NSSelectorFromString(@"charonHostPointerStyleProvider"), set_selector = NSSelectorFromString(@"charonHostSetPointerStyleProvider:");
    for (int ours = 0; ours < 2; ours++) {
        NSMutableArray *rows = [NSMutableArray array];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [window addSubview:button];
        BOOL (^is_on)(void) = ^BOOL { return ours ? ((BOOL (*)(id, SEL))objc_msgSend)(button, enabled) : button.pointerInteractionEnabled; };
        void (^set_on)(BOOL) = ^(BOOL on) { if (ours) ((void (*)(id, SEL, BOOL))objc_msgSend)(button, set_enabled, on); else button.pointerInteractionEnabled = on; };
        id (^get_provider)(void) = ^id { return ours ? ((id (*)(id, SEL))objc_msgSend)(button, get_selector) : (id)button.pointerStyleProvider; };
        void (^set_provider)(id) = ^(id block) { if (ours) ((void (*)(id, SEL, id))objc_msgSend)(button, set_selector, block); else button.pointerStyleProvider = block; };
        NSUInteger base = button.interactions.count;
        id block = ^UIPointerStyle *(UIButton *b, UIPointerEffect *e, UIPointerShape *s) { return nil; };
        [rows addObject:line(@"fresh", @[yes(is_on()), get_provider() ? @"provider" : @"none"])];
        set_provider(block);
        [rows addObject:line(@"provider enables it", @[yes(is_on()), get_provider() ? @"provider" : @"none", @(button.interactions.count - base)])];
        set_on(NO);
        [rows addObject:line(@"off keeps the provider", @[yes(is_on()), get_provider() ? @"provider" : @"none", @(button.interactions.count - base)])];
        set_on(YES);
        set_on(YES);
        [rows addObject:line(@"on adds one interaction", @[yes(is_on()), @(button.interactions.count - base)])];
        set_provider(nil);
        [rows addObject:line(@"no provider keeps it on", @[yes(is_on()), get_provider() ? @"provider" : @"none", @(button.interactions.count - base)])];
        UIButton *plain = [UIButton buttonWithType:UIButtonTypeCustom];
        [rows addObject:line(@"custom button", yes(ours ? ((BOOL (*)(id, SEL))objc_msgSend)(plain, enabled) : plain.pointerInteractionEnabled))];
        [lines addObject:[rows componentsJoinedByString:@"\n"]];
        [button removeFromSuperview];
    }
    return @[lines[0], lines[1]];
}

static NSArray *gesture_lines(BOOL ours)
{
    NSMutableArray *lines = [NSMutableArray array];
    SEL modifiers = NSSelectorFromString(@"charonHostModifierFlags"), mask = NSSelectorFromString(@"charonHostButtonMask"), receive = NSSelectorFromString(@"charonHostShouldReceiveEvent:"),
        required = NSSelectorFromString(@"charonHostButtonMaskRequired"), set_required = NSSelectorFromString(@"charonHostSetButtonMaskRequired:");
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] init];
    UIEvent *event = [[UIEvent alloc] init];
    [lines addObject:line(@"recognizer", @[@(ours ? ((NSInteger (*)(id, SEL))objc_msgSend)(pan, modifiers) : pan.modifierFlags), @(ours ? ((NSInteger (*)(id, SEL))objc_msgSend)(pan, mask) : pan.buttonMask),
                                            yes(ours ? ((BOOL (*)(id, SEL, id))objc_msgSend)(pan, receive, event) : [pan shouldReceiveEvent:event])])];
    [lines addObject:line(@"event", @[@(ours ? ((NSInteger (*)(id, SEL))objc_msgSend)(event, modifiers) : event.modifierFlags), @(ours ? ((NSInteger (*)(id, SEL))objc_msgSend)(event, mask) : event.buttonMask)])];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    NSInteger (^get)(void) = ^NSInteger { return ours ? ((NSInteger (*)(id, SEL))objc_msgSend)(tap, required) : tap.buttonMaskRequired; };
    [lines addObject:line(@"required at first", @(get()))];
    for (NSNumber *value in @[@8, @3, @1, @0, @-1, @2])
        [lines addObject:raised(^id {
            if (ours)
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(tap, set_required, value.integerValue);
            else
                tap.buttonMaskRequired = (UIEventButtonMask)value.integerValue;
            return @(get());
        })];
    return lines;
}

void charon_windowed_run(UIWindow *window)
{
    BOOL masks = YES;
    NSMutableString *bad = [NSMutableString string];
    for (NSInteger number = -70; number < 200; number++) {
        NSInteger ours = CharonHostUIEventButtonMaskForButtonNumber(number), system = UIEventButtonMaskForButtonNumber(number);
        if (ours != system) {
            masks = NO;
            [bad appendFormat:@" %ld:%ld/%ld", (long)number, (long)ours, (long)system];
        }
    }
    charon_check(masks, "UIEventButtonMaskForButtonNumber answers as the system's does", bad);

    NSArray *buttons = button_lines(window);
    charon_check([buttons[0] isEqual:buttons[1]], "a button's pointer interaction and style provider", ([NSString stringWithFormat:@"\n    port   %@\n    system %@", buttons[1], buttons[0]]));
    agree(@"gesture recognizer and event members", gesture_lines(YES), gesture_lines(NO));
}
