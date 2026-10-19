#import "uirest.h"

static void *ur_symbol(const char *name)
{
    char prefixed[256];
    snprintf(prefixed, sizeof(prefixed), "CharonHost%s", name);
    void *found = dlsym(RTLD_DEFAULT, prefixed);
    return found ? found : dlsym(RTLD_DEFAULT, name);
}

static NSString *ur_constant(const char *name)
{
    NSString *const *found = (NSString *const *)ur_symbol(name);
    return found ? *found : @"<missing>";
}

@interface ResponderChain : UIView
@property (nonatomic) int validated;
@end

@implementation ResponderChain

- (void)validateCommand:(UICommand *)command
{
    self.validated++;
}

@end

static NSArray *views_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];
    BOOL (*flag)(void) = NULL;
    NSString *functions[] = {@"UIAccessibilityShouldDifferentiateWithoutColor", @"UIAccessibilityIsOnOffSwitchLabelsEnabled", @"UIAccessibilityIsVideoAutoplayEnabled", @"UIAccessibilityButtonShapesEnabled", @"UIAccessibilityPrefersCrossFadeTransitions"};
    NSMutableArray *answers = [NSMutableArray array];
    for (int index = 0; index < 5; index++) {
        flag = ur_symbol(functions[index].UTF8String);
        [answers addObject:flag ? ur_yes(flag()) : @"<missing>"];
    }
    [lines addObject:ur_line(@"accessibility functions", answers)];
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *name in @[@"UIAccessibilityOnOffSwitchLabelsDidChangeNotification", @"UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification", @"UIAccessibilityVideoAutoplayStatusDidChangeNotification",
                             @"UIAccessibilityButtonShapesEnabledStatusDidChangeNotification", @"UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification", @"UIAccessibilitySpeechAttributeSpellOut",
                             @"UIAccessibilityTextAttributeContext", @"UIAccessibilityTextualContextConsole", @"UIAccessibilityTextualContextFileSystem", @"UIAccessibilityTextualContextMessaging",
                             @"UIAccessibilityTextualContextNarrative", @"UIAccessibilityTextualContextSourceCode", @"UIAccessibilityTextualContextSpreadsheet", @"UIAccessibilityTextualContextWordProcessing",
                             @"NSCocoaVersionDocumentAttribute", @"NSTextScalingDocumentAttribute", @"NSSourceTextScalingDocumentAttribute", @"NSSourceTextScalingDocumentOption", @"NSTargetTextScalingDocumentOption",
                             @"NSTrackingAttributeName", @"UIPasteboardDetectionPatternNumber", @"UIPasteboardDetectionPatternProbableWebURL", @"UIPasteboardDetectionPatternProbableWebSearch",
                             @"UIFontDescriptorSystemDesignDefault", @"UIFontDescriptorSystemDesignRounded", @"UIFontDescriptorSystemDesignSerif", @"UIFontDescriptorSystemDesignMonospaced"])
        [names addObject:ur_constant(name.UTF8String)];
    [lines addObject:ur_line(@"constants", names)];

    NSObject *object = [[NSObject alloc] init];
    [lines addObject:ur_line(@"accessibility defaults", @[object.accessibilityUserInputLabels, object.accessibilityAttributedUserInputLabels ?: @"nil", object.accessibilityTextualContext ?: @"nil", ur_yes(object.accessibilityRespondsToUserInteraction)])];
    object.accessibilityUserInputLabels = @[@"a", @"b"];
    [lines addObject:ur_line(@"labels set", @[object.accessibilityUserInputLabels, @([object.accessibilityAttributedUserInputLabels count]), [[object.accessibilityAttributedUserInputLabels firstObject] string]])];
    object.accessibilityAttributedUserInputLabels = @[[[NSAttributedString alloc] initWithString:@"z"]];
    [lines addObject:ur_line(@"attributed labels set", @[object.accessibilityUserInputLabels, @([object.accessibilityAttributedUserInputLabels count])])];
    NSMutableArray *mutable = [NSMutableArray arrayWithObject:@"m"];
    object.accessibilityUserInputLabels = mutable;
    [mutable addObject:@"n"];
    [lines addObject:ur_line(@"labels are copied", @([object.accessibilityUserInputLabels count]))];
    object.accessibilityTextualContext = UIAccessibilityTextualContextSourceCode;
    object.accessibilityRespondsToUserInteraction = YES;
    [lines addObject:ur_line(@"context and interaction", @[object.accessibilityTextualContext, ur_yes(object.accessibilityRespondsToUserInteraction)])];

    UIAccessibilityCustomAction *(^custom)(void) = ^UIAccessibilityCustomAction *{ return [[UIAccessibilityCustomAction alloc] initWithName:@"n" actionHandler:^BOOL(UIAccessibilityCustomAction *x) { return YES; }]; };
    UIAccessibilityCustomAction *ca = custom();
    [lines addObject:ur_line(@"custom action", @[ca.name, ur_yes(ca.actionHandler != nil), ca.target ?: @"nil", ca.selector ? NSStringFromSelector(ca.selector) : @"nil", ca.image ?: @"nil"])];
    UIAccessibilityCustomAction *cb = [[UIAccessibilityCustomAction alloc] initWithName:@"cn" image:[[UIImage alloc] init] actionHandler:^BOOL(UIAccessibilityCustomAction *x) { return NO; }];
    [lines addObject:ur_line(@"custom action with an image", @[cb.name, ur_yes(cb.image != nil), ur_yes(cb.actionHandler != nil)])];
    UIAccessibilityCustomAction *cc = [[UIAccessibilityCustomAction alloc] initWithName:@"dn" image:nil target:object selector:@selector(description)];
    [lines addObject:ur_line(@"custom action with a target", @[ur_yes(cc.target == object), NSStringFromSelector(cc.selector), ur_yes(cc.actionHandler != nil)])];
    cc.actionHandler = ^BOOL(UIAccessibilityCustomAction *x) { return YES; };
    [lines addObject:ur_line(@"handler set later", ur_yes(cc.actionHandler != nil))];

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    [lines addObject:ur_line(@"view", @[@(view.overrideUserInterfaceStyle), view.focusGroupIdentifier ?: @"nil", NSStringFromCGRect(view.frame)])];
    view.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    view.focusGroupIdentifier = @"group";
    [lines addObject:ur_line(@"view set", @[@(view.overrideUserInterfaceStyle), view.focusGroupIdentifier])];
    view.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    view.transform3D = CATransform3DMakeRotation(1, 1, 0, 0);
    [lines addObject:ur_line(@"transform3D", @[ur_yes(CATransform3DEqualToTransform(view.transform3D, view.layer.transform)), ur_yes(CATransform3DEqualToTransform(view.transform3D, CATransform3DIdentity))])];
    view.transform = CGAffineTransformMakeScale(2, 2);
    [lines addObject:ur_line(@"transform after", ur_yes(CATransform3DEqualToTransform(view.transform3D, CATransform3DMakeScale(2, 2, 1))))];
    UIViewController *controller = [[UIViewController alloc] init];
    [lines addObject:ur_line(@"controller", @[@(controller.overrideUserInterfaceStyle), ur_yes(controller.modalInPresentation), ur_yes(controller.performsActionsWhilePresentingModally), controller.focusGroupIdentifier ?: @"nil"])];
    controller.modalInPresentation = YES;
    controller.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    controller.focusGroupIdentifier = @"g";
    [lines addObject:ur_line(@"controller set", @[@(controller.overrideUserInterfaceStyle), ur_yes(controller.modalInPresentation), controller.focusGroupIdentifier])];

    UISwitch *sw = [[UISwitch alloc] init];
    [lines addObject:ur_line(@"switch", @[@(sw.style), @(sw.preferredStyle)])];
    sw.preferredStyle = UISwitchStyleCheckbox;
    [lines addObject:ur_line(@"switch preferred", @[@(sw.style), @(sw.preferredStyle)])];
    UIPageControl *pc = [[UIPageControl alloc] init];
    [lines addObject:ur_line(@"page control", @[pc.preferredIndicatorImage ?: @"nil", @(pc.backgroundStyle), ur_yes(pc.allowsContinuousInteraction), @(pc.interactionState)])];
    [lines addObject:ur_line(@"no pages", ur_raised(^id { return [pc indicatorImageForPage:0]; }))];
    pc.numberOfPages = 3;
    UIImage *dot = [[UIImage alloc] init];
    [pc setIndicatorImage:dot forPage:1];
    [lines addObject:ur_line(@"page images", @[ur_yes([pc indicatorImageForPage:1] == dot), [pc indicatorImageForPage:2] ?: @"nil", ur_raised(^id { return [pc indicatorImageForPage:3]; }), ur_raised(^id { [pc setIndicatorImage:nil forPage:-1]; return @"no"; })])];
    pc.preferredIndicatorImage = dot;
    pc.allowsContinuousInteraction = NO;
    pc.backgroundStyle = UIPageControlBackgroundStyleProminent;
    [lines addObject:ur_line(@"page control set", @[ur_yes(pc.preferredIndicatorImage == dot), ur_yes(pc.allowsContinuousInteraction), @(pc.backgroundStyle)])];
    UILabel *label = [[UILabel alloc] init];
    [lines addObject:ur_line(@"label", @(label.lineBreakStrategy))];
    label.lineBreakStrategy = NSLineBreakStrategyHangulWordPriority;
    [lines addObject:ur_line(@"label set", @(label.lineBreakStrategy))];
    UIScrollView *scroll = [[UIScrollView alloc] init];
    [lines addObject:ur_line(@"scroll view", ur_yes(scroll.automaticallyAdjustsScrollIndicatorInsets))];
    scroll.automaticallyAdjustsScrollIndicatorInsets = NO;
    [lines addObject:ur_line(@"scroll view set", ur_yes(scroll.automaticallyAdjustsScrollIndicatorInsets))];
    UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:@[@"a", @"b"]];
    UIColor *red = [UIColor redColor];
    segments.selectedSegmentTintColor = red;
    [lines addObject:ur_line(@"selected segment tint", @[ur_yes(segments.selectedSegmentTintColor == red)])];
    UITextView *text = [[UITextView alloc] init];
    [lines addObject:ur_line(@"text view", ur_yes(text.usesStandardTextScaling))];
    text.usesStandardTextScaling = YES;
    [lines addObject:ur_line(@"text view set", ur_yes(text.usesStandardTextScaling))];
    UISearchBar *bar = [[UISearchBar alloc] init];
    [bar setShowsScopeBar:YES animated:NO];
    [lines addObject:ur_line(@"search bar", ur_yes(bar.showsScopeBar))];
    [lines addObject:ur_line(@"screen", @([UIScreen mainScreen].calibratedLatency))];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] init];
    [lines addObject:ur_line(@"pan", @(pan.allowedScrollTypesMask))];
    pan.allowedScrollTypesMask = UIScrollTypeMaskAll;
    [lines addObject:ur_line(@"pan set", @(pan.allowedScrollTypesMask))];
    NSLayoutManager *layout = [[NSLayoutManager alloc] init];
    [lines addObject:ur_line(@"layout manager", ur_yes(layout.usesDefaultHyphenation))];
    layout.usesDefaultHyphenation = YES;
    [lines addObject:ur_line(@"layout manager set", ur_yes(layout.usesDefaultHyphenation))];
    UIDatePicker *picker = [[UIDatePicker alloc] init];
    [lines addObject:ur_line(@"date picker", @(picker.preferredDatePickerStyle))];
    picker.preferredDatePickerStyle = UIDatePickerStyleInline;
    [lines addObject:ur_line(@"date picker set", @(picker.preferredDatePickerStyle))];
    UIView *outer = [[ResponderChain alloc] init];
    UIView *inner = [[UIView alloc] init];
    [outer addSubview:inner];
    [inner validateCommand:[UICommand commandWithTitle:@"t" image:nil action:@selector(description) propertyList:nil]];
    [lines addObject:ur_line(@"validate does not forward", @(((ResponderChain *)outer).validated))];
    UIResponder *responder = [[UIResponder alloc] init];
    [lines addObject:ur_line(@"responder", @[@(responder.editingInteractionConfiguration), responder.activityItemsConfiguration ?: @"nil"])];
    [lines addObject:ur_line(@"vibrancy", ur_yes([[UIVibrancyEffect effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] style:UIVibrancyEffectStyleLabel] isKindOfClass:[UIVibrancyEffect class]]))];
    UIFont *mono = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    UIFont *bold = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
    [lines addObject:ur_line(@"monospaced fonts", @[ur_yes(mono.pointSize == 12), ur_yes(bold.pointSize == 12), ur_yes(mono != nil)])];
    NSMutableArray *widths = [NSMutableArray array];
    for (NSString *sample in @[@"i", @"m", @"W", @"."])
        [widths addObject:@((NSInteger)[sample sizeWithAttributes:@{NSFontAttributeName: mono}].width)];
    [lines addObject:ur_line(@"monospaced widths agree", ur_yes([widths[0] isEqual:widths[1]] && [widths[1] isEqual:widths[2]] && [widths[2] isEqual:widths[3]]))];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"x"];
    [lines addObject:ur_line(@"navigation item", @(item.backButtonDisplayMode))];
    item.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    [lines addObject:ur_line(@"navigation item set", @(item.backButtonDisplayMode))];
    NSMutableAttributedString *(^base)(void) = ^NSMutableAttributedString *{
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"hello world"];
        [text addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(6, 5)];
        return text;
    };
    NSAttributedString *insert = [[NSAttributedString alloc] initWithString:@"XY" attributes:@{NSForegroundColorAttributeName: [UIColor blueColor]}];
    NSArray *selections = @[[NSValue valueWithRange:NSMakeRange(0, 0)], [NSValue valueWithRange:NSMakeRange(11, 0)], [NSValue valueWithRange:NSMakeRange(4, 2)], [NSValue valueWithRange:NSMakeRange(1, 9)], [NSValue valueWithRange:NSMakeRange(9, 2)],
                            [NSValue valueWithRange:NSMakeRange(3, 5)]];
    for (int kind = 0; kind < 2; kind++) {
        for (NSValue *held in selections) {
            UIView<UITextInput> *input = kind ? (UIView<UITextInput> *)[[UITextView alloc] initWithFrame:CGRectMake(0, 0, 200, 50)] : (UIView<UITextInput> *)[[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
            [(id)input setAttributedText:base()];
            NSRange chosen = held.rangeValue;
            UITextPosition *a = [input positionFromPosition:input.beginningOfDocument offset:(NSInteger)chosen.location], *b = [input positionFromPosition:input.beginningOfDocument offset:(NSInteger)NSMaxRange(chosen)];
            input.selectedTextRange = [input textRangeFromPosition:a toPosition:b];
            UITextPosition *from = [input positionFromPosition:input.beginningOfDocument offset:3], *to = [input positionFromPosition:input.beginningOfDocument offset:8];
            [input replaceRange:[input textRangeFromPosition:from toPosition:to] withAttributedText:insert];
            NSAttributedString *result = [(id)input attributedText];
            NSMutableArray *runs = [NSMutableArray array];
            [result enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, result.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                CGFloat red = 0, green = 0, blue = 0, alpha = 0;
                [(UIColor *)value getRed:&red green:&green blue:&blue alpha:&alpha];
                [runs addObject:[NSString stringWithFormat:@"%@:%.0f%.0f%.0f", NSStringFromRange(range), red, green, blue]];
            }];
            UITextRange *now = input.selectedTextRange;
            [lines addObject:ur_line(kind ? @"text view replaced" : @"text field replaced", @[NSStringFromRange(chosen), result.string, runs, NSStringFromRange(NSMakeRange((NSUInteger)[input offsetFromPosition:input.beginningOfDocument toPosition:now.start],
                                                                                                                                                                       (NSUInteger)[input offsetFromPosition:now.start toPosition:now.end]))])];
        }
    }
    NSMutableArray *flat = [NSMutableArray array];
    for (NSString *entry in lines)
        [flat addObject:[entry stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return flat;
}
