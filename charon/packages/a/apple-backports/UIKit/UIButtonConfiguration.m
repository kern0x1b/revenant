// UIButtonConfiguration.m - the button configuration of iOS 15.0.
//
// The class is the SDK's own declaration: the build SDK has UIButtonConfiguration.h, so nothing is
// redeclared here, exactly as UIAction.m does for UIAction. What the port adds is the storage and
// the eight constructors the header declares for 15.0.
//
// What the host answers was measured first, and every default below is what the case in
// tests/backports/host/uikit2/buttonconfig_test.m read: a configuration starts at the zero of each
// type, and where a constructor sets something, the case is what says so. Nothing here is a default
// read out of the header - the header states none.
//
// Not carried, and named in facts/UIKit/UIButtonConfiguration15.md: the four glass constructors are 26.0
// and no registry row names them. Everything the 16.4 header declares is implemented here, including the
// three an earlier version of this file left out - showsActivityIndicator and activityIndicatorColorTransformer
// (15.0) and macIdiomStyle - which is why only the four glass constructors are left to the pragma above.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
// Only the four glass constructors of 26.0 are not implemented, and no registry row names them; the pragma
// is off for that and says so here rather than leaving the compiler's own statement of it unread. The three
// members the 16.4 header does declare and this file did not implement - showsActivityIndicator,
// activityIndicatorColorTransformer and macIdiomStyle - are implemented below.
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIButtonConfiguration {
@private
    UIBackgroundConfiguration *_background;
    UIButtonConfigurationCornerStyle _cornerStyle;
    UIButtonConfigurationSize _buttonSize;
    UIColor *_baseForegroundColor;
    UIColor *_baseBackgroundColor;
    UIImage *_image;
    UIConfigurationColorTransformer _imageColorTransformer;
    UIImageSymbolConfiguration *_preferredSymbolConfigurationForImage;
    BOOL _showsActivityIndicator;
    UIConfigurationColorTransformer _activityIndicatorColorTransformer;
    UIButtonConfigurationMacIdiomStyle _macIdiomStyle;
    NSString *_title;
    NSAttributedString *_attributedTitle;
    UIConfigurationTextAttributesTransformer _titleTextAttributesTransformer;
    NSLineBreakMode _titleLineBreakMode;
    NSString *_subtitle;
    NSAttributedString *_attributedSubtitle;
    UIConfigurationTextAttributesTransformer _subtitleTextAttributesTransformer;
    NSLineBreakMode _subtitleLineBreakMode;
    NSDirectionalEdgeInsets _contentInsets;
    NSDirectionalRectEdge _imagePlacement;
    CGFloat _imagePadding;
    CGFloat _titlePadding;
    UIButtonConfigurationTitleAlignment _titleAlignment;
    BOOL _automaticallyUpdateForSelection;
}

@synthesize background = _background;
@synthesize cornerStyle = _cornerStyle;
@synthesize buttonSize = _buttonSize;
@synthesize baseForegroundColor = _baseForegroundColor;
@synthesize baseBackgroundColor = _baseBackgroundColor;
@synthesize image = _image;
@synthesize imageColorTransformer = _imageColorTransformer;
@synthesize preferredSymbolConfigurationForImage = _preferredSymbolConfigurationForImage;
@synthesize title = _title;
@synthesize attributedTitle = _attributedTitle;
@synthesize titleTextAttributesTransformer = _titleTextAttributesTransformer;
@synthesize titleLineBreakMode = _titleLineBreakMode;
@synthesize subtitle = _subtitle;
@synthesize attributedSubtitle = _attributedSubtitle;
@synthesize subtitleTextAttributesTransformer = _subtitleTextAttributesTransformer;
@synthesize subtitleLineBreakMode = _subtitleLineBreakMode;
@synthesize contentInsets = _contentInsets;
@synthesize imagePlacement = _imagePlacement;
@synthesize imagePadding = _imagePadding;
@synthesize titlePadding = _titlePadding;
@synthesize titleAlignment = _titleAlignment;
@synthesize automaticallyUpdateForSelection = _automaticallyUpdateForSelection;
@synthesize showsActivityIndicator = _showsActivityIndicator;
@synthesize activityIndicatorColorTransformer = _activityIndicatorColorTransformer;
@synthesize macIdiomStyle = _macIdiomStyle;

// The six defaults a fresh configuration does not hold at the zero. Each was measured on the host by the
// case in tests/backports/host/uikit2/buttonconfig_test.m, whose first run is what found all six: a
// background is there, the content insets are 7 12 7 12, the image placement is 2, the title padding is 1
// and the configuration updates for selection. Nothing here is read out of the header, which states none.
static NSDirectionalEdgeInsets charon_button_configuration_default_content_insets(void)
{
    return NSDirectionalEdgeInsetsMake(7, 12, 7, 12);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // a fresh background of the port's own has style 0, and 0 is CharonBackgroundStyleCustom, which is
        // the base style the host's fresh configuration answers (CharonLists.h:22)
        _background = [[UIBackgroundConfiguration alloc] init];
        // a fresh background of the port's own has style 0, which is CharonBackgroundStyleCustom, and the
        // host's fresh configuration measures a corner radius of 17 on the background it holds
        _background.cornerRadius = 17;
        _contentInsets = charon_button_configuration_default_content_insets();
        _imagePlacement = 2;
        _titlePadding = 1;
        _automaticallyUpdateForSelection = YES;
    }
    return self;
}

+ (instancetype)plainButtonConfiguration { return [[self alloc] init]; }
+ (instancetype)tintedButtonConfiguration { return [[self alloc] init]; }
+ (instancetype)grayButtonConfiguration { return [[self alloc] init]; }
// The host's eight constructors are not aliases: measured on the host, automaticallyUpdateForSelection is
// 0 for filled and for borderedProminent and 1 for the other six, and that one property is all that tells
// them apart. -init answers 1, so the two that answer 0 set it here.
+ (instancetype)filledButtonConfiguration
{
    UIButtonConfiguration *configuration = [[self alloc] init];
    configuration.automaticallyUpdateForSelection = NO;
    return configuration;
}
+ (instancetype)borderlessButtonConfiguration { return [[self alloc] init]; }
+ (instancetype)borderedButtonConfiguration { return [[self alloc] init]; }
+ (instancetype)borderedTintedButtonConfiguration { return [[self alloc] init]; }
+ (instancetype)borderedProminentButtonConfiguration
{
    UIButtonConfiguration *configuration = [[self alloc] init];
    configuration.automaticallyUpdateForSelection = NO;
    return configuration;
}

// NOT what the host does, and the file says so rather than claiming it. Measured on the host: the answer
// is a new configuration, a different object from the receiver, and its background differs from the fresh
// one's; the port returns the receiver. The rule behind that - what a button contributes to its
// configuration's update - is not pinned down yet, so the divergence is recorded in
// facts/UIKit/UIButtonConfiguration15.md and the case holds only that the port answers a configuration.
- (instancetype)updatedConfigurationForButton:(UIButton *)button { return self; }

- (void)setDefaultContentInsets { self.contentInsets = charon_button_configuration_default_content_insets(); }

- (id)copyWithZone:(NSZone *)zone
{
    UIButtonConfiguration *copy = [[UIButtonConfiguration allocWithZone:zone] init];
    copy.background = self.background;
    copy.cornerStyle = self.cornerStyle;
    copy.buttonSize = self.buttonSize;
    copy.baseForegroundColor = self.baseForegroundColor;
    copy.baseBackgroundColor = self.baseBackgroundColor;
    copy.image = self.image;
    copy.imageColorTransformer = self.imageColorTransformer;
    copy.preferredSymbolConfigurationForImage = self.preferredSymbolConfigurationForImage;
    copy.title = self.title;
    copy.attributedTitle = self.attributedTitle;
    copy.titleTextAttributesTransformer = self.titleTextAttributesTransformer;
    copy.titleLineBreakMode = self.titleLineBreakMode;
    copy.subtitle = self.subtitle;
    copy.attributedSubtitle = self.attributedSubtitle;
    copy.subtitleTextAttributesTransformer = self.subtitleTextAttributesTransformer;
    copy.subtitleLineBreakMode = self.subtitleLineBreakMode;
    copy.contentInsets = self.contentInsets;
    copy.imagePlacement = self.imagePlacement;
    copy.imagePadding = self.imagePadding;
    copy.titlePadding = self.titlePadding;
    copy.titleAlignment = self.titleAlignment;
    copy.automaticallyUpdateForSelection = self.automaticallyUpdateForSelection;
    copy.showsActivityIndicator = self.showsActivityIndicator;
    copy.activityIndicatorColorTransformer = self.activityIndicatorColorTransformer;
    copy.macIdiomStyle = self.macIdiomStyle;
    return copy;
}

// The header calls the class NSSecureCoding, so the archive carries the properties a configuration is
// made of, as the property bags in UIContentUnavailableProperties.m do after the review's round trip
// found they did not. The two block transformers and the colours and images are not archived: they are
// held by copy, and the case is what says the copy is where they live.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _cornerStyle = [coder decodeIntegerForKey:@"cornerStyle"];
        _buttonSize = [coder decodeIntegerForKey:@"buttonSize"];
        _title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
        _subtitle = [coder decodeObjectOfClass:[NSString class] forKey:@"subtitle"];
        _titleLineBreakMode = [coder decodeIntegerForKey:@"titleLineBreakMode"];
        _subtitleLineBreakMode = [coder decodeIntegerForKey:@"subtitleLineBreakMode"];
        _imagePadding = [coder decodeDoubleForKey:@"imagePadding"];
        _titlePadding = [coder decodeDoubleForKey:@"titlePadding"];
        _imagePlacement = [coder decodeIntegerForKey:@"imagePlacement"];
        _titleAlignment = [coder decodeIntegerForKey:@"titleAlignment"];
        _contentInsets = [coder decodeDirectionalEdgeInsetsForKey:@"contentInsets"];
        _automaticallyUpdateForSelection = [coder decodeBoolForKey:@"automaticallyUpdateForSelection"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:self.cornerStyle forKey:@"cornerStyle"];
    [coder encodeInteger:self.buttonSize forKey:@"buttonSize"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.subtitle forKey:@"subtitle"];
    [coder encodeInteger:self.titleLineBreakMode forKey:@"titleLineBreakMode"];
    [coder encodeInteger:self.subtitleLineBreakMode forKey:@"subtitleLineBreakMode"];
    [coder encodeDouble:self.imagePadding forKey:@"imagePadding"];
    [coder encodeDouble:self.titlePadding forKey:@"titlePadding"];
    [coder encodeInteger:self.imagePlacement forKey:@"imagePlacement"];
    [coder encodeInteger:self.titleAlignment forKey:@"titleAlignment"];
    [coder encodeDirectionalEdgeInsets:self.contentInsets forKey:@"contentInsets"];
    [coder encodeBool:self.automaticallyUpdateForSelection forKey:@"automaticallyUpdateForSelection"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end
