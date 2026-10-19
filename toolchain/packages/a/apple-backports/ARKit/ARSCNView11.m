#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

__attribute__((used)) static Protocol *CharonEmitARSCNViewDelegate(void) { return @protocol(ARSCNViewDelegate); }

NS_ASSUME_NONNULL_BEGIN

@interface ARSCNView ()

@property (nonatomic, strong) NSMapTable<SCNNode *, ARAnchor *> *anchorsByNode;
@property (nonatomic, strong) NSMapTable<ARAnchor *, SCNNode *> *nodesByAnchor;

- (void)charon_resetAnchorMaps;

- (void)charon_placeAnchor:(ARAnchor *)anchor atNode:(SCNNode *)node;
- (void)charon_moveAnchor:(ARAnchor *)anchor toNode:(SCNNode *)node;
- (void)charon_removeAnchor:(ARAnchor *)anchor;

@end

@implementation ARSCNView

@synthesize anchorsByNode = _anchorsByNode;
@synthesize nodesByAnchor = _nodesByAnchor;
@synthesize session = _session;
@synthesize delegate = _delegate;
@synthesize automaticallyUpdatesLighting = _automaticallyUpdatesLighting;
@synthesize rendersCameraGrain = _rendersCameraGrain;
@synthesize rendersMotionBlur = _rendersMotionBlur;
@synthesize scene = _scene;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
        [self charon_resetAnchorMaps];
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        [self charon_resetAnchorMaps];
    return self;
}

- (void)charon_resetAnchorMaps
{
    _anchorsByNode = [NSMapTable weakToWeakObjectsMapTable];
    _nodesByAnchor = [NSMapTable weakToWeakObjectsMapTable];
}

- (void)charon_placeAnchor:(ARAnchor *)anchor atNode:(SCNNode *)node
{
    [self.anchorsByNode setObject:anchor forKey:node];
    [self.nodesByAnchor setObject:node forKey:anchor];
    if ([self.delegate respondsToSelector:@selector(renderer:didAddNode:forAnchor:)])
        [self.delegate renderer:self didAddNode:node forAnchor:anchor];
}

- (void)charon_moveAnchor:(ARAnchor *)anchor toNode:(SCNNode *)node
{
    SCNNode *was = [self.nodesByAnchor objectForKey:anchor];
    if ([self.delegate respondsToSelector:@selector(renderer:willUpdateNode:forAnchor:)])
        [self.delegate renderer:self willUpdateNode:was ?: node forAnchor:anchor];
    [self.anchorsByNode setObject:anchor forKey:node];
    [self.nodesByAnchor setObject:node forKey:anchor];
    if ([self.delegate respondsToSelector:@selector(renderer:didUpdateNode:forAnchor:)])
        [self.delegate renderer:self didUpdateNode:node forAnchor:anchor];
}

- (void)charon_removeAnchor:(ARAnchor *)anchor
{
    SCNNode *node = [self.nodesByAnchor objectForKey:anchor];
    if (node)
        [self.anchorsByNode removeObjectForKey:node];
    [self.nodesByAnchor removeObjectForKey:anchor];
    if (node && [self.delegate respondsToSelector:@selector(renderer:didRemoveNode:forAnchor:)])
        [self.delegate renderer:self didRemoveNode:node forAnchor:anchor];
}

- (nullable ARAnchor *)anchorForNode:(SCNNode *)node
{
    for (SCNNode *walk = node; walk; walk = walk.parentNode) {
        ARAnchor *anchor = [self.anchorsByNode objectForKey:walk];
        if (anchor)
            return anchor;
    }
    return nil;
}

- (nullable SCNNode *)nodeForAnchor:(ARAnchor *)anchor
{
    SCNNode *node = [self.nodesByAnchor objectForKey:anchor];
    if (node)
        return node;
    if ([self.delegate respondsToSelector:@selector(renderer:nodeForAnchor:)]) {
        node = [self.delegate renderer:self nodeForAnchor:anchor];
        if (node)
            [self charon_placeAnchor:anchor atNode:node];
    }
    return node;
}

- (NSArray<ARHitTestResult *> *)hitTest:(CGPoint)point types:(ARHitTestResultType)types
{
    return [self.session.currentFrame hitTest:point types:types];
}

- (nullable ARRaycastQuery *)raycastQueryFromPoint:(CGPoint)point
                                    allowingTarget:(ARRaycastTarget)target
                                          alignment:(ARRaycastTargetAlignment)alignment
{
    return [self.session.currentFrame raycastQueryFromPoint:point
                                             allowingTarget:target
                                                   alignment:alignment];
}

@end

NS_ASSUME_NONNULL_END
