// UIContentUnavailableProperties.m - the three property bags of the empty-state API, and the state object
// the search and loading configurations are built over.
//
// What the host answers was measured first (facts/UIKit/UIContentUnavailable17.md, M1): each of these is a
// plain value holder, so the port's copy is the same holder and every property is asked of both sides by the
// case in tests/backports/host/uikit2/contentunavailable_test.m. Where the header states a default this file
// uses it; the two defaults the header does not state - a button bag's `enabled` and a state's `traitCollection`
// - are set here and the case is what says whether the port and the host agree, so a wrong guess is a red run
// and not a row that claims otherwise.
//
// UIContentUnavailableConfiguration and UIContentUnavailableView are NOT here. The first has a `button` and a
// `secondaryButton` of type UIButtonConfiguration, which this library does not carry, and the second is built
// over the first; their rows stay absent with that reason, and they are what d2 carries once
// UIButtonConfiguration is.

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
    // The two defaults the header states none for, measured on the host and written here from what the case
    // read (facts/UIKit/UIContentUnavailable17.md, M1): a fresh text bag breaks its last line
    // (NSLineBreakByTruncatingTail, which is 4) and holds the system font at 17 points. The port asks for the
    // system font by size rather than naming it, because the name the host answers with is its own and does not
    // exist on 6.1.3 or 4.3; what the case compares is the size and the fact that both are the system font.
    self = [super init];
    if (self) {
        _font = [UIFont systemFontOfSize:17];
        // the host's fresh bag holds a dynamic catalog colour named labelColor, which is iOS 13 and
        // has no name on 6.1.3; the release's own label text colour is the same role, and the case
        // compares the role rather than a name neither side could share
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
    // The bag claims NSSecureCoding, so the archive is read back: a bag that answered
    // [self init] here decoded an archived disabled destructive button as an enabled plain one,
    // which is the reviewer's round trip and this is what it now does instead.
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
    // every property the header states no default for is zero here, which is what a fresh object holds
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
    // The bag claims NSSecureCoding, so the archive is read back: a bag that answered
    // [self init] here decoded an archived disabled destructive button as an enabled plain one,
    // which is the reviewer's round trip and this is what it now does instead.
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
    // A button is enabled until something disables it, and a fresh bag has no action, no menu and no role
    // beyond the header's zero. The case measures both defaults; see the file's header.
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
    // The bag claims NSSecureCoding, so the archive is read back: a bag that answered
    // [self init] here decoded an archived disabled destructive button as an enabled plain one,
    // which is the reviewer's round trip and this is what it now does instead.
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

// The keyed state the protocol's five methods share. It is not one of the header's properties, so it is
// created on first use and stays nil for a state nobody subscripts.
- (NSMutableDictionary *)customStates
{
    if (!_customStates)
        _customStates = [[NSMutableDictionary alloc] init];
    return _customStates;
}

- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection
{
    // The host refuses this and names the precondition, so the port refuses the same way rather than
    // building a state over nothing. Measured: the host raises NSInternalInconsistencyException with
    // "Invalid parameter not satisfying: traitCollection != nil" (facts/UIKit/UIContentUnavailable17.md, M2).
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
    // The coder carries the trait collection and the search text; a state built this way answers what it was
    // archived with, and the case reads both back.
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
