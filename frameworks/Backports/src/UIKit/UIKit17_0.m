#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UISymbolEffectCompletionContext (RevenantInit)
- (instancetype)initRevenantWithSender:(id)sender effect:(NSSymbolEffect *)effect finished:(BOOL)finished;
@end

@implementation UISymbolEffectCompletionContext {
    __weak id _sender;
    NSSymbolEffect *_effect;
    BOOL _finished;
}

- (instancetype)initRevenantWithSender:(id)sender effect:(NSSymbolEffect *)effect finished:(BOOL)finished
{
    if ((self = [super init])) {
        _sender = sender;
        _effect = effect;
        _finished = finished;
    }
    return self;
}

- (BOOL)isFinished
{
    return _finished;
}

- (BOOL)finished
{
    return _finished;
}

- (id)sender
{
    return _sender;
}

- (NSSymbolEffect *)effect
{
    return _effect;
}

- (NSSymbolContentTransition *)contentTransition
{
    return nil;
}

@end

@implementation UISceneSessionActivationRequest {
    UISceneSessionRole _role;
    UISceneSession *_session;
    NSUserActivity *_userActivity;
}

+ (instancetype)request
{
    return [self requestWithRole:UIWindowSceneSessionRoleApplication];
}

+ (instancetype)requestWithRole:(UISceneSessionRole)role
{
    UISceneSessionActivationRequest *request = [[self alloc] init];
    request->_role = [role copy];
    return request;
}

+ (instancetype)requestWithSession:(UISceneSession *)session
{
    UISceneSessionActivationRequest *request = [[self alloc] init];
    request->_session = session;
    request->_role = [session.role copy];
    return request;
}

- (UISceneSessionRole)role
{
    return _role;
}

- (UISceneSession *)session
{
    return _session;
}

- (NSUserActivity *)userActivity
{
    return _userActivity;
}

- (void)setUserActivity:(NSUserActivity *)userActivity
{
    _userActivity = userActivity;
}

- (id)copyWithZone:(NSZone *)zone
{
    UISceneSessionActivationRequest *copy = [[[self class] allocWithZone:zone] init];
    copy->_role = _role;
    copy->_session = _session;
    copy->_userActivity = _userActivity;
    return copy;
}

@end

@implementation UITouch (RevenantRoll17)

- (CGFloat)rollAngle
{
    return 0;
}

@end

@implementation UIHoverGestureRecognizer (RevenantRoll17)

- (CGFloat)rollAngle
{
    return 0;
}

@end

@implementation UITextSelectionRect (RevenantTransform17)

- (CGAffineTransform)transform
{
    return CGAffineTransformIdentity;
}

@end

static const char RevenantTextBorderKey;

@implementation UITextView (RevenantBorder17)

- (UITextBorderStyle)borderStyle
{
    return (UITextBorderStyle)[objc_getAssociatedObject(self, &RevenantTextBorderKey) integerValue];
}

- (void)setBorderStyle:(UITextBorderStyle)borderStyle
{
    objc_setAssociatedObject(self, &RevenantTextBorderKey, @(borderStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.layer.borderWidth = borderStyle == UITextBorderStyleNone ? 0 : 1;
    self.layer.borderColor = [UIColor colorWithWhite:0.6f alpha:1].CGColor;
    self.layer.cornerRadius = borderStyle == UITextBorderStyleRoundedRect ? 6 : 0;
}

@end
