#import <UIKit/UIKit.h>
#import "sheet-cases.h"
#import "sheet-shadow-expectations.h"

/* A context of the test's own, with the container bounds the medium detent asks for. */
@interface SheetContext : NSObject <UISheetPresentationControllerDetentResolutionContext>
@property (nonatomic, strong) UITraitCollection *containerTraitCollection;
@property (nonatomic, assign) CGFloat maximumDetentValue;
@property (nonatomic, assign) CGRect bounds;
@end

@implementation SheetContext
- (CGRect)_containerBounds { return self.bounds; }
@end

/* A context of the caller's own with the protocol's members only: UIKit's medium detent sends it _containerBounds all the
   same (0x189d322b4). */
@interface BareSheetContext : NSObject <UISheetPresentationControllerDetentResolutionContext>
@property (nonatomic, strong) UITraitCollection *containerTraitCollection;
@property (nonatomic, assign) CGFloat maximumDetentValue;
@end

@implementation BareSheetContext
@end

@interface SheetDelegate : NSObject <UISheetPresentationControllerDelegate>
@property (nonatomic, strong) NSMutableArray *calls;
@end

@implementation SheetDelegate
- (instancetype)init { if ((self = [super init])) _calls = [NSMutableArray array]; return self; }
- (void)sheetPresentationControllerDidChangeSelectedDetentIdentifier:(UISheetPresentationController *)sheet { [_calls addObject:@"didChangeDetent"]; }
- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)controller { [_calls addObject:@"shouldDismiss"]; return YES; }
- (void)presentationControllerWillDismiss:(UIPresentationController *)controller { [_calls addObject:@"willDismiss"]; }
- (void)presentationControllerDidDismiss:(UIPresentationController *)controller { [_calls addObject:@"didDismiss"]; }
- (void)presentationControllerDidAttemptToDismiss:(UIPresentationController *)controller { [_calls addObject:@"didAttempt"]; }
@end

static NSString *number(CGFloat value)
{
    if (value == CGFLOAT_MAX)
        return @"max";
    return [NSString stringWithFormat:@"%.2f", (double)value];
}

static NSString *flag(BOOL value)
{
    return value ? @"1" : @"0";
}

/* The description without its address. */
static NSString *detent_text(UISheetPresentationControllerDetent *detent)
{
    NSString *text = detent.description;
    NSRange range = [text rangeOfString:@"_type="];
    return range.location == NSNotFound ? text : [text substringFromIndex:range.location];
}

static NSString *identifiers(NSArray *detents)
{
    NSMutableArray *names = [NSMutableArray array];
    for (UISheetPresentationControllerDetent *detent in detents)
        [names addObject:detent.identifier];
    return [names componentsJoinedByString:@","];
}

void sheet_api_run(SheetRecorder record)
{
    record(@"const.medium", UISheetPresentationControllerDetentIdentifierMedium);
    record(@"const.large", UISheetPresentationControllerDetentIdentifierLarge);
    record(@"const.automatic", number(UISheetPresentationControllerAutomaticDimension));
    record(@"const.inactive", number(UISheetPresentationControllerDetentInactive));

    CGFloat (^constant)(id<UISheetPresentationControllerDetentResolutionContext>) = ^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) { return -5; };
    CGFloat (^fraction)(id<UISheetPresentationControllerDetentResolutionContext>) = ^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) { return context.maximumDetentValue * 0.3; };
    record(@"detent.medium", detent_text([UISheetPresentationControllerDetent mediumDetent]));
    record(@"detent.large", detent_text([UISheetPresentationControllerDetent largeDetent]));
    record(@"detent.custom", detent_text([UISheetPresentationControllerDetent customDetentWithIdentifier:@"x" resolver:constant]));
    NSString *dynamic = [UISheetPresentationControllerDetent customDetentWithIdentifier:nil resolver:constant].identifier;
    record(@"detent.dynamic", [NSString stringWithFormat:@"prefix=%@ uuid=%@", flag([dynamic hasPrefix:@"com.apple.UIKit.dynamic."]),
        flag([[NSUUID alloc] initWithUUIDString:[dynamic stringByReplacingOccurrencesOfString:@"com.apple.UIKit.dynamic." withString:@""]] != nil)]);
    UISheetPresentationControllerDetent *shared = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"z" resolver:constant];
    record(@"detent.custom.equality", [NSString stringWithFormat:@"sameResolver=%@ self=%@ hashEqual=%@",
        flag([shared isEqual:[UISheetPresentationControllerDetent customDetentWithIdentifier:@"z" resolver:constant]]), flag([shared isEqual:shared]),
        flag([UISheetPresentationControllerDetent mediumDetent].hash == [UISheetPresentationControllerDetent mediumDetent].hash)]);
    record(@"detent.identity", [NSString stringWithFormat:@"sameMedium=%@ equalMedium=%@ equalLarge=%@ mediumLarge=%@ customSameId=%@",
        flag([UISheetPresentationControllerDetent mediumDetent] == [UISheetPresentationControllerDetent mediumDetent]),
        flag([[UISheetPresentationControllerDetent mediumDetent] isEqual:[UISheetPresentationControllerDetent mediumDetent]]),
        flag([[UISheetPresentationControllerDetent largeDetent] isEqual:[UISheetPresentationControllerDetent largeDetent]]),
        flag([[UISheetPresentationControllerDetent mediumDetent] isEqual:[UISheetPresentationControllerDetent largeDetent]]),
        flag([[UISheetPresentationControllerDetent customDetentWithIdentifier:@"y" resolver:constant] isEqual:[UISheetPresentationControllerDetent customDetentWithIdentifier:@"y" resolver:fraction]])]);

    NSArray *sizes = @[ [NSValue valueWithCGSize:CGSizeMake(320, 480)], [NSValue valueWithCGSize:CGSizeMake(320, 568)], [NSValue valueWithCGSize:CGSizeMake(320, 569)],
                        [NSValue valueWithCGSize:CGSizeMake(375, 667)], [NSValue valueWithCGSize:CGSizeMake(768, 1024)], [NSValue valueWithCGSize:CGSizeMake(480, 320)] ];
    for (NSValue *value in sizes) {
        CGSize size = value.CGSizeValue;
        for (NSNumber *vertical in @[ @(UIUserInterfaceSizeClassRegular), @(UIUserInterfaceSizeClassCompact), @(UIUserInterfaceSizeClassUnspecified) ]) {
            SheetContext *context = [[SheetContext alloc] init];
            context.containerTraitCollection = [UITraitCollection traitCollectionWithVerticalSizeClass:vertical.integerValue];
            context.maximumDetentValue = 440;
            context.bounds = CGRectMake(0, 0, size.width, size.height);
            record([NSString stringWithFormat:@"resolve.%.0fx%.0f.v%@", size.width, size.height, vertical],
                [NSString stringWithFormat:@"medium=%@ large=%@ constant=%@ fraction=%@", number([[UISheetPresentationControllerDetent mediumDetent] resolvedValueInContext:context]),
                    number([[UISheetPresentationControllerDetent largeDetent] resolvedValueInContext:context]),
                    number([[UISheetPresentationControllerDetent customDetentWithIdentifier:nil resolver:constant] resolvedValueInContext:context]),
                    number([[UISheetPresentationControllerDetent customDetentWithIdentifier:nil resolver:fraction] resolvedValueInContext:context])]);
        }
    }

    BareSheetContext *bare = [[BareSheetContext alloc] init];
    bare.containerTraitCollection = [UITraitCollection traitCollectionWithVerticalSizeClass:UIUserInterfaceSizeClassRegular];
    bare.maximumDetentValue = 440;
    NSString *bareMedium = nil;
    @try {
        bareMedium = [NSString stringWithFormat:@"medium=%@", number([[UISheetPresentationControllerDetent mediumDetent] resolvedValueInContext:bare])];
    } @catch (NSException *exception) {
        bareMedium = [NSString stringWithFormat:@"medium raises %@", exception.name];
    }
    record(@"resolve.bare", [NSString stringWithFormat:@"%@ large=%@", bareMedium, number([[UISheetPresentationControllerDetent largeDetent] resolvedValueInContext:bare])]);

    /* A controller owns the sheet it was asked for and the sheet does not own it back; a presentation controller the
       caller made holds both of its controllers. */
    __weak UIViewController *ownerGone = nil;
    __weak UIViewController *heldGone = nil;
    __weak UIViewController *customPresented = nil;
    __weak UIViewController *customPresenting = nil;
    __weak UIPresentationController *sheetGone = nil;
    UIPresentationController *heldSheet = nil;
    UIPresentationController *custom = nil;
    @autoreleasepool {
        UIViewController *owner = [[UIViewController alloc] init];
        owner.modalPresentationStyle = UIModalPresentationPageSheet;
        sheetGone = owner.sheetPresentationController;
        ownerGone = owner;
        UIViewController *held = [[UIViewController alloc] init];
        held.modalPresentationStyle = UIModalPresentationPageSheet;
        heldSheet = held.sheetPresentationController;
        heldGone = held;
        UIViewController *presented = [[UIViewController alloc] init], *presenting = [[UIViewController alloc] init];
        custom = [[UIPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
        customPresented = presented;
        customPresenting = presenting;
    }
    record(@"sheet.lifetime", [NSString stringWithFormat:@"controller=%@ sheet=%@ heldSheetController=%@ heldSheetPresented=%@ customPresented=%@ customPresenting=%@",
        flag(ownerGone != nil), flag(sheetGone != nil), flag(heldGone != nil), flag(heldSheet.presentedViewController != nil), flag(customPresented != nil), flag(customPresenting != nil)]);

    for (NSNumber *style in @[ @(UIModalPresentationFullScreen), @(UIModalPresentationPageSheet), @(UIModalPresentationFormSheet), @(UIModalPresentationCustom), @(UIModalPresentationOverFullScreen) ]) {
        UIViewController *controller = [[UIViewController alloc] init];
        controller.modalPresentationStyle = style.integerValue;
        UISheetPresentationController *sheet = controller.sheetPresentationController;
        record([NSString stringWithFormat:@"style.%@", style], [NSString stringWithFormat:@"sheet=%@ same=%@ again=%@",
            flag([sheet isKindOfClass:[UISheetPresentationController class]]), flag(!sheet || controller.presentationController == sheet), flag(controller.sheetPresentationController == sheet)]);
        UIViewController *asked = [[UIViewController alloc] init];
        asked.modalPresentationStyle = style.integerValue;
        UIPresentationController *first = asked.presentationController;
        record([NSString stringWithFormat:@"style.first.%@", style], [NSString stringWithFormat:@"sheet=%@ same=%@",
            flag([first isKindOfClass:[UISheetPresentationController class]]), flag(!asked.sheetPresentationController || asked.sheetPresentationController == first)]);
    }

    UIViewController *controller = [[UIViewController alloc] init];
    controller.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = controller.sheetPresentationController;
    record(@"sheet.defaults", [NSString stringWithFormat:@"detents=%@ selected=%@ undimmed=%@ grabber=%@ radius=%@ expands=%@ edge=%@ width=%@ source=%@ delegate=%@ presented=%@ presenting=%@ container=%@",
        identifiers(sheet.detents), sheet.selectedDetentIdentifier ?: @"nil", sheet.largestUndimmedDetentIdentifier ?: @"nil", flag(sheet.prefersGrabberVisible), number(sheet.preferredCornerRadius),
        flag(sheet.prefersScrollingExpandsWhenScrolledToEdge), flag(sheet.prefersEdgeAttachedInCompactHeight), flag(sheet.widthFollowsPreferredContentSizeWhenEdgeAttached),
        flag(sheet.sourceView != nil), flag(sheet.delegate != nil), flag(sheet.presentedViewController == controller), flag(sheet.presentingViewController != nil), flag(sheet.containerView != nil)]);
    record(@"sheet.base", [NSString stringWithFormat:@"style=%ld fullscreen=%@ removes=%@ frame=%@",
        (long)sheet.presentationStyle, flag(sheet.shouldPresentInFullscreen), flag(sheet.shouldRemovePresentersView), NSStringFromCGRect(sheet.frameOfPresentedViewInContainerView)]);

    UIView *source = [[UIView alloc] init];
    SheetDelegate *delegate = [[SheetDelegate alloc] init];
    sheet.detents = @[ [UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent] ];
    sheet.selectedDetentIdentifier = @"bogus";
    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
    sheet.prefersGrabberVisible = YES;
    sheet.preferredCornerRadius = 12;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    sheet.prefersEdgeAttachedInCompactHeight = YES;
    sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
    sheet.sourceView = source;
    sheet.delegate = delegate;
    [sheet invalidateDetents];
    __block BOOL ran = NO;
    [sheet animateChanges:^{
        ran = YES;
    }];
    record(@"sheet.set", [NSString stringWithFormat:@"detents=%@ selected=%@ undimmed=%@ grabber=%@ radius=%@ expands=%@ edge=%@ width=%@ source=%@ delegate=%@ animateRan=%@ calls=%@",
        identifiers(sheet.detents), sheet.selectedDetentIdentifier, sheet.largestUndimmedDetentIdentifier, flag(sheet.prefersGrabberVisible), number(sheet.preferredCornerRadius),
        flag(sheet.prefersScrollingExpandsWhenScrolledToEdge), flag(sheet.prefersEdgeAttachedInCompactHeight), flag(sheet.widthFollowsPreferredContentSizeWhenEdgeAttached),
        flag(sheet.sourceView == source), flag(sheet.delegate == delegate), flag(ran), [delegate.calls componentsJoinedByString:@","]]);
    NSArray *given = @[ [UISheetPresentationControllerDetent largeDetent] ];
    sheet.detents = given;
    sheet.selectedDetentIdentifier = nil;
    record(@"sheet.reset", [NSString stringWithFormat:@"equal=%@ selected=%@", flag([sheet.detents isEqualToArray:given]), sheet.selectedDetentIdentifier ?: @"nil"]);
}

static NSString *window_rect(UIView *view)
{
    CGRect rect = [view convertRect:view.bounds toView:nil];
    return [NSString stringWithFormat:@"%.1f %.1f %.1f %.1f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

@interface SheetLayoutSteps : NSObject
@property (nonatomic, strong) NSMutableArray *steps;
@end

@implementation SheetLayoutSteps
- (void)next
{
    if (!_steps.count)
        return;
    void (^step)(void) = _steps.firstObject;
    [_steps removeObjectAtIndex:0];
    step();
    [self performSelector:@selector(next) withObject:nil afterDelay:1.2];
}
@end

/* The sheet's grabber: the one control among the sheet view's own subviews, as UIKit's drop
   shadow view holds its _UIGrabber. */
static UIControl *sheet_grabber(UIView *sheetView)
{
    for (UIView *view in sheetView.subviews)
        if ([view isKindOfClass:[UIControl class]])
            return (UIControl *)view;
    return nil;
}

/* A responder that takes key input and says it is not editable, as a text view that is not. */
@interface SheetReadOnlyInput : UIView <UIKeyInput>
@end

@implementation SheetReadOnlyInput
- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)isEditable { return NO; }
- (BOOL)hasText { return NO; }
- (void)insertText:(NSString *)text {}
- (void)deleteBackward {}
@end

static void post_keyboard(NSString *name, UIWindow *window)
{
    CGRect end = CGRectMake(0, CGRectGetHeight(window.bounds) - 216, CGRectGetWidth(window.bounds), 216);
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:nil userInfo:@{
        UIKeyboardFrameEndUserInfoKey: [NSValue valueWithCGRect:end], UIKeyboardAnimationDurationUserInfoKey: @0.25, UIKeyboardAnimationCurveUserInfoKey: @(UIViewAnimationCurveEaseInOut)}];
}

static NSString *hits(UIWindow *window, CGPoint point, UIView *view)
{
    return flag([window hitTest:point withEvent:nil] == view);
}

/* One pixel of the window at the screen's scale, its top left corner at a point. */
static void window_pixel(UIWindow *window, CGPoint point, uint8_t pixel[4])
{
    CGFloat scale = window.screen.scale;
    memset(pixel, 0, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(context, 0, 1);
    CGContextScaleCTM(context, scale, -scale);
    CGContextTranslateCTM(context, -point.x, -point.y);
    [window.layer renderInContext:context];
    CGContextRelease(context);
}

/* The magic shadow 20 points above a sheet's card, over what lies under it, per the host's shadow view
   (host/sheetshadow/run.sh): the alpha of its image along an edge at the pixel's distance from the shadow's outer
   edge, 150 points above the card, and its vibrant matrix of the destination laid over it with the matrix's alpha.
   The destination is read 162 points above the card, beyond the shadow. */
static NSString *magic_shadow(UIWindow *window, UIView *card, SheetRecorder record)
{
    NSDictionary *host = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:sheet_shadow_expectations length:strlen(sheet_shadow_expectations)] options:0 error:NULL];
    NSArray *edge = host[@"edge"], *matrix = host[@"matrix"];
    CGFloat scale = window.screen.scale, top = [card convertRect:card.bounds toView:nil].origin.y;
    CGFloat x = floor(CGRectGetMidX(window.bounds) * scale) / scale, y = floor((top - 20) * scale) / scale;
    uint8_t near[4], far[4];
    window_pixel(window, CGPointMake(x, y), near);
    window_pixel(window, CGPointMake(x, floor((top - 162) * scale) / scale), far);
    double u = (y + 0.5 / scale - (top - 150)) * [host[@"edgeScale"] doubleValue] - 0.5;
    NSUInteger i = (NSUInteger)floor(u);
    double f = u - i, alpha = ((1 - f) * [edge[i] doubleValue] + f * [edge[i + 1] doubleValue]) / 255;
    double d[3] = {far[0] / 255.0, far[1] / 255.0, far[2] / 255.0}, m[20];
    for (int k = 0; k < 20; k++)
        m[k] = [matrix[k] doubleValue];
    double a = fmin(fmax(m[15] * d[0] + m[16] * d[1] + m[17] * d[2] + m[18] + m[19], 0), 1);
    BOOL within = YES;
    double expected[3];
    for (int c = 0; c < 3; c++) {
        double v = fmin(fmax(m[c * 5] * d[0] + m[c * 5 + 1] * d[1] + m[c * 5 + 2] * d[2] + m[c * 5 + 3] + m[c * 5 + 4], 0), 1);
        expected[c] = 255 * (d[c] + alpha * a * (v - d[c]));
        within = within && fabs(near[c] - expected[c]) <= 3;
    }
    record(@"layout.shadow.values", [NSString stringWithFormat:@"under=%u %u %u near=%u %u %u expected=%.1f %.1f %.1f alpha=%.3f",
        far[0], far[1], far[2], near[0], near[1], near[2], expected[0], expected[1], expected[2], alpha]);
    return [NSString stringWithFormat:@"near=%@", flag(within)];
}

void sheet_layout_run(UIWindow *window, SheetRecorder record, void (^done)(void))
{
    UIViewController *root = window.rootViewController;
    UIViewController *first = [[UIViewController alloc] init];
    first.view.backgroundColor = [UIColor whiteColor];
    first.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = first.sheetPresentationController;
    SheetDelegate *delegate = [[SheetDelegate alloc] init];
    sheet.delegate = delegate;
    sheet.detents = @[ [UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent] ];
    sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(20, 60, 280, 31)];
    field.borderStyle = UITextBorderStyleRoundedRect;
    [first.view addSubview:field];
    UIViewController *second = [[UIViewController alloc] init];
    second.view.backgroundColor = [UIColor lightGrayColor];
    second.modalPresentationStyle = UIModalPresentationFormSheet;
    SheetReadOnlyInput *input = [[SheetReadOnlyInput alloc] initWithFrame:CGRectMake(20, 100, 100, 30)];
    [first.view addSubview:input];
    /* A sheet over a full-screen presentation has no parent to stack with, so it has the magic shadow. */
    UIViewController *under = [[UIViewController alloc] init];
    under.view.backgroundColor = [UIColor redColor];
    under.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *shadowed = [[UIViewController alloc] init];
    shadowed.view.backgroundColor = [UIColor whiteColor];
    shadowed.modalPresentationStyle = UIModalPresentationPageSheet;
    shadowed.sheetPresentationController.detents = @[ [UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent] ];
    shadowed.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
    void (^state)(NSString *) = ^(NSString *name) {
        record([@"layout." stringByAppendingString:name], [NSString stringWithFormat:@"root=%@ first=%@ second=%@ selected=%@ container=%@ calls=%@",
            window_rect(root.view), first.view.window ? window_rect(first.view) : @"-", second.view.window ? window_rect(second.view) : @"-",
            sheet.selectedDetentIdentifier ?: @"nil", flag(sheet.containerView != nil), [delegate.calls componentsJoinedByString:@","]]);
    };
    SheetLayoutSteps *steps = [[SheetLayoutSteps alloc] init];
    steps.steps = [NSMutableArray arrayWithObjects:
        ^{ [root presentViewController:first animated:YES completion:nil]; },
        ^{ state(@"large");
           record(@"layout.controller", [NSString stringWithFormat:@"same=%@ presenting=%@", flag(first.presentationController == sheet), flag(sheet.presentingViewController == root)]);
           [sheet animateChanges:^{ sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium; }]; },
        ^{ state(@"medium");
           sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge; },
        ^{ state(@"largeAgain");
           sheet.prefersGrabberVisible = YES;
           [sheet_grabber(sheet.presentedView) sendActionsForControlEvents:UIControlEventTouchUpInside]; },
        ^{ state(@"grabberFromLarge");
           /* The grabber takes touches in 44 points around itself, beyond the card's top edge too. */
           UIControl *grabber = sheet_grabber(sheet.presentedView);
           CGPoint centre = [grabber convertPoint:CGPointMake(CGRectGetMidX(grabber.bounds), CGRectGetMidY(grabber.bounds)) toView:nil];
           CGFloat top = [sheet.presentedView convertRect:sheet.presentedView.bounds toView:nil].origin.y;
           record(@"layout.hit.visible", [NSString stringWithFormat:@"centre=%@ above=%@", hits(window, centre, grabber), hits(window, CGPointMake(centre.x, top - 10), grabber)]);
           [grabber sendActionsForControlEvents:UIControlEventTouchUpInside]; },
        ^{ state(@"grabberFromMedium");
           [delegate.calls removeAllObjects];
           [sheet animateChanges:^{ sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium; }]; },
        ^{ [field becomeFirstResponder]; },
        ^{ state(@"keyboard");
           record(@"layout.keyboard.editing", flag(field.isFirstResponder));
           [sheet_grabber(sheet.presentedView) sendActionsForControlEvents:UIControlEventTouchUpInside]; },
        ^{ state(@"keyboardEnded");
           record(@"layout.keyboardEnded.editing", flag(field.isFirstResponder));
           sheet.prefersGrabberVisible = NO; },
        ^{ UIControl *grabber = sheet_grabber(sheet.presentedView);
           CGFloat top = [sheet.presentedView convertRect:sheet.presentedView.bounds toView:nil].origin.y;
           record(@"layout.hit.hidden", [NSString stringWithFormat:@"above=%@", hits(window, CGPointMake(CGRectGetMidX(window.bounds), top - 10), grabber)]);
           /* Whether the release lets a text view that is not editable hold the keyboard: a note, not a check. */
           UITextView *text = [[UITextView alloc] initWithFrame:CGRectMake(20, 140, 100, 40)];
           text.editable = NO;
           [first.view addSubview:text];
           record(@"layout.note.readOnlyTextView", [NSString stringWithFormat:@"becameFirstResponder=%@", flag([text becomeFirstResponder])]);
           [text resignFirstResponder];
           [text removeFromSuperview];
           [input becomeFirstResponder];
           post_keyboard(UIKeyboardWillShowNotification, window); },
        ^{ state(@"readOnly");
           record(@"layout.readOnly.responder", flag(input.isFirstResponder));
           [input resignFirstResponder];
           post_keyboard(UIKeyboardWillHideNotification, window);
           sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge; },
        ^{ [first presentViewController:second animated:YES completion:nil]; },
        ^{ state(@"stacked");
           [second dismissViewControllerAnimated:YES completion:nil]; },
        ^{ state(@"unstacked");
           [first dismissViewControllerAnimated:YES completion:nil]; },
        ^{ state(@"dismissed");
           record(@"layout.after", [NSString stringWithFormat:@"transform=%@ radius=%.1f masks=%@", NSStringFromCGAffineTransform(root.view.transform), root.view.layer.cornerRadius, flag(root.view.layer.masksToBounds)]);
           [root presentViewController:under animated:NO completion:nil]; },
        ^{ [under presentViewController:shadowed animated:YES completion:nil]; },
        ^{ record(@"layout.shadow", magic_shadow(window, shadowed.sheetPresentationController.presentedView, record));
           [shadowed dismissViewControllerAnimated:NO completion:nil]; },
        ^{ [under dismissViewControllerAnimated:NO completion:nil]; },
        ^{ done(); },
        nil];
    /* The delayed perform keeps the steps alive until the last one has run. */
    [steps next];
}
