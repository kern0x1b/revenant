#import <UIKit/UIKit.h>
#import "UIContentUnavailableProperties.h"

@implementation UIContentUnavailableTextProperties

@synthesize font = _font;
@synthesize color = _color;
@synthesize lineBreakMode = _lineBreakMode;
@synthesize numberOfLines = _numberOfLines;
@synthesize adjustsFontSizeToFitWidth = _adjustsFontSizeToFitWidth;
@synthesize minimumScaleFactor = _minimumScaleFactor;
@synthesize allowsDefaultTighteningForTruncation = _allowsDefaultTighteningForTruncation;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _font = [UIFont systemFontOfSize:17];
        _color = [UIColor darkTextColor];
        _lineBreakMode = NSLineBreakByTruncatingTail;
        _numberOfLines = 0;
        _adjustsFontSizeToFitWidth = NO;
        _minimumScaleFactor = 0;
        _allowsDefaultTighteningForTruncation = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIContentUnavailableTextProperties *copy = [[UIContentUnavailableTextProperties allocWithZone:zone] init];
    copy.font = self.font;
    copy.color = self.color;
    copy.lineBreakMode = self.lineBreakMode;
    copy.numberOfLines = self.numberOfLines;
    copy.adjustsFontSizeToFitWidth = self.adjustsFontSizeToFitWidth;
    copy.minimumScaleFactor = self.minimumScaleFactor;
    copy.allowsDefaultTighteningForTruncation = self.allowsDefaultTighteningForTruncation;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _font = [coder decodeObjectOfClass:[UIFont class] forKey:@"font"];
        _color = [coder decodeObjectOfClass:[UIColor class] forKey:@"color"];
        _lineBreakMode = [coder decodeIntegerForKey:@"lineBreakMode"];
        _numberOfLines = [coder decodeIntegerForKey:@"numberOfLines"];
        _adjustsFontSizeToFitWidth = [coder decodeBoolForKey:@"adjustsFontSizeToFitWidth"];
        _minimumScaleFactor = [coder decodeDoubleForKey:@"minimumScaleFactor"];
        _allowsDefaultTighteningForTruncation = [coder decodeBoolForKey:@"allowsDefaultTighteningForTruncation"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.font forKey:@"font"];
    [coder encodeObject:self.color forKey:@"color"];
    [coder encodeInteger:self.lineBreakMode forKey:@"lineBreakMode"];
    [coder encodeInteger:self.numberOfLines forKey:@"numberOfLines"];
    [coder encodeBool:self.adjustsFontSizeToFitWidth forKey:@"adjustsFontSizeToFitWidth"];
    [coder encodeDouble:self.minimumScaleFactor forKey:@"minimumScaleFactor"];
    [coder encodeBool:self.allowsDefaultTighteningForTruncation forKey:@"allowsDefaultTighteningForTruncation"];
}

+ (BOOL)supportsSecureCoding { return YES; }


@end

@implementation UIContentUnavailableImageProperties

@synthesize preferredSymbolConfiguration = _preferredSymbolConfiguration;
@synthesize tintColor = _tintColor;
@synthesize cornerRadius = _cornerRadius;
@synthesize maximumSize = _maximumSize;
@synthesize accessibilityIgnoresInvertColors = _accessibilityIgnoresInvertColors;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cornerRadius = 0;
        _maximumSize = CGSizeZero;
        _accessibilityIgnoresInvertColors = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIContentUnavailableImageProperties *copy = [[UIContentUnavailableImageProperties allocWithZone:zone] init];
    copy.preferredSymbolConfiguration = self.preferredSymbolConfiguration;
    copy.tintColor = self.tintColor;
    copy.cornerRadius = self.cornerRadius;
    copy.maximumSize = self.maximumSize;
    copy.accessibilityIgnoresInvertColors = self.accessibilityIgnoresInvertColors;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _preferredSymbolConfiguration = [coder decodeObjectOfClass:[UIImageSymbolConfiguration class] forKey:@"preferredSymbolConfiguration"];
        _tintColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"tintColor"];
        _cornerRadius = [coder decodeDoubleForKey:@"cornerRadius"];
        _maximumSize = [coder decodeCGSizeForKey:@"maximumSize"];
        _accessibilityIgnoresInvertColors = [coder decodeBoolForKey:@"accessibilityIgnoresInvertColors"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.preferredSymbolConfiguration forKey:@"preferredSymbolConfiguration"];
    [coder encodeObject:self.tintColor forKey:@"tintColor"];
    [coder encodeDouble:self.cornerRadius forKey:@"cornerRadius"];
    [coder encodeCGSize:self.maximumSize forKey:@"maximumSize"];
    [coder encodeBool:self.accessibilityIgnoresInvertColors forKey:@"accessibilityIgnoresInvertColors"];
}

+ (BOOL)supportsSecureCoding { return YES; }


@end

@implementation UIContentUnavailableButtonProperties

@synthesize primaryAction = _primaryAction;
@synthesize menu = _menu;
@synthesize enabled = _enabled;
@synthesize role = _role;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _enabled = YES;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIContentUnavailableButtonProperties *copy = [[UIContentUnavailableButtonProperties allocWithZone:zone] init];
    copy.primaryAction = self.primaryAction;
    copy.menu = self.menu;
    copy.enabled = self.enabled;
    copy.role = self.role;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _primaryAction = [coder decodeObjectOfClass:[UIAction class] forKey:@"primaryAction"];
        _menu = [coder decodeObjectOfClass:[UIMenu class] forKey:@"menu"];
        _enabled = [coder decodeBoolForKey:@"enabled"];
        _role = [coder decodeIntegerForKey:@"role"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.primaryAction forKey:@"primaryAction"];
    [coder encodeObject:self.menu forKey:@"menu"];
    [coder encodeBool:self.enabled forKey:@"enabled"];
    [coder encodeInteger:self.role forKey:@"role"];
}

+ (BOOL)supportsSecureCoding { return YES; }


@end


@implementation UIContentUnavailableConfigurationState {
    NSMutableDictionary *_customStates;
}

@synthesize traitCollection = _traitCollection;
@synthesize searchText = _searchText;

- (NSMutableDictionary *)customStates
{
    if (!_customStates)
        _customStates = [[NSMutableDictionary alloc] init];
    return _customStates;
}

- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection
{
    if (!traitCollection) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Invalid parameter not satisfying: traitCollection != nil"];
    }
    self = [super init];
    if (self) {
        _traitCollection = traitCollection;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _traitCollection = [coder decodeObjectOfClass:[UITraitCollection class] forKey:@"traitCollection"];
        _searchText = [coder decodeObjectOfClass:[NSString class] forKey:@"searchText"];
    }
    return self;
}

- (id)objectForKeyedSubscript:(UIConfigurationStateCustomKey)key
{
    return [[self customStates] objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(UIConfigurationStateCustomKey)key
{
    [[self customStates] setObject:object forKey:key];
}

- (id)customStateForKey:(UIConfigurationStateCustomKey)key
{
    return [self objectForKeyedSubscript:key];
}

- (void)setCustomState:(id)object forKey:(UIConfigurationStateCustomKey)key
{
    [self setObject:object forKeyedSubscript:key];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIContentUnavailableConfigurationState *copy =
        [[UIContentUnavailableConfigurationState allocWithZone:zone] initWithTraitCollection:self.traitCollection];
    copy.searchText = self.searchText;
    copy->_customStates = [self.customStates copy];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.traitCollection forKey:@"traitCollection"];
    [coder encodeObject:self.searchText forKey:@"searchText"];
}

+ (BOOL)supportsSecureCoding { return YES; }

@end
