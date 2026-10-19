#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation GCMotion {
    __weak GCController *_controller;
    GCAcceleration _gravity;
    GCAcceleration _userAcceleration;
    GCAcceleration _acceleration;
    GCQuaternion _attitude;
    GCRotationRate _rotationRate;
    BOOL _hasAttitudeAndRotationRate;
}

- (instancetype)initWithCharonAttitudeAndRotationRate:(BOOL)has
{
    self = [super init];
    if (self) {
        _gravity = (GCAcceleration){0, 0, -1};
        _hasAttitudeAndRotationRate = has;
        if (has)
            _attitude = (GCQuaternion){0, 0, 0, 1};
    }
    return self;
}

- (void)charon_setHasAttitudeAndRotationRate:(BOOL)has
{
    _hasAttitudeAndRotationRate = has;
}

- (instancetype)init
{
    return [self initWithCharonAttitudeAndRotationRate:NO];
}

- (void)charon_setController:(GCController *)controller
{
    _controller = controller;
}

- (GCController *)controller
{
    return _controller;
}

- (BOOL)sensorsRequireManualActivation
{
    return NO;
}

- (BOOL)sensorsActive
{
    return YES;
}

- (void)setSensorsActive:(BOOL)active
{
}

- (BOOL)hasGravityAndUserAcceleration
{
    return NO;
}

- (BOOL)hasAttitudeAndRotationRate
{
    return _hasAttitudeAndRotationRate;
}

- (BOOL)hasAttitude
{
    return _hasAttitudeAndRotationRate;
}

- (BOOL)hasRotationRate
{
    return _hasAttitudeAndRotationRate;
}

- (GCAcceleration)gravity
{
    return _gravity;
}

- (GCAcceleration)userAcceleration
{
    return _userAcceleration;
}

- (GCAcceleration)acceleration
{
    return _acceleration;
}

- (GCQuaternion)attitude
{
    return _attitude;
}

- (GCRotationRate)rotationRate
{
    return _rotationRate;
}

- (void)setGravity:(GCAcceleration)gravity
{
    _gravity = gravity;
}

- (void)setUserAcceleration:(GCAcceleration)userAcceleration
{
    _userAcceleration = userAcceleration;
}

- (void)setAcceleration:(GCAcceleration)acceleration
{
    _acceleration = acceleration;
}

- (void)setAttitude:(GCQuaternion)attitude
{
    _attitude = attitude;
}

- (void)setRotationRate:(GCRotationRate)rotationRate
{
    _rotationRate = rotationRate;
}

- (void)setStateFromMotion:(GCMotion *)motion
{
    _gravity = motion.gravity;
    _userAcceleration = motion.userAcceleration;
    _acceleration = motion.acceleration;
    _attitude = motion.attitude;
    _rotationRate = motion.rotationRate;
    GCMotionValueChangedHandler changed = self.valueChangedHandler;
    if (!changed)
        return;
    dispatch_queue_t queue = _controller.handlerQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        changed(self);
    });
}

@end
