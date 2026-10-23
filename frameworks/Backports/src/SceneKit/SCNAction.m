#import "RevenantSCNActions.h"

@implementation SCNAction
{
    RevenantSCNActionKind _kind;
    NSTimeInterval _leafDuration;
    SCNVector3 _vector;
    SCNVector4 _axisAngle;
    CGFloat _scalar;
    BOOL _shortestUnitArc;
    NSArray<SCNAction *> *_children;
    NSUInteger _repeatCount;
    BOOL _repeatsForever;
    RevenantSCNActionBlock _block;
    RevenantSCNActionCustomBlock _customBlock;
    dispatch_queue_t _queue;
    SCNActionTimingFunction _timingFunction;
    SCNActionTimingMode _timingMode;
    CGFloat _speed;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _speed = 1;
    }
    return self;
}

+ (instancetype)revenantActionOfKind:(RevenantSCNActionKind)kind duration:(NSTimeInterval)duration
{
    SCNAction *action = [[self alloc] init];
    action->_kind = kind;
    action->_leafDuration = duration;
    return action;
}

+ (SCNAction *)revenantCompositeOfKind:(RevenantSCNActionKind)kind children:(NSArray<SCNAction *> *)children
{
    SCNAction *action = [self revenantActionOfKind:kind duration:0];
    action->_children = [children copy];
    return action;
}

- (RevenantSCNActionKind)revenantKind
{
    return _kind;
}

- (SCNVector3)revenantVector
{
    return _vector;
}

- (SCNVector4)revenantAxisAngle
{
    return _axisAngle;
}

- (CGFloat)revenantScalar
{
    return _scalar;
}

- (BOOL)revenantShortestUnitArc
{
    return _shortestUnitArc;
}

- (NSArray<SCNAction *> *)revenantChildren
{
    return _children;
}

- (NSUInteger)revenantRepeatCount
{
    return _repeatCount;
}

- (BOOL)revenantRepeatsForever
{
    return _repeatsForever;
}

- (RevenantSCNActionBlock)revenantBlock
{
    return _block;
}

- (RevenantSCNActionCustomBlock)revenantCustomBlock
{
    return _customBlock;
}

- (dispatch_queue_t)revenantQueue
{
    return _queue;
}

- (BOOL)revenantIsComposite
{
    return _kind == RevenantSCNActionKindSequence || _kind == RevenantSCNActionKindGroup || _kind == RevenantSCNActionKindRepeat;
}

- (NSTimeInterval)duration
{
    switch (_kind) {
        case RevenantSCNActionKindSequence: {
            NSTimeInterval total = 0;
            for (SCNAction *child in _children) {
                total += child.duration;
            }
            return total;
        }
        case RevenantSCNActionKindGroup: {
            NSTimeInterval longest = 0;
            for (SCNAction *child in _children) {
                longest = MAX(longest, child.duration);
            }
            return longest;
        }
        case RevenantSCNActionKindRepeat:
            if (_repeatsForever) {
                return INFINITY;
            }
            return _repeatCount * _children.firstObject.duration;
        default:
            return _leafDuration;
    }
}

- (void)setDuration:(NSTimeInterval)duration
{
    if (self.revenantIsComposite) {
        [NSException raise:NSInvalidArgumentException format:@"SCNAction: a sequence, group or repeat takes its duration from the actions it holds"];
    }
    _leafDuration = duration;
}

- (SCNActionTimingMode)timingMode
{
    return _timingMode;
}

- (void)setTimingMode:(SCNActionTimingMode)timingMode
{
    _timingMode = timingMode;
}

- (SCNActionTimingFunction)timingFunction
{
    return _timingFunction;
}

- (void)setTimingFunction:(SCNActionTimingFunction)timingFunction
{
    _timingFunction = [timingFunction copy];
}

- (CGFloat)speed
{
    return _speed;
}

- (void)setSpeed:(CGFloat)speed
{
    _speed = speed;
}

- (id)copyWithZone:(NSZone *)zone
{
    SCNAction *copy = [[[self class] allocWithZone:zone] init];
    copy->_kind = _kind;
    copy->_leafDuration = _leafDuration;
    copy->_vector = _vector;
    copy->_axisAngle = _axisAngle;
    copy->_scalar = _scalar;
    copy->_shortestUnitArc = _shortestUnitArc;
    copy->_children = _children;
    copy->_repeatCount = _repeatCount;
    copy->_repeatsForever = _repeatsForever;
    copy->_block = _block;
    copy->_customBlock = _customBlock;
    copy->_queue = _queue;
    copy->_timingFunction = _timingFunction;
    copy->_timingMode = _timingMode;
    copy->_speed = _speed;
    return copy;
}

+ (SCNAction *)moveByX:(CGFloat)deltaX y:(CGFloat)deltaY z:(CGFloat)deltaZ duration:(NSTimeInterval)duration
{
    return [self moveBy:SCNVector3Make(deltaX, deltaY, deltaZ) duration:duration];
}

+ (SCNAction *)moveBy:(SCNVector3)delta duration:(NSTimeInterval)duration
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindMoveBy duration:duration];
    action->_vector = delta;
    return action;
}

+ (SCNAction *)moveTo:(SCNVector3)location duration:(NSTimeInterval)duration
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindMoveTo duration:duration];
    action->_vector = location;
    return action;
}

+ (SCNAction *)rotateByX:(CGFloat)xAngle y:(CGFloat)yAngle z:(CGFloat)zAngle duration:(NSTimeInterval)duration
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindRotateBy duration:duration];
    action->_vector = SCNVector3Make(xAngle, yAngle, zAngle);
    return action;
}

+ (SCNAction *)rotateToX:(CGFloat)xAngle y:(CGFloat)yAngle z:(CGFloat)zAngle duration:(NSTimeInterval)duration
{
    return [self rotateToX:xAngle y:yAngle z:zAngle duration:duration shortestUnitArc:NO];
}

+ (SCNAction *)rotateToX:(CGFloat)xAngle y:(CGFloat)yAngle z:(CGFloat)zAngle duration:(NSTimeInterval)duration shortestUnitArc:(BOOL)shortestUnitArc
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindRotateTo duration:duration];
    action->_vector = SCNVector3Make(xAngle, yAngle, zAngle);
    action->_shortestUnitArc = shortestUnitArc;
    return action;
}

+ (SCNAction *)rotateByAngle:(CGFloat)angle aroundAxis:(SCNVector3)axis duration:(NSTimeInterval)duration
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindRotateByAngle duration:duration];
    action->_vector = axis;
    action->_scalar = angle;
    return action;
}

+ (SCNAction *)rotateToAxisAngle:(SCNVector4)axisAngle duration:(NSTimeInterval)duration
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindRotateToAxisAngle duration:duration];
    action->_axisAngle = axisAngle;
    return action;
}

+ (SCNAction *)scaleBy:(CGFloat)scale duration:(NSTimeInterval)sec
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindScaleBy duration:sec];
    action->_scalar = scale;
    return action;
}

+ (SCNAction *)scaleTo:(CGFloat)scale duration:(NSTimeInterval)sec
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindScaleTo duration:sec];
    action->_scalar = scale;
    return action;
}

+ (SCNAction *)sequence:(NSArray<SCNAction *> *)actions
{
    return [self revenantCompositeOfKind:RevenantSCNActionKindSequence children:actions];
}

+ (SCNAction *)group:(NSArray<SCNAction *> *)actions
{
    return [self revenantCompositeOfKind:RevenantSCNActionKindGroup children:actions];
}

+ (SCNAction *)repeatAction:(SCNAction *)action count:(NSUInteger)count
{
    SCNAction *repeat = [self revenantCompositeOfKind:RevenantSCNActionKindRepeat children:@[action]];
    repeat->_repeatCount = count;
    return repeat;
}

+ (SCNAction *)repeatActionForever:(SCNAction *)action
{
    SCNAction *repeat = [self revenantCompositeOfKind:RevenantSCNActionKindRepeat children:@[action]];
    repeat->_repeatsForever = YES;
    return repeat;
}

+ (SCNAction *)fadeInWithDuration:(NSTimeInterval)sec
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindFadeOpacityTo duration:sec];
    action->_scalar = 1;
    return action;
}

+ (SCNAction *)fadeOutWithDuration:(NSTimeInterval)sec
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindFadeOpacityTo duration:sec];
    action->_scalar = 0;
    return action;
}

+ (SCNAction *)fadeOpacityBy:(CGFloat)factor duration:(NSTimeInterval)sec
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindFadeOpacityBy duration:sec];
    action->_scalar = factor;
    return action;
}

+ (SCNAction *)fadeOpacityTo:(CGFloat)opacity duration:(NSTimeInterval)sec
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindFadeOpacityTo duration:sec];
    action->_scalar = opacity;
    return action;
}

+ (SCNAction *)hide
{
    return [self revenantActionOfKind:RevenantSCNActionKindHide duration:0];
}

+ (SCNAction *)unhide
{
    return [self revenantActionOfKind:RevenantSCNActionKindUnhide duration:0];
}

+ (SCNAction *)waitForDuration:(NSTimeInterval)sec
{
    return [self revenantActionOfKind:RevenantSCNActionKindWait duration:sec];
}

+ (SCNAction *)removeFromParentNode
{
    return [self revenantActionOfKind:RevenantSCNActionKindRemoveFromParent duration:0];
}

+ (SCNAction *)runBlock:(void (^)(SCNNode *node))block
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindRunBlock duration:0];
    action->_block = [block copy];
    return action;
}

+ (SCNAction *)runBlock:(void (^)(SCNNode *node))block queue:(dispatch_queue_t)queue
{
    SCNAction *action = [self runBlock:block];
    action->_queue = queue;
    return action;
}

+ (SCNAction *)customActionWithDuration:(NSTimeInterval)seconds actionBlock:(void (^)(SCNNode *node, CGFloat elapsedTime))block
{
    SCNAction *action = [self revenantActionOfKind:RevenantSCNActionKindCustom duration:seconds];
    action->_customBlock = [block copy];
    return action;
}

@end
