#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlaySessionConfiguration.h"

@implementation CPSessionConfiguration {
    __weak id<CPSessionConfigurationDelegate> _delegate;
    CPLimitableUserInterface _limitedUserInterfaces;
    CPContentStyle _revenantContentStyle;
}

@dynamic contentStyle;

- (instancetype)initWithDelegate:(id<CPSessionConfigurationDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _limitedUserInterfaces = 0;
        _revenantContentStyle = 0;
    }
    return self;
}

- (CPLimitableUserInterface)limitedUserInterfaces
{
    return _limitedUserInterfaces;
}

- (id<CPSessionConfigurationDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<CPSessionConfigurationDelegate>)delegate
{
    _delegate = delegate;
}

- (CPContentStyle)revenant_contentStyle
{
    return _revenantContentStyle;
}

@end
