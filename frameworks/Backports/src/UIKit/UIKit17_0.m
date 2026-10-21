#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@interface UIWindowScenePlacement (RevenantInit)
- (instancetype)initRevenantPlacement;
@end

@interface UITextItem (RevenantInit)
- (instancetype)initRevenantWithContentType:(UITextItemContentType)contentType range:(NSRange)range link:(NSURL *)link textAttachment:(NSTextAttachment *)textAttachment tagIdentifier:(NSString *)tagIdentifier;
@end

@interface UIPencilHoverPose (RevenantInit)
- (instancetype)initRevenantWithLocation:(CGPoint)location zOffset:(CGFloat)zOffset azimuthAngle:(CGFloat)azimuthAngle altitudeAngle:(CGFloat)altitudeAngle rollAngle:(CGFloat)rollAngle;
@end

@interface UIPencilInteractionTap (RevenantInit)
- (instancetype)initRevenantWithTimestamp:(NSTimeInterval)timestamp hoverPose:(UIPencilHoverPose *)hoverPose;
@end

@interface UIPencilInteractionSqueeze (RevenantInit)
- (instancetype)initRevenantWithTimestamp:(NSTimeInterval)timestamp phase:(UIPencilInteractionPhase)phase hoverPose:(UIPencilHoverPose *)hoverPose;
@end

@interface UISymbolEffectCompletionContext (RevenantInit)
- (instancetype)initRevenantWithSender:(id)sender finished:(BOOL)finished;
@end

@implementation UITextItem {
    UITextItemContentType _contentType;
    NSRange _range;
    NSURL *_link;
    NSTextAttachment *_textAttachment;
    NSString *_tagIdentifier;
}

- (instancetype)initRevenantWithContentType:(UITextItemContentType)contentType range:(NSRange)range link:(NSURL *)link textAttachment:(NSTextAttachment *)textAttachment tagIdentifier:(NSString *)tagIdentifier
{
    if ((self = [super init])) {
        _contentType = contentType;
        _range = range;
        _link = link;
        _textAttachment = textAttachment;
        _tagIdentifier = [tagIdentifier copy];
    }
    return self;
}

- (UITextItemContentType)contentType
{
    return _contentType;
}

- (NSRange)range
{
    return _range;
}

- (NSURL *)link
{
    return _contentType == UITextItemContentTypeLink ? _link : nil;
}

- (NSTextAttachment *)textAttachment
{
    return _contentType == UITextItemContentTypeTextAttachment ? _textAttachment : nil;
}

- (NSString *)tagIdentifier
{
    return _contentType == UITextItemContentTypeTag ? _tagIdentifier : nil;
}

@end

@implementation UITextItemMenuPreview {
    UIView *_view;
}

+ (instancetype)defaultPreview
{
    return [[self alloc] init];
}

- (instancetype)initWithView:(UIView *)view
{
    if ((self = [super init]))
        _view = view;
    return self;
}

@end

@implementation UITextItemMenuConfiguration {
    UITextItemMenuPreview *_preview;
    UIMenu *_menu;
}

+ (instancetype)configurationWithMenu:(UIMenu *)menu
{
    return [self configurationWithPreview:[UITextItemMenuPreview defaultPreview] menu:menu];
}

+ (instancetype)configurationWithPreview:(UITextItemMenuPreview *)preview menu:(UIMenu *)menu
{
    UITextItemMenuConfiguration *configuration = [[self alloc] init];
    configuration->_preview = preview;
    configuration->_menu = menu;
    return configuration;
}

@end

@implementation UIPencilHoverPose {
    CGPoint _location;
    CGFloat _zOffset;
    CGFloat _azimuthAngle;
    CGFloat _altitudeAngle;
    CGFloat _rollAngle;
}

- (instancetype)initRevenantWithLocation:(CGPoint)location zOffset:(CGFloat)zOffset azimuthAngle:(CGFloat)azimuthAngle altitudeAngle:(CGFloat)altitudeAngle rollAngle:(CGFloat)rollAngle
{
    if ((self = [super init])) {
        _location = location;
        _zOffset = zOffset;
        _azimuthAngle = azimuthAngle;
        _altitudeAngle = altitudeAngle;
        _rollAngle = rollAngle;
    }
    return self;
}

- (CGPoint)location
{
    return _location;
}

- (CGFloat)zOffset
{
    return _zOffset;
}

- (CGFloat)azimuthAngle
{
    return _azimuthAngle;
}

- (CGVector)azimuthUnitVector
{
    return CGVectorMake((CGFloat)cos(_azimuthAngle), (CGFloat)sin(_azimuthAngle));
}

- (CGFloat)altitudeAngle
{
    return _altitudeAngle;
}

- (CGFloat)rollAngle
{
    return _rollAngle;
}

@end

@implementation UIPencilInteractionTap {
    NSTimeInterval _timestamp;
    UIPencilHoverPose *_hoverPose;
}

- (instancetype)initRevenantWithTimestamp:(NSTimeInterval)timestamp hoverPose:(UIPencilHoverPose *)hoverPose
{
    if ((self = [super init])) {
        _timestamp = timestamp;
        _hoverPose = hoverPose;
    }
    return self;
}

- (NSTimeInterval)timestamp
{
    return _timestamp;
}

- (UIPencilHoverPose *)hoverPose
{
    return _hoverPose;
}

@end

@implementation UIPencilInteractionSqueeze {
    NSTimeInterval _timestamp;
    UIPencilInteractionPhase _phase;
    UIPencilHoverPose *_hoverPose;
}

- (instancetype)initRevenantWithTimestamp:(NSTimeInterval)timestamp phase:(UIPencilInteractionPhase)phase hoverPose:(UIPencilHoverPose *)hoverPose
{
    if ((self = [super init])) {
        _timestamp = timestamp;
        _phase = phase;
        _hoverPose = hoverPose;
    }
    return self;
}

- (NSTimeInterval)timestamp
{
    return _timestamp;
}

- (UIPencilInteractionPhase)phase
{
    return _phase;
}

- (UIPencilHoverPose *)hoverPose
{
    return _hoverPose;
}

@end

@implementation UISymbolEffectCompletionContext {
    __weak id _sender;
    BOOL _finished;
}

- (instancetype)initRevenantWithSender:(id)sender finished:(BOOL)finished
{
    if ((self = [super init])) {
        _sender = sender;
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
    return nil;
}

- (NSSymbolContentTransition *)contentTransition
{
    return nil;
}

@end

@implementation UIMenuDisplayPreferences {
    NSInteger _maximumNumberOfTitleLines;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        _maximumNumberOfTitleLines = [coder decodeIntegerForKey:@"maximumNumberOfTitleLines"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_maximumNumberOfTitleLines forKey:@"maximumNumberOfTitleLines"];
}

- (NSInteger)maximumNumberOfTitleLines
{
    return _maximumNumberOfTitleLines;
}

- (void)setMaximumNumberOfTitleLines:(NSInteger)maximumNumberOfTitleLines
{
    _maximumNumberOfTitleLines = maximumNumberOfTitleLines;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIMenuDisplayPreferences *copy = [[[self class] allocWithZone:zone] init];
    copy->_maximumNumberOfTitleLines = _maximumNumberOfTitleLines;
    return copy;
}

@end

@implementation UIWindowScenePlacement

- (instancetype)initRevenantPlacement
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation UIWindowSceneStandardPlacement

+ (instancetype)standardPlacement
{
    return [[self alloc] initRevenantPlacement];
}

@end

@implementation UIWindowSceneProminentPlacement

+ (instancetype)prominentPlacement
{
    return [[self alloc] initRevenantPlacement];
}

@end

@implementation UISceneSessionActivationRequest {
    UISceneSessionRole _role;
    UISceneSession *_session;
    NSUserActivity *_userActivity;
    UISceneActivationRequestOptions *_options;
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

- (UISceneActivationRequestOptions *)options
{
    return _options;
}

- (void)setOptions:(UISceneActivationRequestOptions *)options
{
    _options = [options copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    UISceneSessionActivationRequest *copy = [[[self class] allocWithZone:zone] init];
    copy->_role = _role;
    copy->_session = _session;
    copy->_userActivity = _userActivity;
    copy->_options = [_options copy];
    return copy;
}

@end

@implementation UIApplication (RevenantSceneActivation17)

- (void)activateSceneSessionForRequest:(UISceneSessionActivationRequest *)request errorHandler:(void (^)(NSError *))errorHandler
{
    if (request.session && [self.openSessions containsObject:request.session])
        return;
    if (!errorHandler)
        return;
    NSError *error = [NSError errorWithDomain:UISceneErrorDomain code:UISceneErrorCodeMultipleScenesNotSupported userInfo:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        errorHandler(error);
    });
}

@end

@implementation UIPencilInteraction (RevenantInit17)

- (instancetype)initWithDelegate:(id<UIPencilInteractionDelegate>)delegate
{
    if ((self = [self init]))
        self.delegate = delegate;
    return self;
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

static const char RevenantPreferredVibrancyKey;
static const char RevenantTextBorderKey;

@implementation UILabel (RevenantVibrancy17)

- (UIVibrancyEffectStyle)preferredVibrancy
{
    return (UIVibrancyEffectStyle)[objc_getAssociatedObject(self, &RevenantPreferredVibrancyKey) integerValue];
}

- (void)setPreferredVibrancy:(UIVibrancyEffectStyle)preferredVibrancy
{
    objc_setAssociatedObject(self, &RevenantPreferredVibrancyKey, @(preferredVibrancy), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

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
