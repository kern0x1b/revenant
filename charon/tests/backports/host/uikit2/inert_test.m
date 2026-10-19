#import "uirest.h"

@interface UIView (CharonHostLargeContent)
- (BOOL)charonHostShowsLargeContentViewer;
- (void)charonHostSetShowsLargeContentViewer:(BOOL)value;
- (NSString *)charonHostLargeContentTitle;
- (void)charonHostSetLargeContentTitle:(NSString *)value;
- (UIImage *)charonHostLargeContentImage;
- (void)charonHostSetLargeContentImage:(UIImage *)value;
- (BOOL)charonHostScalesLargeContentImage;
- (void)charonHostSetScalesLargeContentImage:(BOOL)value;
- (UIEdgeInsets)charonHostLargeContentImageInsets;
- (void)charonHostSetLargeContentImageInsets:(UIEdgeInsets)value;
@end

@interface UIWindowScene (CharonHostScreenshot)
- (id)charonHostScreenshotService;
@end

@interface UIScene (CharonHostPointerLock)
- (id)charonHostPointerLockState;
@end

@interface UIViewController (CharonHostPointerLock)
- (BOOL)charonHostPrefersPointerLocked;
- (UIViewController *)charonHostChildViewControllerForPointerLock;
- (void)charonHostSetNeedsUpdateOfPrefersPointerLocked;
@end

@interface Delegate : NSObject <UILargeContentViewerInteractionDelegate, UIScribbleInteractionDelegate, UIIndirectScribbleInteractionDelegate, UITextInteractionDelegate, UIScreenshotServiceDelegate, UITextFormattingCoordinatorDelegate>
@end

@implementation Delegate

- (void)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction requestElementsInRect:(CGRect)rect completion:(void (^)(NSArray *))completion
{
}

- (BOOL)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction isElementFocused:(id)elementIdentifier
{
    return NO;
}

- (CGRect)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction frameForElement:(id)elementIdentifier
{
    return CGRectZero;
}

- (void)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction focusElementIfNeeded:(id)elementIdentifier referencePoint:(CGPoint)point completion:(void (^)(UIResponder<UITextInput> *))completion
{
}

- (void)updateTextAttributesWithConversionHandler:(UITextAttributesConversionHandler)conversionHandler
{
}

@end

static NSString *insets(UIEdgeInsets value)
{
    return NSStringFromUIEdgeInsets(value);
}

static NSArray *large_lines(BOOL port, UIView *view, Class interaction, UIView *other)
{
    NSMutableArray *lines = [NSMutableArray array];
    BOOL (*shows)(id, SEL) = (void *)objc_msgSend;
    NSString *(*title)(id, SEL) = (void *)objc_msgSend;
    id (*image)(id, SEL) = (void *)objc_msgSend;
    UIEdgeInsets (*edge)(id, SEL) = (void *)objc_msgSend;
    void (*setBool)(id, SEL, BOOL) = (void *)objc_msgSend;
    void (*setObject)(id, SEL, id) = (void *)objc_msgSend;
    void (*setEdge)(id, SEL, UIEdgeInsets) = (void *)objc_msgSend;
    SEL showsGet = port ? @selector(charonHostShowsLargeContentViewer) : @selector(showsLargeContentViewer), showsSet = port ? @selector(charonHostSetShowsLargeContentViewer:) : @selector(setShowsLargeContentViewer:),
        titleGet = port ? @selector(charonHostLargeContentTitle) : @selector(largeContentTitle), titleSet = port ? @selector(charonHostSetLargeContentTitle:) : @selector(setLargeContentTitle:),
        imageGet = port ? @selector(charonHostLargeContentImage) : @selector(largeContentImage), imageSet = port ? @selector(charonHostSetLargeContentImage:) : @selector(setLargeContentImage:),
        scalesGet = port ? @selector(charonHostScalesLargeContentImage) : @selector(scalesLargeContentImage), scalesSet = port ? @selector(charonHostSetScalesLargeContentImage:) : @selector(setScalesLargeContentImage:),
        edgeGet = port ? @selector(charonHostLargeContentImageInsets) : @selector(largeContentImageInsets), edgeSet = port ? @selector(charonHostSetLargeContentImageInsets:) : @selector(setLargeContentImageInsets:);
    [lines addObject:ur_line(@"defaults", @[ur_yes(shows(view, showsGet)), title(view, titleGet) ?: @"nil", image(view, imageGet) ?: @"nil", ur_yes(shows(view, scalesGet)), insets(edge(view, edgeGet))])];
    UIImage *picture = [[UIImage alloc] init];
    NSMutableString *mutable = [NSMutableString stringWithString:@"a"];
    setBool(view, showsSet, YES);
    setObject(view, titleSet, mutable);
    setObject(view, imageSet, picture);
    setBool(view, scalesSet, YES);
    setEdge(view, edgeSet, UIEdgeInsetsMake(1, 2, 3, 4));
    [mutable appendString:@"b"];
    [lines addObject:ur_line(@"set", @[ur_yes(shows(view, showsGet)), title(view, titleGet), ur_yes(image(view, imageGet) == picture), ur_yes(shows(view, scalesGet)), insets(edge(view, edgeGet))])];
    [lines addObject:ur_line(@"other view untouched", @[ur_yes(shows(other, showsGet)), title(other, titleGet) ?: @"nil"])];
    Delegate *delegate = [[Delegate alloc] init];
    id made = [[interaction alloc] initWithDelegate:delegate];
    [lines addObject:ur_line(@"interaction", @[ur_yes([made delegate] == delegate), [made view] ?: @"nil", [made gestureRecognizerForExclusionRelationship] ?: @"nil", ur_yes([interaction isEnabled])])];
    [view addInteraction:made];
    [lines addObject:ur_line(@"added", @[ur_yes([made view] == view), ur_yes([[made gestureRecognizerForExclusionRelationship] isKindOfClass:[UIGestureRecognizer class]]), ur_yes([[made gestureRecognizerForExclusionRelationship] view] == view),
                                        @(view.interactions.count)])];
    [view removeInteraction:made];
    [lines addObject:ur_line(@"removed", @[[made view] ?: @"nil", @(view.interactions.count)])];
    id bare = [[interaction alloc] performSelector:NSSelectorFromString(@"init")];
    [lines addObject:ur_line(@"init", @[[bare delegate] ?: @"nil"])];
    return lines;
}

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Class ourLarge = NSClassFromString(@"CharonHostUILargeContentViewerInteraction"), ourShot = NSClassFromString(@"CharonHostUIScreenshotService"), ourScribble = NSClassFromString(@"CharonHostUIScribbleInteraction"),
              ourIndirect = NSClassFromString(@"CharonHostUIIndirectScribbleInteraction"), ourLock = NSClassFromString(@"CharonHostUIPointerLockState"), ourCoordinator = NSClassFromString(@"CharonHostUITextFormattingCoordinator"),
              ourPlaceholder = NSClassFromString(@"CharonHostUITextPlaceholder");
        charon_check(ourLarge && ourShot && ourScribble && ourIndirect && ourLock && ourCoordinator && ourPlaceholder, "the port's classes are linked under their host names", @"one is missing");
        UIView *a = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)], *b = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [window addSubview:a];
        [window addSubview:b];
        ur_agree(@"large content viewer", large_lines(YES, a, ourLarge, [[UIView alloc] init]), large_lines(NO, b, [UILargeContentViewerInteraction class], [[UIView alloc] init]));
        charon_check(![ourLarge isEnabled], "the large content viewer is not enabled", @"it is");
        NSString *(^constant)(const char *) = ^NSString *(const char *name) { return *(NSString *const *)dlsym(RTLD_DEFAULT, name); };
        charon_check([constant("CharonHostUILargeContentViewerInteractionEnabledStatusDidChangeNotification") isEqualToString:UILargeContentViewerInteractionEnabledStatusDidChangeNotification] &&
                         [constant("CharonHostUIPointerLockStateDidChangeNotification") isEqualToString:UIPointerLockStateDidChangeNotification] && [constant("CharonHostUIPointerLockStateSceneUserInfoKey") isEqualToString:UIPointerLockStateSceneUserInfoKey],
                     "the notification names and the key are the system's", @"one differs");

        Delegate *delegate = [[Delegate alloc] init];
        NSMutableArray *ours = [NSMutableArray array], *theirs = [NSMutableArray array];
        for (int round = 0; round < 2; round++) {
            NSMutableArray *lines = round ? theirs : ours;
            Class scribble = round ? [UIScribbleInteraction class] : ourScribble, indirect = round ? [UIIndirectScribbleInteraction class] : ourIndirect;
            id s = [[scribble alloc] initWithDelegate:delegate];
            [lines addObject:ur_line(@"scribble", @[ur_yes([s delegate] == delegate), ur_yes([s isHandlingWriting]), ur_yes([scribble isPencilInputExpected]), [s view] ?: @"nil"])];
            id bare = [[scribble alloc] performSelector:NSSelectorFromString(@"init")];
            [lines addObject:ur_line(@"scribble init", @[[bare delegate] ?: @"nil", ur_yes([bare isHandlingWriting])])];
            id i = [[indirect alloc] initWithDelegate:delegate];
            [lines addObject:ur_line(@"indirect scribble", @[ur_yes([i delegate] == delegate), ur_yes([i isHandlingWriting])])];
            UIView *host = round ? b : a;
            [host addInteraction:s];
            [lines addObject:ur_line(@"scribble added", @[ur_yes([s view] == host)])];
            [host removeInteraction:s];
            [lines addObject:ur_line(@"scribble removed", @[[s view] ?: @"nil"])];
            UITextView *placeholderHost = nil;
            (void)placeholderHost;
            id placeholder = [[round ? [UITextPlaceholder class] : ourPlaceholder alloc] performSelector:NSSelectorFromString(@"init")];
            [lines addObject:ur_line(@"text placeholder", @[ur_norm(placeholder), [placeholder rects] ?: @"nil"])];
            id coordinator = ur_raised(^id { return @([(round ? [UITextFormattingCoordinator class] : ourCoordinator) isFontPanelVisible]); });
            [lines addObject:ur_line(@"font panel", coordinator)];
        }
        ur_agree(@"scribble and text values", ours, theirs);

        UIWindowScene *scene = window.windowScene;
        id shot = [scene charonHostScreenshotService], systemShot = scene.screenshotService;
        charon_check(shot != nil && systemShot != nil && [shot windowScene] == scene && [systemShot windowScene] == scene && [shot delegate] == nil && [systemShot delegate] == nil, "a scene has a screenshot service with no delegate", @"it does not");
        [shot setDelegate:delegate];
        [systemShot setDelegate:delegate];
        charon_check([shot delegate] == delegate && [systemShot delegate] == delegate && shot == [scene charonHostScreenshotService], "the delegate is kept and the service is the scene's own", @"it is not");
        id state = [scene charonHostPointerLockState], systemState = scene.pointerLockState;
        charon_check(state != nil && systemState != nil && ![state isLocked] && [state isKindOfClass:ourLock] && state == [scene charonHostPointerLockState], "a scene has a pointer lock state that is not locked", @"it does not");
        UIViewController *controller = window.rootViewController;
        NSString *portLock = ur_line(@"lock", @[ur_yes([controller charonHostPrefersPointerLocked]), [controller charonHostChildViewControllerForPointerLock] ?: @"nil", ur_raised(^id { [controller charonHostSetNeedsUpdateOfPrefersPointerLocked]; return @"ok"; })]);
        NSString *systemLock = ur_line(@"lock", @[ur_yes([controller prefersPointerLocked]), controller.childViewControllerForPointerLock ?: @"nil", ur_raised(^id { [controller setNeedsUpdateOfPrefersPointerLocked]; return @"ok"; })]);
        ur_agree(@"pointer lock members of a view controller", @[portLock], @[systemLock]);
    }
}
