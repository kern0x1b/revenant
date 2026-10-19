#import "CharonLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static const char CharonGuideConstraintsKey;

@implementation UILayoutGuide (CharonLists)

- (void)charon_pinFrame:(CGRect)frame inView:(UIView *)view
{
    NSArray *constraints = objc_getAssociatedObject(self, &CharonGuideConstraintsKey);
    if (!constraints) {
        constraints = @[[self.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:frame.origin.x],
                        [self.topAnchor constraintEqualToAnchor:view.topAnchor constant:frame.origin.y],
                        [self.widthAnchor constraintEqualToConstant:frame.size.width],
                        [self.heightAnchor constraintEqualToConstant:frame.size.height]];
        objc_setAssociatedObject(self, &CharonGuideConstraintsKey, constraints, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [NSLayoutConstraint activateConstraints:constraints];
        return;
    }
    NSLayoutConstraint *left = constraints[0], *top = constraints[1], *width = constraints[2], *height = constraints[3];
    if (left.constant != frame.origin.x)
        left.constant = frame.origin.x;
    if (top.constant != frame.origin.y)
        top.constant = frame.origin.y;
    if (width.constant != frame.size.width)
        width.constant = frame.size.width;
    if (height.constant != frame.size.height)
        height.constant = frame.size.height;
}

@end

static NSString *charon_transformed(NSString *text, UIListContentTextTransform transform)
{
    switch (transform) {
    case UIListContentTextTransformUppercase:
        return [text uppercaseString];
    case UIListContentTextTransformLowercase:
        return [text lowercaseString];
    case UIListContentTextTransformCapitalized:
        return [text capitalizedString];
    default:
        return text;
    }
}

static NSTextAlignment charon_alignment(UIListContentTextAlignment alignment)
{
    return alignment == UIListContentTextAlignmentCenter ? NSTextAlignmentCenter : alignment == UIListContentTextAlignmentJustified ? NSTextAlignmentJustified : NSTextAlignmentLeft;
}

@implementation UIListContentView {
@private
    UIListContentConfiguration *_configuration;
    UILabel *_textLabel;
    UILabel *_secondaryLabel;
    UIImageView *_imageView;
    UILayoutGuide *_textGuide;
    UILayoutGuide *_secondaryGuide;
    UILayoutGuide *_imageGuide;
    CGRect _textFrame;
    CGRect _secondaryFrame;
    CGRect _imageFrame;
}

- (instancetype)initWithConfiguration:(UIListContentConfiguration *)configuration
{
    if ((self = [super initWithFrame:CGRectZero])) {
        self.clipsToBounds = NO;
        [self setConfiguration:configuration];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [self initWithConfiguration:[UIListContentConfiguration cellConfiguration]]))
        self.frame = frame;
    return self;
}

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        UIListContentConfiguration *configuration = [coder decodeObjectOfClass:[UIListContentConfiguration class] forKey:@"configuration"];
        [self setConfiguration:configuration ?: [UIListContentConfiguration cellConfiguration]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_configuration forKey:@"configuration"];
}

- (UIListContentConfiguration *)configuration
{
    return [_configuration copy];
}

- (UILabel *)charon_makeLabel
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.backgroundColor = [UIColor clearColor];
    return label;
}

- (void)charon_configureLabel:(UILabel *)label properties:(UIListContentTextProperties *)properties text:(NSString *)text attributed:(NSAttributedString *)attributed
{
    label.numberOfLines = properties.numberOfLines;
    label.lineBreakMode = properties.lineBreakMode;
    label.textAlignment = charon_alignment(properties.alignment);
    label.adjustsFontSizeToFitWidth = properties.adjustsFontSizeToFitWidth;
    label.minimumScaleFactor = properties.minimumScaleFactor;
    if ([label respondsToSelector:@selector(setAllowsDefaultTighteningForTruncation:)])
        label.allowsDefaultTighteningForTruncation = properties.allowsDefaultTighteningForTruncation;
    label.font = properties.font;
    label.textColor = [properties resolvedColor];
    if (attributed) {
        NSMutableAttributedString *content = [attributed mutableCopy];
        NSRange whole = NSMakeRange(0, content.length);
        [content enumerateAttributesInRange:whole options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
            if (!attributes[NSFontAttributeName])
                [content addAttribute:NSFontAttributeName value:properties.font range:range];
            if (!attributes[NSForegroundColorAttributeName])
                [content addAttribute:NSForegroundColorAttributeName value:[properties resolvedColor] range:range];
        }];
        label.attributedText = content;
    } else {
        label.text = charon_transformed(text, properties.transform);
    }
}

- (void)setConfiguration:(UIListContentConfiguration *)configuration
{
    _configuration = [configuration copy];
    UIListContentConfiguration *config = _configuration;
    BOOL hasText = config.text != nil || config.attributedText != nil;
    BOOL hasSecondary = config.secondaryText != nil || config.secondaryAttributedText != nil;
    if (hasText) {
        if (!_textLabel) {
            _textLabel = [self charon_makeLabel];
            [self addSubview:_textLabel];
        }
        [self charon_configureLabel:_textLabel properties:config.textProperties text:config.text attributed:config.attributedText];
    } else {
        [_textLabel removeFromSuperview];
        _textLabel = nil;
    }
    if (hasSecondary) {
        if (!_secondaryLabel) {
            _secondaryLabel = [self charon_makeLabel];
            [self addSubview:_secondaryLabel];
        }
        [self charon_configureLabel:_secondaryLabel properties:config.secondaryTextProperties text:config.secondaryText attributed:config.secondaryAttributedText];
    } else {
        [_secondaryLabel removeFromSuperview];
        _secondaryLabel = nil;
    }
    UIListContentImageProperties *image = config.imageProperties;
    if (config.image) {
        if (!_imageView) {
            _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
            _imageView.contentMode = UIViewContentModeScaleAspectFit;
            [self insertSubview:_imageView atIndex:0];
        }
        _imageView.image = config.image;
        _imageView.layer.cornerRadius = image.cornerRadius;
        _imageView.clipsToBounds = image.cornerRadius > 0;
        UIColor *tint = [image resolvedTintColorForTintColor:self.tintColor];
        if (tint && [_imageView respondsToSelector:@selector(setTintColor:)])
            _imageView.tintColor = tint;
        if ([_imageView respondsToSelector:@selector(setPreferredSymbolConfiguration:)])
            _imageView.preferredSymbolConfiguration = image.preferredSymbolConfiguration;
    } else {
        [_imageView removeFromSuperview];
        _imageView = nil;
    }
    CGFloat alpha = [config charon_alpha];
    _textLabel.alpha = alpha;
    _secondaryLabel.alpha = alpha;
    _imageView.alpha = alpha;
    [self setNeedsLayout];
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    if (_configuration)
        [self setConfiguration:_configuration];
}

- (CGSize)charon_imageSize
{
    UIListContentImageProperties *properties = _configuration.imageProperties;
    CGSize size = _configuration.image.size;
    CGSize limit = properties.maximumSize;
    if (_configuration.image && (limit.width > 0 || limit.height > 0)) {
        CGFloat scale = 1;
        if (limit.width > 0 && size.width > limit.width)
            scale = MIN(scale, limit.width / size.width);
        if (limit.height > 0 && size.height > limit.height)
            scale = MIN(scale, limit.height / size.height);
        size = CGSizeMake(size.width * scale, size.height * scale);
    }
    return _configuration.image ? size : CGSizeZero;
}

- (CGFloat)charon_lineHeightOfLabel:(UILabel *)label lines:(NSInteger)lines
{
    NSString *saved = label.text;
    NSAttributedString *savedAttributed = label.attributedText;
    NSInteger savedLines = label.numberOfLines;
    label.numberOfLines = 0;
    label.text = lines == 1 ? @"a" : @"a\na";
    CGFloat height = [label sizeThatFits:CGSizeMake(100000, CGFLOAT_MAX)].height;
    label.numberOfLines = savedLines;
    if (savedAttributed)
        label.attributedText = savedAttributed;
    else
        label.text = saved;
    return height;
}

- (CGSize)charon_fit:(UILabel *)label width:(CGFloat)width
{
    if (!label)
        return CGSizeZero;
    NSInteger limit = label.numberOfLines;
    BOOL shrinks = label.adjustsFontSizeToFitWidth;
    label.adjustsFontSizeToFitWidth = NO;
    label.numberOfLines = limit > 1 ? 0 : limit;
    CGSize size = [label sizeThatFits:CGSizeMake(MAX(width, 0), CGFLOAT_MAX)];
    label.numberOfLines = limit;
    label.adjustsFontSizeToFitWidth = shrinks;
    if (limit > 1) {
        CGFloat single = [self charon_lineHeightOfLabel:label lines:1], pitch = [self charon_lineHeightOfLabel:label lines:2] - single;
        NSInteger lines = pitch > 0 ? (NSInteger)llround((size.height - single) / pitch) + 1 : 1;
        if (lines > limit)
            size.height = single + pitch * (limit - 1);
    }
    CGFloat scale = charon_screen_scale();
    CGFloat fitted = MIN(charon_pixel_ceil(size.width, scale), MAX(width, 0));
    if (_textLabel && label.textAlignment != NSTextAlignmentLeft)
        fitted = MAX(width, 0);
    return CGSizeMake(fitted, charon_pixel_ceil(size.height, scale));
}

- (CGFloat)charon_textLeading
{
    NSDirectionalEdgeInsets margins = [self charon_effectiveMargins];
    CGSize imageSize = [self charon_imageSize];
    CGSize reserved = _configuration.imageProperties.reservedLayoutSize;
    return margins.leading + (_configuration.image ? (reserved.width > 0 ? reserved.width : imageSize.width) + _configuration.imageToTextPadding : 0);
}

- (CGFloat)charon_minimumHeight
{
    switch ([_configuration charon_style]) {
    case CharonListStyleCell:
    case CharonListStyleSubtitle:
    case CharonListStyleValue:
        return 40.04;
    case CharonListStyleSidebarCell:
    case CharonListStyleSidebarSubtitle:
    case CharonListStyleAccompaniedSidebar:
    case CharonListStyleAccompaniedSidebarSubtitle:
    case CharonListStyleSidebarHeader:
        return 33.88;
    }
    return 0;
}

- (NSDirectionalEdgeInsets)charon_effectiveMargins
{
    NSDirectionalEdgeInsets margins = _configuration.directionalLayoutMargins;
    UIAxis axes = _configuration.axesPreservingSuperviewLayoutMargins;
    UIView *parent = self.superview;
    if (!parent || !axes)
        return margins;
    UIEdgeInsets inherited = parent.layoutMargins;
    CGRect bounds = parent.bounds, frame = self.frame;
    if (axes & UIAxisHorizontal) {
        margins.leading = MAX(margins.leading, inherited.left - MAX(CGRectGetMinX(frame) - CGRectGetMinX(bounds), 0));
        margins.trailing = MAX(margins.trailing, inherited.right - MAX(CGRectGetMaxX(bounds) - CGRectGetMaxX(frame), 0));
    }
    if (axes & UIAxisVertical) {
        margins.top = MAX(margins.top, inherited.top - MAX(CGRectGetMinY(frame) - CGRectGetMinY(bounds), 0));
        margins.bottom = MAX(margins.bottom, inherited.bottom - MAX(CGRectGetMaxY(bounds) - CGRectGetMaxY(frame), 0));
    }
    return margins;
}

- (CGFloat)charon_solveInSize:(CGSize)bounds apply:(BOOL)apply totalHeight:(CGFloat *)totalHeight
{
    UIListContentConfiguration *config = _configuration;
    UIListContentImageProperties *properties = config.imageProperties;
    CGFloat scale = charon_screen_scale();
    NSDirectionalEdgeInsets margins = [self charon_effectiveMargins];
    CGFloat region = bounds.height - margins.top - margins.bottom;
    CGSize reserved = properties.reservedLayoutSize;
    CGSize imageSize = [self charon_imageSize];
    BOOL hasImage = config.image != nil;
    if (hasImage && imageSize.height > 0 && bounds.height < CGFLOAT_MAX / 2) {
        CGSize limit = properties.maximumSize;
        BOOL capped = limit.height > 0 && config.image.size.height > limit.height;
        CGFloat room = MAX(region, 0);
        if (reserved.height > 0)
            room = imageSize.height > reserved.height ? bounds.height : room;
        else if (capped)
            room = bounds.height;
        if (imageSize.height > room) {
            CGFloat shrink = room / imageSize.height;
            imageSize = CGSizeMake(imageSize.width * shrink, room);
        }
    }
    CGSize slot = hasImage ? CGSizeMake(reserved.width > 0 ? reserved.width : imageSize.width, reserved.height > 0 ? reserved.height : imageSize.height) : CGSizeZero;
    BOOL hasSlot = hasImage;
    CGFloat textLeft = margins.leading + (hasSlot ? slot.width + (_textLabel || _secondaryLabel ? config.imageToTextPadding : 0) : 0);
    CGFloat available = bounds.width - textLeft - margins.trailing;
    BOOL sideBySide = NO;
    if (_textLabel && _secondaryLabel && config.prefersSideBySideTextAndSecondaryText) {
        CGFloat gap = config.textToSecondaryTextHorizontalPadding;
        CGFloat wide = 100000;
        sideBySide = [_textLabel sizeThatFits:CGSizeMake(wide, wide)].width + gap + [_secondaryLabel sizeThatFits:CGSizeMake(wide, wide)].width <= available;
    }
    NSTextAlignment textAlignment = _textLabel.textAlignment, secondaryAlignment = _secondaryLabel.textAlignment;
    if (sideBySide) {
        _textLabel.textAlignment = NSTextAlignmentLeft;
        _secondaryLabel.textAlignment = NSTextAlignmentLeft;
    } else if (config.prefersSideBySideTextAndSecondaryText && _secondaryLabel && _textLabel &&
               [_textLabel sizeThatFits:CGSizeMake(available, CGFLOAT_MAX)].height < [self charon_lineHeightOfLabel:_textLabel lines:1] * 1.5) {
        _textLabel.textAlignment = NSTextAlignmentLeft;
    }
    CGSize textSize = [self charon_fit:_textLabel width:available];
    CGSize secondarySize = [self charon_fit:_secondaryLabel width:_textLabel ? available : available - config.textToSecondaryTextHorizontalPadding];
    _textLabel.textAlignment = textAlignment;
    _secondaryLabel.textAlignment = secondaryAlignment;
    CGFloat naturalBlock = 0;
    if (_textLabel && _secondaryLabel && !sideBySide)
        naturalBlock = textSize.height + config.textToSecondaryTextVerticalPadding + secondarySize.height;
    else
        naturalBlock = MAX(textSize.height, secondarySize.height);
    if (totalHeight)
        *totalHeight = MAX(margins.top + MAX(naturalBlock, slot.height) + margins.bottom, [self charon_minimumHeight]);
    CGFloat fittingWidth = margins.leading + (hasImage ? slot.width + config.imageToTextPadding : 0) + margins.trailing;
    if (sideBySide)
        fittingWidth += textSize.width + config.textToSecondaryTextHorizontalPadding + secondarySize.width;
    else if (_secondaryLabel && !_textLabel)
        fittingWidth += secondarySize.width + config.textToSecondaryTextHorizontalPadding;
    else
        fittingWidth += MAX(textSize.width, secondarySize.width);
    if (!apply)
        return fittingWidth;
    CGFloat limit = MAX(region, 0);
    CGFloat textX = textLeft, secondaryX = textLeft;
    CGFloat blockHeight = 0, textY = 0, secondaryY = 0;
    if (sideBySide) {
        secondaryX = textLeft + available - secondarySize.width;
        textSize.height = MIN(textSize.height, limit);
        secondarySize.height = MIN(secondarySize.height, limit);
        blockHeight = MAX(textSize.height, secondarySize.height);
        CGFloat center = margins.top + region / 2;
        textY = charon_pixel_round(center - textSize.height / 2, scale) - charon_pixel_round(margins.top + (region - blockHeight) / 2, scale);
        secondaryY = charon_pixel_round(center - secondarySize.height / 2, scale) - charon_pixel_round(margins.top + (region - blockHeight) / 2, scale);
    } else if (_textLabel && _secondaryLabel) {
        textSize.height = MIN(textSize.height, limit);
        secondarySize.height = MAX(0, MIN(secondarySize.height, limit - textSize.height - config.textToSecondaryTextVerticalPadding));
        secondaryY = textSize.height + config.textToSecondaryTextVerticalPadding;
        blockHeight = secondaryY + secondarySize.height;
    } else if (_textLabel) {
        textSize.height = MIN(textSize.height, limit);
        blockHeight = textSize.height;
    } else if (_secondaryLabel) {
        secondarySize.height = MIN(secondarySize.height, limit);
        blockHeight = secondarySize.height;
    }
    CGFloat blockY = charon_pixel_round(margins.top + (region - blockHeight) / 2, scale);
    CGFloat imageY = charon_pixel_round(margins.top + (region - imageSize.height) / 2, scale);
    _textFrame = _textLabel ? CGRectMake(textX, blockY + textY, textSize.width, textSize.height) : CGRectZero;
    _secondaryFrame = _secondaryLabel ? CGRectMake(secondaryX, blockY + secondaryY, secondarySize.width, secondarySize.height) : CGRectZero;
    _imageFrame = hasImage ? CGRectMake(margins.leading + (slot.width - imageSize.width) / 2, imageY, imageSize.width, imageSize.height) : CGRectZero;
    _textFrame.size.height += 0;
    _secondaryFrame.size.height += 0;
    _textLabel.frame = _textFrame;
    _secondaryLabel.frame = _secondaryFrame;
    _imageView.frame = _imageFrame;
    return fittingWidth;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self charon_solveInSize:self.bounds.size apply:YES totalHeight:NULL];
    [_textGuide charon_pinFrame:_textFrame inView:self];
    [_secondaryGuide charon_pinFrame:_secondaryFrame inView:self];
    [_imageGuide charon_pinFrame:_imageFrame inView:self];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGSize bounds = CGSizeMake(size.width, size.height > 0 ? size.height : CGFLOAT_MAX);
    CGFloat height = 0;
    CGFloat width = [self charon_solveInSize:bounds apply:NO totalHeight:&height];
    return CGSizeMake(MIN(width, size.width), MIN(height, bounds.height));
}

- (CGSize)charon_sizeFittingWidth:(CGFloat)width
{
    return [self sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
}

- (UILayoutGuide *)charon_guideNamed:(NSString *)name
{
    UILayoutGuide *guide = [[UILayoutGuide alloc] init];
    guide.identifier = name;
    [self addLayoutGuide:guide];
    return guide;
}

- (UILayoutGuide *)textLayoutGuide
{
    if (!_textGuide) {
        _textGuide = [self charon_guideNamed:@"UIListContentViewTextLayoutGuide"];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
    return _textGuide;
}

- (UILayoutGuide *)secondaryTextLayoutGuide
{
    if (!_secondaryGuide) {
        _secondaryGuide = [self charon_guideNamed:@"UIListContentViewSecondaryTextLayoutGuide"];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
    return _secondaryGuide;
}

- (UILayoutGuide *)imageLayoutGuide
{
    if (!_imageGuide) {
        _imageGuide = [self charon_guideNamed:@"UIListContentViewImageLayoutGuide"];
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
    return _imageGuide;
}

@end
