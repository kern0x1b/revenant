#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#import "check.h"

static void log_line(NSString *line)
{
    charon_check(YES, [line UTF8String], @"");
}

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wundeclared-selector"

static NSString *const results_folder = @"/private/var/backports";

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static UIActionSheet *find_sheet(UIView *view)
{
    if ([view isKindOfClass:[UIActionSheet class]])
        return (UIActionSheet *)view;
    for (UIView *sub in view.subviews) {
        UIActionSheet *found = find_sheet(sub);
        if (found)
            return found;
    }
    return nil;
}

static UIActionSheet *visible_sheet(void)
{
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        UIActionSheet *sheet = find_sheet(window);
        if (sheet)
            return sheet;
    }
    return nil;
}

static BOOL from_backports(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) && info.dli_fname && strstr(info.dli_fname, "UIKitBackports") != NULL;
}

static NSString *rgba(UIColor *color)
{
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        [color getWhite:&w alpha:&a];
        r = g = b = w;
    }
    return [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f", r, g, b, a];
}

static BOOL close_to(UIColor *color, CGFloat r, CGFloat g, CGFloat b, CGFloat a)
{
    CGFloat cr = 0, cg = 0, cb = 0, ca = 0;
    if (![color getRed:&cr green:&cg blue:&cb alpha:&ca]) {
        CGFloat w = 0;
        [color getWhite:&w alpha:&ca];
        cr = cg = cb = w;
    }
    return fabs(cr - r) < 0.005 && fabs(cg - g) < 0.005 && fabs(cb - b) < 0.005 && fabs(ca - a) < 0.005;
}

static UITraitCollection *traits(UIUserInterfaceStyle style, UIAccessibilityContrast contrast, UIUserInterfaceLevel level)
{
    return [UITraitCollection traitCollectionWithTraitsFromCollections:@[[UITraitCollection traitCollectionWithUserInterfaceStyle:style], [UITraitCollection traitCollectionWithAccessibilityContrast:contrast],
                                                                          [UITraitCollection traitCollectionWithUserInterfaceLevel:level]]];
}

static NSUInteger lit_pixels(UIImage *image, CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 1);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(rendered.CGImage));
    NSUInteger count = 0;
    for (CFIndex index = 3; index < CFDataGetLength(data); index += 4)
        count += CFDataGetBytePtr(data)[index] != 0;
    CFRelease(data);
    return count;
}

@interface UIViewController (CharonAppearingDeclaration)
- (void)viewIsAppearing:(BOOL)animated;
@end

@interface UITextView (CharonAttributedReplace)
- (void)replaceRange:(UITextRange *)range withAttributedText:(NSAttributedString *)attributedText;
@end

@interface UIContextMenuInteraction (CharonPrivate)
- (void)charon_beginAtLocation:(CGPoint)location;
@end

@interface Recorder : NSObject
@property (nonatomic, strong) NSMutableArray *log;
- (void)go:(id)sender;
@end

@implementation Recorder

- (instancetype)init
{
    if ((self = [super init]))
        self.log = [NSMutableArray array];
    return self;
}

- (void)go:(id)sender
{
    [self.log addObject:[NSString stringWithFormat:@"target %@", NSStringFromClass([sender class])]];
}

@end

@interface Appearing : UIViewController
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation Appearing

- (void)viewWillAppear:(BOOL)animated
{
    [self.events addObject:@"will"];
    [super viewWillAppear:animated];
    [self.events addObject:@"will done"];
}

- (void)viewIsAppearing:(BOOL)animated
{
    [self.events addObject:@"is"];
    [super viewIsAppearing:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.events addObject:@"did"];
}

@end

@interface UnwindOverride : UIViewController
@property (nonatomic) int asked;
@end

@implementation UnwindOverride

- (IBAction)unwindToHere:(UIStoryboardSegue *)segue
{
}

- (BOOL)canPerformUnwindSegueAction:(SEL)action fromViewController:(UIViewController *)fromViewController sender:(id)sender
{
    self.asked++;
    return action == @selector(description) ? YES : [super canPerformUnwindSegueAction:action fromViewController:fromViewController sender:sender];
}

@end

@interface Selecting : NSObject <UITextFieldDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation Selecting

- (void)textFieldDidChangeSelection:(UITextField *)textField
{
    [self.events addObject:@"selection"];
}

@end

@interface Lists : NSObject <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation Lists

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    [self.events addObject:[NSString stringWithFormat:@"configuration row %ld", (long)indexPath.row]];
    return [UIContextMenuConfiguration configurationWithIdentifier:@"row" previewProvider:nil actionProvider:^UIMenu *(NSArray *suggested) {
        return [UIMenu menuWithTitle:@"Row" children:@[[UIAction actionWithTitle:@"Open" image:nil identifier:nil handler:^(UIAction *action) { [self.events addObject:@"open"]; }]]];
    }];
}

- (void)tableView:(UITableView *)tableView willDisplayContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.events addObject:@"will display"];
}

- (void)tableView:(UITableView *)tableView willEndContextMenuInteractionWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.events addObject:@"will end"];
}

@end

@interface CharonRestSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

static NSMutableArray *scene_events;
static UIWindow *the_window;

@implementation CharonRestSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    the_window = self.window;
}

- (void)windowScene:(UIWindowScene *)windowScene didUpdateCoordinateSpace:(id<UICoordinateSpace>)previousCoordinateSpace interfaceOrientation:(UIInterfaceOrientation)previousInterfaceOrientation
     traitCollection:(UITraitCollection *)previousTraitCollection
{
    [scene_events addObject:[NSString stringWithFormat:@"coordinate space %ld %g", (long)previousInterfaceOrientation, (double)previousTraitCollection.displayScale]];
}

@end

@interface CharonRestDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonRestDelegate

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    return [UISceneConfiguration configurationWithName:@"Default" sessionRole:session.role];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"uirest.log"]);
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
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"uirest.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)commands
{
    CHECK((from_backports([UICommand class]) && from_backports([UICommandAlternate class]) && from_backports([UIKeyCommand class])), "the commands come from the backports library");
    UICommandAlternate *shift = [UICommandAlternate alternateWithTitle:@"alt" action:@selector(description) modifierFlags:UIKeyModifierShift];
    UICommandAlternate *twin = [UICommandAlternate alternateWithTitle:@"other" action:@selector(class) modifierFlags:UIKeyModifierShift];
    CHECK(([shift isEqual:twin] && shift.hash == twin.hash && [shift copy] == shift), "alternates are equal by modifier flags and are their own copies");
    UICommand *x = [UICommand commandWithTitle:@"T" image:nil action:@selector(description) propertyList:@{@"a": @1}];
    UICommand *y = [UICommand commandWithTitle:@"U" image:nil action:@selector(description) propertyList:@{@"a": @1} alternates:@[shift]];
    UICommand *z = [UICommand commandWithTitle:@"T" image:nil action:@selector(class) propertyList:@{@"a": @1}];
    UICommand *w = [UICommand commandWithTitle:@"T" image:nil action:@selector(description) propertyList:@{@"a": @2}];
    CHECK(([x isEqual:y] && x.hash == y.hash && ![x isEqual:z] && ![x isEqual:w] && [x copy] != x && [[x copy] isEqual:x]), "commands are equal by action and property list");
    CHECK(([x.title isEqual:@"T"] && x.image == nil && x.discoverabilityTitle == nil && x.attributes == 0 && x.state == UIMenuElementStateOff && x.alternates.count == 0 && [x.propertyList isEqual:@{@"a": @1}] && y.alternates.count == 1), "a command has the fields it was given");
    x.attributes = UIMenuElementAttributesDestructive;
    x.state = UIMenuElementStateOn;
    x.discoverabilityTitle = @"D";
    x.title = @"T2";
    UICommand *copy = [x copy];
    CHECK((copy.attributes == UIMenuElementAttributesDestructive && copy.state == UIMenuElementStateOn && [copy.discoverabilityTitle isEqual:@"D"] && [copy.title isEqual:@"T2"]), "and a copy keeps what was set");
    NSString *text = [x description];
    CHECK(([text rangeOfString:@"title = T2; action: description"].location != NSNotFound), "its description names title and action");
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:y];
    UICommand *back = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    CHECK(([back isKindOfClass:[UICommand class]] && [back isEqual:y] && [back.title isEqual:@"U"] && back.alternates.count == 1 && [back.propertyList isEqual:@{@"a": @1}]), "a command survives an archive");
    NSString *invalid = nil;
    @try {
        [UICommand commandWithTitle:@"T" image:nil action:@selector(description) propertyList:@{@1: @2}];
    } @catch (NSException *exception) {
        invalid = exception.name;
    }
    CHECK(([invalid isEqual:NSInternalInconsistencyException]), "a property list with a non-string key is refused");
    NSString *twins = nil;
    @try {
        [UICommand commandWithTitle:@"T" image:nil action:@selector(description) propertyList:nil alternates:@[shift, twin]];
    } @catch (NSException *exception) {
        twins = exception.reason;
    }
    CHECK(([twins hasPrefix:@"Invalid parameter not satisfying: alternateModifierFlags"]), "two alternates with one modifier are refused");
    UIKeyCommand *plain = [UIKeyCommand keyCommandWithInput:@"a" modifierFlags:UIKeyModifierCommand action:@selector(description)];
    UIKeyCommand *other = [UIKeyCommand commandWithTitle:@"tt" image:nil action:@selector(class) input:@"a" modifierFlags:UIKeyModifierCommand propertyList:@1];
    CHECK(([plain isEqual:other] && plain.hash == other.hash && ![plain isEqual:[UIKeyCommand keyCommandWithInput:@"a" modifierFlags:UIKeyModifierShift action:@selector(description)]]), "key commands are equal by input and modifiers");
    CHECK(([plain isKindOfClass:[UICommand class]] && [plain.title isEqual:@""] && [other.title isEqual:@"tt"] && [other.propertyList isEqual:@1]), "a key command is a command with a title");
    UIKeyCommand *both = [UIKeyCommand keyCommandWithInput:@"z" modifierFlags:UIKeyModifierShift | UIKeyModifierControl action:@selector(description)];
    CHECK(([[both description] rangeOfString:@"input: z; modifierFlags: Ctrl-Shift"].location != NSNotFound), "its description names the modifiers as the system does");
    UIKeyCommand *bare = [[UIKeyCommand alloc] init];
    CHECK((bare.input == nil && [NSStringFromSelector(bare.action) isEqual:@"_nop"]), "one made with init has no input");
    UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[[UICommand commandWithTitle:@"Do" image:nil action:@selector(description) propertyList:nil]]];
    CHECK((menu.children.count == 1), "a command is a child of a menu");
}

- (void)activityItems
{
    CHECK((from_backports([UIActivityItemsConfiguration class]) && from_backports([UIFontPickerViewController class])), "the configuration and the font picker come from the backports library");
    UIActivityItemsConfiguration *c = [UIActivityItemsConfiguration activityItemsConfigurationWithObjects:@[@"hello", [NSURL URLWithString:@"http://example.com"]]];
    CHECK((c.itemProvidersForActivityItemsConfiguration.count == 2 && [c.supportedInteractions isEqual:@[UIActivityItemsConfigurationInteractionShare]] && c.metadataProvider == nil && c.localObject == nil),
          "a configuration made of objects has a provider for each and the share interaction");
    CHECK(([c activityItemsConfigurationSupportsInteraction:UIActivityItemsConfigurationInteractionShare] && ![c activityItemsConfigurationSupportsInteraction:@"x"]), "it supports what it lists");
    c.metadataProvider = ^id(NSString *key) { return [key stringByAppendingString:@"!"]; };
    c.perItemMetadataProvider = ^id(NSInteger index, NSString *key) { return [NSString stringWithFormat:@"%ld%@", (long)index, key]; };
    c.previewProvider = ^NSItemProvider *(NSInteger index, NSString *intent, CGSize size) { return [[NSItemProvider alloc] initWithObject:intent]; };
    c.applicationActivitiesProvider = ^NSArray *(void) { return @[]; };
    CHECK(([[c activityItemsConfigurationMetadataForKey:UIActivityItemsConfigurationMetadataKeyTitle] isEqual:@"title!"] && [[c activityItemsConfigurationMetadataForItemAtIndex:2 key:@"k"] isEqual:@"2k"] &&
              [c activityItemsConfigurationPreviewForItemAtIndex:0 intent:UIActivityItemsConfigurationPreviewIntentThumbnail suggestedSize:CGSizeZero] != nil && [c.applicationActivitiesForActivityItemsConfiguration isEqual:@[]]),
          "the providers answer the protocol");
    NSString *refused = nil;
    @try {
        [[UIActivityItemsConfiguration alloc] initWithObjects:nil];
    } @catch (NSException *exception) {
        refused = exception.reason;
    }
    CHECK(([refused hasSuffix:@"objects parameter cannot be nil."]), "objects that are nil are refused");
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItemsConfiguration:c];
    CHECK(([sheet isKindOfClass:[UIActivityViewController class]]), "an activity view controller is made of the configuration");
    UIResponder *responder = [[UIResponder alloc] init];
    CHECK((responder.activityItemsConfiguration == nil && responder.editingInteractionConfiguration == UIEditingInteractionConfigurationDefault), "a responder has no configuration and the default editing interaction");
    responder.activityItemsConfiguration = c;
    CHECK((responder.activityItemsConfiguration == c), "and keeps the one it is given");

    UIFontPickerViewControllerConfiguration *config = [[UIFontPickerViewControllerConfiguration alloc] init];
    CHECK((!config.includeFaces && !config.displayUsingSystemFont && config.filteredTraits == 0 && config.filteredLanguagesPredicate == nil), "a font picker configuration starts empty");
    config.includeFaces = YES;
    config.filteredLanguagesPredicate = [UIFontPickerViewControllerConfiguration filterPredicateForFilteredLanguages:@[@"en"]];
    UIFontPickerViewController *picker = [[UIFontPickerViewController alloc] initWithConfiguration:config];
    config.includeFaces = NO;
    CHECK((picker.configuration.includeFaces && picker.configuration != config && [picker.configuration.filteredLanguagesPredicate evaluateWithObject:@"en"]), "a picker keeps a copy of its configuration");
    CHECK(([[picker view] isKindOfClass:[UIView class]] && picker.delegate == nil && picker.selectedFontDescriptor == nil), "a picker has a view and no delegate");
    UIFont *mono = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    NSMutableSet *widths = [NSMutableSet set];
    for (NSString *sample in @[@"i", @"m", @"W", @"."])
        [widths addObject:@((NSInteger)[sample sizeWithFont:mono].width)];
    CHECK((mono != nil && widths.count == 1 && [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold] != nil), "the monospaced system font has one width for every letter");
    NSString *rounded = *(NSString *const *)dlsym(RTLD_DEFAULT, "UIFontDescriptorSystemDesignRounded");
    CHECK(([rounded isEqual:@"NSCTFontUIFontDesignRounded"]), "the system design names are the system's");
}

- (void)inert
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
    CHECK((!view.showsLargeContentViewer && view.largeContentTitle == nil && view.largeContentImage == nil && !view.scalesLargeContentImage && UIEdgeInsetsEqualToEdgeInsets(view.largeContentImageInsets, UIEdgeInsetsZero)), "a view starts with no large content");
    view.largeContentTitle = @"t";
    view.showsLargeContentViewer = YES;
    view.largeContentImageInsets = UIEdgeInsetsMake(1, 2, 3, 4);
    CHECK(([view.largeContentTitle isEqual:@"t"] && view.showsLargeContentViewer && view.largeContentImageInsets.right == 4), "and keeps what it is given");
    UILargeContentViewerInteraction *large = [[UILargeContentViewerInteraction alloc] initWithDelegate:nil];
    CHECK((large.gestureRecognizerForExclusionRelationship == nil && ![UILargeContentViewerInteraction isEnabled]), "a large content interaction is not enabled and has no recogniser before it is added");
    [view addInteraction:large];
    CHECK((large.view == view && large.gestureRecognizerForExclusionRelationship.view == view && !large.gestureRecognizerForExclusionRelationship.enabled), "added, it has a disabled recogniser on the view");
    UIScribbleInteraction *scribble = [[UIScribbleInteraction alloc] initWithDelegate:nil];
    [view addInteraction:scribble];
    CHECK((scribble.view == view && !scribble.handlingWriting && ![UIScribbleInteraction isPencilInputExpected]), "a scribble interaction can be added and never handles writing");
    UIIndirectScribbleInteraction *indirect = [[UIIndirectScribbleInteraction alloc] initWithDelegate:(id)view];
    CHECK((indirect.delegate == (id)view && !indirect.handlingWriting), "an indirect scribble interaction keeps its delegate");
    UITextPlaceholder *placeholder = [[UITextPlaceholder alloc] init];
    CHECK((placeholder.rects == nil), "a text placeholder has no rects");
    CHECK((![UITextFormattingCoordinator isFontPanelVisible]), "no font panel is visible");
    UIWindowScene *scene = the_window.windowScene;
    UIScreenshotService *service = scene.screenshotService;
    CHECK((service != nil && service.windowScene == scene && service.delegate == nil && service == scene.screenshotService), "a scene has one screenshot service");
    UIPointerLockState *state = scene.pointerLockState;
    CHECK((state != nil && !state.locked && state == scene.pointerLockState), "a scene has one pointer lock state, not locked");
    UIViewController *controller = the_window.rootViewController;
    CHECK((!controller.prefersPointerLocked && controller.childViewControllerForPointerLock == nil), "a controller does not prefer a locked pointer");
    [controller setNeedsUpdateOfPrefersPointerLocked];
    CHECK(([UIPointerLockStateDidChangeNotification isEqual:@"UIPointerLockStateDidChangeNotification"] && [UIPointerLockStateSceneUserInfoKey isEqual:@"scene"]), "the pointer lock names are the system's");
}

- (void)traitsAndColors
{
    UITraitCollection *high = [UITraitCollection traitCollectionWithAccessibilityContrast:UIAccessibilityContrastHigh];
    UITraitCollection *bold = [UITraitCollection traitCollectionWithLegibilityWeight:UILegibilityWeightBold];
    UITraitCollection *elevated = [UITraitCollection traitCollectionWithUserInterfaceLevel:UIUserInterfaceLevelElevated];
    UITraitCollection *inactive = [UITraitCollection traitCollectionWithActiveAppearance:UIUserInterfaceActiveAppearanceInactive];
    CHECK((high.accessibilityContrast == UIAccessibilityContrastHigh && high.legibilityWeight == UILegibilityWeightUnspecified && bold.legibilityWeight == UILegibilityWeightBold && elevated.userInterfaceLevel == UIUserInterfaceLevelElevated &&
              inactive.activeAppearance == UIUserInterfaceActiveAppearanceInactive), "each new trait reads back and the others are unspecified");
    UITraitCollection *all = [UITraitCollection traitCollectionWithTraitsFromCollections:@[[UITraitCollection traitCollectionWithDisplayScale:2], high, bold, elevated, [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]]];
    CHECK((all.accessibilityContrast == UIAccessibilityContrastHigh && all.legibilityWeight == UILegibilityWeightBold && all.userInterfaceLevel == UIUserInterfaceLevelElevated && all.userInterfaceStyle == UIUserInterfaceStyleDark && all.displayScale == 2),
          "collections merge the new traits");
    NSString *description = [all description];
    CHECK(([description rangeOfString:@"UserInterfaceStyle = Dark, AccessibilityContrast = High, UserInterfaceLevel = Elevated"].location != NSNotFound), "and their description names the two the system names");
    CHECK(([all containsTraitsInCollection:high] && ![[UITraitCollection traitCollectionWithDisplayScale:2] containsTraitsInCollection:high] && [high isEqual:[UITraitCollection traitCollectionWithAccessibilityContrast:UIAccessibilityContrastHigh]] && ![high isEqual:bold]),
          "containment and equality follow them");
    CHECK(([[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark] hasDifferentColorAppearanceComparedToTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]] &&
              ![bold hasDifferentColorAppearanceComparedToTraitCollection:[UITraitCollection traitCollectionWithLegibilityWeight:UILegibilityWeightRegular]]), "a difference of appearance is a difference of style, contrast, level or activity");
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:all];
    UITraitCollection *back = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    CHECK(([back isEqual:all] && back.accessibilityContrast == UIAccessibilityContrastHigh), "a collection survives an archive");
    UITraitCollection *screen = [UIScreen mainScreen].traitCollection;
    CHECK((screen.accessibilityContrast == UIAccessibilityContrastNormal && screen.userInterfaceLevel == UIUserInterfaceLevelBase && screen.legibilityWeight == UILegibilityWeightRegular && screen.userInterfaceStyle == UIUserInterfaceStyleLight &&
              screen.activeAppearance == UIUserInterfaceActiveAppearanceActive), "the screen is light, normal, base and active");
    UITraitCollection *current = [UITraitCollection currentTraitCollection];
    CHECK((current.userInterfaceStyle == UIUserInterfaceStyleLight && current.displayScale == screen.displayScale), "the current collection is the screen's");
    __block UIUserInterfaceStyle inside = UIUserInterfaceStyleUnspecified;
    __block UIAccessibilityContrast nested = UIAccessibilityContrastUnspecified;
    [[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark] performAsCurrentTraitCollection:^{
        inside = [UITraitCollection currentTraitCollection].userInterfaceStyle;
        [high performAsCurrentTraitCollection:^{ nested = [UITraitCollection currentTraitCollection].accessibilityContrast; }];
    }];
    CHECK((inside == UIUserInterfaceStyleDark && nested == UIAccessibilityContrastHigh && [UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleLight), "performing as a collection sets it for the block only");
    CHECK(([[[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark] imageConfiguration] traitCollection].userInterfaceStyle == UIUserInterfaceStyleDark), "a collection makes an image configuration of itself");
    UIView *plainView = [[UIView alloc] init];
    CHECK((plainView.traitCollection.accessibilityContrast != UIAccessibilityContrastUnspecified || plainView.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight), "a view has the screen's traits");

    UIColor *(^provider)(UITraitCollection *) = ^UIColor *(UITraitCollection *t) {
        if (t.userInterfaceStyle == UIUserInterfaceStyleDark)
            return [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
        return t.userInterfaceLevel == UIUserInterfaceLevelElevated ? [UIColor colorWithRed:0 green:1 blue:0 alpha:0.5] : [UIColor colorWithRed:0 green:0 blue:1 alpha:1];
    };
    UIColor *dynamic = [UIColor colorWithDynamicProvider:provider];
    UIColor *made = [[UIColor alloc] initWithDynamicProvider:provider];
    CHECK((close_to(dynamic, 0, 0, 1, 1) && dynamic != made), "a dynamic colour is its light value, and two of them are two colours");
    CHECK((close_to([dynamic resolvedColorWithTraitCollection:traits(UIUserInterfaceStyleDark, UIAccessibilityContrastNormal, UIUserInterfaceLevelBase)], 1, 0, 0, 1) &&
              close_to([dynamic resolvedColorWithTraitCollection:traits(UIUserInterfaceStyleLight, UIAccessibilityContrastNormal, UIUserInterfaceLevelElevated)], 0, 1, 0, 0.5)), "it resolves against the collection it is given");
    UIColor *plainBlue = [UIColor colorWithRed:0 green:0 blue:1 alpha:1];
    CHECK(([plainBlue resolvedColorWithTraitCollection:traits(UIUserInterfaceStyleDark, UIAccessibilityContrastHigh, UIUserInterfaceLevelElevated)] == plainBlue), "an ordinary colour resolves to itself");
    CHECK((plainBlue != dynamic && close_to([[UIColor colorWithRed:0 green:0 blue:1 alpha:1] resolvedColorWithTraitCollection:traits(UIUserInterfaceStyleDark, 0, 0)], 0, 0, 1, 1)), "an ordinary colour of the same value does not turn dynamic");
    CHECK((close_to([[UIColor blueColor] resolvedColorWithTraitCollection:traits(UIUserInterfaceStyleDark, 0, 0)], 0, 0, 1, 1) && close_to([UIColor whiteColor], 1, 1, 1, 1)), "and neither do the shared ones");
    UITraitCollection *light = traits(UIUserInterfaceStyleLight, UIAccessibilityContrastNormal, UIUserInterfaceLevelBase), *dark = traits(UIUserInterfaceStyleDark, UIAccessibilityContrastNormal, UIUserInterfaceLevelBase);
    UITraitCollection *lifted = traits(UIUserInterfaceStyleDark, UIAccessibilityContrastNormal, UIUserInterfaceLevelElevated);
    CHECK((close_to([[UIColor labelColor] resolvedColorWithTraitCollection:light], 0, 0, 0, 1) && close_to([[UIColor labelColor] resolvedColorWithTraitCollection:dark], 1, 1, 1, 1)), "the label colour is black and white");
    CHECK((close_to([[UIColor secondarySystemBackgroundColor] resolvedColorWithTraitCollection:light], 242 / 255.0, 242 / 255.0, 247 / 255.0, 1) && close_to([[UIColor systemBackgroundColor] resolvedColorWithTraitCollection:dark], 0, 0, 0, 1) &&
              close_to([[UIColor systemBackgroundColor] resolvedColorWithTraitCollection:lifted], 28 / 255.0, 28 / 255.0, 30 / 255.0, 1)), "the backgrounds follow the appearance and the level");
    CHECK((close_to([[UIColor systemGray3Color] resolvedColorWithTraitCollection:light], 199 / 255.0, 199 / 255.0, 204 / 255.0, 1) && close_to([[UIColor systemGray3Color] resolvedColorWithTraitCollection:dark], 72 / 255.0, 72 / 255.0, 74 / 255.0, 1) &&
              close_to([[UIColor systemFillColor] resolvedColorWithTraitCollection:light], 120 / 255.0, 120 / 255.0, 128 / 255.0, 0.2) && close_to([[UIColor linkColor] resolvedColorWithTraitCollection:dark], 9 / 255.0, 132 / 255.0, 255 / 255.0, 1)),
          "the grays, fills and link are the recorded ones");
    CHECK(([UIColor labelColor] == [UIColor labelColor] && [UIColor systemBackgroundColor] != [UIColor secondarySystemBackgroundColor]), "a system colour is one colour");
    UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 4, 4)];
    swatch.backgroundColor = [UIColor systemBackgroundColor];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 4), YES, 1);
    [swatch.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *drawn = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CFDataRef pixels = CGDataProviderCopyData(CGImageGetDataProvider(drawn.CGImage));
    CHECK((CFDataGetLength(pixels) >= 4 && CFDataGetBytePtr(pixels)[0] > 250 && CFDataGetBytePtr(pixels)[1] > 250 && CFDataGetBytePtr(pixels)[2] > 250), "a view painted with the system background is white");
    CFRelease(pixels);
}

- (void)viewsAndControls
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    view.transform3D = CATransform3DMakeRotation(1, 1, 0, 0);
    CHECK((CATransform3DEqualToTransform(view.transform3D, view.layer.transform) && !CATransform3DEqualToTransform(view.transform3D, CATransform3DIdentity)), "transform3D is the layer's transform");
    view.transform = CGAffineTransformMakeScale(2, 2);
    CHECK((CATransform3DEqualToTransform(view.transform3D, CATransform3DMakeScale(2, 2, 1))), "and follows the affine one");
    view.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    CHECK((view.overrideUserInterfaceStyle == UIUserInterfaceStyleDark && view.traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark), "a dark override is kept and does not change the traits");
    UIViewController *controller = [[UIViewController alloc] init];
    controller.modalInPresentation = YES;
    controller.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    CHECK((controller.modalInPresentation && controller.overrideUserInterfaceStyle == UIUserInterfaceStyleLight && controller.performsActionsWhilePresentingModally), "a controller keeps its presentation flags");
    UIView *animated = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    [the_window addSubview:animated];
    [UIView animateWithDuration:1 animations:^{
        [UIView modifyAnimationsWithRepeatCount:2 autoreverses:YES animations:^{ animated.alpha = 0.3; }];
    }];
    CAAnimation *animation = [animated.layer animationForKey:@"opacity"];
    CHECK((animation == nil || (animation.repeatCount == 2 && animation.autoreverses)), "an animation made inside modifyAnimations repeats twice and reverses");
    [animated.layer removeAllAnimations];

    Recorder *target = [[Recorder alloc] init];
    NSMutableArray *fired = [NSMutableArray array];
    UIAction *a1 = [UIAction actionWithTitle:@"a1" image:nil identifier:@"id1" handler:^(UIAction *action) { [fired addObject:[NSString stringWithFormat:@"a1 %@", NSStringFromClass([action.sender class])]]; }];
    UIAction *a2 = [UIAction actionWithTitle:@"a2" image:nil identifier:@"id2" handler:^(UIAction *action) { [fired addObject:@"a2"]; }];
    UIAction *a1b = [UIAction actionWithTitle:@"a1b" image:nil identifier:@"id1" handler:^(UIAction *action) { [fired addObject:@"a1b"]; }];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button addAction:a1 forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:target action:@selector(go:) forControlEvents:UIControlEventTouchUpInside | UIControlEventValueChanged];
    [button addAction:a2 forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchDown];
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
    CHECK(([fired isEqual:@[@"a1 UIButton", @"a2"]] && [target.log isEqual:@[@"target UIButton"]]), "actions and targets fire for their events, with the button as the sender");
    [fired removeAllObjects];
    [button sendActionsForControlEvents:UIControlEventTouchDown];
    CHECK(([fired isEqual:@[@"a2"]]), "an action fires for each event it was added for");
    NSMutableArray *rows = [NSMutableArray array];
    [button enumerateEventHandlers:^(UIAction *action, id targetObject, SEL selector, UIControlEvents events, BOOL *stop) {
        [rows addObject:[NSString stringWithFormat:@"%@ %@ 0x%lx", action ? action.title : @"-", selector ? NSStringFromSelector(selector) : @"-", (unsigned long)events]];
    }];
    NSArray *sorted = [rows sortedArrayUsingSelector:@selector(compare:)];
    CHECK(([sorted isEqual:@[@"- go: 0x1040", @"a1 - 0x40", @"a2 - 0x41"]]), "the handlers are enumerated with their events");
    [button addAction:a1b forControlEvents:UIControlEventTouchUpInside];
    [fired removeAllObjects];
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
    CHECK(([fired containsObject:@"a1b"] && ![fired containsObject:@"a1 UIButton"]), "an action with the same identifier replaces the first");
    [button removeActionForIdentifier:@"id2" forControlEvents:UIControlEventTouchDown];
    [fired removeAllObjects];
    [button sendActionsForControlEvents:UIControlEventTouchDown];
    CHECK((fired.count == 0), "an action is removed for one event by its identifier");
    [button removeAction:a1 forControlEvents:UIControlEventTouchUpInside];
    [fired removeAllObjects];
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
    CHECK((![fired containsObject:@"a1b"]), "an equal action removes by identifier");
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    NSUInteger handlers = 0;
    __block NSUInteger counted = 0;
    [button enumerateEventHandlers:^(UIAction *action, id targetObject, SEL selector, UIControlEvents events, BOOL *stop) { counted++; }];
    handlers = counted;
    CHECK((handlers == 0), "removing every target removes the actions too");
    NSString *nilAction = nil;
    @try {
        [button addAction:nil forControlEvents:UIControlEventTouchUpInside];
    } @catch (NSException *exception) {
        nilAction = exception.reason;
    }
    CHECK(([nilAction hasPrefix:@"Attempt to set nil action with event mask:"]), "a nil action is refused");
    [fired removeAllObjects];
    UIButton *primary = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 10, 10) primaryAction:[UIAction actionWithTitle:@"P" image:nil identifier:@"pid" handler:^(UIAction *action) { [fired addObject:@"primary"]; }]];
    CHECK(([[primary titleForState:UIControlStateNormal] isEqual:@"P"]), "a button made with a primary action has its title");
    [primary sendActionsForControlEvents:UIControlEventTouchUpInside];
    CHECK(([fired isEqual:@[@"primary"]]), "the primary action fires on a touch up inside");
    [fired removeAllObjects];
    [primary sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
    CHECK(([fired isEqual:@[@"primary"]]), "and when the primary action event is sent");
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero primaryAction:[UIAction actionWithTitle:@"S" image:nil identifier:@"sid" handler:^(UIAction *action) { [fired addObject:@"switch"]; }]];
    [fired removeAllObjects];
    [toggle sendActionsForControlEvents:UIControlEventValueChanged];
    CHECK(([fired isEqual:@[@"switch"]]), "a switch fires its primary action when its value changes");
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero primaryAction:[UIAction actionWithTitle:@"F" image:nil identifier:@"fid" handler:^(UIAction *action) { [fired addObject:@"field"]; }]];
    [fired removeAllObjects];
    [field sendActionsForControlEvents:UIControlEventEditingDidEndOnExit];
    CHECK(([fired isEqual:@[@"field"]]), "a text field fires it when editing ends on exit");
    UIButton *systemButton = [UIButton systemButtonWithImage:[[UIImage alloc] init] target:target action:@selector(go:)];
    CHECK(([systemButton imageForState:UIControlStateNormal] != nil), "a system button with an image has it");
    UIButton *typed = [UIButton buttonWithType:UIButtonTypeCustom primaryAction:a1];
    CHECK(([[typed titleForState:UIControlStateNormal] isEqual:@"a1"]), "a button of a type made with an action has its title");
    typed.role = UIButtonRoleDestructive;
    CHECK((typed.role == UIButtonRoleDestructive), "a button keeps its role");
    [typed setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20] forImageInState:UIControlStateNormal];
    CHECK(([typed preferredSymbolConfigurationForImageInState:UIControlStateNormal] != nil && typed.currentPreferredSymbolConfiguration != nil && [typed preferredSymbolConfigurationForImageInState:UIControlStateSelected] == nil), "a button keeps a symbol configuration for a state");

    UISegmentedControl *segments = [[UISegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 200, 30) actions:@[a1, a2]];
    CHECK((segments.numberOfSegments == 2 && [[segments titleForSegmentAtIndex:1] isEqual:@"a2"] && segments.selectedSegmentIndex == UISegmentedControlNoSegment && [segments segmentIndexForActionIdentifier:@"id2"] == 1 &&
              [segments segmentIndexForActionIdentifier:@"nope"] == NSNotFound), "a segmented control made of actions has a segment for each");
    segments.selectedSegmentIndex = 1;
    [fired removeAllObjects];
    [segments sendActionsForControlEvents:UIControlEventValueChanged];
    CHECK(([fired isEqual:@[@"a2"]]), "choosing a segment performs its action");
    [segments insertSegmentWithTitle:@"plain" atIndex:0 animated:NO];
    CHECK(([segments actionForSegmentAtIndex:0] == nil && [segments segmentIndexForActionIdentifier:@"id2"] == 2 && [segments actionForSegmentAtIndex:2] != nil), "a plain segment inserted before shifts the actions with their segments");
    [segments removeSegmentAtIndex:0 animated:NO];
    CHECK(([segments segmentIndexForActionIdentifier:@"id2"] == 1), "and removing it shifts them back");
    NSString *duplicate = nil;
    @try {
        [segments setAction:a1 forSegmentAtIndex:1];
    } @catch (NSException *exception) {
        duplicate = exception.reason;
    }
    CHECK(([duplicate hasSuffix:@"Identifiers are required to be unique."]), "two segments may not share an identifier");
    UIBarButtonItem *space = [UIBarButtonItem fixedSpaceItemOfWidth:10];
    CHECK((space.width == 10 && [UIBarButtonItem flexibleSpaceItem] != nil), "the space items are made");
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithTitle:@"Item" image:nil identifier:@"iid" handler:^(UIAction *action) { [fired addObject:[NSString stringWithFormat:@"item %@", NSStringFromClass([action.sender class])]]; }]];
    CHECK(([item.title isEqual:@"Item"] && item.primaryAction != nil && item.menu == nil), "a bar button item made of an action has its title");
    [fired removeAllObjects];
    [item.target performSelector:item.action withObject:item];
    CHECK(([fired isEqual:@[@"item UIBarButtonItem"]]), "tapping it performs the action with the item as the sender");
}

- (void)menus
{
    NSMutableArray *chosen = [NSMutableArray array];
    UIAction *open = [UIAction actionWithTitle:@"Open" image:nil identifier:nil handler:^(UIAction *action) { [chosen addObject:@"open"]; }];
    UIAction *remove = [UIAction actionWithTitle:@"Remove" image:nil identifier:nil handler:^(UIAction *action) { [chosen addObject:@"remove"]; }];
    remove.attributes = UIMenuElementAttributesDestructive;
    UICommand *command = [UICommand commandWithTitle:@"Command" image:nil action:@selector(charonRestCommand:) propertyList:nil];
    UIMenu *menu = [UIMenu menuWithTitle:@"Things" children:@[open, command, remove]];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(20, 200, 80, 40);
    [the_window.rootViewController.view addSubview:button];
    button.menu = menu;
    CHECK((button.menu != nil && [button.menu isEqual:menu] && button.menu != menu && button.contextMenuInteractionEnabled && button.contextMenuInteraction != nil && !button.showsMenuAsPrimaryAction), "a button with a menu has a context menu interaction and copies the menu");
    button.showsMenuAsPrimaryAction = YES;
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
    CHECK((wait_until(^BOOL { return visible_sheet() != nil; }, 10)), "a button whose menu is its primary action shows an action sheet when tapped");
    UIActionSheet *sheet = visible_sheet();
    NSMutableArray *titles = [NSMutableArray array];
    for (NSInteger index = 0; index < sheet.numberOfButtons; index++)
        [titles addObject:[sheet buttonTitleAtIndex:index]];
    CHECK(([titles containsObject:@"Open"] && [titles containsObject:@"Command"] && [titles containsObject:@"Remove"] && sheet.destructiveButtonIndex >= 0), "the sheet lists actions and commands");
    NSInteger openIndex = [titles indexOfObject:@"Open"];
    [sheet dismissWithClickedButtonIndex:openIndex animated:NO];
    CHECK((wait_until(^BOOL { return [chosen containsObject:@"open"]; }, 5)), "choosing an action runs its handler");
    button.menu = nil;
    CHECK((!button.contextMenuInteractionEnabled && button.menu == nil), "a button without a menu has no interaction");

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Menu" menu:menu];
    CHECK((item.menu != nil && [item.title isEqual:@"Menu"]), "a bar button item with a menu keeps it");
    [item.target performSelector:item.action withObject:item];
    CHECK((wait_until(^BOOL { return visible_sheet() != nil; }, 10)), "tapping it shows an action sheet");
    sheet = visible_sheet();
    [sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
    CHECK((wait_until(^BOOL { return visible_sheet() == nil; }, 5)), "the sheet goes away");

    Lists *lists = [[Lists alloc] init];
    lists.events = [NSMutableArray array];
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 300) style:UITableViewStylePlain];
    table.dataSource = lists;
    table.rowHeight = 44;
    [the_window.rootViewController.view addSubview:table];
    table.delegate = lists;
    [table reloadData];
    UIContextMenuInteraction *interaction = table.contextMenuInteraction;
    CHECK((interaction != nil && interaction == table.contextMenuInteraction && [table.interactions containsObject:interaction]), "a table whose delegate wants menus has a context menu interaction");
    id<UIContextMenuInteractionDelegate> owner = interaction.delegate;
    UIContextMenuConfiguration *configuration = [owner contextMenuInteraction:interaction configurationForMenuAtLocation:CGPointMake(10, 44 * 2 + 5)];
    CHECK((configuration != nil && [lists.events isEqual:@[@"configuration row 2"]]), "the delegate is asked for the row under the point");
    CHECK(([owner contextMenuInteraction:interaction configurationForMenuAtLocation:CGPointMake(10, 44 * 5 + 5)] == nil), "and for no row when there is none");
    [interaction charon_beginAtLocation:CGPointMake(10, 44 * 2 + 5)];
    CHECK((wait_until(^BOOL { return visible_sheet() != nil; }, 10)), "a long press on a row shows its menu");
    sheet = visible_sheet();
    CHECK(([lists.events containsObject:@"will display"]), "the delegate hears the menu appear");
    [sheet dismissWithClickedButtonIndex:0 animated:NO];
    CHECK((wait_until(^BOOL { return [lists.events containsObject:@"open"] && [lists.events containsObject:@"will end"]; }, 5)), "choosing runs the action and the delegate hears it end");
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    UICollectionView *collection = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 300) collectionViewLayout:layout];
    CHECK((collection.contextMenuInteraction != nil && [collection.interactions containsObject:collection.contextMenuInteraction]), "a collection view answers a context menu interaction too");
}

- (void)lifecycle
{
    Appearing *first = [[Appearing alloc] init];
    first.events = [NSMutableArray array];
    UIViewController *root = the_window.rootViewController;
    [root presentViewController:first animated:NO completion:nil];
    CHECK((wait_until(^BOOL { return [first.events containsObject:@"did"]; }, 10)), "a presented controller appears");
    NSArray *expected = @[@"will", @"will done", @"is", @"did"];
    CHECK(([first.events isEqual:expected]), "viewIsAppearing comes once, after viewWillAppear has finished and before viewDidAppear");
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    [keep addObject:first];
    [first dismissViewControllerAnimated:NO completion:nil];
    wait_until(^BOOL { return NO; }, 1.5);
    Appearing *second = [[Appearing alloc] init];
    second.events = [NSMutableArray array];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:second];
    [root presentViewController:navigation animated:NO completion:nil];
    CHECK((wait_until(^BOOL { return [second.events containsObject:@"did"]; }, 10) && [second.events isEqual:expected]), "a controller in a navigation controller is called too");
    [keep addObject:navigation];
    [keep addObject:second];
    [navigation dismissViewControllerAnimated:NO completion:nil];
    wait_until(^BOOL { return NO; }, 1.5);

    UnwindOverride *override = [[UnwindOverride alloc] init];
    UIViewController *from = [[UIViewController alloc] init];
    BOOL (*old)(id, SEL, SEL, id, id) = (void *)objc_msgSend;
    CHECK((old(override, @selector(canPerformUnwindSegueAction:fromViewController:withSender:), @selector(description), from, nil) && override.asked == 1), "the release's own unwind question reaches an override of the new one");
    CHECK(([override canPerformUnwindSegueAction:@selector(unwindToHere:) fromViewController:from sender:nil] && ![override canPerformUnwindSegueAction:@selector(nothing:) fromViewController:from sender:nil]), "and the default of the new one is the release's answer");
    CHECK((old(override, @selector(canPerformUnwindSegueAction:fromViewController:withSender:), @selector(unwindToHere:), from, nil)), "an action the controller implements is allowed through the old question");
    CHECK((![UIStoryboard instancesRespondToSelector:@selector(instantiateInitialViewControllerWithCreator:)] && ![UIStoryboard instancesRespondToSelector:@selector(instantiateViewControllerWithIdentifier:creator:)]), "storyboards answer no creator");

    NSUInteger before = scene_events.count;
    NSNotification *rotated = [NSNotification notificationWithName:UIApplicationDidChangeStatusBarOrientationNotification object:[UIApplication sharedApplication]
                                                          userInfo:@{UIApplicationStatusBarOrientationUserInfoKey: @(UIInterfaceOrientationLandscapeLeft)}];
    [[NSNotificationCenter defaultCenter] postNotification:rotated];
    log_line([NSString stringWithFormat:@"scene events %lu -> %lu, last [%@]", (unsigned long)before, (unsigned long)scene_events.count, scene_events.lastObject]);
    CHECK((scene_events.count == before + 1 && [scene_events.lastObject hasPrefix:@"coordinate space 4 "]), "the scene delegate hears the interface change with the previous orientation");

    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 300, 300, 30)];
    field.text = @"hello brave new world";
    Selecting *selecting = [[Selecting alloc] init];
    selecting.events = [NSMutableArray array];
    field.delegate = selecting;
    [the_window.rootViewController.view addSubview:field];
    [field becomeFirstResponder];
    wait_until(^BOOL { return [selecting.events count] > 0; }, 3);
    NSUInteger began = selecting.events.count;
    UITextPosition *start = [field positionFromPosition:field.beginningOfDocument offset:2];
    field.selectedTextRange = [field textRangeFromPosition:start toPosition:start];
    CHECK((wait_until(^BOOL { return selecting.events.count > began; }, 3)), "the delegate hears of a change of selection at the end of the run loop");
    NSUInteger settled = selecting.events.count;
    wait_until(^BOOL { return NO; }, 0.3);
    CHECK((selecting.events.count == settled), "and does not hear of one that did not change");
    [field resignFirstResponder];
}

- (void)images
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 10), NO, 1);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, 10, 5));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImage *tinted = [image imageWithTintColor:[UIColor redColor]];
    // Read the pixels through a bitmap of a known layout: the layout of a UIKit image differs between releases.
    UInt8 bytes[10 * 10 * 4];
    memset(bytes, 0, sizeof(bytes));
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(bytes, 10, 10, 8, 40, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(bitmap, 0, 10);
    CGContextScaleCTM(bitmap, 1, -1);
    UIGraphicsPushContext(bitmap);
    [tinted drawInRect:CGRectMake(0, 0, 10, 10)];
    UIGraphicsPopContext();
    CGContextRelease(bitmap);
    log_line([NSString stringWithFormat:@"tint pixels top %d %d %d %d, bottom alpha %d", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4 * 10 * 8 + 3]]);
    CHECK((tinted.size.width == 10 && bytes[0] > 250 && bytes[1] < 5 && bytes[2] < 5 && bytes[3] > 250 && bytes[4 * 10 * 8 + 3] == 0), "a tinted image is red where it was opaque and empty where it was");
    CHECK((tinted.renderingMode == UIImageRenderingModeAutomatic && [image imageWithTintColor:[UIColor redColor] renderingMode:UIImageRenderingModeAlwaysTemplate].renderingMode == UIImageRenderingModeAlwaysTemplate), "its rendering mode is the one asked for");
    UIImage *based = [image imageWithBaselineOffsetFromBottom:3];
    CHECK((!image.hasBaseline && based != image), "a baseline is set on a copy, not on the image");
    CHECK((based.hasBaseline && based.baselineOffsetFromBottom == 3), "the copy has the baseline");
    CHECK((![based imageWithoutBaseline].hasBaseline && based.hasBaseline), "a baseline is dropped on a copy");
    CHECK(([based imageWithTintColor:[UIColor redColor]].hasBaseline), "a baseline is carried by a tint");
    CHECK(([[image configuration] isKindOfClass:[UIImageConfiguration class]] && [image imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20]].symbolConfiguration != nil), "an image has a configuration and takes a symbol one");
    UIImage *glyphs[] = {[UIImage checkmarkImage], [UIImage strokedCheckmarkImage], [UIImage addImage], [UIImage removeImage], [UIImage actionsImage]};
    BOOL drawn = YES;
    for (int index = 0; index < 5; index++)
        drawn = drawn && glyphs[index].renderingMode == UIImageRenderingModeAlwaysTemplate && glyphs[index].size.width == 20 && lit_pixels(glyphs[index], CGSizeMake(20, 20)) > 10;
    CHECK((drawn && [UIImage checkmarkImage] == [UIImage checkmarkImage]), "the system images are template images of 20 points that draw something");

    NSString *folder = [results_folder stringByAppendingPathComponent:@"uirest-images.bundle"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 6), NO, 1);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, 8, 6));
    [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[folder stringByAppendingPathComponent:@"logo.png"] atomically:YES];
    UIGraphicsEndImageContext();
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(16, 12), NO, 1);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, 16, 12));
    [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[folder stringByAppendingPathComponent:@"logo@2x.png"] atomically:YES];
    UIGraphicsEndImageContext();
    NSBundle *bundle = [NSBundle bundleWithPath:folder];
    UIImage *named = [UIImage imageNamed:@"logo" inBundle:bundle withConfiguration:nil];
    CHECK((named != nil && named.scale == [UIScreen mainScreen].scale && named.size.width == 8 && [UIImage imageNamed:@"absent" inBundle:bundle withConfiguration:nil] == nil && [UIImage imageNamed:@"absent" inBundle:nil withConfiguration:nil] == nil),
          "an image is found in a bundle at the scale of the screen");

    NSLayoutManager *layout = [[NSLayoutManager alloc] init];
    CHECK((!layout.usesDefaultHyphenation), "a layout manager does not use default hyphenation");
    UIFont *font = [UIFont systemFontOfSize:20];
    CGGlyph glyph[1];
    CGFontRef face = CGFontCreateWithFontName((__bridge CFStringRef)font.fontName);
    glyph[0] = CGFontGetGlyphWithGlyphName(face, CFSTR("H"));
    CFRelease(face);
    CGPoint position = CGPointMake(2, 22);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 1);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, 30);
    CGContextScaleCTM(context, 1, -1);
    [layout showCGGlyphs:glyph positions:&position count:1 font:font textMatrix:CGAffineTransformIdentity attributes:@{NSForegroundColorAttributeName: [UIColor blackColor]} inContext:context];
    UIImage *glyphImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CHECK((lit_pixels(glyphImage, CGSizeMake(30, 30)) > 20), "showCGGlyphs draws the glyph");

    CHECK((UIFontWidthStandard == 0 && UIFontWidthExpanded == 0.2f && UIFontWidthCondensed == -0.2f && UIFontWidthCompressed == -0.3f), "the four font widths have the values of the release that has them");
    UIFont *widthFont = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular width:UIFontWidthCondensed];
    CHECK((widthFont != nil && widthFont.pointSize == 17 && [widthFont.familyName isEqual:[UIFont systemFontOfSize:17].familyName]), "a system font of a width is the font of the weight");

    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"hello world"];
    [text addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(6, 5)];
    textView.attributedText = text;
    UITextPosition *from = [textView positionFromPosition:textView.beginningOfDocument offset:3], *to = [textView positionFromPosition:textView.beginningOfDocument offset:8];
    [textView replaceRange:[textView textRangeFromPosition:from toPosition:to] withAttributedText:[[NSAttributedString alloc] initWithString:@"XY" attributes:@{NSForegroundColorAttributeName: [UIColor blueColor]}]];
    log_line([NSString stringWithFormat:@"text is [%@] length %lu", textView.attributedText.string, (unsigned long)textView.attributedText.length]);
    CHECK(([[textView.attributedText.string stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] isEqual:@"helXYrld"]), "replacing a range with attributed text changes the text");
    CHECK((close_to([textView.attributedText attribute:NSForegroundColorAttributeName atIndex:3 effectiveRange:NULL], 0, 0, 1, 1) &&
              close_to([textView.attributedText attribute:NSForegroundColorAttributeName atIndex:6 effectiveRange:NULL], 1, 0, 0, 1)), "the runs are kept");
    log_line([NSString stringWithFormat:@"caret %lu length %lu", (unsigned long)textView.selectedRange.location, (unsigned long)textView.selectedRange.length]);
    CHECK((textView.selectedRange.location == 5 && textView.selectedRange.length == 0), "and the caret is after the inserted text");
}

- (void)members
{
    CHECK((!UIAccessibilityShouldDifferentiateWithoutColor() && !UIAccessibilityIsOnOffSwitchLabelsEnabled() && UIAccessibilityIsVideoAutoplayEnabled() && !UIAccessibilityButtonShapesEnabled() && !UIAccessibilityPrefersCrossFadeTransitions()),
          "the accessibility settings of iOS 13 and 14 answer as the host does");
    CHECK(([UIAccessibilityTextualContextSourceCode isEqual:@"UIAccessibilityTextualContextSourceCode"] && [UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification isEqual:@"UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification"] &&
              [NSCocoaVersionDocumentAttribute isEqual:@"CocoaRTFVersion"] && [NSTrackingAttributeName isEqual:@"CTTracking"] && [UIPasteboardDetectionPatternNumber isEqual:@"com.apple.uikit.pasteboard-detection-pattern.number"]), "the names are the system's");
    NSObject *object = [[NSObject alloc] init];
    CHECK((object.accessibilityUserInputLabels.count == 0 && object.accessibilityAttributedUserInputLabels == nil && object.accessibilityTextualContext == nil && !object.accessibilityRespondsToUserInteraction), "an object has no input labels");
    object.accessibilityUserInputLabels = @[@"a", @"b"];
    CHECK(([object.accessibilityUserInputLabels count] == 2 && [[object.accessibilityAttributedUserInputLabels firstObject] isKindOfClass:[NSAttributedString class]]), "labels turn into attributed labels");
    object.accessibilityAttributedUserInputLabels = @[[[NSAttributedString alloc] initWithString:@"z"]];
    CHECK(([object.accessibilityUserInputLabels isEqual:@[@"z"]]), "and attributed ones into plain");
    object.accessibilityTextualContext = UIAccessibilityTextualContextConsole;
    object.accessibilityRespondsToUserInteraction = YES;
    CHECK(([object.accessibilityTextualContext isEqual:UIAccessibilityTextualContextConsole] && object.accessibilityRespondsToUserInteraction), "the context and the interaction hint are kept");
    UIAccessibilityCustomAction *custom = [[UIAccessibilityCustomAction alloc] initWithName:@"n" actionHandler:^BOOL(UIAccessibilityCustomAction *x) { return YES; }];
    UIAccessibilityCustomAction *imaged = [[UIAccessibilityCustomAction alloc] initWithName:@"m" image:[[UIImage alloc] init] target:object selector:@selector(description)];
    CHECK(([custom.name isEqual:@"n"] && custom.actionHandler != nil && custom.target == nil && imaged.image != nil && imaged.target == object && imaged.actionHandler == nil), "a custom action keeps its handler and image");
    UIDatePicker *picker = [[UIDatePicker alloc] init];
    picker.preferredDatePickerStyle = UIDatePickerStyleInline;
    CHECK((picker.preferredDatePickerStyle == UIDatePickerStyleInline && picker.datePickerStyle == UIDatePickerStyleWheels), "a date picker keeps the style asked for and draws wheels");
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.preferredStyle = UISwitchStyleCheckbox;
    CHECK((toggle.style == UISwitchStyleSliding && toggle.preferredStyle == UISwitchStyleCheckbox && toggle.title == nil), "a switch is sliding whatever style is preferred");
    UIPageControl *pages = [[UIPageControl alloc] init];
    pages.numberOfPages = 3;
    UIImage *dot = [[UIImage alloc] init];
    [pages setIndicatorImage:dot forPage:1];
    NSString *range = nil;
    @try {
        [pages indicatorImageForPage:3];
    } @catch (NSException *exception) {
        range = exception.reason;
    }
    CHECK(([pages indicatorImageForPage:1] == dot && [pages indicatorImageForPage:2] == nil && [range isEqual:@"Page (3) must be within 0 and 3."] && pages.allowsContinuousInteraction && pages.interactionState == UIPageControlInteractionStateNone),
          "a page control keeps its indicator images and checks the page");
    UILabel *label = [[UILabel alloc] init];
    CHECK((label.lineBreakStrategy == NSLineBreakStrategyStandard), "a label's line break strategy is the standard");
    UIScrollView *scroll = [[UIScrollView alloc] init];
    CHECK((scroll.automaticallyAdjustsScrollIndicatorInsets && [UIScreen mainScreen].calibratedLatency == 0), "a scroll view adjusts its indicator insets and the screen has no latency to calibrate");
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"x"];
    item.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    CHECK((item.backButtonDisplayMode == UINavigationItemBackButtonDisplayModeMinimal), "a navigation item keeps its back button display mode");
    UISearchBar *bar = [[UISearchBar alloc] init];
    [bar setShowsScopeBar:YES animated:NO];
    CHECK((bar.showsScopeBar), "a search bar shows its scope bar");
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] init];
    pan.allowedScrollTypesMask = UIScrollTypeMaskAll;
    CHECK((pan.allowedScrollTypesMask == UIScrollTypeMaskAll), "a pan recogniser keeps the scroll types it may take");
    UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [impact impactOccurredWithIntensity:0.5];
    [impact impactOccurredWithIntensity:0];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithUniqueName];
    __block NSSet *found = nil;
    [pasteboard detectPatternsForPatterns:[NSSet setWithObject:UIPasteboardDetectionPatternNumber] completionHandler:^(NSSet *set, NSError *error) { found = set ?: [NSSet setWithObject:@"error"]; }];
    CHECK((wait_until(^BOOL { return found != nil; }, 3) && found.count == 0), "pattern detection finds no pattern");
    UIVibrancyEffect *effect = [UIVibrancyEffect effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] style:UIVibrancyEffectStyleLabel];
    CHECK(([effect isKindOfClass:[UIVibrancyEffect class]]), "a vibrancy effect can be made with a style");
    UIView *hyphen = [[UIView alloc] init];
    hyphen.focusGroupIdentifier = @"group";
    CHECK(([hyphen.focusGroupIdentifier isEqual:@"group"] && [UISplitViewController instancesRespondToSelector:@selector(primaryBackgroundStyle)] && ![UISplitViewController instancesRespondToSelector:@selector(showColumn:)]), "the focus group is kept and the columns of a split view controller are absent");
    UITextView *scaling = [[UITextView alloc] init];
    scaling.usesStandardTextScaling = YES;
    CHECK((scaling.usesStandardTextScaling), "a text view keeps its text scaling");
    CHECK((![UIDocumentPickerViewController instancesRespondToSelector:@selector(initForOpeningContentTypes:)]), "a document picker made of content types is absent");
}

- (void)run
{
    CHECK((wait_until(^BOOL { return the_window != nil; }, 10) && the_window.windowScene != nil), "the scene is connected");
    [self commands];
    [self activityItems];
    [self inert];
    [self traitsAndColors];
    [self viewsAndControls];
    [self menus];
    [self lifecycle];
    [self images];
    [self members];
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        scene_events = [NSMutableArray array];
        return UIApplicationMain(argc, argv, nil, @"CharonRestDelegate");
    }
}
