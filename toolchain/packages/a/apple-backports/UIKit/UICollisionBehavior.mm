#import "RevenantDynamics.h"

@implementation UICollisionBehavior {
    BOOL _usesImplicitBounds;
    UIEdgeInsets _implicitBoundsInsets;
    RevenantDynamicsBody *_implicitBoundsBody;
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
    if (!(self = [super revenant_initPrimitive:YES]))
        return nil;
    [[self revenant_items] addObjectsFromArray:items ?: @[]];
    _collisionMode = UICollisionBehaviorModeEverything;
    _boundaryBodies = [NSMutableDictionary new];
    _boundaryPaths = [NSMutableDictionary new];
    return self;
}

- (NSArray *)items
{
    return [NSArray arrayWithArray:[self revenant_items]];
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
    if (![self revenant_isAssociated])
        return;
    UIDynamicAnimator *context = [self revenant_context];
    for (id<UIDynamicItem> item in [self revenant_items])
        [self revenant_setCollisions:YES forBody:[context revenant_bodyForItem:item] isEdge:NO];
    if (_implicitBoundsBody)
        [self revenant_setCollisions:YES forBody:_implicitBoundsBody isEdge:YES];
    for (RevenantDynamicsBody *body in _boundaryBodies.allValues)
        [self revenant_setCollisions:YES forBody:body isEdge:YES];
}

- (void)revenant_setCollisions:(BOOL)on forBody:(RevenantDynamicsBody *)body isEdge:(BOOL)edge
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
    [self revenant_changedParameterForBody:body];
}

- (void)revenant_addItem:(id<UIDynamicItem>)item
{
    [self revenant_setCollisions:YES forBody:[[self revenant_context] revenant_registerBodyForItem:item shape:RevenantDynamicsShapeBox] isEdge:NO];
}

- (void)revenant_removeBodyOfItem:(id<UIDynamicItem>)item
{
    [[self revenant_context] revenant_unregisterBodyForItem:item action:^(RevenantDynamicsBody *body) {
        [self revenant_setCollisions:NO forBody:body isEdge:NO];
    }];
}

- (void)addItem:(id<UIDynamicItem>)item
{
    if ([[self revenant_items] containsObject:item])
        return;
    [[self revenant_items] addObject:item];
    if ([self revenant_isAssociated])
        [self revenant_addItem:item];
}

- (void)removeItem:(id<UIDynamicItem>)item
{
    if (![[self revenant_items] containsObject:item])
        return;
    [self revenant_removeBodyOfItem:item];
    [[self revenant_items] removeObject:item];
}

- (void)revenant_associate
{
    [super revenant_associate];
    UIDynamicAnimator *context = [self revenant_context];
    int group = [context revenant_registerCollisionGroup];
    _groupVID = 1u << ((2 * group) & 31);
    _groupBID = 1u << ((2 * group + 1) & 31);
    if (_usesImplicitBounds)
        [context revenant_registerImplicitBounds];
    for (id<UIDynamicItem> item in [self revenant_items])
        [self revenant_addItem:item];
    [self revenant_setupImplicitBoundaries];
    for (id identifier in _boundaryPaths) {
        RevenantDynamicsBody *body = [self revenant_bodyForBoundary:_boundaryPaths[identifier]];
        _boundaryBodies[identifier] = body;
        [context revenant_addBody:body];
        [self revenant_setCollisions:YES forBody:body isEdge:YES];
    }
}

- (void)revenant_dissociate
{
    UIDynamicAnimator *context = [self revenant_context];
    [context revenant_unregisterCollisionGroup];
    if (_usesImplicitBounds)
        [context revenant_unregisterImplicitBounds];
    if (_implicitBoundsBody) {
        [context revenant_removeBody:_implicitBoundsBody];
        _implicitBoundsBody = nil;
    }
    for (RevenantDynamicsBody *body in _boundaryBodies.allValues)
        [context revenant_removeBody:body];
    [_boundaryBodies removeAllObjects];
    for (id<UIDynamicItem> item in [self revenant_items])
        [self revenant_removeBodyOfItem:item];
    [super revenant_dissociate];
}

#pragma mark Boundaries

struct RevenantFlattening {
    BOOL stop;
    CFMutableDataRef points;
};

static NSUInteger revenant_count(RevenantFlattening *state)
{
    return CFDataGetLength(state->points) / sizeof(CGPoint);
}

static CGPoint revenant_point(RevenantFlattening *state, NSUInteger index)
{
    return ((const CGPoint *)CFDataGetBytePtr(state->points))[index];
}

static void revenant_append(RevenantFlattening *state, CGPoint point)
{
    CFDataAppendBytes(state->points, (const UInt8 *)&point, sizeof point);
}

static CGPoint revenant_bezier(const CGPoint *controls, int count, float t)
{
    float u = 1.0f - t;
    if (count == 3)
        return CGPointMake(u * u * (float)controls[0].x + 2 * u * t * (float)controls[1].x + t * t * (float)controls[2].x,
                           u * u * (float)controls[0].y + 2 * u * t * (float)controls[1].y + t * t * (float)controls[2].y);
    return CGPointMake(u * u * u * (float)controls[0].x + 3 * u * u * t * (float)controls[1].x + 3 * u * t * t * (float)controls[2].x + t * t * t * (float)controls[3].x,
                       u * u * u * (float)controls[0].y + 3 * u * u * t * (float)controls[1].y + 3 * u * t * t * (float)controls[2].y + t * t * t * (float)controls[3].y);
}

static void revenant_flatten_curve(RevenantFlattening *state, const CGPoint *controls, int count)
{
    float length = 0;
    CGPoint previous = controls[0];
    for (int index = 1; index <= 10; index++) {
        CGPoint point = revenant_bezier(controls, count, index / 10.0f);
        length += hypotf((float)(point.x - previous.x), (float)(point.y - previous.y));
        previous = point;
    }
    int chords = MAX((int)(length / 10.0f), 1);
    for (int index = 0; index <= chords; index++)
        revenant_append(state, revenant_bezier(controls, count, MIN(MAX(index / (float)chords, 0.0f), 1.0f)));
}

static void revenant_flatten_element(void *info, const CGPathElement *element)
{
    RevenantFlattening *state = (RevenantFlattening *)info;
    if (state->stop)
        return;
    CGPoint controls[4];
    switch (element->type) {
    case kCGPathElementMoveToPoint:
        if (revenant_count(state))
            state->stop = YES;
        else
            revenant_append(state, element->points[0]);
        break;
    case kCGPathElementAddLineToPoint:
        revenant_append(state, element->points[0]);
        break;
    case kCGPathElementAddQuadCurveToPoint:
        controls[0] = revenant_count(state) ? revenant_point(state, revenant_count(state) - 1) : CGPointZero;
        controls[1] = element->points[0];
        controls[2] = element->points[1];
        revenant_flatten_curve(state, controls, 3);
        break;
    case kCGPathElementAddCurveToPoint:
        controls[0] = revenant_count(state) ? revenant_point(state, revenant_count(state) - 1) : CGPointZero;
        controls[1] = element->points[0];
        controls[2] = element->points[1];
        controls[3] = element->points[2];
        revenant_flatten_curve(state, controls, 4);
        break;
    case kCGPathElementCloseSubpath:
        if (revenant_count(state))
            revenant_append(state, revenant_point(state, 0));
        state->stop = YES;
        break;
    }
}

static NSData *revenant_loop_vertices(CGPathRef path)
{
    RevenantFlattening state = {NO, CFDataCreateMutable(NULL, 0)};
    CGPathApply(path, &state, revenant_flatten_element);
    NSMutableData *vertices = [NSMutableData data];
    NSUInteger kept = 0;
    for (NSUInteger index = 0; index < revenant_count(&state); index++) {
        CGPoint point = revenant_point(&state, index);
        b2Vec2 vertex((float)point.x * REVENANT_DYNAMICS_INVERSE_PTM, (float)point.y * REVENANT_DYNAMICS_INVERSE_PTM);
        if (kept && b2DistanceSquared(vertex, ((const b2Vec2 *)vertices.bytes)[kept - 1]) <= 1.42108547e-14f)
            continue;
        [vertices appendBytes:&vertex length:sizeof vertex];
        kept += 1;
    }
    const b2Vec2 *kept_vertices = (const b2Vec2 *)vertices.bytes;
    if (kept > 1) {
        while (kept >= 2 && b2DistanceSquared(kept_vertices[kept - 1], kept_vertices[0]) <= 1.42108547e-14f)
            kept -= 1;
    }
    vertices.length = kept < 2 ? 0 : kept * sizeof(b2Vec2);
    CFRelease(state.points);
    return vertices;
}

static RevenantDynamicsBody *revenant_loop_body(UIDynamicAnimator *context, NSData *vertices)
{
    if (vertices.length == 0)
        [NSException raise:NSInternalInconsistencyException format:@"invalid path for collision boundary"];
    return [context revenant_boundaryBodyWithLoop:(const b2Vec2 *)vertices.bytes count:(int32)(vertices.length / sizeof(b2Vec2))];
}

- (RevenantDynamicsBody *)revenant_bodyForBoundary:(id)description
{
    UIDynamicAnimator *context = [self revenant_context];
    if ([description isKindOfClass:[UIBezierPath class]])
        return revenant_loop_body(context, revenant_loop_vertices([description CGPath]));
    return [context revenant_boundaryBodyFromPoint:[description[0] CGPointValue] toPoint:[description[1] CGPointValue]];
}

- (BOOL)translatesReferenceBoundsIntoBoundary
{
    return _usesImplicitBounds;
}

- (void)setTranslatesReferenceBoundsIntoBoundary:(BOOL)translates
{
    [self revenant_setTranslates:translates insets:UIEdgeInsetsZero];
}

- (void)setTranslatesReferenceBoundsIntoBoundaryWithInsets:(UIEdgeInsets)insets
{
    [self revenant_setTranslates:YES insets:insets];
}

- (void)revenant_setTranslates:(BOOL)translates insets:(UIEdgeInsets)insets
{
    BOOL changed = translates != _usesImplicitBounds;
    _usesImplicitBounds = translates;
    _implicitBoundsInsets = insets;
    if (![self revenant_isAssociated])
        return;
    UIDynamicAnimator *context = [self revenant_context];
    if (changed) {
        if (translates)
            [context revenant_registerImplicitBounds];
        else
            [context revenant_unregisterImplicitBounds];
    }
    [self revenant_setupImplicitBoundaries];
}

- (BOOL)revenant_usesImplicitBounds
{
    return _usesImplicitBounds;
}

- (void)revenant_reevaluateImplicitBounds
{
    [self revenant_setupImplicitBoundaries];
}

- (void)revenant_setupImplicitBoundaries
{
    UIDynamicAnimator *context = [self revenant_context];
    CGRect bounds = [context revenant_referenceSystemBounds];
    if (CGRectIsNull(bounds))
        return;
    if (_implicitBoundsBody) {
        [context revenant_removeBody:_implicitBoundsBody];
        _implicitBoundsBody = nil;
    }
    if (!_usesImplicitBounds)
        return;
    CGRect inset = UIEdgeInsetsInsetRect(bounds, _implicitBoundsInsets);
    CGPathRef path = CGPathCreateWithRect(CGRectMake(inset.origin.x - 1, inset.origin.y - 1, inset.size.width + 2, inset.size.height + 2), NULL);
    _implicitBoundsBody = revenant_loop_body(context, revenant_loop_vertices(path));
    CGPathRelease(path);
    [context revenant_addBody:_implicitBoundsBody];
    [self revenant_setCollisions:YES forBody:_implicitBoundsBody isEdge:YES];
    [context revenant_tickle];
}

- (void)revenant_addBoundary:(id)description identifier:(id<NSCopying>)identifier
{
    _boundaryPaths[identifier] = description;
    if (![self revenant_isAssociated])
        return;
    UIDynamicAnimator *context = [self revenant_context];
    RevenantDynamicsBody *body = [self revenant_bodyForBoundary:description];
    _boundaryBodies[identifier] = body;
    [context revenant_addBody:body];
    [self revenant_setCollisions:YES forBody:body isEdge:YES];
    [context revenant_tickle];
}

- (void)addBoundaryWithIdentifier:(id<NSCopying>)identifier forPath:(UIBezierPath *)path
{
    if (!identifier || !path)
        return;
    [self revenant_addBoundary:[path copy] identifier:identifier];
}

- (void)addBoundaryWithIdentifier:(id<NSCopying>)identifier fromPoint:(CGPoint)first toPoint:(CGPoint)second
{
    if (!identifier)
        return;
    [self revenant_addBoundary:@[[NSValue valueWithCGPoint:first], [NSValue valueWithCGPoint:second]] identifier:identifier];
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
    RevenantDynamicsBody *body = _boundaryBodies[identifier];
    UIDynamicAnimator *context = [self revenant_context];
    if (body) {
        [self revenant_setCollisions:NO forBody:body isEdge:YES];
        [context revenant_removeBody:body];
        [_boundaryBodies removeObjectForKey:identifier];
    }
    [_boundaryPaths removeObjectForKey:identifier];
    [context revenant_tickle];
}

- (void)removeAllBoundaries
{
    for (id identifier in [_boundaryPaths allKeys])
        [self removeBoundaryWithIdentifier:identifier];
}

#pragma mark Contacts

- (id)revenant_boundaryIdentifierOfBody:(RevenantDynamicsBody *)body found:(BOOL *)found
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

- (void)revenant_report:(RevenantDynamicsContact *)contact began:(BOOL)began
{
    NSArray *items = [self revenant_items];
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
    id identifier = [self revenant_boundaryIdentifierOfBody:ownA ? contact.bodyB : contact.bodyA found:&found];
    if (!found)
        return;
    if (began && _delegateBeganBoundary)
        [delegate collisionBehavior:self beganContactForItem:item withBoundaryIdentifier:identifier atPoint:contact.contactPoint];
    else if (!began && _delegateEndedBoundary)
        [delegate collisionBehavior:self endedContactForItem:item withBoundaryIdentifier:identifier];
}

- (void)revenant_didBeginContact:(RevenantDynamicsContact *)contact
{
    [self revenant_report:contact began:YES];
}

- (void)revenant_didEndContact:(RevenantDynamicsContact *)contact
{
    [self revenant_report:contact began:NO];
}

@end
