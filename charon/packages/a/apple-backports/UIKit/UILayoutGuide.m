#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface NSLayoutAnchor (CharonLayoutGuide)
+ (instancetype)charon_anchorWithItem:(id)item attribute:(NSLayoutAttribute)attribute;
@end

@interface CharonLayoutGuideView : UIView {
@public
    __weak UILayoutGuide *_guide;
}
@end

@implementation CharonLayoutGuideView

- (UILayoutGuide *)charon_guide
{
    return _guide;
}

@end

@implementation UILayoutGuide {
    UIView *_view;
    __weak UIView *_owningView;
    NSString *_identifier;
    NSHashTable *_dependents;
}

- (instancetype)init
{
    if ((self = [super init])) {
        CharonLayoutGuideView *view = [[CharonLayoutGuideView alloc] initWithFrame:CGRectZero];
        view->_guide = self;
        _view = view;
        _view.hidden = YES;
        _view.userInteractionEnabled = NO;
        _view.translatesAutoresizingMaskIntoConstraints = NO;
        _identifier = @"";
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        NSString *identifier = [coder decodeObjectForKey:@"UILayoutGuideIdentifier"];
        if (identifier)
            _identifier = [identifier copy];
        UIView *owningView = [coder decodeObjectForKey:@"UILayoutGuideOwningView"];
        if (owningView)
            [owningView addLayoutGuide:self];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"UILayoutGuideIdentifier"];
    [coder encodeConditionalObject:_owningView forKey:@"UILayoutGuideOwningView"];
}

- (UIView *)charon_view
{
    return _view;
}

- (CGRect)layoutFrame
{
    return _owningView ? _view.frame : CGRectZero;
}

- (UIView *)owningView
{
    return _owningView;
}

- (void)setOwningView:(UIView *)owningView
{
    if (_view.superview != owningView) {
        [_view removeFromSuperview];
        if (owningView)
            [owningView insertSubview:_view atIndex:0];
    }
    _owningView = owningView;
}

- (NSString *)identifier
{
    return _identifier;
}

- (void)setIdentifier:(NSString *)identifier
{
    _identifier = [identifier copy];
}

static id charon_anchor(UILayoutGuide *guide, SEL name, Class type, NSLayoutAttribute attribute)
{
    id anchor = objc_getAssociatedObject(guide, name);
    if (!anchor) {
        anchor = [type charon_anchorWithItem:guide->_view attribute:attribute];
        objc_setAssociatedObject(guide, name, anchor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return anchor;
}

- (NSLayoutXAxisAnchor *)leadingAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeading);
}

- (NSLayoutXAxisAnchor *)trailingAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeTrailing);
}

- (NSLayoutXAxisAnchor *)leftAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeft);
}

- (NSLayoutXAxisAnchor *)rightAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeRight);
}

- (NSLayoutYAxisAnchor *)topAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeTop);
}

- (NSLayoutYAxisAnchor *)bottomAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeBottom);
}

- (NSLayoutDimension *)widthAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeWidth);
}

- (NSLayoutDimension *)heightAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeHeight);
}

- (NSLayoutXAxisAnchor *)centerXAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeCenterX);
}

- (NSLayoutYAxisAnchor *)centerYAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeCenterY);
}

- (UIView *)superview
{
    return _owningView;
}

static BOOL charon_engine_selector(SEL selector)
{
    return strncmp(sel_getName(selector), "nsli_", 5) == 0;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || (charon_engine_selector(selector) && [_view respondsToSelector:selector]);
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    if ([_view respondsToSelector:selector])
        return _view;
    return [super forwardingTargetForSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if (!signature)
        signature = [_view methodSignatureForSelector:selector];
    return signature;
}

- (BOOL)_supportsContentDimensionVariables
{
    return NO;
}

- (void)_rememberDependentConstraint:(NSLayoutConstraint *)constraint
{
    if (!_dependents)
        _dependents = [NSHashTable weakObjectsHashTable];
    [_dependents addObject:constraint];
}

- (void)_setWantsAutolayout
{
    if ([_owningView respondsToSelector:@selector(_setWantsAutolayout)])
        [_owningView performSelector:@selector(_setWantsAutolayout)];
}

- (void)_setWantsAutolayout:(BOOL)wants
{
    [self _setWantsAutolayout];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p - \"%@\", layoutFrame = %@, owningView = %@>", [self class], self, _identifier, NSStringFromCGRect(self.layoutFrame), _owningView];
}

@end
