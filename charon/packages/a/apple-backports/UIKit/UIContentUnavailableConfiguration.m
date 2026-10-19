#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UIContentUnavailableConfiguration.h"
#import "CharonLists.h"

typedef NS_ENUM(NSInteger, CharonUnavailableKind) {
    CharonUnavailableKindEmpty = 0,
    CharonUnavailableKindLoading = 1,
    CharonUnavailableKindSearch = 2,
};

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
        _button = [UIButtonConfiguration plainButtonConfiguration];
        _secondaryButton = [UIButtonConfiguration plainButtonConfiguration];
        _background = [UIBackgroundConfiguration clearConfiguration];

        _margins = NSDirectionalEdgeInsetsMake(16, 32, 16, 32);
        _axes = UIAxisHorizontal;
        _alignment = UIContentUnavailableAlignmentCenter;
        _textToSecondaryTextPadding = 3;
        _textToButtonPadding = 20;
        _buttonToSecondaryButtonPadding = 15;

        BOOL loading = kind == CharonUnavailableKindLoading;
        _textProperties.font = loading ? charon_unavailable_body_font() : charon_unavailable_title_font();
        _textProperties.color = loading ? charon_unavailable_secondary_label_color() : charon_unavailable_label_color();
        _textProperties.lineBreakMode = NSLineBreakByTruncatingTail;
        _textProperties.numberOfLines = 0;
        _secondaryTextProperties.font = charon_unavailable_body_font();
        _secondaryTextProperties.color = charon_unavailable_secondary_label_color();
        _secondaryTextProperties.lineBreakMode = NSLineBreakByTruncatingTail;
        _secondaryTextProperties.numberOfLines = 0;

        CGFloat symbolPointSize = loading ? 32 : 48;
        _imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:symbolPointSize];
        _imageProperties.tintColor = charon_unavailable_secondary_label_color();

        _imageToTextPadding = loading ? 8 : 15;
        switch (kind) {
        case CharonUnavailableKindLoading:
            _text = @"Loading\u2026";
            break;
        case CharonUnavailableKindSearch:
            _text = @"No Results";
            _secondaryText = @"Check the spelling or try a new search.";
            _image = [UIImage systemImageNamed:@"magnifyingglass"
                              withConfiguration:_imageProperties.preferredSymbolConfiguration];
            break;
        case CharonUnavailableKindEmpty:
            break;
        }
    }
    return self;
}

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
    if ((self = [super initWithCoder:coder]))
        self.backgroundColor = [UIColor clearColor];
    return self;
}

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
        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _scrollView.backgroundColor = [UIColor clearColor];
        _contentView = [[UIView alloc] initWithFrame:_scrollView.bounds];
        [_scrollView addSubview:_contentView];
        [self addSubview:_scrollView];
    } else if (!scrollEnabled && _scrollView) {
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

- (NSDirectionalEdgeInsets)charon_effectiveMargins
{
    NSDirectionalEdgeInsets margins = _configuration.directionalLayoutMargins;
    UIView *superview = self.superview;
    if (![superview isKindOfClass:[UIView class]])
        return margins;
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
