#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlaySessionConfiguration.h"

@implementation CPSessionConfiguration {
    __weak id<CPSessionConfigurationDelegate> _delegate;
    CPLimitableUserInterface _limitedUserInterfaces;
    CPContentStyle _charonContentStyle;
}

@dynamic contentStyle;

- (instancetype)initWithDelegate:(id<CPSessionConfigurationDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _limitedUserInterfaces = 0;
        _charonContentStyle = 0;
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

- (CPContentStyle)charon_contentStyle
{
    return _charonContentStyle;
}

@end
