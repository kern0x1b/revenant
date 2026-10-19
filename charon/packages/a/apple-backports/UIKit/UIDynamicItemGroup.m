#import <UIKit/UIKit.h>

static CGRect charon_union_of_items(NSArray *items)
{
    CGRect united = CGRectNull;
    for (id<UIDynamicItem> item in items) {
        CGPoint center = item.center;
        CGSize size = item.bounds.size;
        CGRect box = CGRectMake(center.x - size.width * 0.5, center.y - size.height * 0.5, size.width, size.height);
        united = CGRectIsNull(united) ? box : CGRectUnion(united, box);
    }
    return united;
}

@implementation UIDynamicItemGroup {
    NSMapTable *_itemsToOffsets;
    CGPoint _center;
    CGAffineTransform _transform;
}

- (instancetype)initWithItems:(NSArray *)items
{
    if (!(self = [super init]))
        return nil;
    _itemsToOffsets = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
    if (items.count == 0)
        return self;
    CGRect united = charon_union_of_items(items);
    _center = CGPointMake(united.origin.x + united.size.width * 0.5, united.origin.y + united.size.height * 0.5);
    for (id<UIDynamicItem> item in items) {
        if ([(id)item isKindOfClass:[UIDynamicItemGroup class]])
            [NSException raise:@"Invalid Argument" format:@"%@ cannot be initialized with items containing %@",
                               NSStringFromClass([self class]), NSStringFromClass([UIDynamicItemGroup class])];
        CGPoint center = item.center;
        [_itemsToOffsets setObject:[NSValue valueWithCGPoint:CGPointMake(center.x - _center.x, center.y - _center.y)] forKey:item];
    }
    return self;
}

- (NSArray *)items
{
    return [[_itemsToOffsets keyEnumerator] allObjects];
}

- (CGRect)bounds
{
    CGRect united = charon_union_of_items(self.items);
    return CGRectMake(0, 0, united.size.width, united.size.height);
}

- (CGPoint)center
{
    return _center;
}

- (void)setCenter:(CGPoint)center
{
    CGFloat dx = center.x - _center.x, dy = center.y - _center.y;
    for (id<UIDynamicItem> item in self.items) {
        CGPoint position = item.center;
        item.center = CGPointMake(position.x + dx, position.y + dy);
    }
    _center = center;
}

- (CGAffineTransform)transform
{
    return _transform;
}

- (void)setTransform:(CGAffineTransform)transform
{
    if (CGAffineTransformEqualToTransform(_transform, transform))
        return;
    _transform = transform;
    for (id<UIDynamicItem> item in self.items) {
        CGPoint offset = [[_itemsToOffsets objectForKey:item] CGPointValue];
        item.center = CGPointMake(_center.x + transform.a * offset.x + transform.c * offset.y + transform.tx,
                                  _center.y + transform.b * offset.x + transform.d * offset.y + transform.ty);
        item.transform = transform;
    }
}

@end
