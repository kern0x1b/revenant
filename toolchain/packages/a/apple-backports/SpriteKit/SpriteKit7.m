#import "CharonSpriteKit.h"
#include <fnmatch.h>

static NSString *const CharonSKInvalidArgument = @"NSInvalidArgumentException";
static NSString *const CharonSKNilNode = @"Attemped to add nil node";

static BOOL CharonSKNameMatches(NSString *name, NSString *pattern)
{
    return name != nil && fnmatch([pattern UTF8String], [name UTF8String], 0) == 0;
}

static CGAffineTransform CharonSKLocalTransform(SKNode *node)
{
    CGAffineTransform scale = CGAffineTransformMakeScale(node.xScale, node.yScale);
    CGAffineTransform rotation = CGAffineTransformMakeRotation(node.zRotation);
    CGAffineTransform place = CGAffineTransformMakeTranslation(node.position.x, node.position.y);
    return CGAffineTransformConcat(CGAffineTransformConcat(scale, rotation), place);
}

static CGAffineTransform CharonSKAbsoluteTransform(SKNode *node)
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    for (SKNode *current = node; current != nil; current = current.parent) {
        transform = CGAffineTransformConcat(transform, CharonSKLocalTransform(current));
    }
    return transform;
}

static CGAffineTransform CharonSKParentTransform(SKNode *node)
{
    return node.parent != nil ? CharonSKAbsoluteTransform(node.parent) : CGAffineTransformIdentity;
}

@implementation SKNode {
    NSString *_name;
    CGPoint _position;
    CGFloat _zPosition;
    CGFloat _zRotation;
    CGFloat _xScale;
    CGFloat _yScale;
    CGFloat _alpha;
    CGFloat _speed;
    BOOL _paused;
    BOOL _hidden;
    BOOL _userInteractionEnabled;
    NSMutableDictionary *_userData;
    NSMutableArray *_children;
    __weak SKNode *_parent;
}

+ (instancetype)node
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _xScale = 1;
        _yScale = 1;
        _alpha = 1;
        _speed = 1;
        _children = [NSMutableArray array];
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    _name = [name copy];
}

- (CGPoint)position
{
    return _position;
}

- (void)setPosition:(CGPoint)position
{
    _position = position;
}

- (CGFloat)zPosition
{
    return _zPosition;
}

- (void)setZPosition:(CGFloat)zPosition
{
    _zPosition = zPosition;
}

- (CGFloat)zRotation
{
    return _zRotation;
}

- (void)setZRotation:(CGFloat)zRotation
{
    _zRotation = zRotation;
}

- (CGFloat)xScale
{
    return _xScale;
}

- (void)setXScale:(CGFloat)xScale
{
    _xScale = xScale;
}

- (CGFloat)yScale
{
    return _yScale;
}

- (void)setYScale:(CGFloat)yScale
{
    _yScale = yScale;
}

- (void)setScale:(CGFloat)scale
{
    _xScale = scale;
    _yScale = scale;
}

- (CGFloat)alpha
{
    return _alpha;
}

- (void)setAlpha:(CGFloat)alpha
{
    _alpha = alpha;
}

- (CGFloat)speed
{
    return _speed;
}

- (void)setSpeed:(CGFloat)speed
{
    _speed = speed;
}

- (BOOL)isPaused
{
    return _paused;
}

- (void)setPaused:(BOOL)paused
{
    _paused = paused;
}

- (BOOL)isHidden
{
    return _hidden;
}

- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
}

- (BOOL)isUserInteractionEnabled
{
    return _userInteractionEnabled;
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
    _userInteractionEnabled = userInteractionEnabled;
}

- (NSMutableDictionary *)userData
{
    return _userData;
}

- (void)setUserData:(NSMutableDictionary *)userData
{
    _userData = userData;
}

- (SKNode *)parent
{
    return _parent;
}

- (NSArray *)children
{
    return [_children copy];
}

- (CGRect)frame
{
    return CGRectMake(_position.x, _position.y, 0, 0);
}

- (CGRect)calculateAccumulatedFrame
{
    CGRect accumulated = self.frame;
    CGAffineTransform local = CharonSKLocalTransform(self);
    for (SKNode *child in _children) {
        CGRect childFrame = CGRectApplyAffineTransform([child calculateAccumulatedFrame], local);
        if (CGRectIsEmpty(childFrame)) {
            continue;
        }
        accumulated = CGRectIsEmpty(accumulated) ? childFrame : CGRectUnion(accumulated, childFrame);
    }
    return accumulated;
}

- (NSString *)charon_describe
{
    CGRect accumulated = [self calculateAccumulatedFrame];
    return [NSString stringWithFormat:@"<%@> name:'%@' position:{%g, %g} scale:{%.2f, %.2f} accumulatedFrame:{{%g, %g}, {%g, %g}}",
            NSStringFromClass([self class]), _name, _position.x, _position.y, _xScale, _yScale,
            accumulated.origin.x, accumulated.origin.y, accumulated.size.width, accumulated.size.height];
}

- (void)insertChild:(SKNode *)node atIndex:(NSUInteger)index
{
    if (node == nil) {
        NSString *reason = [NSString stringWithFormat:@"Attemped to add nil node to parent: %@", [self charon_describe]];
        [[NSException exceptionWithName:CharonSKNilNode reason:reason userInfo:nil] raise];
    }
    if (node.parent != nil) {
        [NSException raise:CharonSKInvalidArgument format:@"Attempted to add a SKNode which already has a parent"];
    }
    for (SKNode *ancestor = self; ancestor != nil; ancestor = ancestor.parent) {
        if (ancestor == node) {
            [NSException raise:CharonSKInvalidArgument format:@"Attempted to add a SKNode that is this node or one of its ancestors"];
        }
    }
    [_children insertObject:node atIndex:index];
    node->_parent = self;
}

- (void)addChild:(SKNode *)node
{
    [self insertChild:node atIndex:_children.count];
}

- (void)removeChildrenInArray:(NSArray *)nodes
{
    for (SKNode *node in nodes) {
        if (node->_parent == self) {
            [_children removeObjectIdenticalTo:node];
            node->_parent = nil;
        }
    }
}

- (void)removeAllChildren
{
    for (SKNode *node in _children) {
        node->_parent = nil;
    }
    [_children removeAllObjects];
}

- (void)removeFromParent
{
    SKNode *parent = _parent;
    if (parent != nil) {
        [parent removeChildrenInArray:@[ self ]];
    }
}

- (NSArray *)charon_nodesMatchingPath:(NSString *)path
{
    if (path == nil) {
        return @[];
    }
    NSArray *components = [path componentsSeparatedByString:@"/"];
    NSUInteger count = components.count;
    NSMutableArray *current = [NSMutableArray arrayWithObject:self];
    BOOL descend = NO;
    for (NSUInteger i = 0; i < count; i++) {
        NSString *component = components[i];
        if (component.length == 0) {
            if (i == 0 && count > 1 && [components[1] length] > 0) {
                continue;
            }
            descend = YES;
            continue;
        }
        NSMutableArray *next = [NSMutableArray array];
        for (SKNode *node in current) {
            if ([component isEqualToString:@"."]) {
                [next addObject:node];
            } else if ([component isEqualToString:@".."]) {
                if (node.parent != nil) {
                    [next addObject:node.parent];
                }
            } else if (descend) {
                NSMutableArray *queue = [NSMutableArray arrayWithArray:node->_children];
                for (NSUInteger q = 0; q < queue.count; q++) {
                    SKNode *candidate = queue[q];
                    if (CharonSKNameMatches(candidate.name, component)) {
                        [next addObject:candidate];
                    }
                    [queue addObjectsFromArray:candidate->_children];
                }
            } else {
                for (SKNode *child in node->_children) {
                    if (CharonSKNameMatches(child.name, component)) {
                        [next addObject:child];
                    }
                }
            }
        }
        current = next;
        descend = NO;
    }
    if (descend) {
        return @[];
    }
    return current;
}

- (SKNode *)childNodeWithName:(NSString *)name
{
    NSArray *matches = [self charon_nodesMatchingPath:name];
    return matches.count > 0 ? matches[0] : nil;
}

- (void)enumerateChildNodesWithName:(NSString *)name usingBlock:(void (^)(SKNode *node, BOOL *stop))block
{
    BOOL stop = NO;
    for (SKNode *node in [self charon_nodesMatchingPath:name]) {
        block(node, &stop);
        if (stop) {
            break;
        }
    }
}

- (BOOL)inParentHierarchy:(SKNode *)parent
{
    if (parent == nil) {
        return NO;
    }
    for (SKNode *ancestor = _parent; ancestor != nil; ancestor = ancestor.parent) {
        if (ancestor == parent) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)containsPoint:(CGPoint)point
{
    return CGRectContainsPoint(self.frame, point);
}

- (NSArray *)nodesAtPoint:(CGPoint)point
{
    CGPoint absolute = CGPointApplyAffineTransform(point, CharonSKAbsoluteTransform(self));
    NSMutableArray *hits = [NSMutableArray array];
    NSMutableArray *queue = [NSMutableArray arrayWithArray:_children];
    for (NSUInteger q = 0; q < queue.count; q++) {
        SKNode *candidate = queue[q];
        CGPoint local = CGPointApplyAffineTransform(absolute, CGAffineTransformInvert(CharonSKParentTransform(candidate)));
        if ([candidate containsPoint:local]) {
            [hits addObject:candidate];
        }
        [queue addObjectsFromArray:candidate->_children];
    }
    return hits;
}

- (SKNode *)nodeAtPoint:(CGPoint)point
{
    NSArray *hits = [self nodesAtPoint:point];
    return hits.count > 0 ? hits.lastObject : self;
}

- (CGPoint)convertPoint:(CGPoint)point fromNode:(SKNode *)node
{
    CGPoint absolute = CGPointApplyAffineTransform(point, CharonSKAbsoluteTransform(node));
    return CGPointApplyAffineTransform(absolute, CGAffineTransformInvert(CharonSKAbsoluteTransform(self)));
}

- (CGPoint)convertPoint:(CGPoint)point toNode:(SKNode *)node
{
    return [node convertPoint:point fromNode:self];
}

- (BOOL)intersectsNode:(SKNode *)node
{
    CGRect mine = CGRectApplyAffineTransform([self calculateAccumulatedFrame], CharonSKParentTransform(self));
    CGRect theirs = CGRectApplyAffineTransform([node calculateAccumulatedFrame], CharonSKParentTransform(node));
    if (CGRectIsEmpty(mine) || CGRectIsEmpty(theirs)) {
        return NO;
    }
    return CGRectIntersectsRect(mine, theirs);
}

- (BOOL)isEqualToNode:(SKNode *)node
{
    return self == node;
}

@end
