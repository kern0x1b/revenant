#import <UIKit/UIKit.h>

typedef UIBezierPath *(^RevenantShapeBuilder)(CGRect rect);

@interface UIShape (RevenantInit)
- (instancetype)initRevenantFixed:(BOOL)fixed fixedRect:(CGRect)fixedRect builder:(RevenantShapeBuilder)builder;
@end

@interface UIResolvedShape (RevenantInit)
- (instancetype)initRevenantWithShape:(UIShape *)shape boundingRect:(CGRect)boundingRect path:(UIBezierPath *)path;
@end

@interface UIShapeResolutionContext (RevenantInit)
- (instancetype)initRevenantWithContentShape:(UIResolvedShape *)contentShape;
@end

static UIBezierPath *revenant_rounded(CGRect rect, CGFloat radius, UIRectCorner corners)
{
    if (radius <= 0)
        return [UIBezierPath bezierPathWithRect:rect];
    return [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:corners cornerRadii:CGSizeMake(radius, radius)];
}

static UIShape *revenant_shape(BOOL fixed, CGRect fixedRect, RevenantShapeBuilder builder)
{
    return [[UIShape alloc] initRevenantFixed:fixed fixedRect:fixedRect builder:builder];
}

@implementation UIShape {
    BOOL _fixed;
    CGRect _fixedRect;
    RevenantShapeBuilder _builder;
}

- (instancetype)initRevenantFixed:(BOOL)fixed fixedRect:(CGRect)fixedRect builder:(RevenantShapeBuilder)builder
{
    if ((self = [super init])) {
        _fixed = fixed;
        _fixedRect = fixedRect;
        _builder = [builder copy];
    }
    return self;
}

+ (UIShape *)rectShape
{
    return revenant_shape(NO, CGRectZero, ^UIBezierPath *(CGRect rect) {
        return [UIBezierPath bezierPathWithRect:rect];
    });
}

+ (UIShape *)capsuleShape
{
    return revenant_shape(NO, CGRectZero, ^UIBezierPath *(CGRect rect) {
        return revenant_rounded(rect, MIN(rect.size.width, rect.size.height) / 2, UIRectCornerAllCorners);
    });
}

+ (UIShape *)circleShape
{
    return revenant_shape(NO, CGRectZero, ^UIBezierPath *(CGRect rect) {
        CGFloat side = MIN(rect.size.width, rect.size.height);
        return [UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMidX(rect) - side / 2, CGRectGetMidY(rect) - side / 2, side, side)];
    });
}

+ (instancetype)rectShapeWithCornerRadius:(CGFloat)cornerRadius
{
    return [self rectShapeWithCornerRadius:cornerRadius cornerCurve:UICornerCurveAutomatic maskedCorners:UIRectCornerAllCorners];
}

+ (instancetype)rectShapeWithCornerRadius:(CGFloat)cornerRadius cornerCurve:(UICornerCurve)cornerCurve
{
    return [self rectShapeWithCornerRadius:cornerRadius cornerCurve:cornerCurve maskedCorners:UIRectCornerAllCorners];
}

+ (instancetype)rectShapeWithCornerRadius:(CGFloat)cornerRadius cornerCurve:(UICornerCurve)cornerCurve maskedCorners:(UIRectCorner)maskedCorners
{
    return revenant_shape(NO, CGRectZero, ^UIBezierPath *(CGRect rect) {
        return revenant_rounded(rect, cornerRadius, maskedCorners);
    });
}

+ (instancetype)fixedRectShapeWithRect:(CGRect)rect
{
    return [self fixedRectShapeWithRect:rect cornerRadius:0 cornerCurve:UICornerCurveAutomatic maskedCorners:UIRectCornerAllCorners];
}

+ (instancetype)fixedRectShapeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius
{
    return [self fixedRectShapeWithRect:rect cornerRadius:cornerRadius cornerCurve:UICornerCurveAutomatic maskedCorners:UIRectCornerAllCorners];
}

+ (instancetype)fixedRectShapeWithRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius cornerCurve:(UICornerCurve)cornerCurve maskedCorners:(UIRectCorner)maskedCorners
{
    return revenant_shape(YES, rect, ^UIBezierPath *(CGRect fixed) {
        return revenant_rounded(fixed, cornerRadius, maskedCorners);
    });
}

+ (instancetype)shapeWithBezierPath:(UIBezierPath *)path
{
    UIBezierPath *copy = [path copy];
    return revenant_shape(YES, copy.bounds, ^UIBezierPath *(CGRect rect) {
        return [copy copy];
    });
}

+ (instancetype)shapeWithProvider:(id<UIShapeProvider>)provider
{
    return revenant_shape(NO, CGRectZero, ^UIBezierPath *(CGRect rect) {
        UIResolvedShape *content = [[UIResolvedShape alloc] initRevenantWithShape:[UIShape rectShape] boundingRect:rect path:[UIBezierPath bezierPathWithRect:rect]];
        return [provider resolvedShapeInContext:[[UIShapeResolutionContext alloc] initRevenantWithContentShape:content]].path;
    });
}

- (UIResolvedShape *)resolvedShapeInContext:(UIShapeResolutionContext *)context
{
    CGRect rect = _fixed ? _fixedRect : context.contentShape.boundingRect;
    return [[UIResolvedShape alloc] initRevenantWithShape:self boundingRect:rect path:_builder(rect)];
}

- (UIShape *)shapeByApplyingInsets:(UIEdgeInsets)insets
{
    RevenantShapeBuilder builder = _builder;
    BOOL fixed = _fixed;
    return revenant_shape(fixed, UIEdgeInsetsInsetRect(_fixedRect, insets), ^UIBezierPath *(CGRect rect) {
        return builder(fixed ? rect : UIEdgeInsetsInsetRect(rect, insets));
    });
}

- (UIShape *)shapeByApplyingInset:(CGFloat)inset
{
    return [self shapeByApplyingInsets:UIEdgeInsetsMake(inset, inset, inset, inset)];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation UIResolvedShape {
    UIShape *_shape;
    CGRect _boundingRect;
    UIBezierPath *_path;
}

- (instancetype)initRevenantWithShape:(UIShape *)shape boundingRect:(CGRect)boundingRect path:(UIBezierPath *)path
{
    if ((self = [super init])) {
        _shape = shape;
        _boundingRect = boundingRect;
        _path = path;
    }
    return self;
}

- (UIShape *)shape
{
    return _shape;
}

- (CGRect)boundingRect
{
    return _boundingRect;
}

- (UIBezierPath *)path
{
    return [_path copy];
}

- (UIResolvedShape *)shapeByApplyingInsets:(UIEdgeInsets)insets
{
    UIShape *inset = [_shape shapeByApplyingInsets:insets];
    UIShapeResolutionContext *context = [[UIShapeResolutionContext alloc] initRevenantWithContentShape:self];
    return [inset resolvedShapeInContext:context];
}

- (UIResolvedShape *)shapeByApplyingInset:(CGFloat)inset
{
    return [self shapeByApplyingInsets:UIEdgeInsetsMake(inset, inset, inset, inset)];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation UIShapeResolutionContext {
    UIResolvedShape *_contentShape;
}

- (instancetype)initRevenantWithContentShape:(UIResolvedShape *)contentShape
{
    if ((self = [super init]))
        _contentShape = contentShape;
    return self;
}

- (UIResolvedShape *)contentShape
{
    return _contentShape;
}

@end

@implementation UIHoverHighlightEffect

+ (instancetype)effect
{
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation UIHoverLiftEffect

+ (instancetype)effect
{
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation UIHoverAutomaticEffect

+ (instancetype)effect
{
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation UIHoverStyle {
    id<UIHoverEffect> _effect;
    UIShape *_shape;
    BOOL _enabled;
}

+ (instancetype)styleWithEffect:(id<UIHoverEffect>)effect shape:(UIShape *)shape
{
    UIHoverStyle *style = [[self alloc] init];
    style->_effect = effect;
    style->_shape = shape;
    style->_enabled = YES;
    return style;
}

+ (instancetype)styleWithShape:(UIShape *)shape
{
    return [self styleWithEffect:[UIHoverAutomaticEffect effect] shape:shape];
}

+ (instancetype)automaticStyle
{
    return [self styleWithEffect:[UIHoverAutomaticEffect effect] shape:nil];
}

- (id<UIHoverEffect>)effect
{
    return _effect;
}

- (void)setEffect:(id<UIHoverEffect>)effect
{
    _effect = effect;
}

- (UIShape *)shape
{
    return _shape;
}

- (void)setShape:(UIShape *)shape
{
    _shape = shape;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (BOOL)enabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIHoverStyle *copy = [[[self class] allocWithZone:zone] init];
    copy->_effect = [_effect copyWithZone:zone];
    copy->_shape = _shape;
    copy->_enabled = _enabled;
    return copy;
}

@end
