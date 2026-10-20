#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

BOOL revenant_layout_has_baseline(UIView *view);

@interface UILayoutGuide (RevenantStackView)
- (UIView *)revenant_view;
- (void)setOwningView:(UIView *)owningView;
@end

static void *revenant_hidden_context = &revenant_hidden_context;

static BOOL revenant_engine_knows_margins(void)
{
    return NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_8_0;
}

static id revenant_start(id item, UILayoutConstraintAxis axis)
{
    if (axis == UILayoutConstraintAxisHorizontal)
        return [item leadingAnchor];
    return [item topAnchor];
}

static id revenant_end(id item, UILayoutConstraintAxis axis)
{
    if (axis == UILayoutConstraintAxisHorizontal)
        return [item trailingAnchor];
    return [item bottomAnchor];
}

static id revenant_center(id item, UILayoutConstraintAxis axis)
{
    if (axis == UILayoutConstraintAxisHorizontal)
        return [item centerXAnchor];
    return [item centerYAnchor];
}

static id revenant_size(id item, UILayoutConstraintAxis axis)
{
    return axis == UILayoutConstraintAxisHorizontal ? [item widthAnchor] : [item heightAnchor];
}

static CGFloat revenant_intrinsic(UIView *view, UILayoutConstraintAxis axis)
{
    CGSize size = [view intrinsicContentSize];
    return axis == UILayoutConstraintAxisHorizontal ? size.width : size.height;
}

static CGFloat revenant_natural(UIView *view, UILayoutConstraintAxis axis)
{
    CGFloat size = revenant_intrinsic(view, axis);
    if (size != UIViewNoIntrinsicMetric)
        return size;
    CGSize fitting = [view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    return axis == UILayoutConstraintAxisHorizontal ? fitting.width : fitting.height;
}

static NSLayoutConstraint *revenant_relate(NSLayoutAnchor *anchor, NSLayoutRelation relation, NSLayoutAnchor *other, CGFloat constant)
{
    switch (relation) {
    case NSLayoutRelationLessThanOrEqual:
        return [anchor constraintLessThanOrEqualToAnchor:other constant:constant];
    case NSLayoutRelationGreaterThanOrEqual:
        return [anchor constraintGreaterThanOrEqualToAnchor:other constant:constant];
    default:
        return [anchor constraintEqualToAnchor:other constant:constant];
    }
}

static NSLayoutConstraint *revenant_system_spacing(NSLayoutAnchor *anchor, NSLayoutRelation relation, NSLayoutAnchor *other,
                                                 UILayoutConstraintAxis axis, CGFloat multiplier)
{
    if (axis == UILayoutConstraintAxisHorizontal) {
        NSLayoutXAxisAnchor *first = (NSLayoutXAxisAnchor *)anchor, *second = (NSLayoutXAxisAnchor *)other;
        switch (relation) {
        case NSLayoutRelationLessThanOrEqual:
            return [first constraintLessThanOrEqualToSystemSpacingAfterAnchor:second multiplier:multiplier];
        case NSLayoutRelationGreaterThanOrEqual:
            return [first constraintGreaterThanOrEqualToSystemSpacingAfterAnchor:second multiplier:multiplier];
        default:
            return [first constraintEqualToSystemSpacingAfterAnchor:second multiplier:multiplier];
        }
    }
    NSLayoutYAxisAnchor *first = (NSLayoutYAxisAnchor *)anchor, *second = (NSLayoutYAxisAnchor *)other;
    switch (relation) {
    case NSLayoutRelationLessThanOrEqual:
        return [first constraintLessThanOrEqualToSystemSpacingBelowAnchor:second multiplier:multiplier];
    case NSLayoutRelationGreaterThanOrEqual:
        return [first constraintGreaterThanOrEqualToSystemSpacingBelowAnchor:second multiplier:multiplier];
    default:
        return [first constraintEqualToSystemSpacingBelowAnchor:second multiplier:multiplier];
    }
}

static void revenant_add(NSMutableArray *list, NSLayoutConstraint *constraint, UILayoutPriority priority, NSString *identifier)
{
    constraint.priority = priority;
    if ([constraint respondsToSelector:@selector(setIdentifier:)])
        [constraint setIdentifier:identifier];
    [list addObject:constraint];
}

@implementation UIStackView {
    NSMutableArray *_arrangedSubviews;
    UILayoutConstraintAxis _axis;
    UIStackViewDistribution _distribution;
    UIStackViewAlignment _alignment;
    CGFloat _spacing;
    BOOL _baselineRelativeArrangement;
    BOOL _layoutMarginsRelativeArrangement;
    NSMutableArray *_stackConstraints;
    NSMutableArray *_itemConstraints;
    UILayoutGuide *_orderingSpanner;
    UILayoutGuide *_alignmentSpanner;
    NSMutableArray *_distributingGuides;
    NSArray *_intrinsicSizes;
    NSMapTable *_customSpacing;
    BOOL _needsRebuild;
}

+ (Class)layerClass
{
    return [CATransformLayer class];
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

static void revenant_setup(UIStackView *self)
{
    self->_arrangedSubviews = [NSMutableArray array];
    self->_stackConstraints = [NSMutableArray array];
    self->_itemConstraints = [NSMutableArray array];
    self->_distributingGuides = [NSMutableArray array];
    [self setLayoutMargins:UIEdgeInsetsZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
        revenant_setup(self);
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        revenant_setup(self);
        _axis = [coder decodeIntegerForKey:@"UIStackViewAxis"];
        _distribution = [coder decodeIntegerForKey:@"UIStackViewDistribution"];
        _alignment = [coder decodeIntegerForKey:@"UIStackViewAlignment"];
        _spacing = [coder decodeDoubleForKey:@"UIStackViewSpacing"];
        _baselineRelativeArrangement = [coder decodeBoolForKey:@"UIStackViewBaselineRelative"];
        _layoutMarginsRelativeArrangement = [coder decodeBoolForKey:@"UIStackViewLayoutMarginsRelative"];
        id margins = [coder decodeObjectForKey:@"UIViewLayoutMargins"];
        if ([margins isKindOfClass:[NSString class]])
            [self setLayoutMargins:UIEdgeInsetsFromString(margins)];
        for (UIView *view in [coder decodeObjectForKey:@"UIStackViewArrangedSubviews"])
            [self addArrangedSubview:view];
        [self revenant_setNeedsRebuild];
    }
    return self;
}

- (instancetype)initWithArrangedSubviews:(NSArray *)views
{
    if ((self = [self initWithFrame:CGRectZero])) {
        for (UIView *view in views)
            [self addArrangedSubview:view];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeInteger:_axis forKey:@"UIStackViewAxis"];
    [coder encodeInteger:_distribution forKey:@"UIStackViewDistribution"];
    [coder encodeInteger:_alignment forKey:@"UIStackViewAlignment"];
    [coder encodeDouble:_spacing forKey:@"UIStackViewSpacing"];
    [coder encodeBool:_baselineRelativeArrangement forKey:@"UIStackViewBaselineRelative"];
    [coder encodeBool:_layoutMarginsRelativeArrangement forKey:@"UIStackViewLayoutMarginsRelative"];
    [coder encodeObject:[_arrangedSubviews copy] forKey:@"UIStackViewArrangedSubviews"];
    if (!revenant_engine_knows_margins())
        [coder encodeObject:NSStringFromUIEdgeInsets([self layoutMargins]) forKey:@"UIViewLayoutMargins"];
}

- (void)dealloc
{
    for (UIView *view in _arrangedSubviews)
        [view removeObserver:self forKeyPath:@"hidden" context:revenant_hidden_context];
    [_arrangedSubviews removeAllObjects];
}

- (NSArray *)arrangedSubviews
{
    return [_arrangedSubviews copy];
}

- (void)addArrangedSubview:(UIView *)view
{
    [self insertArrangedSubview:view atIndex:_arrangedSubviews.count];
}

- (void)insertArrangedSubview:(UIView *)view atIndex:(NSUInteger)stackIndex
{
    if (stackIndex > _arrangedSubviews.count)
        [NSException raise:NSInvalidArgumentException format:@"index out of bounds for arranged subview: index = %lu expected to be less than or equal to %lu", (unsigned long)stackIndex, (unsigned long)_arrangedSubviews.count];
    NSUInteger existing = [_arrangedSubviews indexOfObjectIdenticalTo:view];
    if (existing != NSNotFound) {
        [_arrangedSubviews removeObjectAtIndex:existing];
        [_arrangedSubviews insertObject:view atIndex:MIN(stackIndex, _arrangedSubviews.count)];
    } else {
        if (!view)
            [NSException raise:NSInvalidArgumentException format:@"arranged subview must not be nil"];
        if (view.superview != self)
            [self addSubview:view];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [_arrangedSubviews insertObject:view atIndex:stackIndex];
        [view addObserver:self forKeyPath:@"hidden" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:revenant_hidden_context];
    }
    [self revenant_setNeedsRebuild];
}

- (void)removeArrangedSubview:(UIView *)view
{
    NSUInteger index = [_arrangedSubviews indexOfObjectIdenticalTo:view];
    if (index == NSNotFound)
        return;
    [view removeObserver:self forKeyPath:@"hidden" context:revenant_hidden_context];
    [_arrangedSubviews removeObjectAtIndex:index];
    [_customSpacing removeObjectForKey:view];
    [self revenant_setNeedsRebuild];
}

- (void)setCustomSpacing:(CGFloat)customSpacing afterView:(UIView *)arrangedSubview
{
    if (!arrangedSubview || [_arrangedSubviews indexOfObjectIdenticalTo:arrangedSubview] == NSNotFound)
        return;
    if (!_customSpacing)
        _customSpacing = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsObjectPointerPersonality | NSPointerFunctionsStrongMemory
                                                   valueOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory capacity:0];
    NSNumber *held = [_customSpacing objectForKey:arrangedSubview];
    if (held && held.doubleValue == customSpacing)
        return;
    [_customSpacing setObject:@(customSpacing) forKey:arrangedSubview];
    [self revenant_setNeedsRebuild];
}

- (CGFloat)customSpacingAfterView:(UIView *)arrangedSubview
{
    NSNumber *held = arrangedSubview ? [_customSpacing objectForKey:arrangedSubview] : nil;
    return held ? (CGFloat)held.doubleValue : UIStackViewSpacingUseDefault;
}

- (CGFloat)revenant_spacingAfterView:(UIView *)view
{
    CGFloat spacing = [self customSpacingAfterView:view];
    if (spacing == UIStackViewSpacingUseDefault)
        spacing = _spacing;
    if (spacing == UIStackViewSpacingUseDefault)
        return 0;
    if (spacing == UIStackViewSpacingUseSystem)
        return spacing;
    CGFloat scale = (self.window.screen ?: [UIScreen mainScreen]).scale;
    return scale > 1 ? round(spacing * scale) / scale : round(spacing);
}

- (void)willRemoveSubview:(UIView *)subview
{
    [super willRemoveSubview:subview];
    [self removeArrangedSubview:subview];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != revenant_hidden_context) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if (![[change objectForKey:NSKeyValueChangeOldKey] isEqual:[change objectForKey:NSKeyValueChangeNewKey]])
        [self revenant_setNeedsRebuild];
}

- (UILayoutConstraintAxis)axis
{
    return _axis;
}

- (void)setAxis:(UILayoutConstraintAxis)axis
{
    if (_axis == axis)
        return;
    _axis = axis;
    [self revenant_setNeedsRebuild];
}

- (UIStackViewDistribution)distribution
{
    return _distribution;
}

- (void)setDistribution:(UIStackViewDistribution)distribution
{
    if (_distribution == distribution)
        return;
    _distribution = distribution;
    [self revenant_setNeedsRebuild];
}

- (UIStackViewAlignment)alignment
{
    return _alignment;
}

- (void)setAlignment:(UIStackViewAlignment)alignment
{
    if (_alignment == alignment)
        return;
    _alignment = alignment;
    [self revenant_setNeedsRebuild];
}

- (CGFloat)spacing
{
    return _spacing;
}

- (void)setSpacing:(CGFloat)spacing
{
    if (_spacing == spacing)
        return;
    _spacing = spacing;
    [self revenant_setNeedsRebuild];
}

- (BOOL)isBaselineRelativeArrangement
{
    return _baselineRelativeArrangement;
}

- (void)setBaselineRelativeArrangement:(BOOL)baselineRelativeArrangement
{
    if (_baselineRelativeArrangement == baselineRelativeArrangement)
        return;
    _baselineRelativeArrangement = baselineRelativeArrangement;
    [self revenant_setNeedsRebuild];
}

- (BOOL)isLayoutMarginsRelativeArrangement
{
    return _layoutMarginsRelativeArrangement;
}

- (void)setLayoutMarginsRelativeArrangement:(BOOL)layoutMarginsRelativeArrangement
{
    if (_layoutMarginsRelativeArrangement == layoutMarginsRelativeArrangement)
        return;
    _layoutMarginsRelativeArrangement = layoutMarginsRelativeArrangement;
    [self revenant_setNeedsRebuild];
}

static NSArray *revenant_visible(NSArray *views)
{
    NSMutableArray *visible = [NSMutableArray array];
    for (UIView *view in views) {
        if (!view.hidden)
            [visible addObject:view];
    }
    return visible;
}

static UIView *revenant_baseline_view(UIStackView *self, BOOL first)
{
    NSArray *visible = revenant_visible(self->_arrangedSubviews);
    UIView *found = nil;
    UIStackViewAlignment alignment = self->_alignment;
    if (self->_axis == UILayoutConstraintAxisVertical || alignment == UIStackViewAlignmentFill) {
        found = first ? (visible.count ? visible[0] : nil) : [visible lastObject];
    } else if (first && (alignment == UIStackViewAlignmentLeading || alignment == UIStackViewAlignmentFirstBaseline)) {
        found = (visible.count ? visible[0] : nil);
    } else if (!first && (alignment == UIStackViewAlignmentTrailing || alignment == UIStackViewAlignmentLastBaseline)) {
        found = [visible lastObject];
    } else {
        CGFloat tallest = 0;
        for (UIView *view in visible) {
            if (CGRectGetHeight(view.frame) > tallest) {
                tallest = CGRectGetHeight(view.frame);
                found = view;
            }
        }
        for (UIView *view in found ? @[] : visible) {
            CGFloat height = revenant_natural(view, UILayoutConstraintAxisVertical);
            if (height > tallest) {
                tallest = height;
                found = view;
            }
        }
    }
    if (!found)
        return self;
    if ([found isKindOfClass:[UIStackView class]])
        return first ? [found viewForFirstBaselineLayout] : [found viewForLastBaselineLayout];
    return found;
}

- (UIView *)viewForFirstBaselineLayout
{
    return revenant_baseline_view(self, YES);
}

- (UIView *)viewForLastBaselineLayout
{
    return revenant_baseline_view(self, NO);
}

- (UIView *)viewForBaselineLayout
{
    return revenant_baseline_view(self, NO);
}

static NSArray *revenant_intrinsic_sizes(UIStackView *self)
{
    NSMutableArray *sizes = [NSMutableArray array];
    BOOL proportional = self->_distribution == UIStackViewDistributionFillProportionally;
    for (UIView *view in revenant_visible(self->_arrangedSubviews))
        [sizes addObject:@(proportional ? revenant_natural(view, self->_axis) : revenant_intrinsic(view, self->_axis))];
    return sizes;
}

static UILayoutGuide *revenant_guide(UIStackView *self, UILayoutGuide *guide, NSString *identifier)
{
    if (!guide) {
        guide = [[UILayoutGuide alloc] init];
        guide.identifier = identifier;
    }
    if (guide.owningView != self)
        [self addLayoutGuide:guide];
    else if ([guide revenant_view].superview != self)
        [guide setOwningView:self];
    return guide;
}

- (void)revenant_setNeedsRebuild
{
    if (!_arrangedSubviews)
        return;
    _needsRebuild = YES;
    [self setNeedsUpdateConstraints];
    [self setNeedsLayout];
    [self.superview setNeedsLayout];
}

- (void)revenant_rebuild
{
    if (!_arrangedSubviews)
        return;
    _needsRebuild = NO;
    [self removeConstraints:_stackConstraints];
    for (NSLayoutConstraint *constraint in _itemConstraints)
        [constraint.firstItem removeConstraint:constraint];
    [_stackConstraints removeAllObjects];
    [_itemConstraints removeAllObjects];
    _intrinsicSizes = revenant_intrinsic_sizes(self);

    NSArray *all = _arrangedSubviews;
    NSArray *visible = revenant_visible(all);
    UILayoutConstraintAxis axis = _axis;
    UILayoutConstraintAxis across = axis == UILayoutConstraintAxisHorizontal ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    NSMutableArray *stack = _stackConstraints, *items = _itemConstraints;
    UILayoutGuide *orderingSpanner = nil, *alignmentSpanner = nil;
    NSMutableArray *gaps = [NSMutableArray array];
    id canvas = _layoutMarginsRelativeArrangement ? [self layoutMarginsGuide] : self;
    BOOL spreading = _distribution == UIStackViewDistributionEqualSpacing || _distribution == UIStackViewDistributionEqualCentering;
    NSLayoutRelation relation = spreading ? NSLayoutRelationGreaterThanOrEqual : NSLayoutRelationEqual;
    BOOL baselines = _baselineRelativeArrangement && axis == UILayoutConstraintAxisVertical;

    if (all.count) {
        for (UIView *view in all) {
            if (view.hidden)
                revenant_add(items, [revenant_size(view, axis) constraintEqualToConstant:0], 999.999f, @"UISV-hiding");
        }
        if (visible.count) {
            revenant_add(stack, [revenant_start(canvas, axis) constraintEqualToAnchor:revenant_start(visible[0], axis)], UILayoutPriorityRequired, @"UISV-canvas-connection");
            revenant_add(stack, [revenant_end(canvas, axis) constraintEqualToAnchor:revenant_end([visible lastObject], axis)], UILayoutPriorityRequired, @"UISV-canvas-connection");
            for (NSUInteger index = 1; index < visible.count; index++) {
                UIView *previous = visible[index - 1], *next = visible[index];
                NSLayoutAnchor *leading = revenant_start(next, axis), *trailing = revenant_end(previous, axis);
                if (baselines) {
                    leading = next.firstBaselineAnchor;
                    trailing = previous.lastBaselineAnchor;
                }
                CGFloat gap = [self revenant_spacingAfterView:previous];
                NSLayoutConstraint *constraint = gap == UIStackViewSpacingUseSystem
                    ? revenant_system_spacing(leading, relation, trailing, axis, 1)
                    : revenant_relate(leading, relation, trailing, gap);
                revenant_add(stack, constraint, UILayoutPriorityRequired, @"UISV-spacing");
            }
            for (NSUInteger index = 0; index < all.count; index++) {
                UIView *view = all[index];
                if (!view.hidden)
                    continue;
                UIView *previous = nil, *next = nil;
                for (NSUInteger other = index; other > 0 && !previous; other--) {
                    if (![all[other - 1] isHidden])
                        previous = all[other - 1];
                }
                for (NSUInteger other = index + 1; other < all.count && !next; other++) {
                    if (![all[other] isHidden])
                        next = all[other];
                }
                UIView *leadingView = previous ? view : next, *trailingView = previous ? previous : view;
                NSLayoutAnchor *leading = revenant_start(leadingView, axis), *trailing = revenant_end(trailingView, axis);
                if (baselines && !leadingView.hidden)
                    leading = leadingView.firstBaselineAnchor;
                if (baselines && !trailingView.hidden)
                    trailing = trailingView.lastBaselineAnchor;
                CGFloat gap = previous && next ? [self revenant_spacingAfterView:previous] : 0;
                NSLayoutConstraint *constraint = gap == UIStackViewSpacingUseSystem
                    ? revenant_system_spacing(leading, relation, trailing, axis, 0.5)
                    : revenant_relate(leading, relation, trailing, gap / 2);
                revenant_add(stack, constraint, 50, @"UISV-spacing-hidden");
            }
        } else {
            orderingSpanner = revenant_guide(self, _orderingSpanner, @"UISV-ordering-spanner");
            revenant_add(stack, [revenant_start(canvas, axis) constraintEqualToAnchor:revenant_start(orderingSpanner, axis)], UILayoutPriorityRequired, @"UISV-canvas-connection");
            revenant_add(stack, [revenant_end(canvas, axis) constraintEqualToAnchor:revenant_end(orderingSpanner, axis)], UILayoutPriorityRequired, @"UISV-canvas-connection");
            revenant_add(stack, [revenant_size(orderingSpanner, axis) constraintEqualToConstant:0], 0.001f, @"UISV-spanning-fit");
            for (UIView *view in all)
                revenant_add(stack, revenant_relate(revenant_start(view, axis), relation, revenant_end(orderingSpanner, axis), 0), 50, @"UISV-spacing-hidden");
        }

        if (_distribution != UIStackViewDistributionEqualCentering && _distribution != UIStackViewDistributionFillProportionally) {
            for (NSUInteger index = 1; index < visible.count; index++) {
                UIView *view = visible[index];
                CGFloat size = revenant_intrinsic(view, axis);
                if (size <= 0)
                    continue;
                UILayoutPriority hugging = [view contentHuggingPriorityForAxis:axis], resistance = [view contentCompressionResistancePriorityForAxis:axis];
                if (hugging < UILayoutPriorityRequired - 1)
                    revenant_add(items, [revenant_size(view, axis) constraintLessThanOrEqualToConstant:size], hugging + 0.001f * index, @"revenant-arrangement-order");
                if (resistance < UILayoutPriorityRequired - 1)
                    revenant_add(items, [revenant_size(view, axis) constraintGreaterThanOrEqualToConstant:size], resistance + 0.001f * index, @"revenant-arrangement-order");
            }
        }

        if (_distribution == UIStackViewDistributionFillEqually) {
            for (NSUInteger index = 1; index < visible.count; index++)
                revenant_add(stack, [revenant_size(visible[index], axis) constraintEqualToAnchor:revenant_size(visible[0], axis)], UILayoutPriorityRequired, @"UISV-fill-equally");
        } else if (_distribution == UIStackViewDistributionFillProportionally && visible.count) {
            CGFloat total = _spacing * (visible.count - 1);
            NSUInteger proportional = 0;
            for (UIView *view in visible) {
                CGFloat size = revenant_natural(view, axis);
                if (size > 0) {
                    total += size;
                    proportional++;
                }
            }
            for (UIView *view in visible) {
                CGFloat size = revenant_natural(view, axis);
                if (size <= 0 || total <= 0) {
                    revenant_add(items, [revenant_size(view, axis) constraintEqualToConstant:0], UILayoutPriorityRequired, @"UISV-fill-proportionally");
                    continue;
                }
                UILayoutPriority priority = proportional == 1 ? UILayoutPriorityRequired : UILayoutPriorityRequired - 1 - [all indexOfObjectIdenticalTo:view];
                revenant_add(stack, [revenant_size(view, axis) constraintEqualToAnchor:revenant_size(canvas, axis) multiplier:size / total], priority, @"UISV-fill-proportionally");
            }
        } else if (spreading && visible.count > 1) {
            BOOL centering = _distribution == UIStackViewDistributionEqualCentering;
            for (NSUInteger index = 1; index < visible.count; index++) {
                UILayoutGuide *gap = revenant_guide(self, index - 1 < _distributingGuides.count ? _distributingGuides[index - 1] : nil, @"UISV-distributing");
                [gaps addObject:gap];
                UIView *previous = visible[index - 1], *next = visible[index];
                NSLayoutAnchor *previousEdge = centering ? revenant_center(previous, axis) : revenant_end(previous, axis);
                NSLayoutAnchor *nextEdge = centering ? revenant_center(next, axis) : revenant_start(next, axis);
                if (!centering && baselines) {
                    previousEdge = previous.lastBaselineAnchor;
                    nextEdge = next.firstBaselineAnchor;
                }
                revenant_add(stack, [revenant_start(gap, axis) constraintEqualToAnchor:previousEdge], UILayoutPriorityRequired, @"UISV-distributing-edge");
                revenant_add(stack, [revenant_end(gap, axis) constraintEqualToAnchor:nextEdge], UILayoutPriorityRequired, @"UISV-distributing-edge");
                if (index > 1) {
                    UILayoutPriority priority = centering ? 150 - [all indexOfObjectIdenticalTo:previous] : UILayoutPriorityRequired;
                    revenant_add(stack, [revenant_size(gap, axis) constraintEqualToAnchor:revenant_size(gaps[0], axis)], priority, @"UISV-fill-equally");
                }
            }
            revenant_add(stack, [revenant_size(self, axis) constraintEqualToConstant:0], 49, @"UISV-canvas-fit");
        }

        UIView *first = all[0];
        UIStackViewAlignment alignment = _alignment;
        BOOL baseline = alignment == UIStackViewAlignmentFirstBaseline || alignment == UIStackViewAlignmentLastBaseline;
        BOOL ignored = baseline && axis == UILayoutConstraintAxisVertical;
        if (!ignored) {
            for (NSUInteger index = 1; index < all.count; index++) {
                UIView *view = all[index];
                switch (alignment) {
                case UIStackViewAlignmentFill:
                    revenant_add(stack, [revenant_start(first, across) constraintEqualToAnchor:revenant_start(view, across)], UILayoutPriorityRequired, @"UISV-alignment");
                    revenant_add(stack, [revenant_end(first, across) constraintEqualToAnchor:revenant_end(view, across)], UILayoutPriorityRequired, @"UISV-alignment");
                    break;
                case UIStackViewAlignmentLeading:
                    revenant_add(stack, [revenant_start(first, across) constraintEqualToAnchor:revenant_start(view, across)], UILayoutPriorityRequired, @"UISV-alignment");
                    break;
                case UIStackViewAlignmentTrailing:
                    revenant_add(stack, [revenant_end(first, across) constraintEqualToAnchor:revenant_end(view, across)], UILayoutPriorityRequired, @"UISV-alignment");
                    break;
                case UIStackViewAlignmentCenter:
                    revenant_add(stack, [revenant_center(first, across) constraintEqualToAnchor:revenant_center(view, across)], UILayoutPriorityRequired, @"UISV-alignment");
                    break;
                case UIStackViewAlignmentFirstBaseline:
                    if (revenant_layout_has_baseline(first) && revenant_layout_has_baseline(view))
                        revenant_add(stack, [first.firstBaselineAnchor constraintEqualToAnchor:view.firstBaselineAnchor], UILayoutPriorityRequired, @"UISV-alignment");
                    else
                        revenant_add(stack, [first.topAnchor constraintEqualToAnchor:view.topAnchor], UILayoutPriorityRequired, @"UISV-alignment");
                    break;
                case UIStackViewAlignmentLastBaseline:
                    if (revenant_layout_has_baseline(first) && revenant_layout_has_baseline(view))
                        revenant_add(stack, [first.lastBaselineAnchor constraintEqualToAnchor:view.lastBaselineAnchor], UILayoutPriorityRequired, @"UISV-alignment");
                    else
                        revenant_add(stack, [first.bottomAnchor constraintEqualToAnchor:view.bottomAnchor], UILayoutPriorityRequired, @"UISV-alignment");
                    break;
                }
            }
        }
        if (alignment == UIStackViewAlignmentFill && visible.count) {
            revenant_add(stack, [revenant_start(canvas, across) constraintEqualToAnchor:revenant_start(first, across)], UILayoutPriorityRequired, @"UISV-canvas-connection");
            revenant_add(stack, [revenant_end(canvas, across) constraintEqualToAnchor:revenant_end(first, across)], UILayoutPriorityRequired, @"UISV-canvas-connection");
        } else {
            alignmentSpanner = revenant_guide(self, _alignmentSpanner, @"UISV-alignment-spanner");
            NSLayoutAnchor *spannerStart = revenant_start(alignmentSpanner, across), *spannerEnd = revenant_end(alignmentSpanner, across);
            if (!visible.count || ignored) {
                revenant_add(stack, [revenant_start(canvas, across) constraintEqualToAnchor:spannerStart], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_end(canvas, across) constraintEqualToAnchor:spannerEnd], UILayoutPriorityRequired, @"UISV-canvas-connection");
            } else if (alignment == UIStackViewAlignmentLeading) {
                revenant_add(stack, [revenant_start(canvas, across) constraintEqualToAnchor:revenant_start(first, across)], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_end(canvas, across) constraintEqualToAnchor:spannerEnd], UILayoutPriorityRequired, @"UISV-canvas-connection");
            } else if (alignment == UIStackViewAlignmentTrailing) {
                revenant_add(stack, [revenant_start(canvas, across) constraintEqualToAnchor:spannerStart], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_end(canvas, across) constraintEqualToAnchor:revenant_end(first, across)], UILayoutPriorityRequired, @"UISV-canvas-connection");
            } else if (alignment == UIStackViewAlignmentCenter) {
                revenant_add(stack, [revenant_start(canvas, across) constraintEqualToAnchor:spannerStart], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_end(canvas, across) constraintEqualToAnchor:spannerEnd], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_center(canvas, across) constraintEqualToAnchor:revenant_center(first, across)], UILayoutPriorityRequired, @"UISV-canvas-connection");
            } else if (alignment == UIStackViewAlignmentFirstBaseline) {
                revenant_add(stack, [revenant_start(canvas, across) constraintLessThanOrEqualToAnchor:revenant_start(first, across)], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_end(canvas, across) constraintEqualToAnchor:spannerEnd], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_size(self, across) constraintEqualToConstant:0], 49, @"UISV-canvas-fit");
            } else {
                revenant_add(stack, [revenant_start(canvas, across) constraintEqualToAnchor:spannerStart], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_end(canvas, across) constraintGreaterThanOrEqualToAnchor:revenant_end(first, across)], UILayoutPriorityRequired, @"UISV-canvas-connection");
                revenant_add(stack, [revenant_size(self, across) constraintEqualToConstant:0], 49, @"UISV-canvas-fit");
            }
            for (UIView *view in visible) {
                UILayoutPriority startPriority = alignment == UIStackViewAlignmentLeading && !ignored ? 999.5f : UILayoutPriorityRequired;
                UILayoutPriority endPriority = alignment == UIStackViewAlignmentTrailing && !ignored ? 999.5f : UILayoutPriorityRequired;
                NSLayoutRelation startRelation = startPriority < UILayoutPriorityRequired ? NSLayoutRelationEqual : NSLayoutRelationLessThanOrEqual;
                NSLayoutRelation endRelation = endPriority < UILayoutPriorityRequired ? NSLayoutRelationEqual : NSLayoutRelationGreaterThanOrEqual;
                revenant_add(stack, revenant_relate(spannerStart, startRelation, revenant_start(view, across), 0), startPriority, @"UISV-spanning-boundary");
                revenant_add(stack, revenant_relate(spannerEnd, endRelation, revenant_end(view, across), 0), endPriority, @"UISV-spanning-boundary");
            }
            revenant_add(stack, [revenant_size(alignmentSpanner, across) constraintEqualToConstant:0], visible.count ? 51 : 0.001f, @"UISV-spanning-fit");
            if (alignment != UIStackViewAlignmentFill) {
                for (UIView *view in all)
                    revenant_add(items, [revenant_size(view, across) constraintEqualToConstant:0], 25, @"UISV-ambiguity-suppression");
            }
        }
    }

    if (_orderingSpanner && _orderingSpanner != orderingSpanner)
        [self removeLayoutGuide:_orderingSpanner];
    _orderingSpanner = orderingSpanner;
    if (_alignmentSpanner && _alignmentSpanner != alignmentSpanner)
        [self removeLayoutGuide:_alignmentSpanner];
    _alignmentSpanner = alignmentSpanner;
    for (NSUInteger index = gaps.count; index < _distributingGuides.count; index++)
        [self removeLayoutGuide:_distributingGuides[index]];
    [_distributingGuides setArray:gaps];

    [self addConstraints:stack];
    for (NSLayoutConstraint *constraint in items)
        [constraint.firstItem addConstraint:constraint];
}

- (void)revenant_rebuildIfNeeded
{
    if (_arrangedSubviews && (_needsRebuild || ![revenant_intrinsic_sizes(self) isEqualToArray:_intrinsicSizes]))
        [self revenant_rebuild];
}

- (void)updateConstraints
{
    [self revenant_rebuildIfNeeded];
    [super updateConstraints];
}

- (void)layoutSubviews
{
    [self revenant_rebuildIfNeeded];
    [super layoutSubviews];
}

@end
