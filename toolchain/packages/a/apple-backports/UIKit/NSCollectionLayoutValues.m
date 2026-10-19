#import "RevenantCompositionalLayout.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

static NSUInteger revenant_float_hash(CGFloat value)
{
    double widened = value;
    NSUInteger bits[2] = {0, 0};
    memcpy(bits, &widened, MIN(sizeof(widened), sizeof(bits)));
    return bits[0] ^ (sizeof(widened) > sizeof(bits[0]) ? bits[1] * 31 : 0);
}

@implementation NSCollectionLayoutDimension {
@private
    RevenantDimensionKind _kind;
    CGFloat _value;
}

- (instancetype)initRevenantWithKind:(RevenantDimensionKind)kind value:(CGFloat)value
{
    if ((self = [super init])) {
        _kind = kind;
        _value = value;
    }
    return self;
}

+ (instancetype)fractionalWidthDimension:(CGFloat)fractionalWidth
{
    if (!isfinite(fractionalWidth))
        [NSException raise:NSInternalInconsistencyException format:@"Invalid fractional width: %g. The fraction must be a finite value.", (double)fractionalWidth];
    return [[self alloc] initRevenantWithKind:RevenantDimensionKindFractionalWidth value:fractionalWidth];
}

+ (instancetype)fractionalHeightDimension:(CGFloat)fractionalHeight
{
    if (!isfinite(fractionalHeight))
        [NSException raise:NSInternalInconsistencyException format:@"Invalid fractional height: %g. The fraction must be a finite value.", (double)fractionalHeight];
    return [[self alloc] initRevenantWithKind:RevenantDimensionKindFractionalHeight value:fractionalHeight];
}

+ (instancetype)absoluteDimension:(CGFloat)absoluteDimension
{
    if (!isfinite(absoluteDimension))
        [NSException raise:NSInternalInconsistencyException format:@"Invalid absolute dimension: %g. The dimension must be a finite value.", (double)absoluteDimension];
    return [[self alloc] initRevenantWithKind:RevenantDimensionKindAbsolute value:absoluteDimension];
}

+ (instancetype)estimatedDimension:(CGFloat)estimatedDimension
{
    if (!isfinite(estimatedDimension))
        [NSException raise:NSInternalInconsistencyException format:@"Invalid estimated dimension: %g. The dimension must be a finite value.", (double)estimatedDimension];
    return [[self alloc] initRevenantWithKind:RevenantDimensionKindEstimated value:estimatedDimension];
}

- (BOOL)isFractionalWidth
{
    return _kind == RevenantDimensionKindFractionalWidth;
}

- (BOOL)isFractionalHeight
{
    return _kind == RevenantDimensionKindFractionalHeight;
}

- (BOOL)isAbsolute
{
    return _kind == RevenantDimensionKindAbsolute;
}

- (BOOL)isEstimated
{
    return _kind == RevenantDimensionKindEstimated;
}

- (CGFloat)dimension
{
    return _value;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initRevenantWithKind:_kind value:_value];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSCollectionLayoutDimension class]])
        return NO;
    NSCollectionLayoutDimension *other = object;
    return other->_kind == _kind && other->_value == _value;
}

- (NSUInteger)hash
{
    return (NSUInteger)_kind * 1000003 ^ revenant_float_hash(_value);
}

@end

static NSString *revenant_dimension_text(NSCollectionLayoutDimension *dimension)
{
    if (dimension.isFractionalWidth)
        return [NSString stringWithFormat:@".containerWidthFactor(%g)", (double)dimension.dimension];
    if (dimension.isFractionalHeight)
        return [NSString stringWithFormat:@".containerHeightFactor(%g)", (double)dimension.dimension];
    if (dimension.isEstimated)
        return [NSString stringWithFormat:@".estimated(%g)", (double)dimension.dimension];
    return [NSString stringWithFormat:@".absolute(%g)", (double)dimension.dimension];
}

@implementation NSCollectionLayoutSize {
@private
    NSCollectionLayoutDimension *_width;
    NSCollectionLayoutDimension *_height;
}

- (instancetype)initRevenantWithWidth:(NSCollectionLayoutDimension *)width height:(NSCollectionLayoutDimension *)height
{
    if ((self = [super init])) {
        _width = width ?: [NSCollectionLayoutDimension absoluteDimension:0];
        _height = height ?: [NSCollectionLayoutDimension absoluteDimension:0];
    }
    return self;
}

- (instancetype)init
{
    return [self initRevenantWithWidth:nil height:nil];
}

+ (instancetype)sizeWithWidthDimension:(NSCollectionLayoutDimension *)width heightDimension:(NSCollectionLayoutDimension *)height
{
    return [[self alloc] initRevenantWithWidth:width height:height];
}

- (NSCollectionLayoutDimension *)widthDimension
{
    return _width;
}

- (NSCollectionLayoutDimension *)heightDimension
{
    return _height;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initRevenantWithWidth:_width height:_height];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSCollectionLayoutSize class]])
        return NO;
    NSCollectionLayoutSize *other = object;
    return [other->_width isEqual:_width] && [other->_height isEqual:_height];
}

- (NSUInteger)hash
{
    return [_width hash] * 31 ^ [_height hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{%@, %@}", revenant_dimension_text(_width), revenant_dimension_text(_height)];
}

@end

@implementation NSCollectionLayoutSpacing {
@private
    CGFloat _spacing;
    BOOL _flexible;
}

- (instancetype)initRevenantWithSpacing:(CGFloat)spacing flexible:(BOOL)flexible
{
    if ((self = [super init])) {
        _spacing = spacing;
        _flexible = flexible;
    }
    return self;
}

+ (instancetype)flexibleSpacing:(CGFloat)flexibleSpacing
{
    return [[self alloc] initRevenantWithSpacing:flexibleSpacing flexible:YES];
}

+ (instancetype)fixedSpacing:(CGFloat)fixedSpacing
{
    return [[self alloc] initRevenantWithSpacing:fixedSpacing flexible:NO];
}

- (CGFloat)spacing
{
    return _spacing;
}

- (BOOL)isFlexibleSpacing
{
    return _flexible;
}

- (BOOL)isFixedSpacing
{
    return !_flexible;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initRevenantWithSpacing:_spacing flexible:_flexible];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSCollectionLayoutSpacing class]])
        return NO;
    NSCollectionLayoutSpacing *other = object;
    return other->_flexible == _flexible && other->_spacing == _spacing;
}

- (NSUInteger)hash
{
    return revenant_float_hash(_spacing) ^ (_flexible ? 0x5bd1e995 : 0);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<NSCollectionLayoutSpacing - %p: %@:%g>", self, _flexible ? @"flexible" : @"fixed", (double)_spacing];
}

@end

@implementation NSCollectionLayoutEdgeSpacing {
@private
    NSCollectionLayoutSpacing *_leading;
    NSCollectionLayoutSpacing *_top;
    NSCollectionLayoutSpacing *_trailing;
    NSCollectionLayoutSpacing *_bottom;
}

+ (instancetype)spacingForLeading:(NSCollectionLayoutSpacing *)leading top:(NSCollectionLayoutSpacing *)top trailing:(NSCollectionLayoutSpacing *)trailing
                           bottom:(NSCollectionLayoutSpacing *)bottom
{
    NSCollectionLayoutEdgeSpacing *spacing = [[self alloc] init];
    spacing->_leading = leading;
    spacing->_top = top;
    spacing->_trailing = trailing;
    spacing->_bottom = bottom;
    return spacing;
}

- (NSCollectionLayoutSpacing *)leading
{
    return _leading;
}

- (NSCollectionLayoutSpacing *)top
{
    return _top;
}

- (NSCollectionLayoutSpacing *)trailing
{
    return _trailing;
}

- (NSCollectionLayoutSpacing *)bottom
{
    return _bottom;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] spacingForLeading:[_leading copy] top:[_top copy] trailing:[_trailing copy] bottom:[_bottom copy]];
}

static BOOL revenant_same(id a, id b)
{
    return a == b || (a && b && [a isEqual:b]);
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSCollectionLayoutEdgeSpacing class]])
        return NO;
    NSCollectionLayoutEdgeSpacing *other = object;
    return revenant_same(other->_leading, _leading) && revenant_same(other->_top, _top) && revenant_same(other->_trailing, _trailing) && revenant_same(other->_bottom, _bottom);
}

- (NSUInteger)hash
{
    return [_leading hash] ^ [_top hash] * 3 ^ [_trailing hash] * 5 ^ [_bottom hash] * 7;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<leading=%@; top=%@; trailing=%@; bottom=%@; outsets=@{%g,%g,%g,%g}>", _leading, _top, _trailing, _bottom,
                                      (double)_top.spacing, (double)_trailing.spacing, (double)_bottom.spacing, (double)_leading.spacing];
}

@end

@implementation NSCollectionLayoutAnchor {
@private
    NSDirectionalRectEdge _edges;
    CGPoint _offset;
    BOOL _absolute;
}

+ (instancetype)anchorWithEdges:(NSDirectionalRectEdge)edges offset:(CGPoint)offset absolute:(BOOL)absolute
{
    NSCollectionLayoutAnchor *anchor = [[self alloc] init];
    anchor->_edges = edges;
    anchor->_offset = offset;
    anchor->_absolute = absolute;
    return anchor;
}

+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges
{
    return [self anchorWithEdges:edges offset:CGPointZero absolute:YES];
}

+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges absoluteOffset:(CGPoint)absoluteOffset
{
    return [self anchorWithEdges:edges offset:absoluteOffset absolute:YES];
}

+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges fractionalOffset:(CGPoint)fractionalOffset
{
    return [self anchorWithEdges:edges offset:fractionalOffset absolute:NO];
}

- (NSDirectionalRectEdge)edges
{
    return _edges;
}

- (CGPoint)offset
{
    return _offset;
}

- (BOOL)isAbsoluteOffset
{
    return _absolute;
}

- (BOOL)isFractionalOffset
{
    return !_absolute;
}

- (CGPoint)revenant_anchorPoint
{
    BOOL leading = (_edges & NSDirectionalRectEdgeLeading) != 0, trailing = (_edges & NSDirectionalRectEdgeTrailing) != 0;
    BOOL top = (_edges & NSDirectionalRectEdgeTop) != 0, bottom = (_edges & NSDirectionalRectEdgeBottom) != 0;
    CGFloat x = (leading == trailing) ? 0.5 : (leading ? 0 : 1);
    CGFloat y = (top == bottom) ? 0.5 : (top ? 0 : 1);
    return CGPointMake(x, y);
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] anchorWithEdges:_edges offset:_offset absolute:_absolute];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSCollectionLayoutAnchor class]])
        return NO;
    NSCollectionLayoutAnchor *other = object;
    return other->_edges == _edges && other->_absolute == _absolute && CGPointEqualToPoint(other->_offset, _offset);
}

- (NSUInteger)hash
{
    return (NSUInteger)_edges * 31 ^ revenant_float_hash(_offset.x) ^ revenant_float_hash(_offset.y) * 7 ^ (_absolute ? 1 : 0);
}

- (NSString *)description
{
    CGPoint point = [self revenant_anchorPoint];
    return [NSString stringWithFormat:@"<NSCollectionLayoutAnchor %p: edges=%lu; offset={%g, %g}; anchorPoint={%g, %g}>", self, (unsigned long)_edges, (double)_offset.x,
                                      (double)_offset.y, (double)point.x, (double)point.y];
}

@end

@implementation NSCollectionLayoutGroupCustomItem {
@private
    CGRect _frame;
    NSInteger _zIndex;
}

+ (instancetype)customItemWithFrame:(CGRect)frame
{
    return [self customItemWithFrame:frame zIndex:0];
}

+ (instancetype)customItemWithFrame:(CGRect)frame zIndex:(NSInteger)zIndex
{
    NSCollectionLayoutGroupCustomItem *item = [[self alloc] init];
    item->_frame = frame;
    item->_zIndex = zIndex;
    return item;
}

- (CGRect)frame
{
    return _frame;
}

- (NSInteger)zIndex
{
    return _zIndex;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] customItemWithFrame:_frame zIndex:_zIndex];
}

@end
