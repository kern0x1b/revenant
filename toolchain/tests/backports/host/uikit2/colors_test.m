#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wnonnull"

void charon_windowed_run(UIWindow *window);

@interface CharonTarget : NSObject
@property (nonatomic) int hits;
- (void)hit;
@end

@implementation CharonTarget

- (void)hit
{
    self.hits++;
}

@end

@interface CharonPickerDelegate : NSObject <UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray *log;
@property (nonatomic) BOOL oldStyle;
@end

@implementation CharonPickerDelegate

- (instancetype)init
{
    if ((self = [super init]))
        self.log = [NSMutableArray array];
    return self;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(colorPickerViewController:didSelectColor:continuously:))
        return !self.oldStyle;
    if (selector == @selector(colorPickerViewControllerDidSelectColor:))
        return self.oldStyle;
    return [super respondsToSelector:selector];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)viewController didSelectColor:(UIColor *)color continuously:(BOOL)continuously
{
    [self.log addObject:[NSString stringWithFormat:@"select %@ %d", color, continuously]];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController
{
    [self.log addObject:[NSString stringWithFormat:@"old %@", viewController.selectedColor]];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController
{
    [self.log addObject:@"finish"];
}

@end

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
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

static NSString *color_text(UIColor *color)
{
    if (!color)
        return @"nil";
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha])
        return @"not rgb";
    return [NSString stringWithFormat:@"%.3f %.3f %.3f %.3f", red, green, blue, alpha];
}

static NSArray *well_lines(Class well_class, UIWindow *window)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIColorWell *well = [[well_class alloc] init];
    [lines addObject:line(@"defaults", @[yes(well.supportsAlpha), well.title ?: @"no title", color_text(well.selectedColor), yes(well.enabled), yes(well.userInteractionEnabled), yes(well.opaque),
                                          NSStringFromCGRect(well.frame), well.backgroundColor ?: @"no background", yes(well.isAccessibilityElement), well.accessibilityLabel ?: @"no label",
                                          @(well.gestureRecognizers.count), @(well.allTargets.count), @(well.allControlEvents), @(well.state), yes(well.hidden), @(well.alpha)])];
    [lines addObject:line(@"framed", NSStringFromCGRect(((UIColorWell *)[[well_class alloc] initWithFrame:CGRectMake(1, 2, 3, 4)]).frame))];
    CharonTarget *target = [[CharonTarget alloc] init];
    [well addTarget:target action:@selector(hit) forControlEvents:UIControlEventValueChanged];
    well.selectedColor = [UIColor redColor];
    well.supportsAlpha = NO;
    well.title = @"x";
    [lines addObject:line(@"set", @[@(target.hits), color_text(well.selectedColor), yes(well.supportsAlpha), well.title])];
    well.selectedColor = [UIColor colorWithRed:0.25 green:0.5 blue:0.75 alpha:0.5];
    [lines addObject:line(@"a translucent color", color_text(well.selectedColor))];
    well.selectedColor = nil;
    [lines addObject:line(@"cleared", color_text(well.selectedColor))];
    NSMutableString *title = [NSMutableString stringWithString:@"q"];
    well.title = title;
    [title appendString:@"z"];
    [lines addObject:line(@"the title is a copy", well.title)];
    well.title = nil;
    [lines addObject:line(@"title cleared", well.title ?: @"nil")];
    [lines addObject:line(@"superclass", NSStringFromClass(class_getSuperclass(well_class)))];
    return lines;
}

static NSArray *picker_lines(Class picker_class)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIColorPickerViewController *picker = [[picker_class alloc] init];
    [lines addObject:line(@"defaults", @[color_text(picker.selectedColor), yes(picker.supportsAlpha), (id)picker.delegate ?: @"no delegate", @(picker.modalPresentationStyle), picker.title ?: @"no title",
                                          yes(picker.isViewLoaded), @(picker.modalTransitionStyle), yes(picker.definesPresentationContext), picker.presentingViewController ?: @"not presented"])];
    picker.selectedColor = [UIColor redColor];
    [lines addObject:line(@"selected", color_text(picker.selectedColor))];
    picker.selectedColor = nil;
    [lines addObject:line(@"nil leaves it", color_text(picker.selectedColor))];
    picker.selectedColor = [UIColor colorWithRed:0.25 green:0.5 blue:0.75 alpha:0.5];
    [lines addObject:line(@"translucent", color_text(picker.selectedColor))];
    picker.supportsAlpha = NO;
    [lines addObject:line(@"alpha off", yes(picker.supportsAlpha))];
    CharonPickerDelegate *delegate = [[CharonPickerDelegate alloc] init];
    picker.delegate = delegate;
    [lines addObject:line(@"delegate", yes(picker.delegate == delegate))];
    UIColorPickerViewController *brief;
    @autoreleasepool {
        CharonPickerDelegate *short_lived = [[CharonPickerDelegate alloc] init];
        brief = [[picker_class alloc] init];
        brief.delegate = short_lived;
    }
    [lines addObject:line(@"delegate is weak", (id)brief.delegate ?: @"gone")];
    [lines addObject:line(@"superclass", NSStringFromClass(class_getSuperclass(picker_class)))];
    return lines;
}

static void spin(NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

void charon_windowed_run(UIWindow *window)
{
    Class ourWell = NSClassFromString(@"CharonHostUIColorWell"), ourPicker = NSClassFromString(@"CharonHostUIColorPickerViewController");
    charon_check(ourWell && ourPicker && class_getSuperclass(ourWell) == [UIControl class] && class_getSuperclass(ourPicker) == [UIViewController class], "the port's classes are linked under their host names and descend from UIControl and UIViewController",
                 @"one is missing");
    agree(@"color well", well_lines(ourWell, window), well_lines([UIColorWell class], window));
    agree(@"color picker", picker_lines(ourPicker), picker_lines([UIColorPickerViewController class]));
    charon_check(![ourWell instancesRespondToSelector:NSSelectorFromString(@"supportsEyedropper")] && [UIColorWell instancesRespondToSelector:NSSelectorFromString(@"supportsEyedropper")]
                     && ![ourPicker instancesRespondToSelector:NSSelectorFromString(@"maximumLinearExposure")] && [UIColorPickerViewController instancesRespondToSelector:NSSelectorFromString(@"maximumLinearExposure")],
                 "the well and the picker leave the members of iOS 26 to the release", @"one is answered");
    UIColorPickerViewController *nib = [[[ourPicker alloc] performSelector:NSSelectorFromString(@"initWithNibName:bundle:") withObject:nil withObject:nil] self];
    charon_check(nib.supportsAlpha && nib.modalPresentationStyle == UIModalPresentationFormSheet && [color_text(nib.selectedColor) isEqual:@"0.000 0.000 0.000 1.000"], "a picker made by the unavailable nib initializer is the same as any other", @"it differs");

    UIColorPickerViewController *picker = [[ourPicker alloc] init];
    CharonPickerDelegate *delegate = [[CharonPickerDelegate alloc] init];
    picker.delegate = delegate;
    picker.selectedColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.5];
    UIView *view = picker.view;
    view.frame = CGRectMake(0, 0, 320, 480);
    [view layoutIfNeeded];
    charon_check(picker.isViewLoaded && view.subviews.count >= 4, "the picker builds a view of a bar, a grid, a swatch and a slider", ([NSString stringWithFormat:@"%@", view.subviews]));
    UIView *grid = nil;
    UISlider *slider = nil;
    UINavigationBar *bar = nil;
    for (UIView *sub in view.subviews) {
        if ([NSStringFromClass([sub class]) hasSuffix:@"CharonColorGrid"])
            grid = sub;
        if ([sub isKindOfClass:[UISlider class]])
            slider = (UISlider *)sub;
        if ([sub isKindOfClass:[UINavigationBar class]])
            bar = (UINavigationBar *)sub;
    }
    charon_check(grid && slider && bar && CGRectGetHeight(grid.frame) > 200 && !slider.hidden && fabs(slider.value - 0.5) < 0.01, "the grid fills the view and the slider shows the alpha of the selected color",
                 ([NSString stringWithFormat:@"%@ %@", grid, slider]));
    UIGraphicsBeginImageContextWithOptions(grid.bounds.size, YES, 1);
    [grid.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGFloat cell_w = CGRectGetWidth(grid.bounds) / 12, cell_h = CGRectGetHeight(grid.bounds) / 10;
    NSString *(^sample)(CGFloat, CGFloat) = ^NSString *(CGFloat column, CGFloat row) {
        CGPoint point = CGPointMake((column + 0.5) * cell_w, (row + 0.5) * cell_h);
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), YES, 1);
        [image drawAtPoint:CGPointMake(-point.x, -point.y)];
        UIImage *one = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CGDataProviderRef provider = CGImageGetDataProvider(one.CGImage);
        CFDataRef data = CGDataProviderCopyData(provider);
        const UInt8 *bytes = CFDataGetBytePtr(data);
        NSString *text = [NSString stringWithFormat:@"%d %d %d", bytes[2], bytes[1], bytes[0]];
        CFRelease(data);
        return text;
    };
    charon_check([sample(0, 0) isEqual:@"255 255 255"] && [sample(11, 0) isEqual:@"0 0 0"] && [sample(0, 5) isEqual:@"255 0 0"], "the grid draws white to black in its first row and full colors in the middle", ([NSString stringWithFormat:@"%@ %@ %@", sample(0, 0), sample(11, 0), sample(0, 5)]));

    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(0.5 * cell_w, 5.5 * cell_h), YES);
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(4.5 * cell_w, 5.5 * cell_h), NO);
    charon_check(delegate.log.count == 2 && [color_text(picker.selectedColor) isEqual:@"0.000 1.000 0.000 0.500"] && [delegate.log[0] hasPrefix:@"select "] && [delegate.log[0] hasSuffix:@" 1"] && [delegate.log[1] hasSuffix:@" 0"],
                 "touching the grid selects a color, keeps the alpha and tells the delegate, continuously while the finger moves", ([NSString stringWithFormat:@"%@ %@", delegate.log, color_text(picker.selectedColor)]));
    slider.value = 1;
    ((void (*)(id, SEL, id))objc_msgSend)(picker, NSSelectorFromString(@"charon_alphaChanged:"), slider);
    charon_check([color_text(picker.selectedColor) isEqual:@"0.000 1.000 0.000 1.000"], "the slider changes the alpha", color_text(picker.selectedColor));
    picker.supportsAlpha = NO;
    charon_check(slider.hidden, "a picker that does not support alpha hides the slider", @"it shows");
    picker.selectedColor = [UIColor blueColor];
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(8.5 * cell_w, 5.5 * cell_h), NO);
    charon_check([color_text(picker.selectedColor) hasSuffix:@"1.000"], "and picks an opaque color", color_text(picker.selectedColor));
    CharonPickerDelegate *old = [[CharonPickerDelegate alloc] init];
    old.oldStyle = YES;
    picker.delegate = old;
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(1.5 * cell_w, 5.5 * cell_h), YES);
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(1.5 * cell_w, 5.5 * cell_h), NO);
    charon_check(old.log.count == 1 && [old.log[0] hasPrefix:@"old "], "a delegate of iOS 14 is told once, when the finger lifts", ([NSString stringWithFormat:@"%@", old.log]));
    ((void (*)(id, SEL))objc_msgSend)(picker, NSSelectorFromString(@"charon_done"));
    charon_check([old.log.lastObject isEqual:@"finish"], "Done tells the delegate of a picker that is not presented at once", ([NSString stringWithFormat:@"%@", old.log]));

    UIViewController *host = window.rootViewController;
    UIColorWell *well = [[ourWell alloc] initWithFrame:CGRectMake(10, 10, 44, 44)];
    [host.view addSubview:well];
    CharonTarget *target = [[CharonTarget alloc] init];
    [well addTarget:target action:@selector(hit) forControlEvents:UIControlEventValueChanged];
    well.title = @"Fill";
    well.supportsAlpha = NO;
    well.selectedColor = [UIColor greenColor];
    [well layoutIfNeeded];
    charon_check(well.layer.sublayers.count == 2 && CGSizeEqualToSize([well sizeThatFits:CGSizeZero], CGSizeMake(44, 44)), "the well draws a ring and a swatch and is 44 points square", ([NSString stringWithFormat:@"%@", well.layer.sublayers]));
    ((void (*)(id, SEL))objc_msgSend)(well, NSSelectorFromString(@"charon_present"));
    spin(1.0);
    UIViewController *shown = host.presentedViewController;
    charon_check(shown && [shown isKindOfClass:ourPicker], "tapping the well presents a color picker", ([NSString stringWithFormat:@"%@", shown]));
    UIColorPickerViewController *presented = (UIColorPickerViewController *)shown;
    charon_check(presented && !presented.supportsAlpha && [presented.title isEqual:@"Fill"] && [color_text(presented.selectedColor) isEqual:@"0.000 1.000 0.000 1.000"] && presented.delegate == (id)well,
                 "the picker starts with the well's color, title and alpha setting, and the well is its delegate", ([NSString stringWithFormat:@"%@", presented]));
    ((void (*)(id, SEL, id, BOOL))objc_msgSend)(presented, NSSelectorFromString(@"charon_pickColor:continuously:"), [UIColor magentaColor], YES);
    charon_check(target.hits == 1 && [color_text(well.selectedColor) isEqual:@"1.000 0.000 1.000 1.000"], "choosing a color sets it on the well and sends value changed", ([NSString stringWithFormat:@"%d %@", target.hits, color_text(well.selectedColor)]));
    [delegate.log removeAllObjects];
    presented.delegate = delegate;
    ((void (*)(id, SEL))objc_msgSend)(presented, NSSelectorFromString(@"charon_done"));
    spin(0.5);
    charon_check(host.presentedViewController == presented, "the presentation of a Mac Catalyst tool never completes, so dismissal is held to the device test only", @"it changed");
    UIColorWell *loose = [[ourWell alloc] init];
    ((void (*)(id, SEL))objc_msgSend)(loose, NSSelectorFromString(@"charon_present"));
    charon_check(host.presentedViewController == presented, "a well outside any view controller presents nothing", @"it presented");
}
