#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@implementation GCController {
    GCPhysicalInputProfile *_profile;
    GCMotion *_motion;
    NSString *_vendorName;
    NSString *_productCategory;
    dispatch_queue_t _handlerQueue;
    GCControllerPlayerIndex _playerIndex;
    BOOL _snapshot;
}

@dynamic current, shouldMonitorBackgroundEvents;

- (instancetype)initWithCharonProfile:(GCPhysicalInputProfile *)profile vendorName:(NSString *)vendorName productCategory:(NSString *)productCategory
{
    self = [super init];
    if (self) {
        _profile = profile;
        _vendorName = [vendorName copy];
        _productCategory = [productCategory copy];
        _handlerQueue = dispatch_get_main_queue();
        _playerIndex = GCControllerPlayerIndex1;
        _snapshot = YES;
        [profile charon_setDevice:self];
        [(id)profile charon_setController:self];
        _motion = [[GCMotion alloc] initWithCharonAttitudeAndRotationRate:[profile isKindOfClass:[GCMicroGamepad class]]];
        [_motion charon_setController:self];
    }
    return self;
}

+ (GCController *)controllerWithExtendedGamepad
{
    return [[self alloc] initWithCharonProfile:[[GCExtendedGamepad alloc] init] vendorName:@"ExtendedGamepad" productCategory:@"MFi"];
}

+ (GCController *)controllerWithMicroGamepad
{
    return [[self alloc] initWithCharonProfile:[[GCMicroGamepad alloc] init] vendorName:@"MicroGamepad" productCategory:@"Siri Remote"];
}

- (GCController *)capture
{
    GCController *copy = [[[self class] alloc] initWithCharonProfile:[_profile capture] vendorName:_vendorName productCategory:_productCategory];
    [copy.motion charon_setHasAttitudeAndRotationRate:YES];
    [copy.motion setStateFromMotion:_motion];
    return copy;
}

+ (NSArray *)controllers
{
    return @[];
}

+ (void)startWirelessControllerDiscoveryWithCompletionHandler:(void (^)(void))completionHandler
{
    void (^kept)(void) = [completionHandler copy];
    if (!kept)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        kept();
    });
}

+ (void)stopWirelessControllerDiscovery
{
}

- (BOOL)isAttachedToDevice
{
    return NO;
}

- (BOOL)isSnapshot
{
    return _snapshot;
}

- (GCControllerPlayerIndex)playerIndex
{
    return _playerIndex;
}

- (void)setPlayerIndex:(GCControllerPlayerIndex)playerIndex
{
    _playerIndex = playerIndex;
}

- (dispatch_queue_t)handlerQueue
{
    return _handlerQueue;
}

- (void)setHandlerQueue:(dispatch_queue_t)handlerQueue
{
    _handlerQueue = handlerQueue;
}

- (NSString *)vendorName
{
    return _vendorName;
}

- (NSString *)productCategory
{
    return _productCategory;
}

- (GCPhysicalInputProfile *)physicalInputProfile
{
    return _profile;
}

- (GCExtendedGamepad *)extendedGamepad
{
    return [_profile isKindOfClass:[GCExtendedGamepad class]] ? (GCExtendedGamepad *)_profile : nil;
}

- (GCGamepad *)gamepad
{
    return [_profile isKindOfClass:[GCExtendedGamepad class]] ? (GCGamepad *)_profile : nil;
}

- (GCMicroGamepad *)microGamepad
{
    return (GCMicroGamepad *)_profile;
}

- (GCMotion *)motion
{
    return _motion;
}

- (GCDeviceBattery *)battery
{
    return nil;
}

- (GCDeviceLight *)light
{
    return nil;
}

- (GCDeviceHaptics *)haptics
{
    return nil;
}

@end
