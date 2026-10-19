#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface RevenantTransitionPair : NSObject
@property (nonatomic, strong) UICollectionViewLayoutAttributes *from;
@property (nonatomic, strong) UICollectionViewLayoutAttributes *to;
@end

@implementation RevenantTransitionPair
@synthesize from = _from;
@synthesize to = _to;
@end

@implementation UICollectionViewTransitionLayout {
@private
    UICollectionViewLayout *_currentLayout;
    UICollectionViewLayout *_nextLayout;
    CGFloat _transitionProgress;
}

static NSString *RevenantTransitionKey(NSString *kind, NSIndexPath *path)
{
    return [NSString stringWithFormat:@"%@|%@", kind ?: @"", path];
}

static UICollectionViewLayoutAttributes *RevenantBlend(UICollectionViewLayoutAttributes *from,
                                                    UICollectionViewLayoutAttributes *to,
                                                    CGFloat progress)
{
    if (!from || !to) {
        UICollectionViewLayoutAttributes *only = from ?: to;
        CGFloat alpha = only.alpha * (from ? 1 - progress : progress);
        if (alpha <= 0)
            return nil;
        UICollectionViewLayoutAttributes *attributes = [only copy];
        attributes.alpha = alpha;
        return attributes;
    }
    UICollectionViewLayoutAttributes *attributes = [to copy];
    CGRect start = from.frame, end = to.frame;
    attributes.frame = CGRectMake(start.origin.x + (end.origin.x - start.origin.x) * progress,
                                  start.origin.y + (end.origin.y - start.origin.y) * progress,
                                  start.size.width + (end.size.width - start.size.width) * progress,
                                  start.size.height + (end.size.height - start.size.height) * progress);
    attributes.alpha = from.alpha + (to.alpha - from.alpha) * progress;
    attributes.zIndex = MAX(from.zIndex, to.zIndex);
    return attributes;
}

static NSString *const RevenantCurrentLayoutKey = @"currentLayout";
static NSString *const RevenantNextLayoutKey = @"nextLayout";
static NSString *const RevenantTransitionProgressKey = @"transitionProgress";

- (instancetype)initWithCurrentLayout:(UICollectionViewLayout *)currentLayout nextLayout:(UICollectionViewLayout *)nextLayout
{
    if ((self = [super init])) {
        _currentLayout = currentLayout;
        _nextLayout = nextLayout;
    }
    return self;
}

- (instancetype)init
{
    if ((self = [super init]))
        ;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _currentLayout = [coder decodeObjectForKey:RevenantCurrentLayoutKey];
        _nextLayout = [coder decodeObjectForKey:RevenantNextLayoutKey];
        _transitionProgress = (CGFloat)[coder decodeDoubleForKey:RevenantTransitionProgressKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_currentLayout forKey:RevenantCurrentLayoutKey];
    [coder encodeObject:_nextLayout forKey:RevenantNextLayoutKey];
    [coder encodeDouble:_transitionProgress forKey:RevenantTransitionProgressKey];
}

- (UICollectionViewLayout *)currentLayout
{
    return _currentLayout;
}

- (UICollectionViewLayout *)nextLayout
{
    return _nextLayout;
}

- (CGFloat)transitionProgress
{
    return _transitionProgress;
}

- (void)setTransitionProgress:(CGFloat)transitionProgress
{
    if (transitionProgress == _transitionProgress)
        return;
    _transitionProgress = transitionProgress;
    [self invalidateLayout];
}

- (void)updateValue:(CGFloat)value forAnimatedKey:(NSString *)key
{
}

- (CGFloat)valueForAnimatedKey:(NSString *)key
{
    return 0;
}

- (void)finalizeLayoutTransition
{
    [_currentLayout finalizeLayoutTransition];
    [_nextLayout finalizeLayoutTransition];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (CGSize)collectionViewContentSize
{
    CGSize start = _currentLayout.collectionViewContentSize, end = _nextLayout.collectionViewContentSize;
    return CGSizeMake(start.width + (end.width - start.width) * _transitionProgress,
                      start.height + (end.height - start.height) * _transitionProgress);
}

- (NSArray<UICollectionViewLayoutAttributes *> *)revenant_attributesInRect:(CGRect)rect
{
    NSMutableDictionary *matched = [NSMutableDictionary dictionary];
    NSMutableArray *order = [NSMutableArray array];
    void (^take)(UICollectionViewLayout *, BOOL) = ^(UICollectionViewLayout *layout, BOOL current) {
        for (UICollectionViewLayoutAttributes *attributes in [layout layoutAttributesForElementsInRect:rect]) {
            NSString *key = RevenantTransitionKey(attributes.representedElementKind, attributes.indexPath);
            RevenantTransitionPair *pair = matched[key];
            if (!pair) {
                pair = [[RevenantTransitionPair alloc] init];
                matched[key] = pair;
                [order addObject:pair];
            }
            if (current)
                pair.from = attributes;
            else
                pair.to = attributes;
        }
    };
    take(_currentLayout, YES);
    take(_nextLayout, NO);
    NSMutableArray *blended = [NSMutableArray arrayWithCapacity:order.count];
    for (RevenantTransitionPair *pair in order) {
        UICollectionViewLayoutAttributes *attributes = RevenantBlend(pair.from, pair.to, _transitionProgress);
        if (attributes)
            [blended addObject:attributes];
    }
    return blended;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
    return [self revenant_attributesInRect:rect];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self revenant_attributesAtIndexPath:indexPath ofKind:nil];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    return [self revenant_attributesAtIndexPath:indexPath ofKind:elementKind];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    return [self revenant_attributesAtIndexPath:indexPath ofKind:elementKind];
}

- (UICollectionViewLayoutAttributes *)revenant_attributesAtIndexPath:(NSIndexPath *)indexPath ofKind:(NSString *)kind
{
    if (!indexPath)
        return nil;
    UICollectionViewLayoutAttributes *from = nil, *to = nil;
    if (kind) {
        from = [_currentLayout layoutAttributesForSupplementaryViewOfKind:kind atIndexPath:indexPath];
        to = [_nextLayout layoutAttributesForSupplementaryViewOfKind:kind atIndexPath:indexPath];
    } else {
        from = [_currentLayout layoutAttributesForItemAtIndexPath:indexPath];
        to = [_nextLayout layoutAttributesForItemAtIndexPath:indexPath];
    }
    if (!from && !to)
        return nil;
    return RevenantBlend(from, to, _transitionProgress);
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [_nextLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (!attributes)
        return nil;
    attributes = [attributes copy];
    attributes.alpha = 0;
    return attributes;
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [_currentLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (!attributes)
        return nil;
    attributes = [attributes copy];
    attributes.alpha = 0;
    return attributes;
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [_nextLayout layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
    if (!attributes)
        return nil;
    attributes = [attributes copy];
    attributes.alpha = 0;
    return attributes;
}

- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForDisappearingSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [_currentLayout layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
    if (!attributes)
        return nil;
    attributes = [attributes copy];
    attributes.alpha = 0;
    return attributes;
}

@end
