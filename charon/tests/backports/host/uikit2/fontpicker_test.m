#import "uirest.h"

@interface PickerDelegate : NSObject <UIFontPickerViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@end

@implementation PickerDelegate

- (instancetype)init
{
    if ((self = [super init]))
        self.events = [NSMutableArray array];
    return self;
}

- (void)fontPickerViewControllerDidCancel:(UIFontPickerViewController *)viewController
{
    [self.events addObject:@"cancel"];
}

@end

static NSArray *config_lines(Class config, Class picker)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIFontPickerViewControllerConfiguration *c = [[config alloc] init];
    [lines addObject:ur_line(@"defaults", @[c, @(c.includeFaces), @(c.displayUsingSystemFont), @(c.filteredTraits), c.filteredLanguagesPredicate ?: @"nil"])];
    NSPredicate *p = [config filterPredicateForFilteredLanguages:@[@"en", @"fr"]];
    [lines addObject:ur_line(@"predicate", @[p, [p class] == [NSComparisonPredicate class] ? @"comparison" : @"other", @([p evaluateWithObject:@"en"]), @([p evaluateWithObject:@"de"])])];
    [lines addObject:ur_line(@"empty predicate", [config filterPredicateForFilteredLanguages:@[]] ?: @"nil")];
    c.includeFaces = YES;
    c.displayUsingSystemFont = YES;
    c.filteredTraits = UIFontDescriptorTraitBold;
    c.filteredLanguagesPredicate = p;
    UIFontPickerViewControllerConfiguration *copy = [c copy];
    [lines addObject:ur_line(@"copy", @[copy, @(copy != c), @(copy.includeFaces), @(copy.displayUsingSystemFont), @(copy.filteredTraits), copy.filteredLanguagesPredicate, @([copy isEqual:c])])];
    UIFontPickerViewController *v = [[picker alloc] initWithConfiguration:c];
    [lines addObject:ur_line(@"picker", @[v, @(v.configuration != c), @(v.configuration.includeFaces), v.delegate ?: @"nil", v.selectedFontDescriptor ?: @"nil", @([v isKindOfClass:[UIViewController class]])])];
    c.includeFaces = NO;
    [lines addObject:ur_line(@"mutation after creation", @(v.configuration.includeFaces))];
    [lines addObject:ur_line(@"same configuration each time", @(v.configuration == v.configuration))];
    [lines addObject:ur_line(@"nil configuration", @(ur_raised(^id { return ((UIFontPickerViewController *)[[picker alloc] initWithConfiguration:nil]).configuration ?: @"nil"; }).length))];
    UIFontPickerViewController *bare = [[picker alloc] performSelector:NSSelectorFromString(@"init")];
    [lines addObject:ur_line(@"init", @[bare, bare.configuration, @(bare.configuration.includeFaces)])];
    PickerDelegate *delegate = [[PickerDelegate alloc] init];
    v.delegate = delegate;
    [lines addObject:ur_line(@"delegate", @(v.delegate == delegate))];
    v.delegate = nil;
    delegate = nil;
    [lines addObject:ur_line(@"delegate is weak", v.delegate ?: @"nil")];
    return lines;
}

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Class ourConfig = NSClassFromString(@"CharonHostUIFontPickerViewControllerConfiguration"), ourPicker = NSClassFromString(@"CharonHostUIFontPickerViewController");
        charon_check(ourConfig && ourPicker, "the port's classes are linked under their host names", @"missing");
        ur_agree(@"font picker values", config_lines(ourConfig, ourPicker), config_lines([UIFontPickerViewControllerConfiguration class], [UIFontPickerViewController class]));
        UIFontPickerViewController *picker = [[ourPicker alloc] initWithConfiguration:[[ourConfig alloc] init]];
        PickerDelegate *delegate = [[PickerDelegate alloc] init];
        picker.delegate = delegate;
        UIView *view = picker.view;
        UIButton *cancel = nil;
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:[UIButton class]])
                cancel = (UIButton *)subview;
        }
        charon_check(cancel != nil, "the picker offers a button", @"it has none");
        [cancel sendActionsForControlEvents:UIControlEventTouchUpInside];
        charon_check([delegate.events isEqual:@[@"cancel"]], "the button tells the delegate the picker was cancelled", ur_norm(delegate.events));
    }
}
