#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// The layout a collection view holds while it transitions between two layouts: every element it
// draws is the element of the layout it is coming from and the element of the layout it is going
// to, placed at transitionProgress between the two. What the host answers is measured under Mac
// Catalyst (macOS 27.0) with tests/backports/host/collectiontransition and
// tests/backports/host/presses against this file: the progress is the caller's own number and is
// bounded nowhere, the four element questions on the base layout name no element, and a cell that is
// only in one of the two layouts fades in or out across the transition.
@interface CharonTransitionPair : NSObject
@property (nonatomic, strong) UICollectionViewLayoutAttributes *from;
@property (nonatomic, strong) UICollectionViewLayoutAttributes *to;
@end

@implementation CharonTransitionPair
@synthesize from = _from;
@synthesize to = _to;
@end

@implementation UICollectionViewTransitionLayout {
@private
    UICollectionViewLayout *_currentLayout;
    UICollectionViewLayout *_nextLayout;
    CGFloat _transitionProgress;
}

// The key an element is matched on across the two layouts: its kind and its index path, so a
// header at 0-1 in one layout and the same header at 0-1 in the other is one element and not two.
static NSString *CharonTransitionKey(NSString *kind, NSIndexPath *path)
{
    return [NSString stringWithFormat:@"%@|%@", kind ?: @"", path];
}

static UICollectionViewLayoutAttributes *CharonBlend(UICollectionViewLayoutAttributes *from,
                                                    UICollectionViewLayoutAttributes *to,
                                                    CGFloat progress)
{
    // Both layouts have it: the element moves and resizes from where the one it comes from has it
    // to where the one it goes to has it. Only one has it: it is arriving or leaving, so it stays
    // where that layout puts it and fades across the transition, and is gone at either end.
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

// The keys a transition layout is coded under. The header names none, and a transition layout is
// never coded by an application, so these are the port's own and named after the properties.
static NSString *const CharonCurrentLayoutKey = @"currentLayout";
static NSString *const CharonNextLayoutKey = @"nextLayout";
static NSString *const CharonTransitionProgressKey = @"transitionProgress";

- (instancetype)initWithCurrentLayout:(UICollectionViewLayout *)currentLayout nextLayout:(UICollectionViewLayout *)nextLayout
{
    if ((self = [super init])) {
        _currentLayout = currentLayout;
        _nextLayout = nextLayout;
    }
    return self;
}

// A transition layout with no layout on either side of it: the two are what it interpolates
// between, so with none it has nothing to draw until it is given a pair.
- (instancetype)init
{
    if ((self = [super init]))
        ;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _currentLayout = [coder decodeObjectForKey:CharonCurrentLayoutKey];
        _nextLayout = [coder decodeObjectForKey:CharonNextLayoutKey];
        _transitionProgress = (CGFloat)[coder decodeDoubleForKey:CharonTransitionProgressKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_currentLayout forKey:CharonCurrentLayoutKey];
    [coder encodeObject:_nextLayout forKey:CharonNextLayoutKey];
    [coder encodeDouble:_transitionProgress forKey:CharonTransitionProgressKey];
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

// The progress is the caller's own number and is held as given: the host's transition layout keeps
// 2 when 2 is set and -1 when -1 is set, measured under Mac Catalyst by
// tests/backports/host/collectiontransition, and bounds it nowhere.
- (void)setTransitionProgress:(CGFloat)transitionProgress
{
    if (transitionProgress == _transitionProgress)
        return;
    _transitionProgress = transitionProgress;
    [self invalidateLayout];
}

// The animated keys are the collection view's own bookkeeping for the values it animates while a
// transition is running, and outside a running transition they keep nothing: the host answers 0 for
// every key, before and after an update, and the update moves nothing. Measured on the host and held
// by tests/backports/host/presses (the case "transition.set"), whose committed expectation the
// device test in the tree reads: progress 0.5, value 0.0, other 0.0.
//
// This port's transition drives the progress through the transitionProgress property instead, from
// UICollectionView+InteractiveTransition.m, so nothing here needs the keys to store anything and
// they are left answering as they do outside a transition.
- (void)updateValue:(CGFloat)value forAnimatedKey:(NSString *)key
{
}

- (CGFloat)valueForAnimatedKey:(NSString *)key
{
    return 0;
}

// The message a transition sends to both the layout it comes from and the one it goes to once the
// animation block is done, and it leaves the progress where the caller left it.
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

- (NSArray<UICollectionViewLayoutAttributes *> *)charon_attributesInRect:(CGRect)rect
{
    // Every element either layout draws in the rect, matched across the two by kind and index
    // path, so an element the transition adds or drops is placed and faded rather than missing.
    NSMutableDictionary *matched = [NSMutableDictionary dictionary];
    NSMutableArray *order = [NSMutableArray array];
    void (^take)(UICollectionViewLayout *, BOOL) = ^(UICollectionViewLayout *layout, BOOL current) {
        for (UICollectionViewLayoutAttributes *attributes in [layout layoutAttributesForElementsInRect:rect]) {
            NSString *key = CharonTransitionKey(attributes.representedElementKind, attributes.indexPath);
            CharonTransitionPair *pair = matched[key];
            if (!pair) {
                pair = [[CharonTransitionPair alloc] init];
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
    for (CharonTransitionPair *pair in order) {
        UICollectionViewLayoutAttributes *attributes = CharonBlend(pair.from, pair.to, _transitionProgress);
        if (attributes)
            [blended addObject:attributes];
    }
    return blended;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
    return [self charon_attributesInRect:rect];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self charon_attributesAtIndexPath:indexPath ofKind:nil];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    return [self charon_attributesAtIndexPath:indexPath ofKind:elementKind];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    return [self charon_attributesAtIndexPath:indexPath ofKind:elementKind];
}

// A cell carries no element kind of its own, so kind nil is the cell and a kind is a
// supplementary or decoration view of that kind.
- (UICollectionViewLayoutAttributes *)charon_attributesAtIndexPath:(NSIndexPath *)indexPath ofKind:(NSString *)kind
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
    return CharonBlend(from, to, _transitionProgress);
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
