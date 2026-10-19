#import "CharonSCN.h"

@implementation SCNMaterialProperty
{
    BOOL _colorNotRead;
    BOOL _holdsDefault;
    CharonSCNAnimations *_animations;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _intensity = 1;
        _minificationFilter = SCNFilterModeLinear;
        _magnificationFilter = SCNFilterModeLinear;
        _mipFilter = SCNFilterModeNone;
        _contentsTransform = SCNMatrix4Identity;
        _wrapS = SCNWrapModeClamp;
        _wrapT = SCNWrapModeClamp;
        _mappingChannel = 0;
    }
    return self;
}

+ (instancetype)materialPropertyWithContents:(id)contents
{
    SCNMaterialProperty *property = [[self alloc] init];
    property->_contents = contents;
    return property;
}

+ (instancetype)charonDefaultWithContents:(id)contents
{
    SCNMaterialProperty *property = [self materialPropertyWithContents:contents];
    property->_holdsDefault = YES;
    // a new material's slots, unlike a property made alone, sample the nearest mipmap level: macOS SceneKit answers 1
    // for every slot and 0 alone (scenekit-defaults-expectations.h), and a 256-texel gradient drawn 16 texels to the
    // pixel shows 248 at its clamped edge, the mean of the 16 edge texels, where level 0 gives 255 (facts/SceneKit/SCNView.md)
    property->_mipFilter = SCNFilterModeNearest;
    return property;
}

- (BOOL)charonHoldsDefault
{
    return _holdsDefault;
}

- (void)charonKeepDefaultOf:(SCNMaterialProperty *)fallback
{
    _contents = fallback->_contents;
    _holdsDefault = fallback->_holdsDefault;
}

- (void)setContents:(id)contents
{
    _contents = contents;
    _holdsDefault = NO;
}

@synthesize contents = _contents;
@synthesize intensity = _intensity;
@synthesize minificationFilter = _minificationFilter;
@synthesize magnificationFilter = _magnificationFilter;
@synthesize mipFilter = _mipFilter;
@synthesize contentsTransform = _contentsTransform;
@synthesize wrapS = _wrapS;
@synthesize wrapT = _wrapT;
@synthesize mappingChannel = _mappingChannel;

- (BOOL)charonColorNotRead
{
    return _colorNotRead;
}

#pragma mark SCNAnimatable

- (CharonSCNAnimations *)charonAnimations
{
    return _animations;
}

- (void)addAnimation:(id<SCNAnimation>)animation forKey:(NSString *)key
{
    if (_animations == nil) {
        _animations = [CharonSCNAnimations new];
    }
    [_animations addAnimation:animation forKey:key];
}

- (void)removeAnimationForKey:(NSString *)key
{
    [_animations removeAnimationForKey:key];
}

- (void)removeAllAnimations
{
    [_animations removeAllAnimations];
}

- (NSArray<NSString *> *)animationKeys
{
    return _animations ? [_animations animationKeys] : @[];
}

- (CAAnimation *)animationForKey:(NSString *)key
{
    return [_animations animationForKey:key];
}

- (void)pauseAnimationForKey:(NSString *)key
{
    [_animations pauseAnimationForKey:key];
}

- (void)resumeAnimationForKey:(NSString *)key
{
    [_animations resumeAnimationForKey:key];
}

- (BOOL)isAnimationForKeyPaused:(NSString *)key
{
    return [_animations isAnimationForKeyPaused:key];
}

// contentsTransform is the key path measured against macOS SceneKit; others are said and left
- (NSValue *)charonModelValueForKeyPath:(NSString *)keyPath
{
    if ([keyPath isEqualToString:@"contentsTransform"]) return [NSValue valueWithSCNMatrix4:_contentsTransform];
    return nil;
}

- (SCNMatrix4)charonPresentedContentsTransform
{
    NSValue *presented = [_animations presented][@"contentsTransform"];
    return presented ? [presented SCNMatrix4Value] : _contentsTransform;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        NSString *image = [CharonSCNCoding decodeFileReferenceName:coder forKey:@"image"];
        if (image) {
            _contents = image;
        } else if ([coder containsValueForKey:@"color"]) {
            _contents = [CharonSCNCoding decodeColor:coder forKey:@"color"];
            _colorNotRead = _contents == nil;
        } else if ([coder containsValueForKey:@"float"]) {
            _contents = [NSNumber numberWithFloat:[coder decodeFloatForKey:@"float"]];
        }
        if ([coder containsValueForKey:@"intensity"]) {
            _intensity = [coder decodeDoubleForKey:@"intensity"];
        }
        if ([coder containsValueForKey:@"minificationFilter"]) {
            _minificationFilter = [coder decodeIntegerForKey:@"minificationFilter"];
        }
        if ([coder containsValueForKey:@"magnificationFilter"]) {
            _magnificationFilter = [coder decodeIntegerForKey:@"magnificationFilter"];
        }
        if ([coder containsValueForKey:@"mipFilter"]) {
            _mipFilter = [coder decodeIntegerForKey:@"mipFilter"];
        }
        if ([coder containsValueForKey:@"wrapS"]) {
            _wrapS = [coder decodeIntegerForKey:@"wrapS"];
        }
        if ([coder containsValueForKey:@"wrapT"]) {
            _wrapT = [coder decodeIntegerForKey:@"wrapT"];
        }
        _mappingChannel = [coder decodeIntegerForKey:@"mappingChannel"];
        if ([coder containsValueForKey:@"contentsTransform"]) {
            _contentsTransform = [CharonSCNCoding decodeMatrix4:coder forKey:@"contentsTransform"];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_intensity forKey:@"intensity"];
    [coder encodeInteger:_minificationFilter forKey:@"minificationFilter"];
    [coder encodeInteger:_magnificationFilter forKey:@"magnificationFilter"];
    [coder encodeInteger:_mipFilter forKey:@"mipFilter"];
    [coder encodeInteger:_wrapS forKey:@"wrapS"];
    [coder encodeInteger:_wrapT forKey:@"wrapT"];
    [coder encodeInteger:_mappingChannel forKey:@"mappingChannel"];
    [CharonSCNCoding encodeMatrix4:_contentsTransform coder:coder forKey:@"contentsTransform"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNMaterialProperty *copy = [[SCNMaterialProperty allocWithZone:zone] init];
    copy->_contents = _contents;
    copy->_intensity = _intensity;
    copy->_minificationFilter = _minificationFilter;
    copy->_magnificationFilter = _magnificationFilter;
    copy->_mipFilter = _mipFilter;
    copy->_contentsTransform = _contentsTransform;
    copy->_wrapS = _wrapS;
    copy->_wrapT = _wrapT;
    copy->_mappingChannel = _mappingChannel;
    copy->_holdsDefault = _holdsDefault;
    copy->_animations = [_animations charonCopy];
    return copy;
}

@end
