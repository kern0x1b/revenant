#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const results_folder = @"/private/var/backports";

extern NSString *const UIKeyInputHome, *const UIKeyInputEnd, *const UIKeyInputF1, *const UIKeyInputF6, *const UIKeyInputF12;
extern UIEventButtonMask UIEventButtonMaskForButtonNumber(NSInteger buttonNumber);

static NSString *text(id object)
{
    return [NSString stringWithFormat:@"%@", object];
}

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static BOOL from_backports(const void *address)
{
    Dl_info info;
    const char *slash;
    return dladdr(address, &info) && (slash = strrchr(info.dli_fname, '/')) && !strcmp(slash + 1, "libUIKitBackports.dylib");
}

static BOOL class_from_backports(Class cls)
{
    return from_backports((__bridge const void *)cls);
}

static BOOL method_from_backports(Class cls, SEL selector)
{
    Method method = class_getInstanceMethod(cls, selector);
    return method && from_backports((const void *)method_getImplementation(method));
}

@interface CharonPickerReport : NSObject <UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray *log;
@end

@implementation CharonPickerReport

- (void)colorPickerViewController:(UIColorPickerViewController *)viewController didSelectColor:(UIColor *)color continuously:(BOOL)continuously
{
    [self.log addObject:continuously ? @"selecting" : @"selected"];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController
{
    [self.log addObject:@"finish"];
}

@end

@interface CharonEventCounter : NSObject
@property (nonatomic) int hits;
- (void)hit;
@end

@implementation CharonEventCounter

- (void)hit
{
    self.hits++;
}

@end

@interface CharonPointerDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *host;
@end

@implementation CharonPointerDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"pointer.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.host = [[UIViewController alloc] init];
    self.window.rootViewController = self.host;
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)runAndReport
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"pointer.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)run
{
    [self runPointer];
    [self runInteractions];
    [self runKeys];
    [self runSearch];
    [self runColors];
}

- (void)runPointer
{
    CHECK(class_from_backports([UIPointerInteraction class]) && class_from_backports([UIPointerStyle class]) && class_from_backports([UIPointerRegion class]) && class_from_backports([UIPointerShape class])
              && class_from_backports([UIPointerEffect class]) && class_from_backports([UIPointerHoverEffect class]) && class_from_backports([UIHoverGestureRecognizer class]) && class_from_backports([UIKey class]),
          "the pointer classes come from the backports library");
    CHECK(class_from_backports([UISearchTextField class]) && class_from_backports([UISearchToken class]) && class_from_backports([UIColorWell class]) && class_from_backports([UIColorPickerViewController class]),
          "the search and color classes come from the backports library");

    UIPointerRegion *region = [UIPointerRegion regionWithRect:CGRectMake(1, 2, 3, 4) identifier:@"x"];
    CHECK_EQUAL(region.identifier, @"x", "a region keeps its identifier");
    CHECK(CGRectEqualToRect(region.rect, CGRectMake(1, 2, 3, 4)) && region.latchingAxes == 0, "and its rect, and latches no axis");
    CHECK_EQUAL(text(region), ([NSString stringWithFormat:@"<UIPointerRegion: %p; rect = (1 2; 3 4); identifier = x>", region]), "a region describes itself as the system's does");
    region.latchingAxes = UIAxisVertical;
    UIPointerRegion *copy = [region copy];
    CHECK(copy != region && [copy isEqual:region] && copy.latchingAxes == UIAxisVertical && copy.hash == region.hash, "a copy is equal, with the same hash and axes");
    CHECK(![region isEqual:[UIPointerRegion regionWithRect:CGRectMake(1, 2, 3, 4) identifier:@"x"]], "a region with another latching axis is not equal");
    CHECK([[UIPointerRegion regionWithRect:CGRectMake(1.5f, 2.5f, 3.5f, 4.5f) identifier:nil] hash] == 4 && [[UIPointerRegion regionWithRect:CGRectMake(-1, -2, 3, 4) identifier:nil] hash] == 6,
          "its hash is the system's");

    UIPointerShape *round = [UIPointerShape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4)];
    UIPointerShape *radius = [UIPointerShape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4) cornerRadius:5];
    UIPointerShape *beam = [UIPointerShape beamWithPreferredLength:10 axis:UIAxisHorizontal];
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 5, 6)];
    UIPointerShape *shaped = [UIPointerShape shapeWithPath:path];
    CHECK(![round isEqual:radius] && [round isEqual:[UIPointerShape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4)]] && [shaped isEqual:[UIPointerShape shapeWithPath:[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 5, 6)]]],
          "shapes compare by rect, radius and path");
    CHECK(round.hash == 12 && radius.hash == 9 && beam.hash == 27, "their hashes are the system's");
    CHECK([text(radius) rangeOfString:@"rect = (1 2; 3 4); cornerRadius = 5>"].location != NSNotFound && [text(beam) rangeOfString:@"beamLength = 10 (horizontal)>"].location != NSNotFound,
          "and they describe themselves as the system's do");

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(10, 10, 100, 50)];
    [self.host.view addSubview:view];
    UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:view];
    UIPointerHoverEffect *hover = (UIPointerHoverEffect *)[UIPointerHoverEffect effectWithPreview:preview];
    CHECK(hover.preview == preview && hover.preferredTintMode == UIPointerEffectTintModeOverlay && !hover.prefersShadow && hover.prefersScaledContent, "a hover effect has the system's defaults");
    UIPointerHoverEffect *changed = (UIPointerHoverEffect *)[hover copy];
    changed.prefersShadow = YES;
    CHECK(![changed isEqual:hover] && [[UIPointerEffect effectWithPreview:preview] isEqual:[UIPointerHighlightEffect effectWithPreview:preview]] && ![[UIPointerHighlightEffect effectWithPreview:preview] isEqual:[UIPointerLiftEffect effectWithPreview:preview]],
          "effects compare by class, preview and settings");
    UIPointerStyle *style = [UIPointerStyle styleWithEffect:hover shape:round];
    UIPointerStyle *hidden = [UIPointerStyle hiddenPointerStyle];
    CHECK([style isEqual:[UIPointerStyle styleWithEffect:hover shape:[UIPointerShape shapeWithRoundedRect:CGRectMake(1, 2, 3, 4)]]] && ![style isEqual:hidden] && [hidden isEqual:[UIPointerStyle hiddenPointerStyle]] && hidden != [UIPointerStyle hiddenPointerStyle],
          "styles compare by kind, effect, shape and axes");
    CHECK([text(style) hasSuffix:@"type = content effect>"] && [text([UIPointerStyle styleWithShape:round constrainedAxes:UIAxisVertical]) hasSuffix:@"type = shape>"]
              && [text(hidden) hasSuffix:@"type = hidden>"],
          "and describe their kind");
    CHECK(![UIPointerStyle instancesRespondToSelector:@selector(accessories)], "a style does not answer the accessories of iOS 15");
}

- (void)runInteractions
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(10, 70, 100, 50)];
    [self.host.view addSubview:view];
    NSObject *delegate = [[NSObject alloc] init];
    UIPointerInteraction *interaction = [[UIPointerInteraction alloc] initWithDelegate:(id<UIPointerInteractionDelegate>)delegate];
    CHECK(interaction.enabled && interaction.view == nil && interaction.delegate == (id)delegate, "a pointer interaction is enabled, with its delegate and no view");
    [view addInteraction:interaction];
    CHECK(interaction.view == view && [view.interactions containsObject:interaction], "added to a view it knows the view");
    [interaction invalidate];
    interaction.enabled = NO;
    CHECK(!interaction.enabled, "it can be disabled");
    [view removeInteraction:interaction];
    CHECK(interaction.view == nil && ![view.interactions containsObject:interaction], "and removed");

    UIHoverGestureRecognizer *hover = [[UIHoverGestureRecognizer alloc] initWithTarget:self action:@selector(hovered:)];
    CHECK(hover.state == UIGestureRecognizerStatePossible && hover.enabled && hover.view == nil, "a hover recognizer is possible, enabled and has no view");
    [view addGestureRecognizer:hover];
    CHECK(hover.view == view && [view.gestureRecognizers containsObject:hover], "added to a view it knows the view");
    CHECK(![hover respondsToSelector:@selector(zOffset)] && ![hover respondsToSelector:@selector(altitudeAngle)], "it answers none of the members of iOS 16");
    [view removeGestureRecognizer:hover];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(10, 130, 100, 40);
    [self.host.view addSubview:button];
    NSUInteger base = button.interactions.count;
    CHECK(!button.pointerInteractionEnabled && button.pointerStyleProvider == nil, "a button has no pointer interaction at first");
    button.pointerStyleProvider = ^UIPointerStyle *(UIButton *b, UIPointerEffect *effect, UIPointerShape *shape) { return nil; };
    CHECK(button.pointerInteractionEnabled && button.pointerStyleProvider != nil && button.interactions.count == base + 1, "a style provider turns its pointer interaction on");
    button.pointerInteractionEnabled = NO;
    CHECK(!button.pointerInteractionEnabled && button.pointerStyleProvider != nil && button.interactions.count == base + 1, "off keeps the provider and the interaction");

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    CHECK(tap.buttonMaskRequired == UIEventButtonMaskPrimary && tap.buttonMask == 0 && tap.modifierFlags == 0 && [tap shouldReceiveEvent:[[UIEvent alloc] init]], "a tap recognizer requires the primary button and has no modifiers");
    BOOL raised = NO;
    @try {
        tap.buttonMaskRequired = (UIEventButtonMask)0;
    } @catch (NSException *exception) {
        raised = [exception.name isEqual:NSInternalInconsistencyException] && [exception.reason isEqual:@"buttonMaskRequired must be greater than 0"];
    }
    CHECK(raised, "and refuses a mask of zero");
    CHECK(UIEventButtonMaskForButtonNumber(0) == 1 && UIEventButtonMaskForButtonNumber(1) == 1 && UIEventButtonMaskForButtonNumber(2) == 2 && UIEventButtonMaskForButtonNumber(4) == 8 && UIEventButtonMaskForButtonNumber(-1) == 0
              && UIEventButtonMaskForButtonNumber(64) == 0,
          "the button mask of a button number is the system's");
    UIEvent *event = [[UIEvent alloc] init];
    CHECK(event.modifierFlags == 0 && event.buttonMask == 0, "an event has no modifiers and no buttons");
}

- (void)hovered:(id)sender
{
}

- (void)runKeys
{
    SEL maker = NSSelectorFromString(@"initCharonWithCharacters:unmodified:keyCode:modifierFlags:");
    UIKey *key = ((id (*)(id, SEL, NSString *, NSString *, NSInteger, NSInteger))objc_msgSend)([UIKey alloc], maker, @"A", @"a", 4, UIKeyModifierShift);
    CHECK([key.characters isEqual:@"A"] && [key.charactersIgnoringModifiers isEqual:@"a"] && key.keyCode == 4 && key.modifierFlags == UIKeyModifierShift, "a key holds its characters, key code and modifiers");
    UIKey *other = ((id (*)(id, SEL, NSString *, NSString *, NSInteger, NSInteger))objc_msgSend)([UIKey alloc], maker, @"b", @"b", 4, UIKeyModifierShift);
    CHECK([key isEqual:other] && key.hash == (NSUInteger)(4 ^ UIKeyModifierShift) && ![key isEqual:nil], "keys are equal by key code and modifiers");
    UIKey *copy = [key copy];
    CHECK(copy != key && [copy isEqual:key] && [copy.characters isEqual:@"A"], "a copy is equal");
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:key];
    UIKey *back = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    CHECK([back isEqual:key] && [back.characters isEqual:@"A"] && back.keyCode == 4, "a key is archived and read back");
    CHECK([text(key) hasSuffix:@"characters=A, unmodified=a, keyCode=4, modifierFlags=131072>"], "and describes itself as the system's does");
    CHECK([UIKeyInputHome isEqual:@"UIKeyInputHome"] && [UIKeyInputEnd isEqual:@"UIKeyInputEnd"] && [UIKeyInputF1 isEqual:@"UIKeyInputF1"] && [UIKeyInputF6 isEqual:@"UIKeyInputF6"] && [UIKeyInputF12 isEqual:@"UIKeyInputF12"],
          "the key input strings are the system's");
}

- (UILabel *)labelWithText:(NSString *)text in:(UIView *)view
{
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && [[(UILabel *)sub text] isEqual:text])
            return (UILabel *)sub;
    }
    return nil;
}

- (void)runSearch
{
    UISearchToken *a = [UISearchToken tokenWithIcon:nil text:@"Alpha"], *b = [UISearchToken tokenWithIcon:nil text:@"Beta"];
    a.representedObject = @1;
    CHECK_EQUAL(a.representedObject, @1, "a search token keeps its represented object");
    UISearchTextField *field = [[UISearchTextField alloc] initWithFrame:CGRectMake(10, 180, 280, 32)];
    [self.host.view addSubview:field];
    CHECK(field.tokens.count == 0 && field.allowsCopyingTokens && field.allowsDeletingTokens && field.borderStyle == UITextBorderStyleRoundedRect && field.clearButtonMode == UITextFieldViewModeWhileEditing
              && field.leftView != nil && field.leftViewMode == UITextFieldViewModeAlways,
          "a search text field has no tokens, a rounded border, a clear button and a magnifier");
    [field insertToken:a atIndex:0];
    [field insertToken:b atIndex:1];
    field.text = @"gamma";
    [field layoutIfNeeded];
    CHECK(field.tokens.count == 2 && field.tokens[0] == a && [field.text isEqual:@"gamma"], "tokens are kept apart from the text");
    UILabel *chip_a = [self labelWithText:@"Alpha" in:field], *chip_b = [self labelWithText:@"Beta" in:field];
    CHECK(chip_a && chip_b && CGRectGetMinX(chip_b.frame) > CGRectGetMaxX(chip_a.frame) && CGRectGetMinX(chip_a.frame) >= CGRectGetMaxX(field.leftView.frame), "each token is a chip after the magnifier, side by side");
    CGRect editing = [field editingRectForBounds:field.bounds];
    CHECK(CGRectGetMinX(editing) >= CGRectGetMaxX(chip_b.frame) && CGRectGetMinX([field textRectForBounds:field.bounds]) >= CGRectGetMaxX(chip_b.frame), "the text starts after the chips");
    CHECK([field.tokenBackgroundColor isEqual:chip_a.backgroundColor], "chips are drawn in the token background");
    field.tokenBackgroundColor = [UIColor orangeColor];
    [field layoutIfNeeded];
    CHECK([chip_a.backgroundColor isEqual:[UIColor orangeColor]], "a new token background repaints them");
    BOOL raised = NO;
    @try {
        [field insertToken:a atIndex:10];
    } @catch (NSException *exception) {
        raised = [exception.name isEqual:NSRangeException];
    }
    CHECK(raised, "a token index out of range raises");
    [field removeTokenAtIndex:0];
    [field layoutIfNeeded];
    CHECK(field.tokens.count == 1 && [self labelWithText:@"Alpha" in:field] == nil && [self labelWithText:@"Beta" in:field] != nil, "a token removed takes its chip away");
    field.text = @"";
    CHECK(wait_until(^BOOL { return [field becomeFirstResponder]; }, 3), "the field takes the keyboard");
    field.selectedTextRange = [field textRangeFromPosition:field.beginningOfDocument toPosition:field.beginningOfDocument];
    [field deleteBackward];
    CHECK(field.tokens.count == 0, "a backspace at the start of an empty field deletes the last token");
    [field resignFirstResponder];

    UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 220, 320, 44)];
    [self.host.view addSubview:bar];
    [bar layoutIfNeeded];
    UISearchTextField *inside = bar.searchTextField;
    CHECK(inside != nil && [inside isKindOfClass:[UITextField class]] && inside.superview != nil, "a search bar answers its text field");
    CHECK(inside == bar.searchTextField && [inside respondsToSelector:@selector(insertToken:atIndex:)] && [inside respondsToSelector:@selector(tokens)], "the same one each time, and it answers the token members");
    [inside insertToken:a atIndex:0];
    CHECK(inside.tokens.count == 1 && inside.tokens[0] == a, "and keeps tokens, without drawing them");
    inside.text = @"typed";
    CHECK([bar.text isEqual:@"typed"], "its text is the search bar's text");
    CHECK(![inside respondsToSelector:@selector(searchSuggestions)], "and it does not answer the suggestions of iOS 16");

    UISearchController *controller = [[UISearchController alloc] initWithSearchResultsController:nil];
    // The scope bar flag is NO by default on the iPad idiom (measured in a bundled Catalyst app), the activation Manual.
    CHECK(!controller.automaticallyShowsScopeBar && controller.automaticallyShowsCancelButton && controller.automaticallyShowsSearchResultsController && !controller.showsSearchResultsController,
          "a search controller shows the cancel button and the results by itself, and asks for the scope bar");
    controller.automaticallyShowsScopeBar = NO;
    controller.showsSearchResultsController = YES;
    CHECK(!controller.automaticallyShowsScopeBar && controller.showsSearchResultsController, "and keeps what it is told");
    [bar removeFromSuperview];
    [field removeFromSuperview];
}

- (void)runColors
{
    UIColorWell *well = [[UIColorWell alloc] initWithFrame:CGRectMake(10, 270, 44, 44)];
    [self.host.view addSubview:well];
    CHECK(well.supportsAlpha && well.title == nil && well.selectedColor == nil && well.enabled, "a color well supports alpha, has no title and no color");
    CharonEventCounter *counter = [[CharonEventCounter alloc] init];
    [well addTarget:counter action:@selector(hit) forControlEvents:UIControlEventValueChanged];
    well.selectedColor = [UIColor greenColor];
    well.title = @"Fill";
    well.supportsAlpha = NO;
    CHECK(counter.hits == 0 && [well.selectedColor isEqual:[UIColor greenColor]] && [well.title isEqual:@"Fill"] && !well.supportsAlpha, "setting values does not send value changed");
    [well layoutIfNeeded];
    CHECK(well.layer.sublayers.count == 2 && CGSizeEqualToSize([well sizeThatFits:CGSizeZero], CGSizeMake(44, 44)), "the well draws a ring and a swatch, 44 points square");

    ((void (*)(id, SEL))objc_msgSend)(well, NSSelectorFromString(@"charon_present"));
    CHECK(wait_until(^BOOL { return self.host.presentedViewController != nil; }, 5), "tapping the well presents the color picker");
    UIColorPickerViewController *picker = (UIColorPickerViewController *)self.host.presentedViewController;
    CHECK([picker isKindOfClass:[UIColorPickerViewController class]] && [picker.title isEqual:@"Fill"] && !picker.supportsAlpha && picker.delegate == (id)well, "the picker gets the well's title, alpha setting and delegate");
    CHECK(wait_until(^BOOL { return picker.isViewLoaded && picker.view.window != nil; }, 5), "its view is on screen");
    [picker.view layoutIfNeeded];
    UIView *grid = nil;
    UINavigationBar *bar = nil;
    for (UIView *sub in picker.view.subviews) {
        if ([sub respondsToSelector:NSSelectorFromString(@"pickAt:continuously:")])
            grid = sub;
        if ([sub isKindOfClass:[UINavigationBar class]])
            bar = (UINavigationBar *)sub;
    }
    CHECK(grid != nil && bar != nil && CGRectGetHeight(grid.frame) > 150 && CGRectGetWidth(grid.frame) > 200, "it shows a bar and a grid of colors");
    CGFloat cell_w = CGRectGetWidth(grid.bounds) / 12, cell_h = CGRectGetHeight(grid.bounds) / 10;
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(0.5f * cell_w, 5.5f * cell_h), NO);
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [well.selectedColor getRed:&red green:&green blue:&blue alpha:&alpha];
    CHECK(counter.hits == 1 && red > 0.99f && green < 0.01f && blue < 0.01f && alpha > 0.99f, "touching a swatch sets the well's color and sends value changed");
    CharonPickerReport *report = [[CharonPickerReport alloc] init];
    report.log = [NSMutableArray array];
    picker.delegate = report;
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(4.5f * cell_w, 5.5f * cell_h), YES);
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(grid, NSSelectorFromString(@"pickAt:continuously:"), CGPointMake(4.5f * cell_w, 5.5f * cell_h), NO);
    CHECK([report.log isEqual:(@[@"selecting", @"selected"])], "the delegate hears the selection, continuously while the finger moves");
    ((void (*)(id, SEL))objc_msgSend)(picker, NSSelectorFromString(@"charon_done"));
    CHECK(wait_until(^BOOL { return self.host.presentedViewController == nil; }, 5), "Done dismisses the picker");
    CHECK(wait_until(^BOOL { return [report.log containsObject:@"finish"]; }, 5), "and tells the delegate");
    [well removeFromSuperview];
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonPointerDelegate");
    }
}
