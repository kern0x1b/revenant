#import "CharonSCN.h"

@implementation SCNParticlePropertyController

- (instancetype)init
{
    if ((self = [super init])) {
        _inputMode = SCNParticleInputModeOverLife;
        _inputScale = 1;
        _inputBias = 0;
    }
    return self;
}

+ (instancetype)controllerWithAnimation:(CAAnimation *)animation
{
    SCNParticlePropertyController *controller = [[self alloc] init];
    controller->_animation = animation;
    return controller;
}

@synthesize animation = _animation;
@synthesize inputMode = _inputMode;
@synthesize inputScale = _inputScale;
@synthesize inputBias = _inputBias;
@synthesize inputOrigin = _inputOrigin;
@synthesize inputProperty = _inputProperty;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        id archivedAnimation = [coder decodeObjectOfClasses:[NSSet setWithObjects:[CAAnimation class], [NSDictionary class], nil] forKey:@"animation"];
        _animation = [archivedAnimation isKindOfClass:[CAAnimation class]] ? archivedAnimation : nil;
        if ([coder containsValueForKey:@"inputMode"]) {
            _inputMode = [coder decodeIntegerForKey:@"inputMode"];
        }
        if ([coder containsValueForKey:@"inputScale"]) {
            _inputScale = [coder decodeDoubleForKey:@"inputScale"];
        }
        _inputBias = [coder decodeDoubleForKey:@"inputBias"];
        _inputProperty = [coder decodeObjectOfClass:[NSString class] forKey:@"inputProperty"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_animation forKey:@"animation"];
    [coder encodeInteger:_inputMode forKey:@"inputMode"];
    [coder encodeDouble:_inputScale forKey:@"inputScale"];
    [coder encodeDouble:_inputBias forKey:@"inputBias"];
    [coder encodeObject:_inputProperty forKey:@"inputProperty"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNParticlePropertyController *copy = [[SCNParticlePropertyController allocWithZone:zone] init];
    copy->_animation = _animation;
    copy->_inputMode = _inputMode;
    copy->_inputScale = _inputScale;
    copy->_inputBias = _inputBias;
    copy->_inputOrigin = _inputOrigin;
    copy->_inputProperty = _inputProperty;
    return copy;
}

@end
