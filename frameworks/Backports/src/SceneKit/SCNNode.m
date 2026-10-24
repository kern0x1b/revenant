#import "RevenantSCN.h"
#import "RevenantSCNMath.h"

@implementation SCNNode
{
    NSMutableArray<SCNNode *> *_childNodes;
    NSMutableArray<SCNParticleSystem *> *_particleSystems;
    __weak SCNNode *_parentNode;
    SCNVector3 _boundingBoxMin;
    SCNVector3 _boundingBoxMax;
    BOOL _hasExplicitBoundingBox;
    SCNQuaternion _orientation;
    SCNVector3 _eulerAngles;
    BOOL _hasEulerAngles;
    SCNMatrix4 _matrix;
    BOOL _hasMatrix;
    SCNNode *_presentation;
    BOOL _isPresentation;
    RevenantSCNAnimations *_animations;
    NSMutableArray<RevenantSCNActionRun *> *_actionRuns;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _childNodes = [NSMutableArray array];
        _particleSystems = [NSMutableArray array];
        _position = SCNVector3Make(0, 0, 0);
        _orientation = SCNVector4Make(0, 0, 0, 1);
        _scale = SCNVector3Make(1, 1, 1);
        _opacity = 1;
        _categoryBitMask = 1;
        _castsShadow = YES;
    }
    return self;
}

+ (instancetype)node
{
    return [[self alloc] init];
}

@synthesize name = _name;
@synthesize light = _light;
@synthesize camera = _camera;
@synthesize geometry = _geometry;
@synthesize position = _position;
@synthesize scale = _scale;
@synthesize hidden = _hidden;
@synthesize opacity = _opacity;
@synthesize renderingOrder = _renderingOrder;
@synthesize castsShadow = _castsShadow;
@synthesize categoryBitMask = _categoryBitMask;
@synthesize movabilityHint = _movabilityHint;
@synthesize physicsField = _physicsField;

- (void)setPosition:(SCNVector3)position
{
    _position = position;
    _hasMatrix = NO;
}

- (void)setScale:(SCNVector3)scale
{
    _scale = scale;
    _hasMatrix = NO;
}

- (SCNQuaternion)orientation
{
    return _orientation;
}

- (void)setOrientation:(SCNQuaternion)orientation
{
    _orientation = orientation;
    _hasEulerAngles = NO;
    _hasMatrix = NO;
}

- (SCNVector4)rotation
{
    return RevenantSCNAxisAngleFromQuaternion(_orientation);
}

- (void)setRotation:(SCNVector4)rotation
{
    _orientation = RevenantSCNQuaternionFromAxisAngle(rotation);
    _hasEulerAngles = NO;
    _hasMatrix = NO;
}

- (SCNVector3)eulerAngles
{
    return _hasEulerAngles ? _eulerAngles : RevenantSCNEulerFromQuaternion(_orientation);
}

- (void)setEulerAngles:(SCNVector3)eulerAngles
{
    _orientation = RevenantSCNQuaternionFromEuler(eulerAngles);
    _eulerAngles = eulerAngles;
    _hasEulerAngles = YES;
    _hasMatrix = NO;
}

- (SCNMatrix4)transform
{
    return _hasMatrix ? _matrix : RevenantSCNMatrixCompose(_position, _orientation, _scale);
}

- (void)setTransform:(SCNMatrix4)transform
{
    RevenantSCNMatrixDecompose(transform, &_position, &_orientation, &_scale);
    _hasEulerAngles = NO;
    _matrix = transform;
    _hasMatrix = YES;
}

- (SCNMatrix4)worldTransform
{
    SCNMatrix4 local = self.transform;
    SCNNode *parent = _parentNode;
    return parent ? RevenantSCNMatrixMultiply(local, parent.worldTransform) : local;
}

#pragma mark SCNAnimatable

- (RevenantSCNAnimations *)revenantAnimations
{
    return _animations;
}

- (void)addAnimation:(id<SCNAnimation>)animation forKey:(NSString *)key
{
    if (_animations == nil) {
        _animations = [RevenantSCNAnimations new];
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

- (NSValue *)revenantModelValueForKeyPath:(NSString *)keyPath
{
    if ([keyPath isEqualToString:@"eulerAngles"]) return [NSValue valueWithSCNVector3:self.eulerAngles];
    if ([keyPath isEqualToString:@"scale"]) return [NSValue valueWithSCNVector3:_scale];
    if ([keyPath isEqualToString:@"position"]) return [NSValue valueWithSCNVector3:_position];
    if ([keyPath isEqualToString:@"opacity"]) return @(_opacity);
    return nil;
}

- (SCNMatrix4)revenantPresentedTransform
{
    NSDictionary<NSString *, NSValue *> *presented = [_animations presented];
    if (presented.count == 0) {
        return self.transform;
    }
    NSValue *position = presented[@"position"], *scale = presented[@"scale"], *euler = presented[@"eulerAngles"];
    SCNQuaternion orientation = euler ? RevenantSCNQuaternionFromEuler([euler SCNVector3Value]) : _orientation;
    return RevenantSCNMatrixCompose(position ? [position SCNVector3Value] : _position, orientation, scale ? [scale SCNVector3Value] : _scale);
}

- (CGFloat)revenantPresentedOpacity
{
    NSNumber *opacity = (NSNumber *)[_animations presented][@"opacity"];
    return opacity ? [opacity doubleValue] : _opacity;
}

- (SCNMatrix4)revenantPresentedWorldTransform
{
    SCNMatrix4 local = [self revenantPresentedTransform];
    SCNNode *parent = _parentNode;
    return parent ? RevenantSCNMatrixMultiply(local, [parent revenantPresentedWorldTransform]) : local;
}

- (SCNNode *)presentationNode
{
    if (_isPresentation) {
        return self;
    }
    if (_presentation == nil) {
        _presentation = [[SCNNode alloc] init];
        _presentation->_isPresentation = YES;
    }
    SCNNode *presentation = _presentation;
    presentation->_name = _name;
    presentation->_light = _light;
    presentation->_camera = _camera;
    presentation->_geometry = _geometry;
    presentation->_hidden = _hidden;
    presentation->_renderingOrder = _renderingOrder;
    presentation->_categoryBitMask = _categoryBitMask;
    presentation->_castsShadow = _castsShadow;
    presentation->_position = _position;
    presentation->_scale = _scale;
    presentation->_orientation = _orientation;
    presentation->_eulerAngles = _eulerAngles;
    presentation->_hasEulerAngles = _hasEulerAngles;
    presentation->_matrix = _matrix;
    presentation->_hasMatrix = _hasMatrix;
    presentation->_opacity = _opacity;
    NSDictionary<NSString *, NSValue *> *presented = [_animations presented];
    if (presented[@"position"]) presentation.position = [presented[@"position"] SCNVector3Value];
    if (presented[@"scale"]) presentation.scale = [presented[@"scale"] SCNVector3Value];
    if (presented[@"eulerAngles"]) presentation.eulerAngles = [presented[@"eulerAngles"] SCNVector3Value];
    if (presented[@"opacity"]) presentation->_opacity = [(NSNumber *)presented[@"opacity"] doubleValue];
    NSMutableArray<SCNNode *> *children = [NSMutableArray arrayWithCapacity:_childNodes.count];
    for (SCNNode *child in _childNodes) {
        [children addObject:child.presentationNode];
    }
    for (SCNNode *gone in presentation->_childNodes) {
        if (![children containsObject:gone]) {
            gone->_parentNode = nil;
        }
    }
    for (SCNNode *child in children) {
        if (child->_parentNode != nil && child->_parentNode != presentation) {
            [child->_parentNode->_childNodes removeObject:child];
        }
        child->_parentNode = presentation;
    }
    presentation->_childNodes = children;
    return presentation;
}

- (instancetype)clone
{
    SCNNode *clone = [self copy];
    for (SCNNode *child in _childNodes) {
        [clone addChildNode:[child clone]];
    }
    return clone;
}

- (NSArray<SCNNode *> *)childNodes
{
    return [_childNodes copy];
}

- (void)addChildNode:(SCNNode *)child
{
    [child removeFromParentNode];
    [_childNodes addObject:child];
    child->_parentNode = self;
}

- (SCNNode *)parentNode
{
    return _parentNode;
}

- (void)removeFromParentNode
{
    if (_parentNode == nil) {
        return;
    }
    [_parentNode->_childNodes removeObject:self];
    _parentNode = nil;
}

- (SCNNode *)childNodeWithName:(NSString *)name recursively:(BOOL)recursively
{
    for (SCNNode *child in _childNodes) {
        if ([child.name isEqualToString:name]) {
            return child;
        }
        if (recursively) {
            SCNNode *found = [child childNodeWithName:name recursively:YES];
            if (found) {
                return found;
            }
        }
    }
    return nil;
}

#pragma mark - SCNBoundingVolume

- (BOOL)getBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max
{
    if (!_hasExplicitBoundingBox) {
        return NO;
    }
    if (min) {
        *min = _boundingBoxMin;
    }
    if (max) {
        *max = _boundingBoxMax;
    }
    return YES;
}

- (void)setBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max
{
    if (min == NULL || max == NULL) {
        _hasExplicitBoundingBox = NO;
        return;
    }
    _boundingBoxMin = *min;
    _boundingBoxMax = *max;
    _hasExplicitBoundingBox = YES;
}

- (BOOL)getBoundingSphereCenter:(SCNVector3 *)center radius:(CGFloat *)radius
{
    if (!_hasExplicitBoundingBox) {
        return NO;
    }
    SCNVector3 mid = SCNVector3Make((_boundingBoxMin.x + _boundingBoxMax.x) / 2,
                                     (_boundingBoxMin.y + _boundingBoxMax.y) / 2,
                                     (_boundingBoxMin.z + _boundingBoxMax.z) / 2);
    float dx = _boundingBoxMax.x - mid.x, dy = _boundingBoxMax.y - mid.y, dz = _boundingBoxMax.z - mid.z;
    if (center) {
        *center = mid;
    }
    if (radius) {
        *radius = sqrt(dx * dx + dy * dy + dz * dz);
    }
    return YES;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _light = [coder decodeObjectOfClass:[SCNLight class] forKey:@"light"];
        _camera = [coder decodeObjectOfClass:[SCNCamera class] forKey:@"camera"];
        _geometry = [coder decodeObjectOfClass:[SCNGeometry class] forKey:@"geometry"];
        _physicsField = [coder decodeObjectOfClass:[SCNPhysicsField class] forKey:@"physicsField"];
        _position = [coder containsValueForKey:@"position"] ? [RevenantSCNCoding decodeVector3:coder forKey:@"position"] : SCNVector3Make(0, 0, 0);
        if ([coder containsValueForKey:@"orientation"]) {
            _orientation = [RevenantSCNCoding decodeVector4:coder forKey:@"orientation"];
        } else if ([coder containsValueForKey:@"rotation"]) {
            _orientation = RevenantSCNQuaternionFromAxisAngle([RevenantSCNCoding decodeVector4:coder forKey:@"rotation"]);
        }
        _scale = [coder containsValueForKey:@"scale"] ? [RevenantSCNCoding decodeVector3:coder forKey:@"scale"] : SCNVector3Make(1, 1, 1);
        _hidden = [RevenantSCNCoding decodeBool:coder forKey:@"hidden" default:NO];
        _opacity = [coder containsValueForKey:@"opacity"] ? [coder decodeDoubleForKey:@"opacity"] : 1;
        _renderingOrder = [coder decodeIntegerForKey:@"renderingOrder"];
        _castsShadow = [RevenantSCNCoding decodeBool:coder forKey:@"castsShadow" default:YES];
        _categoryBitMask = [coder containsValueForKey:@"categoryBitMask"] ? [coder decodeIntegerForKey:@"categoryBitMask"] : 1;
        _movabilityHint = [coder decodeIntegerForKey:@"movabilityHint"];

        [_particleSystems addObjectsFromArray:[RevenantSCNCoding decodeArrayOfClass:[SCNParticleSystem class] coder:coder forKey:@"particleSystem"]];
        [_particleSystems addObjectsFromArray:[RevenantSCNCoding decodeArrayOfClass:[SCNParticleSystem class] coder:coder forKey:@"particleSystems"]];

        NSArray<SCNNode *> *children = [RevenantSCNCoding decodeArrayOfClass:[SCNNode class] coder:coder forKey:@"childNodes"];
        for (SCNNode *child in children) {
            [self addChildNode:child];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_light forKey:@"light"];
    [coder encodeObject:_camera forKey:@"camera"];
    [coder encodeObject:_geometry forKey:@"geometry"];
    [coder encodeObject:_physicsField forKey:@"physicsField"];
    [RevenantSCNCoding encodeVector3:_position coder:coder forKey:@"position"];
    [RevenantSCNCoding encodeVector4:self.rotation coder:coder forKey:@"rotation"];
    [RevenantSCNCoding encodeVector4:_orientation coder:coder forKey:@"orientation"];
    [RevenantSCNCoding encodeVector3:_scale coder:coder forKey:@"scale"];
    [coder encodeBool:_hidden forKey:@"hidden"];
    [coder encodeDouble:_opacity forKey:@"opacity"];
    [coder encodeInteger:_renderingOrder forKey:@"renderingOrder"];
    [coder encodeBool:_castsShadow forKey:@"castsShadow"];
    [coder encodeInteger:_categoryBitMask forKey:@"categoryBitMask"];
    [coder encodeInteger:_movabilityHint forKey:@"movabilityHint"];
    [coder encodeObject:[_particleSystems copy] forKey:@"particleSystems"];
    [coder encodeObject:[_childNodes copy] forKey:@"childNodes"];
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNNode *copy = [[SCNNode allocWithZone:zone] init];
    copy->_name = [_name copy];
    copy->_light = _light;
    copy->_camera = _camera;
    copy->_geometry = _geometry;
    copy->_physicsField = _physicsField;
    copy->_position = _position;
    copy->_orientation = _orientation;
    copy->_eulerAngles = _eulerAngles;
    copy->_hasEulerAngles = _hasEulerAngles;
    copy->_scale = _scale;
    copy->_matrix = _matrix;
    copy->_hasMatrix = _hasMatrix;
    copy->_hidden = _hidden;
    copy->_opacity = _opacity;
    copy->_renderingOrder = _renderingOrder;
    copy->_castsShadow = _castsShadow;
    copy->_categoryBitMask = _categoryBitMask;
    copy->_movabilityHint = _movabilityHint;
    copy->_boundingBoxMin = _boundingBoxMin;
    copy->_boundingBoxMax = _boundingBoxMax;
    copy->_hasExplicitBoundingBox = _hasExplicitBoundingBox;
    for (SCNParticleSystem *system in _particleSystems) {
        [copy->_particleSystems addObject:system];
    }
    copy->_animations = [_animations revenantCopy];
    return copy;
}

@end

@implementation SCNNode (SCNParticleSystemSupport)

- (void)addParticleSystem:(SCNParticleSystem *)system
{
    [self->_particleSystems addObject:system];
}

- (void)removeAllParticleSystems
{
    [self->_particleSystems removeAllObjects];
}

- (void)removeParticleSystem:(SCNParticleSystem *)system
{
    [self->_particleSystems removeObject:system];
}

- (NSArray<SCNParticleSystem *> *)particleSystems
{
    return self->_particleSystems.count ? [self->_particleSystems copy] : nil;
}

#pragma mark SCNActionable

- (BOOL)hasActions
{
    return self->_actionRuns.count > 0;
}

- (NSArray<NSString *> *)actionKeys
{
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    for (RevenantSCNActionRun *run in self->_actionRuns) {
        if (run.key) {
            [keys addObject:run.key];
        }
    }
    return keys;
}

- (SCNAction *)actionForKey:(NSString *)key
{
    for (RevenantSCNActionRun *run in self->_actionRuns) {
        if ([run.key isEqualToString:key]) {
            return run.action;
        }
    }
    return nil;
}

- (void)removeActionForKey:(NSString *)key
{
    for (NSUInteger index = 0; index < self->_actionRuns.count; index++) {
        if ([self->_actionRuns[index].key isEqualToString:key]) {
            [self->_actionRuns removeObjectAtIndex:index];
            return;
        }
    }
}

- (void)removeAllActions
{
    [self->_actionRuns removeAllObjects];
}

- (void)runAction:(SCNAction *)action
{
    [self runAction:action forKey:nil completionHandler:nil];
}

- (void)runAction:(SCNAction *)action completionHandler:(void (^)(void))block
{
    [self runAction:action forKey:nil completionHandler:block];
}

- (void)runAction:(SCNAction *)action forKey:(NSString *)key
{
    [self runAction:action forKey:key completionHandler:nil];
}

- (void)runAction:(SCNAction *)action forKey:(NSString *)key completionHandler:(void (^)(void))block
{
    if (key) {
        [self removeActionForKey:key];
    }
    if (self->_actionRuns == nil) {
        self->_actionRuns = [NSMutableArray array];
    }
    [self->_actionRuns addObject:[[RevenantSCNActionRun alloc] initWithAction:action key:key completion:block time:CACurrentMediaTime()]];
}

- (void)revenantStepActionsAtTime:(CFTimeInterval)now
{
    NSMutableArray<void (^)(void)> *completions = nil;
    for (NSUInteger index = 0; index < self->_actionRuns.count;) {
        RevenantSCNActionRun *run = self->_actionRuns[index];
        NSTimeInterval dt = MAX(now - run.lastTime, 0);
        run.lastTime = now;
        NSTimeInterval leftover = 0;
        if ([run advanceBy:dt onNode:self leftover:&leftover]) {
            [self->_actionRuns removeObjectAtIndex:index];
            if (run.completion) {
                if (completions == nil) {
                    completions = [NSMutableArray array];
                }
                [completions addObject:run.completion];
            }
        } else {
            index++;
        }
    }
    for (void (^completion)(void) in completions) {
        completion();
    }
}

@end
