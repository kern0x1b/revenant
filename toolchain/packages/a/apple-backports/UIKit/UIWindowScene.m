#import "CharonScenes.h"

@interface CharonScreenCoordinateSpace : NSObject <UICoordinateSpace>
@end

@implementation CharonScreenCoordinateSpace

- (CGRect)bounds
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    return UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) ? CGRectMake(0, 0, bounds.size.height, bounds.size.width) : bounds;
}

- (CGPoint)convertPoint:(CGPoint)point toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return [coordinateSpace convertPoint:point fromCoordinateSpace:self];
}

- (CGPoint)convertPoint:(CGPoint)point fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return coordinateSpace == self ? point : [coordinateSpace convertPoint:point toCoordinateSpace:self];
}

- (CGRect)convertRect:(CGRect)rect toCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return [coordinateSpace convertRect:rect fromCoordinateSpace:self];
}

- (CGRect)convertRect:(CGRect)rect fromCoordinateSpace:(id<UICoordinateSpace>)coordinateSpace
{
    return coordinateSpace == self ? rect : [coordinateSpace convertRect:rect toCoordinateSpace:self];
}

@end

@implementation UIStatusBarManager

- (instancetype)initCharon
{
    return [super init];
}

- (UIStatusBarStyle)statusBarStyle
{
    return [UIApplication sharedApplication].statusBarStyle;
}

- (BOOL)isStatusBarHidden
{
    return [UIApplication sharedApplication].statusBarHidden;
}

- (CGRect)statusBarFrame
{
    return [UIApplication sharedApplication].statusBarHidden ? CGRectZero : [UIApplication sharedApplication].statusBarFrame;
}

@end

@implementation UIWindowScene {
    UIStatusBarManager *_statusBarManager;
    CharonScreenCoordinateSpace *_coordinateSpace;
    __weak id<UIActivityItemsConfigurationProviding> _activityItemsConfigurationSource;
}

@dynamic effectiveGeometry, keyWindow, windowingBehaviors;

- (id<UIActivityItemsConfigurationProviding>)activityItemsConfigurationSource
{
    return _activityItemsConfigurationSource;
}

- (void)setActivityItemsConfigurationSource:(id<UIActivityItemsConfigurationProviding>)source
{
    _activityItemsConfigurationSource = source;
}

- (instancetype)initWithSession:(UISceneSession *)session connectionOptions:(UISceneConnectionOptions *)connectionOptions
{
    if ((self = [super initWithSession:session connectionOptions:connectionOptions])) {
        _statusBarManager = [[UIStatusBarManager alloc] initCharon];
        _coordinateSpace = [[CharonScreenCoordinateSpace alloc] init];
    }
    return self;
}

- (UIScreen *)screen
{
    return [UIScreen mainScreen];
}

- (UIInterfaceOrientation)interfaceOrientation
{
    return [UIApplication sharedApplication].statusBarOrientation;
}

- (id<UICoordinateSpace>)coordinateSpace
{
    return _coordinateSpace;
}

- (UITraitCollection *)traitCollection
{
    return [UIScreen mainScreen].traitCollection;
}

- (UISceneSizeRestrictions *)sizeRestrictions
{
    return nil;
}

- (NSArray<UIWindow *> *)windows
{
    return [UIApplication sharedApplication].windows;
}

- (BOOL)isFullScreen
{
    return YES;
}

- (UIStatusBarManager *)statusBarManager
{
    return _statusBarManager;
}

@end
