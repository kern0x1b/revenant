#import "CharonDynamics.h"

// Each collision behavior takes a group from the animator's counter when it joins (the first is 1)
// and gives it back when it leaves: its items carry the category bit 1 << 2g, its boundaries 1 << 2g+1.
// A counter, not an allocator, so a behavior that joins after another left can share bits with one
// still there, as on 7.0. Boundaries are static edge or loop bodies at the reference system's origin.
@implementation UICollisionBehavior {
    BOOL _usesImplicitBounds;
    UIEdgeInsets _implicitBoundsInsets;
    CharonDynamicsBody *_implicitBoundsBody;
    NSMutableDictionary *_boundaryBodies;
    NSMutableDictionary *_boundaryPaths;
    UICollisionBehaviorMode _collisionMode;
    __weak id<UICollisionBehaviorDelegate> _collisionDelegate;
    uint32_t _groupVID;
    uint32_t _groupBID;
    BOOL _delegateBeganItems, _delegateEndedItems, _delegateBeganBoundary, _delegateEndedBoundary;
}

- (instancetype)init
{
    return [self initWithItems:@[]];
}

- (instancetype)initWithItems:(NSArray *)items
{
    if (!(self = [super charon_initPrimitive:YES]))
        return nil;
    [[self charon_items] addObjectsFromArray:items ?: @[]];
    _collisionMode = UICollisionBehaviorModeEverything;
    _boundaryBodies = [NSMutableDictionary new];
    _boundaryPaths = [NSMutableDictionary new];
    return self;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self charon_items]];
}

- (id<UICollisionBehaviorDelegate>)collisionDelegate
{
    return _collisionDelegate;
}

- (void)setCollisionDelegate:(id<UICollisionBehaviorDelegate>)delegate
{
    _collisionDelegate = delegate;
    _delegateBeganItems = [delegate respondsToSelector:@selector(collisionBehavior:beganContactForItem:withItem:atPoint:)];
    _delegateEndedItems = [delegate respondsToSelector:@selector(collisionBehavior:endedContactForItem:withItem:)];
    _delegateBeganBoundary = [delegate respondsToSelector:@selector(collisionBehavior:beganContactForItem:withBoundaryIdentifier:atPoint:)];
    _delegateEndedBoundary = [delegate respondsToSelector:@selector(collisionBehavior:endedContactForItem:withBoundaryIdentifier:)];
}

- (UICollisionBehaviorMode)collisionMode
{
    return _collisionMode;
}

- (void)setCollisionMode:(UICollisionBehaviorMode)mode
{
    _collisionMode = mode;
    if (![self charon_isAssociated])
        return;
    UIDynamicAnimator *context = [self charon_context];
    for (id<UIDynamicItem> item in [self charon_items])
        [self charon_setCollisions:YES forBody:[context charon_bodyForItem:item] isEdge:NO];
    if (_implicitBoundsBody)
        [self charon_setCollisions:YES forBody:_implicitBoundsBody isEdge:YES];
    for (CharonDynamicsBody *body in _boundaryBodies.allValues)
        [self charon_setCollisions:YES forBody:body isEdge:YES];
}

// -[UICollisionBehavior _setCollisions:forBody:isEdge:] (7.0): this behavior's two bits are cleared
// and set again; another behavior's bits on a shared body stay. The contact mask is the collision one.
- (void)charon_setCollisions:(BOOL)on forBody:(CharonDynamicsBody *)body isEdge:(BOOL)edge
{
    if (!body)
        return;
    uint32_t own = edge ? _groupBID : _groupVID;
    uint32_t both = _groupVID | _groupBID;
    uint32_t mode = _collisionMode == UICollisionBehaviorModeItems ? _groupVID : _collisionMode == UICollisionBehaviorModeBoundaries ? _groupBID : both;
    uint32_t collision = body.collisionBitMask & ~both;
    if (on) {
        collision |= mode;
        body.collisionBitMask = collision;
        body.categoryBitMask = (body.categoryBitMask & ~both) | own;
    } else {
        body.collisionBitMask = collision;
        body.categoryBitMask = body.categoryBitMask & ~both;
    }
    body.contactTestBitMask = collision;
    [self charon_changedParameterForBody:body];
}

- (void)charon_addItem:(id<UIDynamicItem>)item
{
    [self charon_setCollisions:YES forBody:[[self charon_context] charon_registerBodyForItem:item shape:CharonDynamicsShapeBox] isEdge:NO];
}

- (void)charon_removeBodyOfItem:(id<UIDynamicItem>)item
{
    [[self charon_context] charon_unregisterBodyForItem:item action:^(CharonDynamicsBody *body) {
        [self charon_setCollisions:NO forBody:body isEdge:NO];
    }];
}

- (void)addItem:(id<UIDynamicItem>)item
{
    if ([[self charon_items] containsObject:item])
        return;
    [[self charon_items] addObject:item];
    if ([self charon_isAssociated])
        [self charon_addItem:item];
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    if (![[self charon_items] containsObject:item])
        return;
    [self charon_removeBodyOfItem:item];
    [[self charon_items] removeObject:item];
}

- (void)charon_associate
{
    [super charon_associate];
    UIDynamicAnimator *context = [self charon_context];
    int group = [context charon_registerCollisionGroup];
    _groupVID = 1u << ((2 * group) & 31);
    _groupBID = 1u << ((2 * group + 1) & 31);
    if (_usesImplicitBounds)
        [context charon_registerImplicitBounds];
    for (id<UIDynamicItem> item in [self charon_items])
        [self charon_addItem:item];
    [self charon_setupImplicitBoundaries];
    for (id identifier in _boundaryPaths) {
        CharonDynamicsBody *body = [self charon_bodyForBoundary:_boundaryPaths[identifier]];
        _boundaryBodies[identifier] = body;
        [context charon_addBody:body];
        [self charon_setCollisions:YES forBody:body isEdge:YES];
    }
}

- (void)charon_dissociate
{
    UIDynamicAnimator *context = [self charon_context];
    [context charon_unregisterCollisionGroup];
    if (_usesImplicitBounds)
        [context charon_unregisterImplicitBounds];
    if (_implicitBoundsBody) {
        [context charon_removeBody:_implicitBoundsBody];
        _implicitBoundsBody = nil;
    }
    for (CharonDynamicsBody *body in _boundaryBodies.allValues)
        [context charon_removeBody:body];
    [_boundaryBodies removeAllObjects];
    for (id<UIDynamicItem> item in [self charon_items])
        [self charon_removeBodyOfItem:item];
    [super charon_dissociate];
}

#pragma mark Boundaries

// A boundary path as 7.0 flattens it: the first subpath only, a curve as max(L / 10 pt, 1) chords of
// equal parameter where L is the length of its 10-chord polyline, a closing subpath back to its start;
// then, in metres, every point that exactly repeats the one before, and a last one that repeats the
// first, dropped.
struct CharonFlattening {
    BOOL stop;
    CFMutableDataRef points;
};

static NSUInteger charon_count(CharonFlattening *state)
{
    return CFDataGetLength(state->points) / sizeof(CGPoint);
}

static CGPoint charon_point(CharonFlattening *state, NSUInteger index)
{
    return ((const CGPoint *)CFDataGetBytePtr(state->points))[index];
}

static void charon_append(CharonFlattening *state, CGPoint point)
{
    CFDataAppendBytes(state->points, (const UInt8 *)&point, sizeof point);
}

static CGPoint charon_bezier(const CGPoint *controls, int count, float t)
{
    float u = 1.0f - t;
    if (count == 3)
        return CGPointMake(u * u * (float)controls[0].x + 2 * u * t * (float)controls[1].x + t * t * (float)controls[2].x,
                           u * u * (float)controls[0].y + 2 * u * t * (float)controls[1].y + t * t * (float)controls[2].y);
    return CGPointMake(u * u * u * (float)controls[0].x + 3 * u * u * t * (float)controls[1].x + 3 * u * t * t * (float)controls[2].x + t * t * t * (float)controls[3].x,
                       u * u * u * (float)controls[0].y + 3 * u * u * t * (float)controls[1].y + 3 * u * t * t * (float)controls[2].y + t * t * t * (float)controls[3].y);
}

static void charon_flatten_curve(CharonFlattening *state, const CGPoint *controls, int count)
{
    float length = 0;
    CGPoint previous = controls[0];
    for (int index = 1; index <= 10; index++) {
        CGPoint point = charon_bezier(controls, count, index / 10.0f);
        length += hypotf((float)(point.x - previous.x), (float)(point.y - previous.y));
        previous = point;
    }
    int chords = MAX((int)(length / 10.0f), 1);
    for (int index = 0; index <= chords; index++)
        charon_append(state, charon_bezier(controls, count, MIN(MAX(index / (float)chords, 0.0f), 1.0f)));
}

static void charon_flatten_element(void *info, const CGPathElement *element)
{
    CharonFlattening *state = (CharonFlattening *)info;
    if (state->stop)
        return;
    CGPoint controls[4];
    switch (element->type) {
    case kCGPathElementMoveToPoint:
        if (charon_count(state))
            state->stop = YES;
        else
            charon_append(state, element->points[0]);
        break;
    case kCGPathElementAddLineToPoint:
        charon_append(state, element->points[0]);
        break;
    case kCGPathElementAddQuadCurveToPoint:
        controls[0] = charon_count(state) ? charon_point(state, charon_count(state) - 1) : CGPointZero;
        controls[1] = element->points[0];
        controls[2] = element->points[1];
        charon_flatten_curve(state, controls, 3);
        break;
    case kCGPathElementAddCurveToPoint:
        controls[0] = charon_count(state) ? charon_point(state, charon_count(state) - 1) : CGPointZero;
        controls[1] = element->points[0];
        controls[2] = element->points[1];
        controls[3] = element->points[2];
        charon_flatten_curve(state, controls, 4);
        break;
    case kCGPathElementCloseSubpath:
        if (charon_count(state))
            charon_append(state, charon_point(state, 0));
        state->stop = YES;
        break;
    }
}

// The loop's vertices in metres, as an NSData of b2Vec2.
static NSData *charon_loop_vertices(CGPathRef path)
{
    CharonFlattening state = {NO, CFDataCreateMutable(NULL, 0)};
    CGPathApply(path, &state, charon_flatten_element);
    NSMutableData *vertices = [NSMutableData data];
    NSUInteger kept = 0;
    for (NSUInteger index = 0; index < charon_count(&state); index++) {
        CGPoint point = charon_point(&state, index);
        b2Vec2 vertex((float)point.x * CHARON_DYNAMICS_INVERSE_PTM, (float)point.y * CHARON_DYNAMICS_INVERSE_PTM);
        if (kept && b2DistanceSquared(vertex, ((const b2Vec2 *)vertices.bytes)[kept - 1]) <= 1.42108547e-14f)
            continue;
        [vertices appendBytes:&vertex length:sizeof vertex];
        kept += 1;
    }
    // A closed path ends on its first point: every trailing point that coincides with it goes. Fewer than two
    // points left make no loop (facts/UIKit/UIDynamicAnimator.md M2, the host's rule of addEdgeLoop).
    const b2Vec2 *kept_vertices = (const b2Vec2 *)vertices.bytes;
    if (kept > 1) {
        while (kept >= 2 && b2DistanceSquared(kept_vertices[kept - 1], kept_vertices[0]) <= 1.42108547e-14f)
            kept -= 1;
    }
    vertices.length = kept < 2 ? 0 : kept * sizeof(b2Vec2);
    CFRelease(state.points);
    return vertices;
}

// A path with no loop in it is refused when its body is made: at add in an animator, else at the association
// that makes it, whose behavior is then left in animator.behaviors but not registered
// (facts/UIKit/UIDynamicAnimator.md M2).
static CharonDynamicsBody *charon_loop_body(UIDynamicAnimator *context, NSData *vertices)
{
    if (vertices.length == 0)
        [NSException raise:NSInternalInconsistencyException format:@"invalid path for collision boundary"];
    return [context charon_boundaryBodyWithLoop:(const b2Vec2 *)vertices.bytes count:(int32)(vertices.length / sizeof(b2Vec2))];
}

// A boundary is kept as its path, or its two points, and has a body only while the behavior is in an
// animator.
- (CharonDynamicsBody *)charon_bodyForBoundary:(id)description
{
    UIDynamicAnimator *context = [self charon_context];
    if ([description isKindOfClass:[UIBezierPath class]])
        return charon_loop_body(context, charon_loop_vertices([description CGPath]));
    return [context charon_boundaryBodyFromPoint:[description[0] CGPointValue] toPoint:[description[1] CGPointValue]];
}

- (BOOL)translatesReferenceBoundsIntoBoundary
{
    return _usesImplicitBounds;
}

- (void)setTranslatesReferenceBoundsIntoBoundary:(BOOL)translates
{
    [self charon_setTranslates:translates insets:UIEdgeInsetsZero];
}

- (void)setTranslatesReferenceBoundsIntoBoundaryWithInsets:(UIEdgeInsets)insets
{
    [self charon_setTranslates:YES insets:insets];
}

- (void)charon_setTranslates:(BOOL)translates insets:(UIEdgeInsets)insets
{
    BOOL changed = translates != _usesImplicitBounds;
    _usesImplicitBounds = translates;
    _implicitBoundsInsets = insets;
    if (![self charon_isAssociated])
        return;
    UIDynamicAnimator *context = [self charon_context];
    if (changed) {
        if (translates)
            [context charon_registerImplicitBounds];
        else
            [context charon_unregisterImplicitBounds];
    }
    [self charon_setupImplicitBoundaries];
}

- (BOOL)charon_usesImplicitBounds
{
    return _usesImplicitBounds;
}

- (void)charon_reevaluateImplicitBounds
{
    [self charon_setupImplicitBoundaries];
}

// The reference bounds, inset, as a loop 1 pt outside them (7.0).
- (void)charon_setupImplicitBoundaries
{
    UIDynamicAnimator *context = [self charon_context];
    CGRect bounds = [context charon_referenceSystemBounds];
    if (CGRectIsNull(bounds))
        return;
    if (_implicitBoundsBody) {
        [context charon_removeBody:_implicitBoundsBody];
        _implicitBoundsBody = nil;
    }
    if (!_usesImplicitBounds)
        return;
    CGRect inset = UIEdgeInsetsInsetRect(bounds, _implicitBoundsInsets);
    CGPathRef path = CGPathCreateWithRect(CGRectMake(inset.origin.x - 1, inset.origin.y - 1, inset.size.width + 2, inset.size.height + 2), NULL);
    _implicitBoundsBody = charon_loop_body(context, charon_loop_vertices(path));
    CGPathRelease(path);
    [context charon_addBody:_implicitBoundsBody];
    [self charon_setCollisions:YES forBody:_implicitBoundsBody isEdge:YES];
    [context charon_tickle];
}

- (void)charon_addBoundary:(id)description identifier:(id<NSCopying>)identifier
{
    _boundaryPaths[identifier] = description;
    if (![self charon_isAssociated])
        return;
    UIDynamicAnimator *context = [self charon_context];
    CharonDynamicsBody *body = [self charon_bodyForBoundary:description];
    _boundaryBodies[identifier] = body;
    [context charon_addBody:body];
    [self charon_setCollisions:YES forBody:body isEdge:YES];
    [context charon_tickle];
}

// A boundary given an identifier already in use replaces the entry, and the body it had stays in the
// world (7.0).
- (void)addBoundaryWithIdentifier:(id<NSCopying>)identifier forPath:(UIBezierPath *)path
{
    if (!identifier || !path)
        return;
    [self charon_addBoundary:[path copy] identifier:identifier];
}

- (void)addBoundaryWithIdentifier:(id<NSCopying>)identifier fromPoint:(CGPoint)first toPoint:(CGPoint)second
{
    if (!identifier)
        return;
    [self charon_addBoundary:@[[NSValue valueWithCGPoint:first], [NSValue valueWithCGPoint:second]] identifier:identifier];
}

- (UIBezierPath *)boundaryWithIdentifier:(id<NSCopying>)identifier
{
    id description = identifier ? _boundaryPaths[identifier] : nil;
    if ([description isKindOfClass:[UIBezierPath class]])
        return [description copy];
    if (!description)
        return nil;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:[description[0] CGPointValue]];
    [path addLineToPoint:[description[1] CGPointValue]];
    return path;
}

- (NSArray *)boundaryIdentifiers
{
    return _boundaryPaths.count ? _boundaryPaths.allKeys : nil;
}

- (void)removeBoundaryWithIdentifier:(id<NSCopying>)identifier
{
    if (!identifier)
        return;
    CharonDynamicsBody *body = _boundaryBodies[identifier];
    UIDynamicAnimator *context = [self charon_context];
    if (body) {
        [self charon_setCollisions:NO forBody:body isEdge:YES];
        [context charon_removeBody:body];
        [_boundaryBodies removeObjectForKey:identifier];
    }
    [_boundaryPaths removeObjectForKey:identifier];
    [context charon_tickle];
}

- (void)removeAllBoundaries
{
    for (id identifier in [_boundaryPaths allKeys])
        [self removeBoundaryWithIdentifier:identifier];
}

#pragma mark Contacts

- (id)charon_boundaryIdentifierOfBody:(CharonDynamicsBody *)body found:(BOOL *)found
{
    *found = YES;
    if (body == _implicitBoundsBody)
        return nil;
    for (id identifier in _boundaryBodies) {
        if (_boundaryBodies[identifier] == body)
            return identifier;
    }
    *found = NO;
    return nil;
}

// A contact is this behavior's when one of its items is in it: with another of its items, with its
// reference bounds (identifier nil) or with one of its boundaries.
- (void)charon_report:(CharonDynamicsContact *)contact began:(BOOL)began
{
    NSArray *items = [self charon_items];
    id a = contact.bodyA.representedObject, b = contact.bodyB.representedObject;
    BOOL ownA = a && [items containsObject:a], ownB = b && [items containsObject:b];
    id<UICollisionBehaviorDelegate> delegate = _collisionDelegate;
    if (ownA && ownB) {
        if (began && _delegateBeganItems)
            [delegate collisionBehavior:self beganContactForItem:a withItem:b atPoint:contact.contactPoint];
        else if (!began && _delegateEndedItems)
            [delegate collisionBehavior:self endedContactForItem:a withItem:b];
        return;
    }
    if (!ownA && !ownB)
        return;
    id item = ownA ? a : b;
    BOOL found;
    id identifier = [self charon_boundaryIdentifierOfBody:ownA ? contact.bodyB : contact.bodyA found:&found];
    if (!found)
        return;
    if (began && _delegateBeganBoundary)
        [delegate collisionBehavior:self beganContactForItem:item withBoundaryIdentifier:identifier atPoint:contact.contactPoint];
    else if (!began && _delegateEndedBoundary)
        [delegate collisionBehavior:self endedContactForItem:item withBoundaryIdentifier:identifier];
}

- (void)charon_didBeginContact:(CharonDynamicsContact *)contact
{
    [self charon_report:contact began:YES];
}

- (void)charon_didEndContact:(CharonDynamicsContact *)contact
{
    [self charon_report:contact began:NO];
}

@end
