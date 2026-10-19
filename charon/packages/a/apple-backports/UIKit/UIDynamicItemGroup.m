#import <UIKit/UIKit.h>

// A group of dynamic items that moves as one (9.0). The group is itself a UIDynamicItem: its center is
// the middle of the union of its members' boxes at init, and moving or turning the group writes every
// member (facts/UIKit/UIFieldBehavior.md §12.1).
//
// In an animator the group is an ordinary item of the 7.0 API, so it gets one rectangle body of its
// union box at its center, and the animator's write-back of that body is what moves the members. 9.0's
// animator instead builds one compound body with a box per member and rounds the group's center and
// angle like a view's; the 7.0 animator API builds exactly one rectangle per item and exposes no way to
// give it more shapes, so a group here collides as its union box, weighs as that box, and is not
// rounded (facts/UIKit/UIFieldBehavior.md §12.5: 0.21 pt apart in free fall, up to 31 pt after a
// contact).

// The members' union box, from their current centers and bounds sizes; a member's own transform is not
// looked at (host listing of the group's union function; facts/UIKit/UIFieldBehavior.md §12.1).
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
    // Each member and its offset from the group's center at init, which the transform setter places
    // members by for the life of the group. Strong both ways, as the host's strongToStrongObjectsMapTable.
    NSMapTable *_itemsToOffsets;
    CGPoint _center;
    // Not initialised, as on the host: a new group reports the all-zero matrix, which the animator reads
    // as angle 0 (atan2(0, 0)), and its first write-back of angle 0 therefore sets every member's transform.
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
        // The name is the host's literal string, not NSInvalidArgumentException.
        if ([(id)item isKindOfClass:[UIDynamicItemGroup class]])
            [NSException raise:@"Invalid Argument" format:@"%@ cannot be initialized with items containing %@",
                               NSStringFromClass([self class]), NSStringFromClass([UIDynamicItemGroup class])];
        CGPoint center = item.center;
        [_itemsToOffsets setObject:[NSValue valueWithCGPoint:CGPointMake(center.x - _center.x, center.y - _center.y)] forKey:item];
    }
    return self;
}

// A group made with -init has no table, as the host's, and answers nil.
- (NSArray *)items
{
    return [[_itemsToOffsets keyEnumerator] allObjects];
}

// Recomputed from the members on every call, so it changes as the group turns.
- (CGRect)bounds
{
    CGRect united = charon_union_of_items(self.items);
    return CGRectMake(0, 0, united.size.width, united.size.height);
}

// The stored center: a member moved by itself does not move it.
- (CGPoint)center
{
    return _center;
}

// Moves every member by the change of the stored center, so a member moved by itself keeps its offset.
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

// Places every member at the stored center plus its init offset under the transform, translation
// included, and gives it the whole transform; the member's own previous transform is discarded.
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
