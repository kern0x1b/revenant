#import "RevenantSCNActions.h"
#import "RevenantSCNActionMath.h"
#import "RevenantSCNMath.h"
#include <math.h>
#include <stdlib.h>

static SCNVector3 revenant_offset(SCNVector3 base, SCNVector3 delta, CGFloat progress)
{
    return SCNVector3Make(base.x + delta.x * progress, base.y + delta.y * progress, base.z + delta.z * progress);
}

@implementation RevenantSCNActionRun
{
    NSTimeInterval _elapsed;
    NSTimeInterval _childClock;
    NSTimeInterval _runDuration;
    BOOL _started;
    SCNVector3 _startPosition;
    SCNVector3 _startEuler;
    SCNVector3 _startScale;
    SCNQuaternion _startOrientation;
    CGFloat _startOpacity;
    NSUInteger _index;
    NSUInteger _iterations;
    RevenantSCNActionRun *_current;
    NSMutableArray<RevenantSCNActionRun *> *_active;
}

@synthesize action = _action;
@synthesize key = _key;
@synthesize completion = _completion;
@synthesize lastTime = _lastTime;

- (instancetype)initWithAction:(SCNAction *)action key:(NSString *)key completion:(void (^)(void))completion time:(CFTimeInterval)time
{
    if ((self = [super init])) {
        _action = action;
        _key = [key copy];
        _completion = [completion copy];
        _lastTime = time;
    }
    return self;
}

- (BOOL)advanceBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover
{
    if (_action.revenantIsComposite) {
        return [self advanceCompositeBy:dt onNode:node leftover:leftover];
    }
    return [self advanceLeafBy:dt onNode:node leftover:leftover];
}

- (void)captureStartOnNode:(SCNNode *)node
{
    _started = YES;
    _startPosition = node.position;
    _startEuler = node.eulerAngles;
    _startScale = node.scale;
    _startOrientation = node.orientation;
    _startOpacity = node.opacity;
    _runDuration = _action.duration;
    if (_action.revenantKind == RevenantSCNActionKindWaitRandom) {
        double unit = (double)arc4random_uniform(1000001) / 1000000.0;
        _runDuration = MAX(_action.duration + _action.revenantScalar * (unit - 0.5), 0);
    }
}

- (double)easedProgress:(double)progress
{
    SCNActionTimingFunction function = _action.timingFunction;
    if (function) {
        return function((float)progress);
    }
    if (_action.timingMode == SCNActionTimingModeLinear) {
        return progress;
    }
    return RevenantSCNActionEase(progress, _action.timingMode);
}

- (BOOL)advanceLeafBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover
{
    if (!_started) {
        [self captureStartOnNode:node];
    }
    NSTimeInterval duration = _runDuration;
    if (duration <= 0) {
        [self applyProgress:1 elapsed:0 onNode:node];
        *leftover = dt;
        return YES;
    }
    NSTimeInterval time = _elapsed + dt * _action.speed;
    if (time >= duration) {
        [self applyProgress:1 elapsed:duration onNode:node];
        _elapsed = duration;
        *leftover = _action.speed > 0 ? (time - duration) / _action.speed : 0;
        return YES;
    }
    _elapsed = MAX(time, 0);
    [self applyProgress:[self easedProgress:_elapsed / duration] elapsed:_elapsed onNode:node];
    return NO;
}

- (void)applyProgress:(double)progress elapsed:(NSTimeInterval)elapsed onNode:(SCNNode *)node
{
    SCNAction *action = _action;
    SCNVector3 vector = action.revenantVector;
    CGFloat p = progress;
    switch (action.revenantKind) {
        case RevenantSCNActionKindMoveBy:
            node.position = revenant_offset(_startPosition, vector, p);
            break;
        case RevenantSCNActionKindMoveTo:
            node.position = revenant_offset(_startPosition, SCNVector3Make(vector.x - _startPosition.x, vector.y - _startPosition.y, vector.z - _startPosition.z), p);
            break;
        case RevenantSCNActionKindRotateBy:
            node.eulerAngles = revenant_offset(_startEuler, vector, p);
            break;
        case RevenantSCNActionKindRotateTo: {
            SCNVector3 delta = action.revenantShortestUnitArc
                ? SCNVector3Make(RevenantSCNActionShortestAngle(_startEuler.x, vector.x), RevenantSCNActionShortestAngle(_startEuler.y, vector.y), RevenantSCNActionShortestAngle(_startEuler.z, vector.z))
                : SCNVector3Make(vector.x - _startEuler.x, vector.y - _startEuler.y, vector.z - _startEuler.z);
            node.eulerAngles = revenant_offset(_startEuler, delta, p);
            break;
        }
        case RevenantSCNActionKindRotateByAngle: {
            SCNQuaternion turn = RevenantSCNQuaternionFromAxisAngle(SCNVector4Make(vector.x, vector.y, vector.z, action.revenantScalar * p));
            node.orientation = RevenantSCNQuaternionMultiply(_startOrientation, turn);
            break;
        }
        case RevenantSCNActionKindRotateToAxisAngle: {
            SCNQuaternion target = RevenantSCNQuaternionFromAxisAngle(action.revenantAxisAngle);
            node.orientation = RevenantSCNQuaternionSlerp(_startOrientation, target, (float)p);
            break;
        }
        case RevenantSCNActionKindScaleBy: {
            CGFloat change = action.revenantScalar * p;
            node.scale = SCNVector3Make(_startScale.x + change, _startScale.y + change, _startScale.z + change);
            break;
        }
        case RevenantSCNActionKindScaleTo: {
            CGFloat target = action.revenantScalar;
            node.scale = SCNVector3Make(_startScale.x + (target - _startScale.x) * p,
                                        _startScale.y + (target - _startScale.y) * p,
                                        _startScale.z + (target - _startScale.z) * p);
            break;
        }
        case RevenantSCNActionKindFadeOpacityBy:
            node.opacity = _startOpacity + action.revenantScalar * p;
            break;
        case RevenantSCNActionKindFadeOpacityTo:
            node.opacity = _startOpacity + (action.revenantScalar - _startOpacity) * p;
            break;
        case RevenantSCNActionKindFadeIn:
            node.opacity = _startOpacity + (1 - _startOpacity) * p;
            break;
        case RevenantSCNActionKindFadeOut:
            node.opacity = _startOpacity - _startOpacity * p;
            break;
        case RevenantSCNActionKindHide:
            node.hidden = YES;
            break;
        case RevenantSCNActionKindUnhide:
            node.hidden = NO;
            break;
        case RevenantSCNActionKindWait:
            break;
        case RevenantSCNActionKindRemoveFromParent:
            [node removeFromParentNode];
            break;
        case RevenantSCNActionKindRunBlock: {
            RevenantSCNActionBlock block = action.revenantBlock;
            dispatch_queue_t queue = action.revenantQueue;
            if (queue) {
                dispatch_async(queue, ^{
                    block(node);
                });
            } else {
                block(node);
            }
            break;
        }
        case RevenantSCNActionKindCustom:
            action.revenantCustomBlock(node, elapsed);
            break;
        default:
            break;
    }
}

- (BOOL)advanceCompositeBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover
{
    SCNAction *action = _action;
    if (action.revenantContainsRandomWait) {
        NSTimeInterval rest = 0;
        if ([self advanceChildrenBy:dt * action.speed onNode:node leftover:&rest]) {
            *leftover = action.speed > 0 ? rest / action.speed : 0;
            return YES;
        }
        return NO;
    }
    NSTimeInterval duration = action.duration;
    NSTimeInterval time = _elapsed + dt * action.speed;
    BOOL over = time >= duration;
    NSTimeInterval clock = time;
    if (over) {
        clock = duration;
    } else if (duration > 0 && duration != INFINITY) {
        clock = [self easedProgress:time / duration] * duration;
    }
    NSTimeInterval childDt = clock - _childClock;
    _childClock = clock;
    _elapsed = time;
    NSTimeInterval rest = 0;
    BOOL done = [self advanceChildrenBy:childDt onNode:node leftover:&rest];
    if (!over && !done) {
        return NO;
    }
    NSTimeInterval spent = over ? time - duration : rest;
    *leftover = action.speed > 0 ? spent / action.speed : 0;
    return YES;
}

- (BOOL)advanceChildrenBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover
{
    switch (_action.revenantKind) {
        case RevenantSCNActionKindSequence:
            return [self advanceSequenceBy:dt onNode:node leftover:leftover];
        case RevenantSCNActionKindGroup:
            return [self advanceGroupBy:dt onNode:node leftover:leftover];
        default:
            return [self advanceRepeatBy:dt onNode:node leftover:leftover];
    }
}

- (BOOL)advanceSequenceBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover
{
    NSArray<SCNAction *> *children = _action.revenantChildren;
    NSTimeInterval remaining = dt;
    while (YES) {
        if (_current == nil) {
            if (_index >= children.count) {
                *leftover = remaining;
                return YES;
            }
            _current = [[RevenantSCNActionRun alloc] initWithAction:children[_index] key:nil completion:nil time:0];
        }
        NSTimeInterval rest = 0;
        if (![_current advanceBy:remaining onNode:node leftover:&rest]) {
            return NO;
        }
        _current = nil;
        _index++;
        remaining = rest;
    }
}

- (BOOL)advanceGroupBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover
{
    if (_active == nil) {
        _active = [NSMutableArray array];
        for (SCNAction *child in _action.revenantChildren) {
            [_active addObject:[[RevenantSCNActionRun alloc] initWithAction:child key:nil completion:nil time:0]];
        }
    }
    NSTimeInterval least = INFINITY;
    for (NSUInteger i = 0; i < _active.count;) {
        NSTimeInterval rest = 0;
        if ([_active[i] advanceBy:dt onNode:node leftover:&rest]) {
            least = MIN(least, rest);
            [_active removeObjectAtIndex:i];
        } else {
            i++;
        }
    }
    if (_active.count) {
        return NO;
    }
    *leftover = least == INFINITY ? dt : least;
    return YES;
}

- (BOOL)advanceRepeatBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover
{
    SCNAction *action = _action;
    SCNAction *child = action.revenantChildren.firstObject;
    NSTimeInterval remaining = dt;
    while (YES) {
        if (_current == nil) {
            if (!action.revenantRepeatsForever && _iterations >= action.revenantRepeatCount) {
                *leftover = remaining;
                return YES;
            }
            _current = [[RevenantSCNActionRun alloc] initWithAction:child key:nil completion:nil time:0];
        }
        NSTimeInterval rest = 0;
        if (![_current advanceBy:remaining onNode:node leftover:&rest]) {
            return NO;
        }
        _current = nil;
        _iterations++;
        remaining = rest;
        if (action.revenantRepeatsForever && child.duration <= 0) {
            return NO;
        }
    }
}

@end
