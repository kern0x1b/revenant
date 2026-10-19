#import "CharonCompositionalLayout.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat CharonDecelerationPerMillisecond = 0.998;
static const CGFloat CharonSpringFrequency = 14;

@interface CharonCollectionLayoutVisibleItem : NSObject <NSCollectionLayoutVisibleItem> {
@public
    CGRect _frame;
    CGRect _bounds;
    CGPoint _baseCenter;
    CGPoint _center;
    CGFloat _alpha;
    NSInteger _zIndex;
    BOOL _hidden;
    CGAffineTransform _transform;
    CATransform3D _transform3D;
    NSString *_name;
    NSIndexPath *_indexPath;
    UICollectionElementCategory _category;
    NSString *_kind;
}
@end

@implementation CharonCollectionLayoutVisibleItem

- (CGFloat)alpha { return _alpha; }
- (void)setAlpha:(CGFloat)alpha { _alpha = alpha; }
- (NSInteger)zIndex { return _zIndex; }
- (void)setZIndex:(NSInteger)zIndex { _zIndex = zIndex; }
- (BOOL)isHidden { return _hidden; }
- (void)setHidden:(BOOL)hidden { _hidden = hidden; }
- (CGPoint)center { return _center; }
- (void)setCenter:(CGPoint)center { _center = center; }
- (CGAffineTransform)transform { return _transform; }
- (void)setTransform:(CGAffineTransform)transform { _transform = transform; _transform3D = CATransform3DMakeAffineTransform(transform); }
- (CATransform3D)transform3D { return _transform3D; }
- (void)setTransform3D:(CATransform3D)transform3D { _transform3D = transform3D; _transform = CATransform3DGetAffineTransform(transform3D); }
- (NSString *)name { return _name; }
- (NSIndexPath *)indexPath { return _indexPath; }
- (CGRect)frame { return CGRectOffset(_frame, _center.x - _baseCenter.x, _center.y - _baseCenter.y); }
- (CGRect)bounds { return _bounds; }
- (UICollectionElementCategory)representedElementCategory { return _category; }
- (NSString *)representedElementKind { return _kind; }

@end

@implementation CharonOrthogonalController {
@private
    __weak UICollectionViewLayout *_layout;
    __weak UICollectionView *_view;
    NSArray *_sections;
    NSMutableDictionary *_offsets;
    NSMutableDictionary *_visible;
    UIPanGestureRecognizer *_pan;
    CADisplayLink *_link;
    id<NSCollectionLayoutEnvironment> _environment;
    NSInteger _active;
    CGFloat _dragStart;
    CGFloat _velocity;
    CGFloat _target;
    BOOL _spring;
    CFTimeInterval _last;
}

- (instancetype)initWithLayout:(UICollectionViewLayout *)layout
{
    if ((self = [super init])) {
        _layout = layout;
        _offsets = [NSMutableDictionary dictionary];
        _visible = [NSMutableDictionary dictionary];
        _active = -1;
    }
    return self;
}

- (CharonSolvedSection *)solvedForSection:(NSInteger)section
{
    for (CharonSolvedSection *solved in _sections) {
        if (solved->section == section)
            return solved;
    }
    return nil;
}

- (CGFloat)centeringOf:(CharonSolvedSection *)solved atGroup:(NSUInteger)index
{
    NSArray *widths = solved->groupWidths;
    CGFloat width = index < widths.count ? [widths[index] doubleValue] : 0;
    return (solved->viewport.size.width - width) / 2;
}

- (CGFloat)minimumOf:(CharonSolvedSection *)solved
{
    if (solved->behavior == UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered && solved->contentWidth > 0)
        return -[self centeringOf:solved atGroup:0];
    return 0;
}

- (CGFloat)maximumOf:(CharonSolvedSection *)solved
{
    CGFloat viewport = solved->viewport.size.width;
    CGFloat edge = 0;
    if (solved->behavior == UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered && solved->groupWidths.count > 0)
        edge = [self centeringOf:solved atGroup:solved->groupWidths.count - 1];
    return MAX([self minimumOf:solved], solved->contentWidth - viewport + edge);
}

- (BOOL)scrollable:(CharonSolvedSection *)solved
{
    return [self maximumOf:solved] > [self minimumOf:solved];
}

- (NSArray *)snapsOf:(CharonSolvedSection *)solved
{
    CGFloat low = [self minimumOf:solved], high = [self maximumOf:solved];
    NSMutableArray *snaps = [NSMutableArray array];
    NSArray *leads = solved->groupLeads;
    switch (solved->behavior) {
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary:
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPaging:
        for (NSNumber *lead in leads)
            [snaps addObject:@(MIN(MAX(lead.doubleValue, low), high))];
        break;
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging: {
        CGFloat page = solved->viewport.size.width;
        for (CGFloat at = 0; page > 0 && at < high + page; at += page)
            [snaps addObject:@(MIN(MAX(at, low), high))];
        break;
    }
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered:
        for (NSUInteger index = 0; index < leads.count; index++)
            [snaps addObject:@(MIN(MAX([leads[index] doubleValue] - [self centeringOf:solved atGroup:index], low), high))];
        break;
    default:
        break;
    }
    return snaps;
}

- (CGFloat)nearestSnap:(CGFloat)offset of:(CharonSolvedSection *)solved
{
    CGFloat best = offset, distance = CGFLOAT_MAX;
    if (solved->behavior == UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging && solved->viewport.size.width > 0) {
        CGFloat page = solved->viewport.size.width;
        if (offset >= [self maximumOf:solved])
            return [self maximumOf:solved];
        return MIN(MAX(floor(offset / page + 0.5) * page, [self minimumOf:solved]), [self maximumOf:solved]);
    }
    for (NSNumber *snap in [self snapsOf:solved]) {
        CGFloat d = fabs(snap.doubleValue - offset);
        if (d < distance) {
            distance = d;
            best = snap.doubleValue;
        }
    }
    return best;
}

- (CGFloat)offsetOfSection:(NSInteger)section
{
    return [_offsets[@(section)] doubleValue];
}

- (CGRect)shiftedFrame:(CGRect)frame section:(NSInteger)section
{
    return CGRectOffset(frame, -[self offsetOfSection:section], 0);
}

- (BOOL)viewportShows:(CGRect)shifted section:(NSInteger)section
{
    CharonSolvedSection *solved = [self solvedForSection:section];
    return solved && CGRectIntersectsRect(shifted, solved->extent);
}

- (NSString *)keyFor:(CharonSolvedElement *)element
{
    return [NSString stringWithFormat:@"%ld/%@/%ld/%ld", (long)element->category, element->kind ?: @"", (long)element->indexPath.section, (long)element->indexPath.item];
}

- (void)runHandlerFor:(CharonSolvedSection *)solved
{
    NSCollectionLayoutSectionVisibleItemsInvalidationHandler handler = solved->handler;
    NSMutableArray *stale = [NSMutableArray array];
    NSMutableDictionary *previous = [NSMutableDictionary dictionary];
    for (NSString *key in _visible) {
        CharonCollectionLayoutVisibleItem *old = _visible[key];
        if (old->_indexPath.section == solved->section) {
            [stale addObject:key];
            previous[key] = old;
        }
    }
    [_visible removeObjectsForKeys:stale];
    if (!handler)
        return;
    CGFloat offset = [self offsetOfSection:solved->section];
    NSMutableArray *items = [NSMutableArray array];
    NSMutableArray *ordered = [NSMutableArray array];
    for (NSInteger rank = 0; rank < 3; rank++) {
        for (CharonSolvedElement *element in solved->elements) {
            BOOL supplementary = element->category == 1;
            BOOL base = element->scrolls && element->frame.origin.x < solved->extent.origin.x + solved->extent.size.width && CGRectGetMaxX(element->frame) > solved->extent.origin.x;
            NSInteger mine = supplementary ? 1 : (base ? 0 : 2);
            if (element->category != 2 && mine == rank)
                [ordered addObject:element];
        }
    }
    for (CharonSolvedElement *element in ordered) {
        if (element->scrolls && !CGRectIntersectsRect([self shiftedFrame:element->frame section:solved->section], solved->extent))
            continue;
        CharonCollectionLayoutVisibleItem *item = previous[[self keyFor:element]];
        if (!item) {
            item = [[CharonCollectionLayoutVisibleItem alloc] init];
            item->_center = CGPointMake(CGRectGetMidX(element->frame), CGRectGetMidY(element->frame));
            item->_alpha = 1;
            item->_zIndex = element->zIndex;
            item->_transform = CGAffineTransformIdentity;
            item->_transform3D = CATransform3DIdentity;
        }
        item->_frame = element->frame;
        item->_bounds = CGRectMake(0, 0, element->frame.size.width, element->frame.size.height);
        item->_baseCenter = CGPointMake(CGRectGetMidX(element->frame), CGRectGetMidY(element->frame));
        item->_name = nil;
        item->_indexPath = element->indexPath;
        item->_category = element->category == 1 ? UICollectionElementCategorySupplementaryView : UICollectionElementCategoryCell;
        item->_kind = element->category == 1 ? element->kind : nil;
        [items addObject:item];
        _visible[[self keyFor:element]] = item;
    }
    handler(items, CGPointMake(offset, 0), _environment);
}

- (void)runAllHandlers
{
    for (CharonSolvedSection *solved in [_sections reverseObjectEnumerator])
        [self runHandlerFor:solved];
}

- (void)updateSections:(NSArray *)sections view:(UICollectionView *)view environment:(id<NSCollectionLayoutEnvironment>)environment
{
    _view = view;
    _environment = environment;
    NSMutableArray *found = [NSMutableArray array];
    for (CharonSolvedSection *solved in sections) {
        if (solved->orthogonal)
            [found addObject:solved];
    }
    _sections = found;
    NSMutableDictionary *kept = [NSMutableDictionary dictionary];
    for (CharonSolvedSection *solved in found) {
        NSNumber *key = @(solved->section);
        CGFloat offset = _offsets[key] ? [_offsets[key] doubleValue] : [self minimumOf:solved];
        kept[key] = @(MIN(MAX(offset, [self minimumOf:solved]), [self maximumOf:solved]));
    }
    _offsets = kept;
    if (found.count == 0) {
        [self detach];
        return;
    }
    if (!_pan) {
        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        _pan.delegate = self;
        [view addGestureRecognizer:_pan];
        [view.panGestureRecognizer requireGestureRecognizerToFail:_pan];
    }
    [self runAllHandlers];
}

- (void)detach
{
    [_link invalidate];
    _link = nil;
    if (_pan) {
        [_pan.view removeGestureRecognizer:_pan];
        _pan = nil;
    }
}

- (CharonSolvedSection *)sectionAtPoint:(CGPoint)point
{
    for (CharonSolvedSection *solved in _sections) {
        if (CGRectContainsPoint(solved->viewport, point))
            return solved;
    }
    return nil;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    if (recognizer != _pan || !_view)
        return YES;
    CharonSolvedSection *solved = [self sectionAtPoint:[recognizer locationInView:_view]];
    if (!solved || ![self scrollable:solved])
        return NO;
    CGPoint translation = [_pan translationInView:_view];
    return fabs(translation.x) > fabs(translation.y);
}

- (CGFloat)rubberBand:(CGFloat)raw of:(CharonSolvedSection *)solved
{
    CGFloat low = [self minimumOf:solved], high = [self maximumOf:solved], width = MAX(1, solved->viewport.size.width);
    CGFloat (^band)(CGFloat) = ^CGFloat(CGFloat excess) { return (1 - 1 / (excess * 0.55 / width + 1)) * width; };
    if (raw < low)
        return low - band(low - raw);
    if (raw > high)
        return high + band(raw - high);
    return raw;
}

- (void)setOffset:(CGFloat)offset section:(CharonSolvedSection *)solved
{
    _offsets[@(solved->section)] = @(offset);
    [self runHandlerFor:solved];
    [_layout charon_offsetsDidChange];
}

- (void)pan:(UIPanGestureRecognizer *)recognizer
{
    CharonSolvedSection *solved = _active >= 0 ? [self solvedForSection:_active] : nil;
    switch (recognizer.state) {
    case UIGestureRecognizerStateBegan: {
        [_link invalidate];
        _link = nil;
        solved = [self sectionAtPoint:[recognizer locationInView:_view]];
        _active = solved ? solved->section : -1;
        _dragStart = solved ? [self offsetOfSection:solved->section] : 0;
        break;
    }
    case UIGestureRecognizerStateChanged:
        if (solved)
            [self setOffset:[self rubberBand:_dragStart - [recognizer translationInView:_view].x of:solved] section:solved];
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
        if (solved)
            [self release:solved velocity:-[recognizer velocityInView:_view].x];
        else
            _active = -1;
        break;
    default:
        break;
    }
}

- (void)release:(CharonSolvedSection *)solved velocity:(CGFloat)velocity
{
    CGFloat offset = [self offsetOfSection:solved->section];
    CGFloat low = [self minimumOf:solved], high = [self maximumOf:solved];
    _velocity = velocity;
    _spring = YES;
    if (offset < low || offset > high) {
        _target = offset < low ? low : high;
    } else if (solved->behavior == UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuous) {
        _spring = NO;
    } else {
        CGFloat projected = offset + velocity * 0.5;
        NSArray *snaps = [self snapsOf:solved];
        CGFloat nearestToStart = [self nearestSnap:_dragStart of:solved];
        NSUInteger startIndex = [snaps indexOfObject:@(nearestToStart)];
        CGFloat target = [self nearestSnap:projected of:solved];
        NSUInteger targetIndex = [snaps indexOfObject:@(target)];
        BOOL pages = solved->behavior != UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
        if (pages && startIndex != NSNotFound && targetIndex != NSNotFound && (targetIndex > startIndex + 1 || targetIndex + 1 < startIndex))
            target = [snaps[targetIndex > startIndex ? startIndex + 1 : startIndex - 1] doubleValue];
        _target = target;
    }
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    _last = 0;
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)finish
{
    [_link invalidate];
    _link = nil;
    _active = -1;
}

- (void)step:(CADisplayLink *)link
{
    CharonSolvedSection *solved = [self solvedForSection:_active];
    if (!solved) {
        [self finish];
        return;
    }
    CFTimeInterval now = link.timestamp;
    CFTimeInterval elapsed = _last > 0 ? MIN(now - _last, 0.1) : link.duration;
    _last = now;
    CGFloat x = [self offsetOfSection:solved->section];
    CGFloat low = [self minimumOf:solved], high = [self maximumOf:solved];
    while (elapsed > 0) {
        CGFloat dt = MIN(elapsed, 1.0 / 120);
        elapsed -= dt;
        if (_spring) {
            CGFloat acceleration = -CharonSpringFrequency * CharonSpringFrequency * (x - _target) - 2 * CharonSpringFrequency * _velocity;
            _velocity += acceleration * dt;
            x += _velocity * dt;
        } else {
            x += _velocity * dt;
            _velocity *= pow(CharonDecelerationPerMillisecond, dt * 1000);
            if (x < low || x > high) {
                _spring = YES;
                _target = x < low ? low : high;
            } else if (fabs(_velocity) < 2) {
                [self setOffset:x section:solved];
                [self finish];
                return;
            }
        }
        if (_spring && fabs(x - _target) < 0.05 && fabs(_velocity) < 2) {
            [self setOffset:_target section:solved];
            [self finish];
            return;
        }
    }
    [self setOffset:x section:solved];
}

- (void)scrollSection:(NSInteger)section toOffset:(CGFloat)offset settle:(BOOL)settle
{
    CharonSolvedSection *solved = [self solvedForSection:section];
    if (!solved)
        return;
    [self finish];
    if (settle)
        offset = [self nearestSnap:MIN(MAX(offset, [self minimumOf:solved]), [self maximumOf:solved]) of:solved];
    if (fabs(offset - [self offsetOfSection:section]) < 0.0001)
        return;
    [self setOffset:offset section:solved];
}

- (void)applyToAttributes:(UICollectionViewLayoutAttributes *)attributes element:(CharonSolvedElement *)element
{
    CGFloat offset = [self offsetOfSection:element->indexPath.section];
    CGPoint center = attributes.center;
    center.x -= offset;
    CharonCollectionLayoutVisibleItem *item = _visible[[self keyFor:element]];
    if (item) {
        center.x += item->_center.x - item->_baseCenter.x;
        center.y += item->_center.y - item->_baseCenter.y;
        attributes.alpha = item->_alpha;
        attributes.zIndex = item->_zIndex;
        attributes.hidden = item->_hidden;
        attributes.transform3D = item->_transform3D;
    }
    attributes.center = center;
}

@end
