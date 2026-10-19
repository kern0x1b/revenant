#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation UIFontPickerViewControllerConfiguration {
@private
    BOOL _includeFaces;
    BOOL _displayUsingSystemFont;
    UIFontDescriptorSymbolicTraits _filteredTraits;
    NSPredicate *_filteredLanguagesPredicate;
}

+ (NSPredicate *)filterPredicateForFilteredLanguages:(NSArray<NSString *> *)filteredLanguages
{
    if (!filteredLanguages.count)
        return nil;
    return [NSPredicate predicateWithFormat:@"ANY %@ IN SELF", filteredLanguages];
}

- (BOOL)includeFaces
{
    return _includeFaces;
}

- (void)setIncludeFaces:(BOOL)includeFaces
{
    _includeFaces = includeFaces;
}

- (BOOL)displayUsingSystemFont
{
    return _displayUsingSystemFont;
}

- (void)setDisplayUsingSystemFont:(BOOL)displayUsingSystemFont
{
    _displayUsingSystemFont = displayUsingSystemFont;
}

- (UIFontDescriptorSymbolicTraits)filteredTraits
{
    return _filteredTraits;
}

- (void)setFilteredTraits:(UIFontDescriptorSymbolicTraits)filteredTraits
{
    _filteredTraits = filteredTraits;
}

- (NSPredicate *)filteredLanguagesPredicate
{
    return _filteredLanguagesPredicate;
}

- (void)setFilteredLanguagesPredicate:(NSPredicate *)filteredLanguagesPredicate
{
    _filteredLanguagesPredicate = [filteredLanguagesPredicate copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIFontPickerViewControllerConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy->_includeFaces = _includeFaces;
    copy->_displayUsingSystemFont = _displayUsingSystemFont;
    copy->_filteredTraits = _filteredTraits;
    copy->_filteredLanguagesPredicate = [_filteredLanguagesPredicate copy];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; includeFaces: %@; displayUsingSystemFont: %@>", [self class], self, _includeFaces ? @"YES" : @"NO", _displayUsingSystemFont ? @"YES" : @"NO"];
}

@end

@implementation UIFontPickerViewController {
@private
    UIFontPickerViewControllerConfiguration *_configuration;
    __weak id<UIFontPickerViewControllerDelegate> _delegate;
    id _selectedFontDescriptor;
}

- (instancetype)initWithConfiguration:(UIFontPickerViewControllerConfiguration *)configuration
{
    if ((self = [super initWithNibName:nil bundle:nil]))
        _configuration = [configuration copy];
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle
{
    return [self initWithConfiguration:[[UIFontPickerViewControllerConfiguration alloc] init]];
}

- (UIFontPickerViewControllerConfiguration *)configuration
{
    return _configuration;
}

- (id<UIFontPickerViewControllerDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIFontPickerViewControllerDelegate>)delegate
{
    _delegate = delegate;
}

- (UIFontDescriptor *)selectedFontDescriptor
{
    return _selectedFontDescriptor;
}

- (void)setSelectedFontDescriptor:(UIFontDescriptor *)selectedFontDescriptor
{
    _selectedFontDescriptor = selectedFontDescriptor;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; configuration: \"%@\">", [self class], self, _configuration];
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    view.backgroundColor = [UIColor whiteColor];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(view.bounds, 20, 60)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor grayColor];
    label.backgroundColor = [UIColor clearColor];
    label.text = @"Fonts cannot be chosen on this release: it has no font descriptor to hand back.";
    [view addSubview:label];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    close.frame = CGRectMake(0, 0, 120, 44);
    close.center = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMaxY(label.frame) + 10);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [close setTitle:[[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(charon_close) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:close];
    self.view = view;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    charon_menus_say_once(@"font-picker", @"UIFontPickerViewController: iOS 6 has no UIFontDescriptor to hand back, so the picker lists no fonts and offers only Cancel, which tells the delegate it was cancelled");
}

- (void)charon_close
{
    id<UIFontPickerViewControllerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(fontPickerViewControllerDidCancel:)])
        [delegate fontPickerViewControllerDidCancel:self];
}

@end
