#import "CharonSCN.h"

@implementation SCNCamera

- (instancetype)init
{
    if ((self = [super init])) {
        _fieldOfView = 60;
        _zNear = 1;
        _zFar = 100;
        _orthographicScale = 1;
        _projectionTransform = SCNMatrix4Identity;
    }
    return self;
}

+ (instancetype)camera
{
    return [[self alloc] init];
}

@synthesize name = _name;
@synthesize fieldOfView = _fieldOfView;
@synthesize zNear = _zNear;
@synthesize zFar = _zFar;
@synthesize usesOrthographicProjection = _usesOrthographicProjection;
@synthesize orthographicScale = _orthographicScale;
@synthesize projectionTransform = _projectionTransform;
@synthesize automaticallyAdjustsZRange = _automaticallyAdjustsZRange;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        BOOL fovFound = NO;
        if ([coder containsValueForKey:@"yFov"]) {
            _fieldOfView = [coder decodeDoubleForKey:@"yFov"];
            fovFound = YES;
        } else if ([coder containsValueForKey:@"fov"]) {
            _fieldOfView = [coder decodeDoubleForKey:@"fov"];
            fovFound = YES;
        }
        [CharonSCNCoding markFound:fovFound forKey:@"fieldOfView" onObject:self];
        if ([coder containsValueForKey:@"zNear"]) {
            _zNear = [coder decodeDoubleForKey:@"zNear"];
        }
        if ([coder containsValueForKey:@"zFar"]) {
            _zFar = [coder decodeDoubleForKey:@"zFar"];
        }
        _usesOrthographicProjection = [CharonSCNCoding decodeBool:coder forKey:@"usesOrthographicProjection" default:NO];
        if ([coder containsValueForKey:@"orthographicScale"]) {
            _orthographicScale = [coder decodeDoubleForKey:@"orthographicScale"];
        }
        _automaticallyAdjustsZRange = [CharonSCNCoding decodeBool:coder forKey:@"automaticallyAdjustsZRange" default:NO];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeDouble:_fieldOfView forKey:@"yFov"];
    [coder encodeDouble:_zNear forKey:@"zNear"];
    [coder encodeDouble:_zFar forKey:@"zFar"];
    [coder encodeBool:_usesOrthographicProjection forKey:@"usesOrthographicProjection"];
    [coder encodeDouble:_orthographicScale forKey:@"orthographicScale"];
    [coder encodeBool:_automaticallyAdjustsZRange forKey:@"automaticallyAdjustsZRange"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNCamera *copy = [[SCNCamera allocWithZone:zone] init];
    copy->_name = [_name copy];
    copy->_fieldOfView = _fieldOfView;
    copy->_zNear = _zNear;
    copy->_zFar = _zFar;
    copy->_usesOrthographicProjection = _usesOrthographicProjection;
    copy->_orthographicScale = _orthographicScale;
    copy->_projectionTransform = _projectionTransform;
    copy->_automaticallyAdjustsZRange = _automaticallyAdjustsZRange;
    return copy;
}

@end
