#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wprotocol"

NSString *const UILargeContentViewerInteractionEnabledStatusDidChangeNotification = @"UILargeContentViewerInteractionEnabledStatusDidChangeNotification";

static const char charon_shows_key, charon_title_key, charon_image_key, charon_scales_key, charon_insets_key;

@implementation UIView (CharonLargeContentViewer)

- (BOOL)showsLargeContentViewer
{
    return [objc_getAssociatedObject(self, &charon_shows_key) boolValue];
}

- (void)setShowsLargeContentViewer:(BOOL)showsLargeContentViewer
{
    objc_setAssociatedObject(self, &charon_shows_key, @(showsLargeContentViewer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)largeContentTitle
{
    return objc_getAssociatedObject(self, &charon_title_key);
}

- (void)setLargeContentTitle:(NSString *)largeContentTitle
{
    objc_setAssociatedObject(self, &charon_title_key, largeContentTitle, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIImage *)largeContentImage
{
    return objc_getAssociatedObject(self, &charon_image_key);
}

- (void)setLargeContentImage:(UIImage *)largeContentImage
{
    objc_setAssociatedObject(self, &charon_image_key, largeContentImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)scalesLargeContentImage
{
    return [objc_getAssociatedObject(self, &charon_scales_key) boolValue];
}

- (void)setScalesLargeContentImage:(BOOL)scalesLargeContentImage
{
    objc_setAssociatedObject(self, &charon_scales_key, @(scalesLargeContentImage), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)largeContentImageInsets
{
    NSValue *held = objc_getAssociatedObject(self, &charon_insets_key);
    return held ? [held UIEdgeInsetsValue] : UIEdgeInsetsZero;
}

- (void)setLargeContentImageInsets:(UIEdgeInsets)largeContentImageInsets
{
    objc_setAssociatedObject(self, &charon_insets_key, [NSValue valueWithUIEdgeInsets:largeContentImageInsets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UILargeContentViewerInteraction {
@private
    __weak id<UILargeContentViewerInteractionDelegate> _delegate;
    __weak UIView *_view;
    UIGestureRecognizer *_recognizer;
}

+ (BOOL)isEnabled
{
    return NO;
}

- (instancetype)initWithDelegate:(id<UILargeContentViewerInteractionDelegate>)delegate
{
    if ((self = [super init]))
        _delegate = delegate;
    return self;
}

- (instancetype)init
{
    return [self initWithDelegate:nil];
}

- (id<UILargeContentViewerInteractionDelegate>)delegate
{
    return _delegate;
}

- (UIGestureRecognizer *)gestureRecognizerForExclusionRelationship
{
    return _recognizer;
}

- (UIView *)view
{
    return _view;
}

- (void)willMoveToView:(UIView *)view
{
    if (_recognizer) {
        [_view removeGestureRecognizer:_recognizer];
        _recognizer = nil;
    }
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (!view)
        return;
    _recognizer = [[UIGestureRecognizer alloc] initWithTarget:nil action:NULL];
    _recognizer.enabled = NO;
    [view addGestureRecognizer:_recognizer];
    charon_menus_say_once(@"large-content", @"UILargeContentViewerInteraction: iOS 6 has no large content viewer, so the interaction is attached and its delegate is never called; UILargeContentViewerInteraction.enabled is NO");
}

@end
