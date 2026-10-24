#import "RevenantSCN.h"
#import "RevenantSCNMath.h"
#import "../RevenantSayOnce.h"
#import "../RevenantBezier.h"
#import "../RevenantSpring.h"
#import <QuartzCore/QuartzCore.h>

@interface RevenantSCNAnimationEntry : NSObject
{
@public
    NSString *_key;
    CAAnimation *_animation;
    CFTimeInterval _begin;
    BOOL _committed, _stopped, _paused;
    CFTimeInterval _pausedLocal;
}
@end

@implementation RevenantSCNAnimationEntry
@end

#pragma mark Timing

static double RevenantSCNTimed(CAMediaTimingFunction *function, double fraction)
{
    if (function == nil) {
        return fraction;
    }
    float p1[2], p2[2];
    [function getControlPointAtIndex:1 values:p1];
    [function getControlPointAtIndex:2 values:p2];
    return revenant_bezier_progress(p1[0], p1[1], p2[0], p2[1], fraction);
}

typedef struct {
    BOOL active;
    BOOL finished;
    double time;
    double duration;
} RevenantSCNPhase;

static RevenantSCNPhase RevenantSCNPhaseAt(CAAnimation *animation, double parentTime)
{
    RevenantSCNPhase phase = {NO, NO, 0, 0};
    double speed = animation.speed;
    double duration = animation.duration > 0 ? animation.duration : 0.25;
    phase.duration = duration;
    double local = (parentTime - animation.beginTime) * speed + animation.timeOffset;
    double period = duration * (animation.autoreverses ? 2 : 1);
    double active;
    if (animation.repeatDuration > 0) {
        active = animation.repeatDuration;
    } else if (animation.repeatCount > 0) {
        active = isinf(animation.repeatCount) ? INFINITY : animation.repeatCount * period;
    } else {
        active = period;
    }
    NSString *fill = animation.fillMode;
    BOOL backwards = [fill isEqualToString:kCAFillModeBackwards] || [fill isEqualToString:kCAFillModeBoth];
    BOOL forwards = [fill isEqualToString:kCAFillModeForwards] || [fill isEqualToString:kCAFillModeBoth];
    if (local < 0) {
        phase.active = backwards;
        phase.time = 0;
        return phase;
    }
    if (local >= active) {
        phase.finished = YES;
        phase.active = forwards;
        double end = fmod(active, period);
        if (end == 0 && active > 0) end = period;
        phase.time = animation.autoreverses && end > duration ? period - end : MIN(end, duration);
        return phase;
    }
    double within = fmod(local, period);
    phase.time = animation.autoreverses && within > duration ? period - within : within;
    phase.active = YES;
    return phase;
}

#pragma mark Values

static NSUInteger RevenantSCNComponents(NSValue *value, float out[16])
{
    if ([value isKindOfClass:[NSNumber class]]) {
        out[0] = [(NSNumber *)value floatValue];
        return 1;
    }
    const char *type = value.objCType;
    if (strcmp(type, @encode(SCNVector3)) == 0) {
        SCNVector3 v = [value SCNVector3Value];
        out[0] = v.x; out[1] = v.y; out[2] = v.z;
        return 3;
    }
    if (strcmp(type, @encode(SCNVector4)) == 0) {
        SCNVector4 v = [value SCNVector4Value];
        out[0] = v.x; out[1] = v.y; out[2] = v.z; out[3] = v.w;
        return 4;
    }
    if (strcmp(type, @encode(SCNMatrix4)) == 0) {
        SCNMatrix4 m = [value SCNMatrix4Value];
        memcpy(out, &m.m11, sizeof(m));
        return 16;
    }
    return 0;
}

static NSValue *RevenantSCNValueOf(const float *c, NSUInteger count)
{
    switch (count) {
    case 1: return @(c[0]);
    case 3: return [NSValue valueWithSCNVector3:SCNVector3Make(c[0], c[1], c[2])];
    case 4: return [NSValue valueWithSCNVector4:SCNVector4Make(c[0], c[1], c[2], c[3])];
    case 16: {
        SCNMatrix4 m;
        memcpy(&m.m11, c, sizeof(m));
        return [NSValue valueWithSCNMatrix4:m];
    }
    }
    return nil;
}

static NSValue *RevenantSCNInterpolate(NSValue *from, NSValue *to, double t)
{
    float a[16], b[16], out[16];
    NSUInteger n = RevenantSCNComponents(from, a);
    if (n == 0 || RevenantSCNComponents(to, b) != n) {
        return nil;
    }
    for (NSUInteger i = 0; i < n; i++) {
        out[i] = (float)(a[i] + (b[i] - a[i]) * t);
    }
    return RevenantSCNValueOf(out, n);
}

static NSValue *RevenantSCNAdd(NSValue *a, NSValue *b)
{
    float x[16], y[16];
    NSUInteger n = RevenantSCNComponents(a, x);
    if (n == 0 || RevenantSCNComponents(b, y) != n) {
        return nil;
    }
    for (NSUInteger i = 0; i < n; i++) {
        x[i] += y[i];
    }
    return RevenantSCNValueOf(x, n);
}

@implementation RevenantSCNAnimations
{
    NSMutableArray<RevenantSCNAnimationEntry *> *_entries;
    NSMutableDictionary<NSString *, NSValue *> *_presented;
    NSUInteger _serial;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _entries = [NSMutableArray array];
        _presented = [NSMutableDictionary dictionary];
    }
    return self;
}

- (RevenantSCNAnimationEntry *)entryForKey:(NSString *)key
{
    for (RevenantSCNAnimationEntry *entry in _entries) {
        if ([entry->_key isEqualToString:key]) {
            return entry;
        }
    }
    return nil;
}

static void RevenantSCNSendStop(CAAnimation *animation, BOOL finished)
{
    id<CAAnimationDelegate> delegate = (id)animation.delegate;
    if ([delegate respondsToSelector:@selector(animationDidStop:finished:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate animationDidStop:animation finished:finished];
        });
    }
}

static void RevenantSCNSayUnmeasured(CAAnimation *animation)
{
    NSString *(^member)(NSString *, NSString *) = ^(NSString *name, NSString *how) {
        return [NSString stringWithFormat:@"SceneKit: an animation sets %@, which this port %@", name, how];
    };
    NSString *measured = @"evaluates by Core Animation's rules and no series has measured against SceneKit";
    if (animation.speed != 1) revenant_say_once_for(@"scenekit member speed", member(@"speed", measured));
    if (animation.timeOffset != 0) revenant_say_once_for(@"scenekit member timeOffset", member(@"timeOffset", measured));
    if (animation.repeatDuration > 0) revenant_say_once_for(@"scenekit member repeatDuration", member(@"repeatDuration", measured));
    if ([animation.fillMode isEqualToString:kCAFillModeBackwards] || [animation.fillMode isEqualToString:kCAFillModeBoth]) {
        revenant_say_once_for(@"scenekit member fillMode", member(@"a backwards fill", measured));
    }
    if ([animation isKindOfClass:[CAPropertyAnimation class]]) {
        CAPropertyAnimation *property = (CAPropertyAnimation *)animation;
        if (property.cumulative) revenant_say_once_for(@"scenekit member cumulative", member(@"cumulative", @"does not evaluate"));
        if (property.valueFunction) revenant_say_once_for(@"scenekit member valueFunction", member(@"a valueFunction", @"does not evaluate"));
    }
    if ([animation isKindOfClass:[CAAnimationGroup class]]) {
        for (CAAnimation *child in [(CAAnimationGroup *)animation animations]) {
            if (child.duration <= 0) revenant_say_once_for(@"scenekit member group child duration", member(@"a group child with no duration", @"takes as a single animation with none, 0.25 s, and no series has measured against SceneKit"));
            RevenantSCNSayUnmeasured(child);
        }
    }
}

- (void)addAnimation:(id)animation forKey:(NSString *)key
{
    if (![animation isKindOfClass:[CAAnimation class]]) {
        revenant_say_once_for(@"scenekit animation class", [NSString stringWithFormat:@"SceneKit: only Core Animation objects are animated by this port; a %@ was not added", [animation class]]);
        return;
    }
    if (key == nil) {
        key = [NSString stringWithFormat:@"RevenantSCNAnimation-%lu", (unsigned long)++_serial];
    }
    [self removeAnimationForKey:key];
    RevenantSCNAnimationEntry *entry = [RevenantSCNAnimationEntry new];
    entry->_key = [key copy];
    entry->_animation = [(CAAnimation *)animation copy];
    RevenantSCNSayUnmeasured(entry->_animation);
    [_entries addObject:entry];
}

- (void)removeAnimationForKey:(NSString *)key
{
    RevenantSCNAnimationEntry *entry = [self entryForKey:key];
    if (entry == nil) {
        return;
    }
    [_entries removeObject:entry];
    if (entry->_committed && !entry->_stopped) {
        RevenantSCNSendStop(entry->_animation, NO);
    }
}

- (void)removeAllAnimations
{
    for (NSString *key in [self animationKeys]) {
        [self removeAnimationForKey:key];
    }
}

- (NSArray<NSString *> *)animationKeys
{
    NSMutableArray *keys = [NSMutableArray array];
    for (RevenantSCNAnimationEntry *entry in _entries) {
        [keys addObject:entry->_key];
    }
    return keys;
}

- (CAAnimation *)animationForKey:(NSString *)key
{
    RevenantSCNAnimationEntry *entry = [self entryForKey:key];
    return entry ? [entry->_animation copy] : nil;
}

- (void)pauseAnimationForKey:(NSString *)key
{
    RevenantSCNAnimationEntry *entry = [self entryForKey:key];
    if (entry && !entry->_paused) {
        entry->_paused = YES;
        entry->_pausedLocal = CACurrentMediaTime() - entry->_begin;
    }
}

- (void)resumeAnimationForKey:(NSString *)key
{
    RevenantSCNAnimationEntry *entry = [self entryForKey:key];
    if (entry && entry->_paused) {
        entry->_paused = NO;
        entry->_begin = CACurrentMediaTime() - entry->_pausedLocal;
    }
}

- (BOOL)isAnimationForKeyPaused:(NSString *)key
{
    RevenantSCNAnimationEntry *entry = [self entryForKey:key];
    return entry ? entry->_paused : NO;
}

- (BOOL)isEmpty
{
    return _entries.count == 0 && _presented.count == 0;
}

- (NSDictionary<NSString *, NSValue *> *)presented
{
    return _presented;
}

- (RevenantSCNAnimations *)revenantCopy
{
    RevenantSCNAnimations *copy = [RevenantSCNAnimations new];
    for (RevenantSCNAnimationEntry *entry in _entries) {
        [copy addAnimation:entry->_animation forKey:entry->_key];
    }
    return copy;
}

- (NSValue *)valueOf:(CAAnimation *)animation keyPath:(NSString *)keyPath atTime:(double)time model:(id<RevenantSCNAnimatable>)model
                into:(NSMutableDictionary<NSString *, NSValue *> *)values
{
    RevenantSCNPhase phase = RevenantSCNPhaseAt(animation, time);
    if (!phase.active) {
        return nil;
    }
    if ([animation isKindOfClass:[CAAnimationGroup class]]) {
        double local = phase.duration > 0 ? RevenantSCNTimed(animation.timingFunction, phase.time / phase.duration) * phase.duration : phase.time;
        for (CAAnimation *child in [(CAAnimationGroup *)animation animations]) {
            if ([child isKindOfClass:[CAPropertyAnimation class]]) {
                NSString *childPath = [(CAPropertyAnimation *)child keyPath];
                NSValue *value = [self valueOf:child keyPath:childPath atTime:local model:model into:values];
                if (value) {
                    values[childPath] = value;
                }
            }
        }
        return nil;
    }
    if (![animation isKindOfClass:[CABasicAnimation class]]) {
        revenant_say_once_for([@"scenekit animation " stringByAppendingString:NSStringFromClass([animation class])],
                            [NSString stringWithFormat:@"SceneKit: a %@ on a node or material property is not evaluated by this port", [animation class]]);
        return nil;
    }
    CABasicAnimation *basic = (CABasicAnimation *)animation;
    NSValue *current = values[keyPath] ?: [model revenantModelValueForKeyPath:keyPath];
    if (current == nil) {
        revenant_say_once_for([@"scenekit keypath " stringByAppendingString:keyPath],
                            [NSString stringWithFormat:@"SceneKit: the key path %@ is not animated by this port", keyPath]);
        return nil;
    }
    NSValue *from = basic.fromValue, *to = basic.toValue, *by = basic.byValue;
    if (from == nil) {
        from = to && by ? nil : current;
    }
    if (from == nil && to && by) {
        float t[16], b[16];
        NSUInteger n = RevenantSCNComponents(to, t);
        if (RevenantSCNComponents(by, b) == n) {
            for (NSUInteger i = 0; i < n; i++) t[i] -= b[i];
            from = RevenantSCNValueOf(t, n);
        }
    }
    if (to == nil) {
        to = by ? RevenantSCNAdd(from, by) : current;
    }
    double progress;
    if ([animation isKindOfClass:[CASpringAnimation class]]) {
        CASpringAnimation *spring = (CASpringAnimation *)animation;
        double velocity = [spring respondsToSelector:@selector(initialVelocity)] ? spring.initialVelocity : 0;
        double omega = sqrt(spring.stiffness / spring.mass), zeta = spring.damping / (2 * sqrt(spring.stiffness * spring.mass));
        progress = isfinite(omega) && omega > 0 ? revenant_spring_value(omega, zeta, velocity, phase.time) : 1;
    } else {
        progress = RevenantSCNTimed(animation.timingFunction, phase.duration > 0 ? phase.time / phase.duration : 1);
    }
    NSValue *value = RevenantSCNInterpolate(from, to, progress);
    if (value && basic.additive) {
        value = RevenantSCNAdd(current, value);
    }
    return value;
}

- (void)evaluateAtTime:(CFTimeInterval)now model:(id<RevenantSCNAnimatable>)model
{
    [_presented removeAllObjects];
    NSMutableArray *finished = nil;
    for (RevenantSCNAnimationEntry *entry in [_entries copy]) {
        CAAnimation *animation = entry->_animation;
        if (!entry->_committed) {
            entry->_committed = YES;
            entry->_begin = animation.beginTime > 0 ? animation.beginTime : now;
            id<CAAnimationDelegate> delegate = (id)animation.delegate;
            if ([delegate respondsToSelector:@selector(animationDidStart:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate animationDidStart:animation];
                });
            }
        }
        CFTimeInterval local = entry->_paused ? entry->_pausedLocal : now - entry->_begin;
        CFTimeInterval time = local + animation.beginTime;
        NSString *keyPath = [animation isKindOfClass:[CAPropertyAnimation class]] ? [(CAPropertyAnimation *)animation keyPath] : nil;
        NSValue *value = [self valueOf:animation keyPath:keyPath atTime:time model:model into:_presented];
        if (value && keyPath) {
            _presented[keyPath] = value;
        }
        RevenantSCNPhase phase = RevenantSCNPhaseAt(animation, time);
        if (phase.finished && !entry->_stopped) {
            entry->_stopped = YES;
            RevenantSCNSendStop(animation, YES);
            if (animation.removedOnCompletion) {
                if (finished == nil) finished = [NSMutableArray array];
                [finished addObject:entry];
                if (keyPath) {
                    [_presented removeObjectForKey:keyPath];
                }
            }
        }
    }
    [_entries removeObjectsInArray:finished ?: @[]];
}

+ (void)evaluateScene:(SCNScene *)scene atTime:(CFTimeInterval)now listener:(SCNNode *)listener
{
    NSMutableArray<SCNNode *> *queue = [NSMutableArray arrayWithObject:scene.rootNode];
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    while (queue.count) {
        SCNNode *node = queue.lastObject;
        [queue removeLastObject];
        [queue addObjectsFromArray:node.childNodes];
        [[node revenantAnimations] evaluateAtTime:now model:node];
        [node revenantStepActionsAtTime:now];
        [node revenantUpdateAudioWithListener:listener];
        for (SCNMaterial *material in node.geometry.materials) {
            if ([seen containsObject:material]) {
                continue;
            }
            [seen addObject:material];
            for (SCNMaterialProperty *property in @[material.diffuse, material.ambient, material.specular, material.emission,
                                                     material.multiply, material.transparent, material.selfIllumination,
                                                     material.metalness, material.roughness, material.normal, material.reflective,
                                                     material.ambientOcclusion, material.displacement]) {
                [[property revenantAnimations] evaluateAtTime:now model:property];
            }
        }
    }
}

@end
