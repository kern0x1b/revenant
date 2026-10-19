#import <UIKit/UIKit.h>
#import "check.h"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

#define port_config RevenantHostUIContentUnavailableConfiguration

@interface RevenantHostUIContentUnavailableTextProperties : NSObject
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic) BOOL allowsDefaultTighteningForTruncation;
@end

@interface RevenantHostUIContentUnavailableImageProperties : NSObject
@property (nonatomic, copy, nullable) UIImageSymbolConfiguration *preferredSymbolConfiguration;
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGSize maximumSize;
@property (nonatomic) BOOL accessibilityIgnoresInvertColors;
@end

@interface RevenantHostUIContentUnavailableButtonProperties : NSObject
@property (nonatomic, copy, nullable) UIAction *primaryAction;
@property (nonatomic, copy, nullable) UIMenu *menu;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) UIButtonRole role;
@end

@interface RevenantHostUIContentUnavailableConfigurationState : NSObject
- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection;
@property (nonatomic, strong) UITraitCollection *traitCollection;
@property (nonatomic, strong, nullable) NSString *searchText;
- (nullable id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id)key;
- (id)copyWithZone:(NSZone *)zone;
@end


@interface RevenantHostUIContentUnavailableConfiguration : NSObject <UIContentConfiguration>
+ (instancetype)emptyConfiguration;
+ (instancetype)loadingConfiguration;
+ (instancetype)searchConfiguration;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, readonly) RevenantHostUIContentUnavailableImageProperties *imageProperties;
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSAttributedString *attributedText;
@property (nonatomic, readonly) RevenantHostUIContentUnavailableTextProperties *textProperties;
@property (nonatomic, copy, nullable) NSString *secondaryText;
@property (nonatomic, copy, nullable) NSAttributedString *secondaryAttributedText;
@property (nonatomic, readonly) RevenantHostUIContentUnavailableTextProperties *secondaryTextProperties;
@property (nonatomic, strong) UIButtonConfiguration *button;
@property (nonatomic, readonly) RevenantHostUIContentUnavailableButtonProperties *buttonProperties;
@property (nonatomic, strong) UIButtonConfiguration *secondaryButton;
@property (nonatomic, readonly) RevenantHostUIContentUnavailableButtonProperties *secondaryButtonProperties;
@property (nonatomic) NSInteger alignment;
@property (nonatomic) NSUInteger axesPreservingSuperviewLayoutMargins;
@property (nonatomic) NSDirectionalEdgeInsets directionalLayoutMargins;
@property (nonatomic) CGFloat imageToTextPadding;
@property (nonatomic) CGFloat textToSecondaryTextPadding;
@property (nonatomic) CGFloat textToButtonPadding;
@property (nonatomic) CGFloat buttonToSecondaryButtonPadding;
@property (nonatomic, strong) UIBackgroundConfiguration *background;
- (__kindof UIView<UIContentView> *)makeContentView;
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state;
@end

@interface RevenantHostUIContentUnavailableView : UIView
- (instancetype)initWithConfiguration:(RevenantHostUIContentUnavailableConfiguration *)configuration;
@property (nonatomic, copy) RevenantHostUIContentUnavailableConfiguration *configuration;
@property (nonatomic, getter=isScrollEnabled) BOOL scrollEnabled;
@end

static void BOTH(NSString *what, NSString *ours, NSString *theirs)
{
    revenant_check([ours isEqualToString:theirs], what.UTF8String,
                 [NSString stringWithFormat:@"port %@ != system %@", ours, theirs]);
}

static RevenantHostUIContentUnavailableTextProperties *PortTextBag(Class c)
{
    return [[c alloc] init];
}

static void check_text_bag(void)
{
    Class port = NSClassFromString(@"RevenantHostUIContentUnavailableTextProperties");
    RevenantHostUIContentUnavailableTextProperties *ours = PortTextBag(port);
    UIContentUnavailableTextProperties *system = [[UIContentUnavailableTextProperties alloc] init];
    revenant_check(ours != nil && system != nil, "both sides make a text bag", @"one of the two answered nothing");

    BOTH(@"a fresh text bag holds the same line break mode",
         [@(ours.lineBreakMode) stringValue], [@(system.lineBreakMode) stringValue]);
    BOTH(@"a fresh text bag holds the same line count",
         [@(ours.numberOfLines) stringValue], [@(system.numberOfLines) stringValue]);
    BOTH(@"a fresh text bag holds the same font-size-to-fit flag",
         [@(ours.adjustsFontSizeToFitWidth) stringValue], [@(system.adjustsFontSizeToFitWidth) stringValue]);
    BOTH(@"a fresh text bag holds the same minimum scale factor",
         [@(ours.minimumScaleFactor) stringValue], [@(system.minimumScaleFactor) stringValue]);
    BOTH(@"a fresh text bag holds the same default tightening flag",
         [@(ours.allowsDefaultTighteningForTruncation) stringValue],
         [@(system.allowsDefaultTighteningForTruncation) stringValue]);
    revenant_check(ours.font != nil && system.font != nil, "a fresh text bag holds a font on both sides",
                 [NSString stringWithFormat:@"port %@ system %@", ours.font, system.font]);
    if (ours.font && system.font) {
        BOTH(@"a fresh text bag's default font is the same size",
             [@(ours.font.pointSize) stringValue], [@(system.font.pointSize) stringValue]);
        BOTH(@"a fresh text bag holds a labelled colour, not none and not clear",
             (ours.color != nil && ![ours.color isEqual:[UIColor clearColor]]) ? @"labelled" : @"other",
             (system.color != nil && ![system.color isEqual:[UIColor clearColor]]) ? @"labelled" : @"other");
    }

    UIFont *font = [UIFont systemFontOfSize:19];
    UIColor *color = [UIColor redColor];
    ours.font = font; system.font = font;
    ours.color = color; system.color = color;
    ours.numberOfLines = 3; system.numberOfLines = 3;
    ours.minimumScaleFactor = 0.75f; system.minimumScaleFactor = 0.75f;
    ours.adjustsFontSizeToFitWidth = YES; system.adjustsFontSizeToFitWidth = YES;
    ours.lineBreakMode = NSLineBreakByTruncatingTail; system.lineBreakMode = NSLineBreakByTruncatingTail;
    ours.allowsDefaultTighteningForTruncation = YES; system.allowsDefaultTighteningForTruncation = YES;

    BOTH(@"a text bag reads back the font it was given, by size",
         [@(ours.font.pointSize) stringValue], [@(system.font.pointSize) stringValue]);
    BOTH(@"a text bag reads back the font object it was given",
         ours.font == font ? @"set" : @"other", system.font == font ? @"set" : @"other");
    BOTH(@"a text bag reads back the line count it was given",
         [@(ours.numberOfLines) stringValue], [@(system.numberOfLines) stringValue]);
    BOTH(@"a text bag reads back the scale factor it was given",
         [@(ours.minimumScaleFactor) stringValue], [@(system.minimumScaleFactor) stringValue]);
    BOTH(@"a text bag reads back the line break mode it was given",
         [@(ours.lineBreakMode) stringValue], [@(system.lineBreakMode) stringValue]);
    BOTH(@"a text bag reads back the font-size-to-fit flag it was given",
         [@(ours.adjustsFontSizeToFitWidth) stringValue], [@(system.adjustsFontSizeToFitWidth) stringValue]);
    BOTH(@"a text bag reads back the default tightening flag it was given",
         [@(ours.allowsDefaultTighteningForTruncation) stringValue],
         [@(system.allowsDefaultTighteningForTruncation) stringValue]);
    RevenantHostUIContentUnavailableTextProperties *ourCopy = [ours copy];
    UIContentUnavailableTextProperties *systemCopy = [system copy];
    BOTH(@"a text bag's copy holds the line count",
         [@(ourCopy.numberOfLines) stringValue], [@(systemCopy.numberOfLines) stringValue]);
    BOTH(@"a text bag's copy holds the font",
         ourCopy.font == font ? @"set" : @"other", systemCopy.font == font ? @"set" : @"other");
}

static void check_image_bag(void)
{
    RevenantHostUIContentUnavailableImageProperties *ours =
        [[NSClassFromString(@"RevenantHostUIContentUnavailableImageProperties") alloc] init];
    UIContentUnavailableImageProperties *system = [[UIContentUnavailableImageProperties alloc] init];
    revenant_check(ours != nil && system != nil, "both sides make an image bag", @"one of the two answered nothing");

    BOTH(@"a fresh image bag holds the same corner radius",
         [@(ours.cornerRadius) stringValue], [@(system.cornerRadius) stringValue]);
    BOTH(@"a fresh image bag holds the same maximum width",
         [@(ours.maximumSize.width) stringValue], [@(system.maximumSize.width) stringValue]);
    BOTH(@"a fresh image bag holds the same maximum height",
         [@(ours.maximumSize.height) stringValue], [@(system.maximumSize.height) stringValue]);
    BOTH(@"a fresh image bag holds the same invert-colours flag",
         [@(ours.accessibilityIgnoresInvertColors) stringValue],
         [@(system.accessibilityIgnoresInvertColors) stringValue]);
    BOTH(@"a fresh image bag has no symbol configuration on either side",
         ours.preferredSymbolConfiguration == nil ? @"nil" : @"set",
         system.preferredSymbolConfiguration == nil ? @"nil" : @"set");

    UIColor *green = [UIColor greenColor];
    ours.tintColor = green; system.tintColor = green;
    ours.cornerRadius = 12.5f; system.cornerRadius = 12.5f;
    ours.maximumSize = CGSizeMake(64, 48); system.maximumSize = CGSizeMake(64, 48);
    ours.accessibilityIgnoresInvertColors = YES; system.accessibilityIgnoresInvertColors = YES;

    BOTH(@"an image bag reads back the corner radius",
         [@(ours.cornerRadius) stringValue], [@(system.cornerRadius) stringValue]);
    BOTH(@"an image bag reads back the maximum width",
         [@(ours.maximumSize.width) stringValue], [@(system.maximumSize.width) stringValue]);
    BOTH(@"an image bag reads back the maximum height",
         [@(ours.maximumSize.height) stringValue], [@(system.maximumSize.height) stringValue]);
    BOTH(@"an image bag reads back the invert-colours flag",
         [@(ours.accessibilityIgnoresInvertColors) stringValue],
         [@(system.accessibilityIgnoresInvertColors) stringValue]);
    BOTH(@"an image bag reads back the tint it was given", ours.tintColor == green ? @"set" : @"other",
         system.tintColor == green ? @"set" : @"other");
    RevenantHostUIContentUnavailableImageProperties *ourCopy = [ours copy];
    UIContentUnavailableImageProperties *systemCopy = [system copy];
    BOTH(@"an image bag's copy holds the corner radius",
         [@(ourCopy.cornerRadius) stringValue], [@(systemCopy.cornerRadius) stringValue]);
}

static void check_button_bag(void)
{
    RevenantHostUIContentUnavailableButtonProperties *ours =
        [[NSClassFromString(@"RevenantHostUIContentUnavailableButtonProperties") alloc] init];
    UIContentUnavailableButtonProperties *system = [[UIContentUnavailableButtonProperties alloc] init];
    revenant_check(ours != nil && system != nil, "both sides make a button bag", @"one of the two answered nothing");

    BOTH(@"a fresh button bag answers enabled the same way",
         [@(ours.isEnabled) stringValue], [@(system.isEnabled) stringValue]);
    BOTH(@"a fresh button bag holds the same role", [@(ours.role) stringValue], [@(system.role) stringValue]);
    BOTH(@"a fresh button bag has no action on either side",
         ours.primaryAction == nil ? @"nil" : @"set", system.primaryAction == nil ? @"nil" : @"set");
    BOTH(@"a fresh button bag has no menu on either side",
         ours.menu == nil ? @"nil" : @"set", system.menu == nil ? @"nil" : @"set");

    ours.enabled = NO; system.enabled = NO;
    ours.role = UIButtonRolePrimary; system.role = UIButtonRolePrimary;
    BOTH(@"a button bag reads back the enabled flag",
         [@(ours.isEnabled) stringValue], [@(system.isEnabled) stringValue]);
    BOTH(@"a button bag reads back the role", [@(ours.role) stringValue], [@(system.role) stringValue]);
    RevenantHostUIContentUnavailableButtonProperties *ourCopy = [ours copy];
    UIContentUnavailableButtonProperties *systemCopy = [system copy];
    BOTH(@"a button bag's copy holds the enabled flag",
         [@(ourCopy.isEnabled) stringValue], [@(systemCopy.isEnabled) stringValue]);
}

static void check_state(void)
{
    RevenantHostUIContentUnavailableConfigurationState *ours =
        [[NSClassFromString(@"RevenantHostUIContentUnavailableConfigurationState") alloc]
            initWithTraitCollection:[UITraitCollection currentTraitCollection]];
    UIContentUnavailableConfigurationState *system =
        [[UIContentUnavailableConfigurationState alloc] initWithTraitCollection:[UITraitCollection currentTraitCollection]];
    revenant_check(ours != nil && system != nil, "both sides make a state over a trait collection",
                 @"one of the two answered nothing");
    BOTH(@"a fresh state has no search text on either side",
         ours.searchText == nil ? @"nil" : @"set", system.searchText == nil ? @"nil" : @"set");

    ours.searchText = @"a search"; system.searchText = @"a search";
    BOTH(@"a state reads back the search text it was given", ours.searchText, system.searchText);

    [ours setObject:@"held" forKeyedSubscript:@"k"];
    [system setObject:@"held" forKeyedSubscript:@"k"];
    BOTH(@"a state holds what was keyed into it", [ours objectForKeyedSubscript:@"k"], [system objectForKeyedSubscript:@"k"]);
    BOTH(@"a state holds nothing at a key nobody keyed",
         [ours objectForKeyedSubscript:@"absent"] == nil ? @"nil" : @"other",
         [system objectForKeyedSubscript:@"absent"] == nil ? @"nil" : @"other");
    RevenantHostUIContentUnavailableConfigurationState *ourCopy = [ours copy];
    UIContentUnavailableConfigurationState *systemCopy = [system copy];
    BOTH(@"a state's copy keeps the keyed value",
         [ourCopy objectForKeyedSubscript:@"k"], [systemCopy objectForKeyedSubscript:@"k"]);
    BOTH(@"a state's copy keeps the search text", ourCopy.searchText, systemCopy.searchText);
}

static void check_state_new_and_init(void)
{
    id ourClass = NSClassFromString(@"RevenantHostUIContentUnavailableConfigurationState");
    id systemClass = NSClassFromString(@"UIContentUnavailableConfigurationState");
    BOTH(@"the state class answers +new on both sides", [ourClass respondsToSelector:@selector(new)] ? @"yes" : @"no",
         [systemClass respondsToSelector:@selector(new)] ? @"yes" : @"no");
    BOTH(@"the state class answers -init on both sides", [ourClass instancesRespondToSelector:@selector(init)] ? @"yes" : @"no",
         [systemClass instancesRespondToSelector:@selector(init)] ? @"yes" : @"no");
    id ourNew = [ourClass new];
    id systemNew = [systemClass new];
    BOTH(@"+new makes an instance of the state class on both sides",
         [ourNew isKindOfClass:ourClass] ? @"instance" : @"other",
         [systemNew isKindOfClass:systemClass] ? @"instance" : @"other");
    BOTH(@"a state made by +new holds no trait collection on either side",
         [ourNew traitCollection] == nil ? @"nil" : @"set", [systemNew traitCollection] == nil ? @"nil" : @"set");
    BOTH(@"a state made by +new holds no search text on either side",
         [ourNew searchText] == nil ? @"nil" : @"set", [systemNew searchText] == nil ? @"nil" : @"set");
    id ourInit = [[ourClass alloc] init];
    id systemInit = [[systemClass alloc] init];
    BOTH(@"-init makes an instance of the state class on both sides",
         [ourInit isKindOfClass:ourClass] ? @"instance" : @"other",
         [systemInit isKindOfClass:systemClass] ? @"instance" : @"other");
}

static void check_one_configuration(NSInteger kind)
{
    NSArray *names = @[@"empty", @"loading", @"search"];
    NSString *label = names[(NSUInteger)kind];
    RevenantHostUIContentUnavailableConfiguration *ours = nil;
    UIContentUnavailableConfiguration *system = nil;
    SEL factory = @selector(emptyConfiguration);
    if (kind == 1)
        factory = @selector(loadingConfiguration);
    else if (kind == 2)
        factory = @selector(searchConfiguration);
    ours = [(id)NSClassFromString(@"RevenantHostUIContentUnavailableConfiguration") performSelector:factory];
    system = [(UIContentUnavailableConfiguration *)[UIContentUnavailableConfiguration performSelector:factory] copy];
    revenant_check(ours != nil && system != nil, "both sides build the configuration",
                 [NSString stringWithFormat:@"port %@ system %@", ours, system]);

    BOTH([NSString stringWithFormat:@"the %@ image-to-text padding", label],
         [@(ours.imageToTextPadding) stringValue], [@(system.imageToTextPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ text-to-secondary-text padding", label],
         [@(ours.textToSecondaryTextPadding) stringValue], [@(system.textToSecondaryTextPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ text-to-button padding", label],
         [@(ours.textToButtonPadding) stringValue], [@(system.textToButtonPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ button-to-secondary-button padding", label],
         [@(ours.buttonToSecondaryButtonPadding) stringValue], [@(system.buttonToSecondaryButtonPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ alignment", label],
         [@(ours.alignment) stringValue], [@(system.alignment) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ preserved axes", label],
         [@(ours.axesPreservingSuperviewLayoutMargins) stringValue],
         [@(system.axesPreservingSuperviewLayoutMargins) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ leading margin", label],
         [@(ours.directionalLayoutMargins.leading) stringValue], [@(system.directionalLayoutMargins.leading) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ trailing margin", label],
         [@(ours.directionalLayoutMargins.trailing) stringValue], [@(system.directionalLayoutMargins.trailing) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ top margin", label],
         [@(ours.directionalLayoutMargins.top) stringValue], [@(system.directionalLayoutMargins.top) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ bottom margin", label],
         [@(ours.directionalLayoutMargins.bottom) stringValue], [@(system.directionalLayoutMargins.bottom) stringValue]);

    BOTH([NSString stringWithFormat:@"the %@ primary text", label],
         ours.text ? ours.text : @"(nil)", system.text ? system.text : @"(nil)");
    BOTH([NSString stringWithFormat:@"the %@ secondary text", label],
         ours.secondaryText ? ours.secondaryText : @"(nil)", system.secondaryText ? system.secondaryText : @"(nil)");
    BOTH([NSString stringWithFormat:@"the %@ attributed text is absent", label],
         ours.attributedText == nil ? @"nil" : @"set", system.attributedText == nil ? @"nil" : @"set");
    BOTH([NSString stringWithFormat:@"the %@ secondary attributed text is absent", label],
         ours.secondaryAttributedText == nil ? @"nil" : @"set",
         system.secondaryAttributedText == nil ? @"nil" : @"set");

    revenant_check(ours.textProperties.font != nil && system.textProperties.font != nil,
                 "both sides hold a primary font", [NSString stringWithFormat:@"port %@ system %@",
                                                     ours.textProperties.font, system.textProperties.font]);
    if (ours.textProperties.font && system.textProperties.font) {
        BOTH([NSString stringWithFormat:@"the %@ primary font size", label],
             [@(ours.textProperties.font.pointSize) stringValue], [@(system.textProperties.font.pointSize) stringValue]);
    }
    BOTH([NSString stringWithFormat:@"the %@ primary colour is a label colour", label],
         (ours.textProperties.color != nil && ![ours.textProperties.color isEqual:[UIColor clearColor]]) ? @"labelled" : @"other",
         (system.textProperties.color != nil && ![system.textProperties.color isEqual:[UIColor clearColor]]) ? @"labelled" : @"other");
    BOTH([NSString stringWithFormat:@"the %@ primary line break mode", label],
         [@(ours.textProperties.lineBreakMode) stringValue], [@(system.textProperties.lineBreakMode) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ primary line count", label],
         [@(ours.textProperties.numberOfLines) stringValue], [@(system.textProperties.numberOfLines) stringValue]);

    revenant_check(ours.secondaryTextProperties.font != nil && system.secondaryTextProperties.font != nil,
                 "both sides hold a secondary font", @"one side answered none");
    if (ours.secondaryTextProperties.font && system.secondaryTextProperties.font) {
        BOTH([NSString stringWithFormat:@"the %@ secondary font size", label],
             [@(ours.secondaryTextProperties.font.pointSize) stringValue],
             [@(system.secondaryTextProperties.font.pointSize) stringValue]);
    }
    BOTH([NSString stringWithFormat:@"the %@ secondary line break mode", label],
         [@(ours.secondaryTextProperties.lineBreakMode) stringValue],
         [@(system.secondaryTextProperties.lineBreakMode) stringValue]);

    revenant_check(ours.imageProperties.preferredSymbolConfiguration != nil && system.imageProperties.preferredSymbolConfiguration != nil,
                 "both sides hold a symbol configuration", @"one side answered none");
    BOTH([NSString stringWithFormat:@"the %@ image corner radius", label],
         [@(ours.imageProperties.cornerRadius) stringValue], [@(system.imageProperties.cornerRadius) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ image tint is a label colour", label],
         (ours.imageProperties.tintColor != nil && ![ours.imageProperties.tintColor isEqual:[UIColor clearColor]]) ? @"labelled" : @"other",
         (system.imageProperties.tintColor != nil && ![system.imageProperties.tintColor isEqual:[UIColor clearColor]]) ? @"labelled" : @"other");

    BOTH([NSString stringWithFormat:@"the %@ primary button exists", label], ours.button ? @"set" : @"nil", @"set");
    BOTH([NSString stringWithFormat:@"the %@ secondary button exists", label], ours.secondaryButton ? @"set" : @"nil", @"set");
    BOTH([NSString stringWithFormat:@"the %@ primary button base style is plain", label],
         [[ours.button description] rangeOfString:@"baseStyle=plain"].location != NSNotFound ? @"plain" : @"other",
         [[system.button description] rangeOfString:@"baseStyle=plain"].location != NSNotFound ? @"plain" : @"other");
    BOTH([NSString stringWithFormat:@"the %@ primary button is enabled", label],
         [@(ours.buttonProperties.isEnabled) stringValue], [@(system.buttonProperties.isEnabled) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ secondary button is enabled", label],
         [@(ours.secondaryButtonProperties.isEnabled) stringValue],
         [@(system.secondaryButtonProperties.isEnabled) stringValue]);
    BOTH([NSString stringWithFormat:@"the %@ primary button has no action", label],
         ours.buttonProperties.primaryAction == nil ? @"nil" : @"set",
         system.buttonProperties.primaryAction == nil ? @"nil" : @"set");
    BOTH([NSString stringWithFormat:@"the %@ background is a clear background", label],
         ours.background != nil && ![ours.background.backgroundColor isEqual:[UIColor blackColor]] ? @"set" : @"other",
         system.background != nil && ![system.background.backgroundColor isEqual:[UIColor blackColor]] ? @"set" : @"other");

    BOTH([NSString stringWithFormat:@"the %@ has the same image presence", label],
         ours.image == nil ? @"none" : @"some", system.image == nil ? @"none" : @"some");

    NSString *primary = [NSString stringWithFormat:@"%@ primary", label];
    ours.text = primary; system.text = primary;
    ours.secondaryText = @"s"; system.secondaryText = @"s";
    ours.imageToTextPadding = 1.5f; system.imageToTextPadding = 1.5f;
    ours.textToSecondaryTextPadding = 2.5f; system.textToSecondaryTextPadding = 2.5f;
    ours.textToButtonPadding = 3.5f; system.textToButtonPadding = 3.5f;
    ours.buttonToSecondaryButtonPadding = 4.5f; system.buttonToSecondaryButtonPadding = 4.5f;
    ours.alignment = 1; system.alignment = 1;
    ours.axesPreservingSuperviewLayoutMargins = 3; system.axesPreservingSuperviewLayoutMargins = 3;
    ours.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
    system.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
    BOTH([NSString stringWithFormat:@"a written %@ primary text reads back", label], ours.text, system.text);
    BOTH([NSString stringWithFormat:@"a written %@ secondary text reads back", label], ours.secondaryText, system.secondaryText);
    BOTH([NSString stringWithFormat:@"a written %@ image-to-text padding reads back", label],
         [@(ours.imageToTextPadding) stringValue], [@(system.imageToTextPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"a written %@ text-to-secondary-text padding reads back", label],
         [@(ours.textToSecondaryTextPadding) stringValue], [@(system.textToSecondaryTextPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"a written %@ text-to-button padding reads back", label],
         [@(ours.textToButtonPadding) stringValue], [@(system.textToButtonPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"a written %@ button-to-secondary-button padding reads back", label],
         [@(ours.buttonToSecondaryButtonPadding) stringValue], [@(system.buttonToSecondaryButtonPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"a written %@ alignment reads back", label],
         [@(ours.alignment) stringValue], [@(system.alignment) stringValue]);
    BOTH([NSString stringWithFormat:@"a written %@ preserved axes read back", label],
         [@(ours.axesPreservingSuperviewLayoutMargins) stringValue],
         [@(system.axesPreservingSuperviewLayoutMargins) stringValue]);
    BOTH([NSString stringWithFormat:@"a written %@ leading margin reads back", label],
         [@(ours.directionalLayoutMargins.leading) stringValue], [@(system.directionalLayoutMargins.leading) stringValue]);
    BOTH([NSString stringWithFormat:@"a written %@ bottom margin reads back", label],
         [@(ours.directionalLayoutMargins.bottom) stringValue], [@(system.directionalLayoutMargins.bottom) stringValue]);

    RevenantHostUIContentUnavailableConfiguration *ourCopy = [ours copy];
    UIContentUnavailableConfiguration *systemCopy = [system copy];
    BOTH([NSString stringWithFormat:@"a %@ copy keeps the text", label], ourCopy.text, systemCopy.text);
    BOTH([NSString stringWithFormat:@"a %@ copy keeps the image-to-text padding", label],
         [@(ourCopy.imageToTextPadding) stringValue], [@(systemCopy.imageToTextPadding) stringValue]);
    BOTH([NSString stringWithFormat:@"a %@ copy is not the receiver", label], ourCopy == ours ? @"same" : @"other",
         systemCopy == system ? @"same" : @"other");
    [ourCopy.textProperties setNumberOfLines:9];
    [systemCopy.textProperties setNumberOfLines:9];
    BOTH([NSString stringWithFormat:@"a %@ copy's bag is its own", label],
         [@(ourCopy.textProperties.numberOfLines) stringValue], [@(systemCopy.textProperties.numberOfLines) stringValue]);
    BOTH([NSString stringWithFormat:@"a %@ copy's bag write leaves the original alone", label],
         [@(ours.textProperties.numberOfLines) stringValue], [@(system.textProperties.numberOfLines) stringValue]);

    NSError *error = nil;
    NSData *ourArchive = [NSKeyedArchiver archivedDataWithRootObject:ours requiringSecureCoding:YES error:&error];
    NSData *systemArchive = [NSKeyedArchiver archivedDataWithRootObject:system requiringSecureCoding:YES error:&error];
    revenant_check(ourArchive != nil && systemArchive != nil, "both sides archive the configuration",
                 [NSString stringWithFormat:@"port %@ system %lu", error, (unsigned long)ourArchive.length]);
    if (ourArchive && systemArchive) {
        RevenantHostUIContentUnavailableConfiguration *ourBack =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[RevenantHostUIContentUnavailableConfiguration class]
                                              fromData:ourArchive
                                                 error:&error];
        UIContentUnavailableConfiguration *systemBack =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[UIContentUnavailableConfiguration class]
                                              fromData:systemArchive
                                                 error:&error];
        revenant_check(ourBack != nil && systemBack != nil, "both sides read the archive back",
                     [NSString stringWithFormat:@"port %@ system %@", ourBack, systemBack]);
        if (ourBack && systemBack) {
            BOTH([NSString stringWithFormat:@"the %@ archived text comes back", label], ourBack.text, systemBack.text);
            BOTH([NSString stringWithFormat:@"the %@ archived image-to-text padding comes back", label],
                 [@(ourBack.imageToTextPadding) stringValue], [@(systemBack.imageToTextPadding) stringValue]);
            BOTH([NSString stringWithFormat:@"the %@ archived leading margin comes back", label],
                 [@(ourBack.directionalLayoutMargins.leading) stringValue],
                 [@(systemBack.directionalLayoutMargins.leading) stringValue]);
            BOTH([NSString stringWithFormat:@"the %@ archived alignment comes back", label],
                 [@(ourBack.alignment) stringValue], [@(systemBack.alignment) stringValue]);
        }
    }
}

static void check_configurations(void)
{
    for (NSInteger kind = 0; kind < 3; kind++)
        check_one_configuration(kind);
}

static void check_the_three_differ(void)
{
    RevenantHostUIContentUnavailableConfiguration *oursEmpty = [RevenantHostUIContentUnavailableConfiguration emptyConfiguration];
    RevenantHostUIContentUnavailableConfiguration *oursLoading = [RevenantHostUIContentUnavailableConfiguration loadingConfiguration];
    RevenantHostUIContentUnavailableConfiguration *oursSearch = [RevenantHostUIContentUnavailableConfiguration searchConfiguration];
    UIContentUnavailableConfiguration *systemEmpty = [UIContentUnavailableConfiguration emptyConfiguration];
    UIContentUnavailableConfiguration *systemLoading = [UIContentUnavailableConfiguration loadingConfiguration];
    UIContentUnavailableConfiguration *systemSearch = [UIContentUnavailableConfiguration searchConfiguration];

    BOTH(@"the loading primary font size is the body's, not the title's",
         [@(oursLoading.textProperties.font.pointSize) stringValue], [@(systemLoading.textProperties.font.pointSize) stringValue]);
    BOTH(@"the empty primary font size is the title's",
         [@(oursEmpty.textProperties.font.pointSize) stringValue], [@(systemEmpty.textProperties.font.pointSize) stringValue]);
    BOTH(@"the loading image-to-text padding is the narrower one",
         [@(oursLoading.imageToTextPadding) stringValue], [@(systemLoading.imageToTextPadding) stringValue]);
    BOTH(@"the search has the secondary text the others do not",
         oursSearch.secondaryText ? @"set" : @"none", systemSearch.secondaryText ? @"set" : @"none");
    BOTH(@"the empty has no secondary text",
         oursEmpty.secondaryText ? @"set" : @"none", systemEmpty.secondaryText ? @"set" : @"none");
    BOTH(@"the search is the only one with an image",
         oursSearch.image ? @"set" : @"none", systemSearch.image ? @"set" : @"none");
}

static void check_configuration_view(void)
{
    RevenantHostUIContentUnavailableConfiguration *oursConfiguration = [RevenantHostUIContentUnavailableConfiguration searchConfiguration];
    UIContentUnavailableConfiguration *systemConfiguration = [UIContentUnavailableConfiguration searchConfiguration];
    UIView *oursMade = [oursConfiguration makeContentView];
    UIView *systemMade = [systemConfiguration makeContentView];
    revenant_check(oursMade != nil && systemMade != nil, "both sides build a content view",
                 [NSString stringWithFormat:@"port %@ system %@", oursMade, systemMade]);
    revenant_check([(RevenantHostUIContentUnavailableView *)oursMade configuration] != nil &&
                     [((UIContentUnavailableView *)systemMade) configuration] != nil,
                 "both content views answer a configuration",
                 [NSString stringWithFormat:@"port %@ system %@", oursMade, systemMade]);
    BOTH(@"the port's content view holds the configuration it was built with",
         [(RevenantHostUIContentUnavailableView *)oursMade configuration].text, oursConfiguration.text);
    BOTH(@"the system's content view holds the configuration it was built with",
         ((UIContentUnavailableView *)systemMade).configuration.text, systemConfiguration.text);

    RevenantHostUIContentUnavailableView *ours = [[RevenantHostUIContentUnavailableView alloc] initWithConfiguration:oursConfiguration];
    UIContentUnavailableView *system = [[UIContentUnavailableView alloc] initWithConfiguration:systemConfiguration];
    BOTH(@"a fresh content view does not scroll on the port", ours.isScrollEnabled ? @"yes" : @"no", @"no");
    BOTH(@"a fresh content view does not scroll on the system", system.isScrollEnabled ? @"yes" : @"no", @"no");
    BOTH(@"a content view reads back the text it was built with", ours.configuration.text, system.configuration.text);
    BOTH(@"a content view's configuration is a copy", ours.configuration == oursConfiguration ? @"same" : @"copy",
         system.configuration == systemConfiguration ? @"same" : @"copy");

    RevenantHostUIContentUnavailableConfiguration *replacement = [RevenantHostUIContentUnavailableConfiguration loadingConfiguration];
    UIContentUnavailableConfiguration *systemReplacement = [UIContentUnavailableConfiguration loadingConfiguration];
    ours.configuration = replacement;
    system.configuration = systemReplacement;
    BOTH(@"a written configuration reads back", ours.configuration.text, system.configuration.text);

    ours.scrollEnabled = YES;
    system.scrollEnabled = YES;
    BOTH(@"a content view reads back the scroll flag", ours.isScrollEnabled ? @"yes" : @"no", @"yes");
    ours.scrollEnabled = NO;
    system.scrollEnabled = NO;
    BOTH(@"a cleared scroll flag reads back", ours.isScrollEnabled ? @"yes" : @"no", @"no");

    ours.frame = CGRectMake(0, 0, 320, 480);
    system.frame = CGRectMake(0, 0, 320, 480);
    [ours layoutIfNeeded];
    [system layoutIfNeeded];
    CGSize oursFit = [ours sizeThatFits:CGSizeMake(320, CGFLOAT_MAX)];
    CGSize systemFit = [system sizeThatFits:CGSizeMake(320, CGFLOAT_MAX)];
    revenant_check(oursFit.height > 0, "the port's content view fits a content", [NSString stringWithFormat:@"%@", NSStringFromCGSize(oursFit)]);
    revenant_check(systemFit.height > 0, "the system's content view fits a content", [NSString stringWithFormat:@"%@", NSStringFromCGSize(systemFit)]);
}

int main(void)
{
    @autoreleasepool {
        check_text_bag();
        check_image_bag();
        check_button_bag();
        check_state();
        check_state_new_and_init();
        check_configurations();
        check_the_three_differ();
        check_configuration_view();
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures;
}
