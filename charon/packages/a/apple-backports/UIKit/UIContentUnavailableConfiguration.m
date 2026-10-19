// UIContentUnavailableConfiguration.m - the empty-state configuration of iOS 17.0 and the content view
// that draws it.
//
// ONE OBJECT, ONE RELEASE: everything here is 17.0 API.  The property bags and the state object of the same
// release are UIContentUnavailableProperties.m, and this file holds the two classes that need what those
// carry: UIButtonConfiguration (15.0, UIButtonConfiguration.m), UIBackgroundConfiguration
// (CharonBackgrounds16.m), UIImageSymbolConfiguration (13.0, UIImage+Symbols.m) and UIContentConfiguration
// (14.0, ios13rest.json).
//
// EVERY DEFAULT BELOW IS MEASURED, not read out of a header, and the header states none of them.  The
// oracle is the host's own UIKit under Mac Catalyst 27.0 (build 26A428), asked through the probe in
// .agent-work/runs/cu17/ and held to this file by the case in
// tests/backports/host/uikit2/contentunavailableconfig_test.m; the numbers are in
// facts/UIKit/UIContentUnavailable17.md, M4.  The transcription of the declarations is read from the SDK
// that declares these names, charon/.agent-work/sdk-26.2's iPhoneOS26.2.sdk, whose
// UIContentUnavailableConfiguration.h and UIContentUnavailableView.h are byte for byte the Catalyst ones.
//
// The three factories differ in six measured values and agree in the rest; -initCharonWithKind: is where
// that table lives, so the three doors are three calls and there is no second copy of the defaults.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UIContentUnavailableConfiguration.h"
#import "CharonLists.h"

// Which of the three factories built this configuration.  The kind is what decides the six values they do
// not share, so it is kept and not re-derived from the fields: two kinds can hold the same field values and
// only the kind tells them apart.
typedef NS_ENUM(NSInteger, CharonUnavailableKind) {
    CharonUnavailableKindEmpty = 0,
    CharonUnavailableKindLoading = 1,
    CharonUnavailableKindSearch = 2,
};

// Measured on the host (facts/UIKit/UIContentUnavailable17.md, M4):
//
//   the primary text of the empty and search configurations is the 22 point BOLD system font in the label
//   colour; the loading configuration's primary text is the 15 point REGULAR system font in the secondary
//   label colour, and its secondary text properties are the same 15 point regular bag
//
//   the two colours are the host's dynamic catalog entries, labelColor and secondaryLabelColor.  Neither
//   name exists on 6.1.3 or on 4.3, so the port answers the release's own colours for the same roles -
//   darkTextColor for the label, darkGrayColor for the secondary label - exactly as
//   UIContentUnavailableProperties.m already does for the bag's labelColor, and the case compares the role
//   rather than a name neither side could share.
//
//   the point sizes ARE comparable: 22 and 15 are numbers both sides hold.
static UIFont *charon_unavailable_title_font(void)
{
    return [UIFont boldSystemFontOfSize:22];
}

static UIFont *charon_unavailable_body_font(void)
{
    return [UIFont systemFontOfSize:15];
}

static UIColor *charon_unavailable_label_color(void)
{
    return [UIColor darkTextColor];
}

static UIColor *charon_unavailable_secondary_label_color(void)
{
    return [UIColor darkGrayColor];
}

@implementation UIContentUnavailableConfiguration {
@private
    UIImage *_image;
    NSString *_text;
    NSAttributedString *_attributedText;
    UIContentUnavailableTextProperties *_textProperties;
    NSString *_secondaryText;
    NSAttributedString *_secondaryAttributedText;
    UIContentUnavailableTextProperties *_secondaryTextProperties;
    UIContentUnavailableImageProperties *_imageProperties;
    UIButtonConfiguration *_button;
    UIContentUnavailableButtonProperties *_buttonProperties;
    UIButtonConfiguration *_secondaryButton;
    UIContentUnavailableButtonProperties *_secondaryButtonProperties;
    UIBackgroundConfiguration *_background;
    UIContentUnavailableAlignment _alignment;
    UIAxis _axes;
    NSDirectionalEdgeInsets _margins;
    CGFloat _imageToTextPadding;
    CGFloat _textToSecondaryTextPadding;
    CGFloat _textToButtonPadding;
    CGFloat _buttonToSecondaryButtonPadding;
    CharonUnavailableKind _kind;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initCharonWithKind:(CharonUnavailableKind)kind
{
    if ((self = [super init])) {
        _kind = kind;
        _imageProperties = [[UIContentUnavailableImageProperties alloc] init];
        _textProperties = [[UIContentUnavailableTextProperties alloc] init];
        _secondaryTextProperties = [[UIContentUnavailableTextProperties alloc] init];
        _buttonProperties = [[UIContentUnavailableButtonProperties alloc] init];
        _secondaryButtonProperties = [[UIContentUnavailableButtonProperties alloc] init];
        // +plainButtonConfiguration, and the reason is measured rather than chosen: the host's two buttons
        // describe themselves "baseStyle=plain macStyle=bordered buttonSize=small titleAlignment=center
        // cornerRadius=dynamic, corner radius 14", and +plainButtonConfiguration is the only public door
        // that gives baseStyle=plain - +[UIButtonConfiguration init] is NS_UNAVAILABLE in the SDK's own
        // header, and there is no factory for the small/bordered/centred variant the host holds.  What the
        // port does not copy is that private style: it takes the plain base style it can name and the row
        // says which of the host's values it does not carry (facts/UIKit/UIContentUnavailable17.md, M4).
        _button = [UIButtonConfiguration plainButtonConfiguration];
        _secondaryButton = [UIButtonConfiguration plainButtonConfiguration];
        // measured: all three configurations hold a clear background, corner radius 0 - the host's
        // description names it "Base Style = Custom", which is +clearConfiguration's own style
        _background = [UIBackgroundConfiguration clearConfiguration];

        // measured, and the same in all three: margins 32 leading, 32 trailing, 16 top, 16 bottom; the
        // horizontal axis preserved; alignment centred; and the three paddings that are not the image one
        _margins = NSDirectionalEdgeInsetsMake(16, 32, 16, 32);
        _axes = UIAxisHorizontal;
        _alignment = UIContentUnavailableAlignmentCenter;
        _textToSecondaryTextPadding = 3;
        _textToButtonPadding = 20;
        _buttonToSecondaryButtonPadding = 15;

        // the primary text properties.  Loading is the one factory whose primary text is not the 22 point
        // title: measured, its primary bag is the 15 point regular body font in the secondary label colour,
        // the same bag its secondary text carries.
        BOOL loading = kind == CharonUnavailableKindLoading;
        _textProperties.font = loading ? charon_unavailable_body_font() : charon_unavailable_title_font();
        _textProperties.color = loading ? charon_unavailable_secondary_label_color() : charon_unavailable_label_color();
        // measured: 4, which is NSLineBreakByTruncatingTail, on all three, and 0 lines
        _textProperties.lineBreakMode = NSLineBreakByTruncatingTail;
        _textProperties.numberOfLines = 0;
        _secondaryTextProperties.font = charon_unavailable_body_font();
        _secondaryTextProperties.color = charon_unavailable_secondary_label_color();
        _secondaryTextProperties.lineBreakMode = NSLineBreakByTruncatingTail;
        _secondaryTextProperties.numberOfLines = 0;

        // measured: the image properties' symbol configuration is a point size and nothing else - 48 for the
        // empty and search configurations and 32 for the loading one, whose spinner is drawn at that size -
        // and the tint is the secondary label colour on all three.  The port builds the configuration with
        // +[UIImageSymbolConfiguration configurationWithPointSize:], which its own symbol table (333 glyphs,
        // CharonSymbolGlyphs.h) draws at.
        CGFloat symbolPointSize = loading ? 32 : 48;
        _imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:symbolPointSize];
        _imageProperties.tintColor = charon_unavailable_secondary_label_color();

        // measured, the six values the three factories do not share.  The image-to-text padding is 15 for
        // empty and search and 8 for loading; only search carries an image, a primary text and a secondary
        // text, and only loading carries a primary text of its own.
        _imageToTextPadding = loading ? 8 : 15;
        switch (kind) {
        case CharonUnavailableKindLoading:
            // U+2026 HORIZONTAL ELLIPSIS, measured byte for byte (e2 80 a6 after "Loading")
            _text = @"Loading\u2026";
            break;
        case CharonUnavailableKindSearch:
            _text = @"No Results";
            _secondaryText = @"Check the spelling or try a new search.";
            // The host's search image is the SF Symbol "magnifyingglass" at the symbol configuration's point
            // size, which for this factory is the 48 the general line above already set - the search is the
            // third factory, so it takes the same 48 the empty one does, and this is the only difference
            // between them here.  The port draws that name itself - it is one of the 333 glyphs
            // CharonSymbolGlyphs.h holds - through +[UIImage systemImageNamed:withConfiguration:], which is
            // the same path an application asking for the symbol by name takes on this release.
            _image = [UIImage systemImageNamed:@"magnifyingglass"
                              withConfiguration:_imageProperties.preferredSymbolConfiguration];
            break;
        case CharonUnavailableKindEmpty:
            break;
        }
    }
    return self;
}

// +new and -init are NS_UNAVAILABLE in the SDK's header, and the port cannot take NSObject's away: the
// class is over NSObject, so a caller that ignores the unavailability gets an object rather than a link
// error.  What it gets is every scalar at the zero of its type, which is what the host's own unavailable
// +new answers (measured: margins 0/0/0/0 and every padding 0).  The one place the port does NOT copy the
// host is the four readonly property bags, which the host's +new leaves nil and the port does not: the
// header declares them nonnull, and a nil bag would turn every write to it into a silent no-op.  Both the
// difference and the measurement are in facts/UIKit/UIContentUnavailable17.md, M4.
- (instancetype)init
{
    return [self initCharonWithKind:CharonUnavailableKindEmpty];
}

- (instancetype)charon_copy
{
    UIContentUnavailableConfiguration *copy = [[UIContentUnavailableConfiguration alloc] initCharonWithKind:_kind];
    copy->_image = _image;
    copy->_text = [_text copy];
    copy->_attributedText = [_attributedText copy];
    copy->_secondaryText = [_secondaryText copy];
    copy->_secondaryAttributedText = [_secondaryAttributedText copy];
    // measured: the bags are deep - writing one copy's bag leaves the other's alone, and writing the
    // original's bag after the copy was taken leaves the copy at what it was given - so they are copied
    // rather than shared.
    copy->_imageProperties = [_imageProperties copy];
    copy->_textProperties = [_textProperties copy];
    copy->_secondaryTextProperties = [_secondaryTextProperties copy];
    copy->_buttonProperties = [_buttonProperties copy];
    copy->_secondaryButtonProperties = [_secondaryButtonProperties copy];
    copy->_button = [_button copy];
    copy->_secondaryButton = [_secondaryButton copy];
    copy->_background = [_background copy];
    copy->_alignment = _alignment;
    copy->_axes = _axes;
    copy->_margins = _margins;
    copy->_imageToTextPadding = _imageToTextPadding;
    copy->_textToSecondaryTextPadding = _textToSecondaryTextPadding;
    copy->_textToButtonPadding = _textToButtonPadding;
    copy->_buttonToSecondaryButtonPadding = _buttonToSecondaryButtonPadding;
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self charon_copy];
}

// The 14.0 protocol member.  Measured: the host answers a copy that is not the receiver, and whose public
// values are the ones it was given - so this is the same copy the three factories' objects answer, not a
// state-dependent rewrite.  A state that is not a UIContentUnavailableConfigurationState has no search
// text to apply, and the host keeps the text either way (measured with a plain UIViewConfigurationState:
// "No Results" came back "No Results").
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state
{
    return [self charon_copy];
}

- (__kindof UIView<UIContentView> *)makeContentView
{
    return [[UIContentUnavailableView alloc] initWithConfiguration:self];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    // The keys are the ones the host writes, measured by archiving a search configuration on the host and
    // reading the plist (facts/UIKit/UIContentUnavailable17.md, M4).  What is NOT written is the host's
    // own style bookkeeping - defaultStyle, prefersButtonsJustified,
    // prefersSideBySideButtonAndSecondaryButton and the hasCustomized-* flags - and that is a decision with
    // a reason rather than an omission: those are 27.0 runtime members that are in no 26.2 header this port
    // transcribes from, they describe a style model the port does not have, and an archive that carried
    // them would claim API this library has no row for.  An archive the port writes reads back through the
    // port; an archive the host wrote reads back here with every public value and without that private
    // state, which is the whole of what this release can draw.
    [coder encodeObject:_image forKey:@"image"];
    [coder encodeObject:_text forKey:@"text"];
    [coder encodeObject:_attributedText forKey:@"attributedText"];
    [coder encodeObject:_secondaryText forKey:@"secondaryText"];
    [coder encodeObject:_secondaryAttributedText forKey:@"secondaryAttributedText"];
    [coder encodeObject:_imageProperties forKey:@"imageProperties"];
    [coder encodeObject:_textProperties forKey:@"textProperties"];
    [coder encodeObject:_secondaryTextProperties forKey:@"secondaryTextProperties"];
    [coder encodeObject:_buttonProperties forKey:@"buttonProperties"];
    [coder encodeObject:_secondaryButtonProperties forKey:@"secondaryButtonProperties"];
    [coder encodeObject:_background forKey:@"background"];
    [coder encodeInteger:_alignment forKey:@"alignment"];
    [coder encodeInteger:(NSInteger)_axes forKey:@"axesPreservingSuperviewLayoutMargins"];
    [coder encodeObject:[NSValue valueWithBytes:&_margins objCType:@encode(NSDirectionalEdgeInsets)] forKey:@"directionalLayoutMargins"];
    [coder encodeDouble:_imageToTextPadding forKey:@"imageToTextPadding"];
    [coder encodeDouble:_textToSecondaryTextPadding forKey:@"textToSecondaryTextPadding"];
    [coder encodeDouble:_textToButtonPadding forKey:@"textToButtonPadding"];
    [coder encodeDouble:_buttonToSecondaryButtonPadding forKey:@"buttonToSecondaryButtonPadding"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self initCharonWithKind:CharonUnavailableKindEmpty])) {
        _image = [coder decodeObjectOfClass:[UIImage class] forKey:@"image"];
        _text = [coder decodeObjectOfClass:[NSString class] forKey:@"text"];
        _attributedText = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"attributedText"];
        _secondaryText = [coder decodeObjectOfClass:[NSString class] forKey:@"secondaryText"];
        _secondaryAttributedText = [coder decodeObjectOfClass:[NSAttributedString class] forKey:@"secondaryAttributedText"];
        UIContentUnavailableImageProperties *image = [coder decodeObjectOfClass:[UIContentUnavailableImageProperties class] forKey:@"imageProperties"];
        if (image)
            _imageProperties = image;
        UIContentUnavailableTextProperties *text = [coder decodeObjectOfClass:[UIContentUnavailableTextProperties class] forKey:@"textProperties"];
        if (text)
            _textProperties = text;
        UIContentUnavailableTextProperties *secondary = [coder decodeObjectOfClass:[UIContentUnavailableTextProperties class] forKey:@"secondaryTextProperties"];
        if (secondary)
            _secondaryTextProperties = secondary;
        UIContentUnavailableButtonProperties *button = [coder decodeObjectOfClass:[UIContentUnavailableButtonProperties class] forKey:@"buttonProperties"];
        if (button)
            _buttonProperties = button;
        UIContentUnavailableButtonProperties *secondaryButton = [coder decodeObjectOfClass:[UIContentUnavailableButtonProperties class] forKey:@"secondaryButtonProperties"];
        if (secondaryButton)
            _secondaryButtonProperties = secondaryButton;
        UIBackgroundConfiguration *background = [coder decodeObjectOfClass:[UIBackgroundConfiguration class] forKey:@"background"];
        if (background)
            _background = background;
        _alignment = (UIContentUnavailableAlignment)[coder decodeIntegerForKey:@"alignment"];
        _axes = (UIAxis)[coder decodeIntegerForKey:@"axesPreservingSuperviewLayoutMargins"];
        NSValue *margins = [coder decodeObjectOfClass:[NSValue class] forKey:@"directionalLayoutMargins"];
        if (margins)
            [margins getValue:&_margins];
        _imageToTextPadding = (CGFloat)[coder decodeDoubleForKey:@"imageToTextPadding"];
        _textToSecondaryTextPadding = (CGFloat)[coder decodeDoubleForKey:@"textToSecondaryTextPadding"];
        _textToButtonPadding = (CGFloat)[coder decodeDoubleForKey:@"textToButtonPadding"];
        _buttonToSecondaryButtonPadding = (CGFloat)[coder decodeDoubleForKey:@"buttonToSecondaryButtonPadding"];
    }
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UIContentUnavailableConfiguration class]])
        return NO;
    UIContentUnavailableConfiguration *that = other;
    return [_text isEqualToString:that->_text] && [_secondaryText isEqualToString:that->_secondaryText] && _alignment == that->_alignment
        && _axes == that->_axes && _margins.top == that->_margins.top && _margins.leading == that->_margins.leading
        && _margins.bottom == that->_margins.bottom && _margins.trailing == that->_margins.trailing
        && _imageToTextPadding == that->_imageToTextPadding && _textToSecondaryTextPadding == that->_textToSecondaryTextPadding
        && _textToButtonPadding == that->_textToButtonPadding
        && _buttonToSecondaryButtonPadding == that->_buttonToSecondaryButtonPadding;
}

- (NSUInteger)hash
{
    return [_text hash] ^ [_secondaryText hash] ^ (NSUInteger)_alignment ^ (NSUInteger)_axes;
}

+ (instancetype)emptyConfiguration
{
    return [[self alloc] initCharonWithKind:CharonUnavailableKindEmpty];
}

+ (instancetype)loadingConfiguration
{
    return [[self alloc] initCharonWithKind:CharonUnavailableKindLoading];
}

+ (instancetype)searchConfiguration
{
    return [[self alloc] initCharonWithKind:CharonUnavailableKindSearch];
}

- (UIImage *)image { return _image; }
- (void)setImage:(UIImage *)image { _image = image; }
- (UIContentUnavailableImageProperties *)imageProperties { return _imageProperties; }
- (NSString *)text { return _text; }
- (void)setText:(NSString *)text { _text = [text copy]; }
- (NSAttributedString *)attributedText { return _attributedText; }
- (void)setAttributedText:(NSAttributedString *)attributedText { _attributedText = [attributedText copy]; }
- (UIContentUnavailableTextProperties *)textProperties { return _textProperties; }
- (NSString *)secondaryText { return _secondaryText; }
- (void)setSecondaryText:(NSString *)secondaryText { _secondaryText = [secondaryText copy]; }
- (NSAttributedString *)secondaryAttributedText { return _secondaryAttributedText; }
- (void)setSecondaryAttributedText:(NSAttributedString *)text { _secondaryAttributedText = [text copy]; }
- (UIContentUnavailableTextProperties *)secondaryTextProperties { return _secondaryTextProperties; }
- (UIButtonConfiguration *)button { return _button; }
- (void)setButton:(UIButtonConfiguration *)button { _button = button; }
- (UIContentUnavailableButtonProperties *)buttonProperties { return _buttonProperties; }
- (UIButtonConfiguration *)secondaryButton { return _secondaryButton; }
- (void)setSecondaryButton:(UIButtonConfiguration *)button { _secondaryButton = button; }
- (UIContentUnavailableButtonProperties *)secondaryButtonProperties { return _secondaryButtonProperties; }
- (UIBackgroundConfiguration *)background { return _background; }
- (void)setBackground:(UIBackgroundConfiguration *)background { _background = background; }
- (UIContentUnavailableAlignment)alignment { return _alignment; }
- (void)setAlignment:(UIContentUnavailableAlignment)alignment { _alignment = alignment; }
- (UIAxis)axesPreservingSuperviewLayoutMargins { return _axes; }
- (void)setAxesPreservingSuperviewLayoutMargins:(UIAxis)axes { _axes = axes; }
- (NSDirectionalEdgeInsets)directionalLayoutMargins { return _margins; }
- (void)setDirectionalLayoutMargins:(NSDirectionalEdgeInsets)margins { _margins = margins; }
- (CGFloat)imageToTextPadding { return _imageToTextPadding; }
- (void)setImageToTextPadding:(CGFloat)padding { _imageToTextPadding = padding; }
- (CGFloat)textToSecondaryTextPadding { return _textToSecondaryTextPadding; }
- (void)setTextToSecondaryTextPadding:(CGFloat)padding { _textToSecondaryTextPadding = padding; }
- (CGFloat)textToButtonPadding { return _textToButtonPadding; }
- (void)setTextToButtonPadding:(CGFloat)padding { _textToButtonPadding = padding; }
- (CGFloat)buttonToSecondaryButtonPadding { return _buttonToSecondaryButtonPadding; }
- (void)setButtonToSecondaryButtonPadding:(CGFloat)padding { _buttonToSecondaryButtonPadding = padding; }

@end

// =====================================================================================
// The content view.  It holds the configuration and draws what the configuration says, on the release's
// own UIView, UILabel, UIImageView, UIButton and UIScrollView - every one of which 6.1.3 and 4.3 have.
// =====================================================================================

@implementation UIContentUnavailableView {
@private
    UIContentUnavailableConfiguration *_configuration;
    UIImageView *_imageView;
    UILabel *_textLabel;
    UILabel *_secondaryLabel;
    UIButton *_button;
    UIButton *_secondaryButton;
    UIScrollView *_scrollView;
    UIView *_contentView;
    UIAction *_buttonAction;
    UIAction *_secondaryButtonAction;
    BOOL _scrollEnabled;
}

- (instancetype)initWithConfiguration:(UIContentUnavailableConfiguration *)configuration
{
    if ((self = [super initWithFrame:CGRectZero])) {
        _configuration = [configuration copy];
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // Measured: the host's class does NOT adopt NSSecureCoding - archiving a view through a secure-coding
    // archiver fails with "Class 'UIContentUnavailableView' does not adopt it." - so this initialiser is
    // the plain UIView one and the configuration is not in the archive.  The port does not claim
    // NSSecureCoding either, and it reads no key of its own, so an archive of a view carries no
    // configuration on either side.
    if ((self = [super initWithCoder:coder]))
        self.backgroundColor = [UIColor clearColor];
    return self;
}

// The 17.0 rows +new and -initWithFrame: are NS_UNAVAILABLE in the SDK's header.  NSObject's -init is what
// +new sends and the port cannot take it away; what it answers is a view with an empty configuration, which
// is the state the host's own +new was measured in, and it is the same object -initWithConfiguration:
// builds with the empty configuration.  The row says so; nothing here claims the release's refusal, which
// is a compile-time annotation this port's callers do not inherit because the class is over NSObject.
- (instancetype)init
{
    return [self initWithConfiguration:[UIContentUnavailableConfiguration emptyConfiguration]];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [self initWithConfiguration:[UIContentUnavailableConfiguration emptyConfiguration]]))
        self.frame = frame;
    return self;
}

- (UIContentUnavailableConfiguration *)configuration
{
    return [_configuration copy];
}

- (void)setConfiguration:(UIContentUnavailableConfiguration *)configuration
{
    _configuration = [configuration copy];
    [self setNeedsLayout];
}

- (BOOL)isScrollEnabled
{
    return _scrollEnabled;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled
{
    if (_scrollEnabled == scrollEnabled)
        return;
    _scrollEnabled = scrollEnabled;
    if (scrollEnabled && !_scrollView) {
        // The release's own scroll view, created only when it is asked for: the host's class is a UIView,
        // so the scrolling is a scroll view inside it rather than a subclass, and the content is a child
        // of that scroll view so it moves when the scroll view is dragged.
        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _scrollView.backgroundColor = [UIColor clearColor];
        _contentView = [[UIView alloc] initWithFrame:_scrollView.bounds];
        [_scrollView addSubview:_contentView];
        [self addSubview:_scrollView];
    } else if (!scrollEnabled && _scrollView) {
        // The five elements were children of the scroll view's content view, so leaving is not only taking
        // the scroll view away: the ivars would still point at views that are in no hierarchy, and
        // charon_buildSubviews only creates an element when its ivar is nil, so the view would lay out into
        // nothing.  All five are released and created again on the next layout.
        [_scrollView removeFromSuperview];
        _scrollView = nil;
        _contentView = nil;
        _imageView = nil;
        _textLabel = nil;
        _secondaryLabel = nil;
        _button = nil;
        _secondaryButton = nil;
    }
    [self setNeedsLayout];
}

- (UIView *)charon_host
{
    return _scrollEnabled && _contentView ? _contentView : self;
}

- (UILabel *)charon_labelWithProperties:(UIContentUnavailableTextProperties *)properties
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.backgroundColor = [UIColor clearColor];
    label.font = properties.font;
    label.textColor = properties.color;
    label.lineBreakMode = properties.lineBreakMode;
    label.numberOfLines = properties.numberOfLines;
    label.adjustsFontSizeToFitWidth = properties.adjustsFontSizeToFitWidth;
    label.minimumScaleFactor = properties.minimumScaleFactor;
    if ([label respondsToSelector:@selector(setAllowsDefaultTighteningForTruncation:)])
        label.allowsDefaultTighteningForTruncation = properties.allowsDefaultTighteningForTruncation;
    return label;
}

- (UIButton *)charon_makeButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectZero;
    return button;
}

- (void)charon_buildSubviews
{
    UIContentUnavailableConfiguration *configuration = _configuration;
    UIView *host = [self charon_host];

    if (configuration.image && !_imageView) {
        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [host addSubview:_imageView];
    } else if (!configuration.image && _imageView) {
        [_imageView removeFromSuperview];
        _imageView = nil;
    }

    NSString *text = configuration.text;
    if (text && !_textLabel) {
        _textLabel = [self charon_labelWithProperties:configuration.textProperties];
        [host addSubview:_textLabel];
    } else if (!text && _textLabel) {
        [_textLabel removeFromSuperview];
        _textLabel = nil;
    }

    NSString *secondaryText = configuration.secondaryText;
    if (secondaryText && !_secondaryLabel) {
        _secondaryLabel = [self charon_labelWithProperties:configuration.secondaryTextProperties];
        [host addSubview:_secondaryLabel];
    } else if (!secondaryText && _secondaryLabel) {
        [_secondaryLabel removeFromSuperview];
        _secondaryLabel = nil;
    }

    if (!_button) {
        _button = [self charon_makeButton];
        [host addSubview:_button];
    }
    if (!_secondaryButton) {
        _secondaryButton = [self charon_makeButton];
        [host addSubview:_secondaryButton];
    }

    // The primary button carries its action, which is what buttonProperties exists for.  The delivery is
    // -addAction:forControlEvents: on UIControlEventPrimaryActionTriggered, the event value the release's
    // own UIControl+PerformPrimaryAction17.m sends and the one UIControl+Actions14.m already dispatches -
    // and it is measured to be the only event that fires a UIAction (facts/UIKit/UIKit17Absence.md, M10,
    // cases 1 and 4).  A touch-up-inside action never runs, so wiring this to touch-up-inside would be a
    // button that cannot be pressed.  A nil action is not wired at all, which is the release's own answer
    // for a control with no action (M10: it returns quietly, it does not raise).
    _button.enabled = configuration.buttonProperties.isEnabled;
    _secondaryButton.enabled = configuration.secondaryButtonProperties.isEnabled;
    [self charon_wireAction:_button from:_buttonAction to:configuration.buttonProperties.primaryAction];
    [self charon_wireAction:_secondaryButton from:_secondaryButtonAction to:configuration.secondaryButtonProperties.primaryAction];
    _buttonAction = configuration.buttonProperties.primaryAction;
    _secondaryButtonAction = configuration.secondaryButtonProperties.primaryAction;
    _button.configuration = configuration.button;
    _secondaryButton.configuration = configuration.secondaryButton;
}

- (void)charon_wireAction:(UIButton *)button from:(UIAction *)was to:(UIAction *)now
{
    if (was == now)
        return;
    if (was)
        [button removeAction:was forControlEvents:UIControlEventPrimaryActionTriggered];
    if (now)
        [button addAction:now forControlEvents:UIControlEventPrimaryActionTriggered];
}

// The margins the content is laid out in.  The configuration's own margins are a minimum on each axis the
// header says is preserved, and the superview's are the other minimum - the header says so in as many words
// about directionalLayoutMargins: when superview layout margins are kept on either or both axes, these are
// minimum margins only, since inherited margins may be larger.
- (NSDirectionalEdgeInsets)charon_effectiveMargins
{
    NSDirectionalEdgeInsets margins = _configuration.directionalLayoutMargins;
    UIView *superview = self.superview;
    if (![superview isKindOfClass:[UIView class]])
        return margins;
    // The release's own -layoutMargins is a UIEdgeInsets and has no leading or trailing; in the left-to-right
    // layout direction its left and right ARE the leading and trailing edges, and this port's releases are
    // the two that read left to right, so the mapping is stated here rather than left implicit.
    UIEdgeInsets inherited = superview.layoutMargins;
    UIAxis axes = _configuration.axesPreservingSuperviewLayoutMargins;
    if (!(axes & UIAxisHorizontal))
        return margins;
    if (inherited.left > margins.leading)
        margins.leading = inherited.left;
    if (inherited.right > margins.trailing)
        margins.trailing = inherited.right;
    if (axes & UIAxisVertical) {
        if (inherited.top > margins.top)
            margins.top = inherited.top;
        if (inherited.bottom > margins.bottom)
            margins.bottom = inherited.bottom;
    }
    return margins;
}

// One pass to measure, one to place.  The stack is: image, then the primary text, then the secondary text,
// then the buttons side by side, each pair separated by the padding the configuration names for it.  The
// paddings that apply only when both of their neighbours are there are not applied when one is missing,
// which is what the header says each of the four does.
- (CGSize)charon_layoutInSize:(CGSize)size apply:(BOOL)apply
{
    UIContentUnavailableConfiguration *configuration = _configuration;
    NSDirectionalEdgeInsets margins = [self charon_effectiveMargins];
    CGFloat available = MAX(size.width - margins.leading - margins.trailing, 0);
    CGFloat scale = charon_screen_scale();

    CGFloat total = margins.top + margins.bottom;
    CGFloat textTop = 0, secondaryTop = 0, buttonTop = 0, secondaryHeight_measured = 0;

    CGSize imageSize = CGSizeZero;
    if (_imageView) {
        imageSize = configuration.image.size;
        CGSize limit = configuration.imageProperties.maximumSize;
        if (limit.width > 0 || limit.height > 0) {
            CGFloat shrink = 1;
            if (limit.width > 0 && imageSize.width > limit.width)
                shrink = MIN(shrink, limit.width / imageSize.width);
            if (limit.height > 0 && imageSize.height > limit.height)
                shrink = MIN(shrink, limit.height / imageSize.height);
            imageSize = CGSizeMake(imageSize.width * shrink, imageSize.height * shrink);
        }
        total += imageSize.height;
    }

    CGFloat textHeight = 0;
    if (_textLabel) {
        [_textLabel setAttributedText:configuration.attributedText];
        _textLabel.text = configuration.attributedText ? nil : configuration.text;
        _textLabel.textAlignment = configuration.alignment == UIContentUnavailableAlignmentCenter ? NSTextAlignmentCenter : NSTextAlignmentNatural;
        CGSize fitted = [_textLabel sizeThatFits:CGSizeMake(available, CGFLOAT_MAX)];
        textHeight = charon_pixel_ceil(fitted.height, scale);
        if (_imageView)
            total += configuration.imageToTextPadding;
        total += textHeight;
        textTop = total - textHeight;
    }

    if (_secondaryLabel) {
        [_secondaryLabel setAttributedText:configuration.secondaryAttributedText];
        _secondaryLabel.text = configuration.secondaryAttributedText ? nil : configuration.secondaryText;
        _secondaryLabel.textAlignment = _textLabel ? _textLabel.textAlignment : NSTextAlignmentNatural;
        if (_textLabel)
            total += configuration.textToSecondaryTextPadding;
        CGSize fitted = [_secondaryLabel sizeThatFits:CGSizeMake(available, CGFLOAT_MAX)];
        CGFloat secondaryHeight = charon_pixel_ceil(fitted.height, scale);
        total += secondaryHeight;
        secondaryTop = total - secondaryHeight;
        secondaryHeight_measured = secondaryHeight;
    }

    CGFloat buttonRow = 0;
    if (_button || _secondaryButton) {
        CGSize primary = [_button sizeThatFits:CGSizeMake(available, CGFLOAT_MAX)];
        CGSize secondary = [_secondaryButton sizeThatFits:CGSizeMake(available, CGFLOAT_MAX)];
        buttonRow = MAX(charon_pixel_ceil(primary.height, scale), charon_pixel_ceil(secondary.height, scale));
        if (_textLabel || _secondaryLabel)
            total += configuration.textToButtonPadding;
        if (_button && _secondaryButton)
            total += configuration.buttonToSecondaryButtonPadding;
        total += buttonRow;
        buttonTop = total - buttonRow;
    }

    CGFloat width = size.width;
    CGFloat height = total;
    if (apply) {
        CGFloat left = margins.leading;
        CGFloat centre = size.width / 2;
        if (_imageView) {
            _imageView.frame = CGRectMake(roundf((float)(centre - imageSize.width / 2)), margins.top, imageSize.width, imageSize.height);
        }
        if (_textLabel)
            _textLabel.frame = CGRectMake(left, textTop, available, textHeight);
        if (_secondaryLabel)
            _secondaryLabel.frame = CGRectMake(left, secondaryTop, available, secondaryHeight_measured);
        if (_button && _secondaryButton) {
            CGFloat gap = configuration.buttonToSecondaryButtonPadding;
            CGFloat each = MAX((available - gap) / 2, 0);
            _button.frame = CGRectMake(left, buttonTop, each, buttonRow);
            _secondaryButton.frame = CGRectMake(left + each + gap, buttonTop, each, buttonRow);
        } else if (_button) {
            _button.frame = CGRectMake(left, buttonTop, available, buttonRow);
        } else if (_secondaryButton) {
            _secondaryButton.frame = CGRectMake(left, buttonTop, available, buttonRow);
        }
        if (_scrollView && _contentView) {
            _contentView.frame = CGRectMake(0, 0, size.width, height);
            _scrollView.contentSize = CGSizeMake(size.width, height);
        }
    }
    return CGSizeMake(width, height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self charon_buildSubviews];
    _scrollView.frame = self.bounds;
    [self charon_layoutInSize:self.bounds.size apply:YES];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGSize fitted = [self charon_layoutInSize:size apply:NO];
    return CGSizeMake(size.width, fitted.height);
}

@end
