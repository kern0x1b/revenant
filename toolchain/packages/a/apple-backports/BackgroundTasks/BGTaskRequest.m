#import <BackgroundTasks/BackgroundTasks.h>
#import "CharonBackgroundTasks.h"

@implementation BGTaskRequest {
    NSString *_identifier;
    NSDate *_earliestBeginDate;
}

- (instancetype)initCharonWithIdentifier:(NSString *)identifier
{
    if ((self = [super init]))
        _identifier = [identifier copy];
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSDate *)earliestBeginDate
{
    return _earliestBeginDate;
}

- (void)setEarliestBeginDate:(NSDate *)earliestBeginDate
{
    _earliestBeginDate = [earliestBeginDate copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    BGTaskRequest *copy = [[[self class] allocWithZone:zone] initCharonWithIdentifier:_identifier];
    copy->_earliestBeginDate = [_earliestBeginDate copy];
    return copy;
}

@end

@implementation BGAppRefreshTaskRequest

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    return [super initCharonWithIdentifier:identifier];
}

@end

@implementation BGProcessingTaskRequest {
    BOOL _requiresNetworkConnectivity;
    BOOL _requiresExternalPower;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    return [super initCharonWithIdentifier:identifier];
}

- (BOOL)requiresNetworkConnectivity
{
    return _requiresNetworkConnectivity;
}

- (void)setRequiresNetworkConnectivity:(BOOL)requiresNetworkConnectivity
{
    _requiresNetworkConnectivity = requiresNetworkConnectivity;
}

- (BOOL)requiresExternalPower
{
    return _requiresExternalPower;
}

- (void)setRequiresExternalPower:(BOOL)requiresExternalPower
{
    _requiresExternalPower = requiresExternalPower;
}

- (id)copyWithZone:(NSZone *)zone
{
    BGProcessingTaskRequest *copy = [super copyWithZone:zone];
    copy->_requiresNetworkConnectivity = _requiresNetworkConnectivity;
    copy->_requiresExternalPower = _requiresExternalPower;
    return copy;
}

@end
