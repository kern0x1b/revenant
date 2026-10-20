#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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

static NSDirectionalEdgeInsets revenant_button_configuration_default_content_insets(void)
{
    return NSDirectionalEdgeInsetsMake(7, 12, 7, 12);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _background = [[UIBackgroundConfiguration alloc] init];
        _background.cornerRadius = 17;
        _contentInsets = revenant_button_configuration_default_content_insets();
        _imagePlacement = 2;
        _titlePadding = 1;
        _automaticallyUpdateForSelection = YES;
    }
    return self;
}

+ (instancetype)plainButtonConfiguration { return [[self alloc] init]; }
+ (instancetype)tintedButtonConfiguration { return [[self alloc] init]; }
+ (instancetype)grayButtonConfiguration { return [[self alloc] init]; }
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

- (instancetype)updatedConfigurationForButton:(UIButton *)button { return self; }

- (void)setDefaultContentInsets { self.contentInsets = revenant_button_configuration_default_content_insets(); }

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
