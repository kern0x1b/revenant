#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const NSInteger RevenantSeparatorStyleDoubleLine = 3;

static const char RevenantTableSeparatorInsetKey;
static const char RevenantCellSeparatorInsetKey;
static const char RevenantTableSeparatorTakenKey;
static const char RevenantTableSavedStyleKey;
static const char RevenantSeparatorColorKey;
static const char RevenantSeparatorEffectKey;
static const char RevenantFollowsReadableKey;
static const char RevenantSeparatorViewKey;

@interface RevenantTableSeparatorView : UIView
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) UITableViewCellSeparatorStyle style;
@property (nonatomic) CGFloat lineWidth;
@end

@implementation RevenantTableSeparatorView
@synthesize color = _color;
@synthesize style = _style;
@synthesize lineWidth = _lineWidth;

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context)
        return;
    CGFloat width = _lineWidth > 0 ? _lineWidth : 1;
    CGRect line = CGRectMake(0, 0, rect.size.width, width);
    if (_style == (UITableViewCellSeparatorStyle)RevenantSeparatorStyleDoubleLine)
        line = CGRectMake(0, 1, rect.size.width, width);
    CGContextSetFillColorWithColor(context, (_color ?: [UIColor lightGrayColor]).CGColor);
    CGContextFillRect(context, line);
}
@end

@interface UITableView (RevenantSeparators7)
- (void)revenant_takeOverSeparators;
- (void)revenant_restoreSeparatorsIfDefault;
@end

@interface UITableViewCell (RevenantSeparatorLayout)
- (void)revenant_layoutSeparator;
@end

@interface RevenantTableSeparatorInstaller : NSObject
@end

@implementation RevenantTableSeparatorInstaller

+ (void)load
{
    if ([UITableView instancesRespondToSelector:@selector(separatorEffect)])
        return;
    Class cell = [UITableViewCell class];
    Method layout = class_getInstanceMethod(cell, @selector(layoutSubviews));
    void (*original)(id, SEL) = (void (*)(id, SEL))method_getImplementation(layout);
    class_replaceMethod(cell, @selector(layoutSubviews), imp_implementationWithBlock(^(UITableViewCell *self_) {
        original(self_, @selector(layoutSubviews));
        [self_ revenant_layoutSeparator];
    }), method_getTypeEncoding(layout));
}

@end

@implementation UITableViewCell (RevenantSeparators7)

- (UIEdgeInsets)separatorInset
{
    NSValue *own = objc_getAssociatedObject(self, &RevenantCellSeparatorInsetKey);
    if (own)
        return [own UIEdgeInsetsValue];
    NSValue *fromTable = objc_getAssociatedObject(self, &RevenantTableSeparatorInsetKey);
    if (fromTable)
        return [fromTable UIEdgeInsetsValue];
    return UIEdgeInsetsMake(0, 8, 0, 8);
}

- (void)setSeparatorInset:(UIEdgeInsets)separatorInset
{
    objc_setAssociatedObject(self, &RevenantCellSeparatorInsetKey, [NSValue valueWithUIEdgeInsets:separatorInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UITableView *table in [self revenant_tables])
        [table revenant_takeOverSeparators];
}

- (NSArray<UITableView *> *)revenant_tables
{
    NSMutableArray *found = [NSMutableArray array];
    UIView *view = self.superview;
    while (view) {
        if ([view isKindOfClass:[UITableView class]])
            [found addObject:(UITableView *)view];
        view = view.superview;
    }
    return found;
}

- (void)revenant_layoutSeparator
{
    UITableView *table = [self revenant_tables].firstObject;
    if (!table)
        return;
    if (![objc_getAssociatedObject(table, &RevenantTableSeparatorTakenKey) boolValue])
        return;
    if (![self revenant_isInATableRow])
        return;
    UIEdgeInsets inset = self.separatorInset;
    CGFloat width = MAX(0, self.bounds.size.width - inset.left - inset.right);
    CGFloat height = table.separatorStyle == (UITableViewCellSeparatorStyle)RevenantSeparatorStyleDoubleLine ? 2 : 1;
    CGRect frame = CGRectMake(inset.left, self.bounds.size.height - inset.bottom - height, width, height);
    if ([objc_getAssociatedObject(table, &RevenantFollowsReadableKey) boolValue]) {
        UIEdgeInsets margins = table.layoutMargins;
        frame.origin.x = inset.left + margins.left;
        frame.size.width = MAX(0, self.bounds.size.width - frame.origin.x - inset.right - margins.right);
    }
    RevenantTableSeparatorView *separator = objc_getAssociatedObject(self, &RevenantSeparatorViewKey);
    if (!separator) {
        separator = [[RevenantTableSeparatorView alloc] initWithFrame:frame];
        separator.backgroundColor = [UIColor clearColor];
        objc_setAssociatedObject(self, &RevenantSeparatorViewKey, separator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *effect = objc_getAssociatedObject(table, &RevenantSeparatorEffectKey);
        if (effect) {
            [self insertSubview:effect belowSubview:separator];
            effect.frame = separator.frame;
        }
        [self addSubview:separator];
    }
    separator.frame = frame;
    separator.color = objc_getAssociatedObject(table, &RevenantSeparatorColorKey) ?: table.separatorColor;
    separator.style = table.separatorStyle == UITableViewCellSeparatorStyleNone ? UITableViewCellSeparatorStyleSingleLine : table.separatorStyle;
    [separator setNeedsDisplay];
}

- (BOOL)revenant_isInATableRow
{
    return self.superview != nil;
}

@end

@implementation UITableView (RevenantSeparators7)

- (UIEdgeInsets)separatorInset
{
    NSValue *stored = objc_getAssociatedObject(self, &RevenantTableSeparatorInsetKey);
    return stored ? [stored UIEdgeInsetsValue] : UIEdgeInsetsMake(0, 16, 0, 0);
}

- (void)setSeparatorInset:(UIEdgeInsets)separatorInset
{
    BOOL wasDefault = UIEdgeInsetsEqualToEdgeInsets(self.separatorInset, UIEdgeInsetsMake(0, 16, 0, 0));
    objc_setAssociatedObject(self, &RevenantTableSeparatorInsetKey, [NSValue valueWithUIEdgeInsets:separatorInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (UIEdgeInsetsEqualToEdgeInsets(separatorInset, UIEdgeInsetsMake(0, 16, 0, 0)) && wasDefault)
        return;
    [self revenant_takeOverSeparators];
}

- (UIColor *)sectionIndexBackgroundColor
{
    return objc_getAssociatedObject(self, &RevenantSeparatorColorKey);
}

- (void)setSectionIndexBackgroundColor:(UIColor *)sectionIndexBackgroundColor
{
    objc_setAssociatedObject(self, &RevenantSeparatorColorKey, sectionIndexBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)separatorEffect
{
    return objc_getAssociatedObject(self, &RevenantSeparatorEffectKey);
}

- (void)setSeparatorEffect:(UIView *)separatorEffect
{
    objc_setAssociatedObject(self, &RevenantSeparatorEffectKey, separatorEffect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (separatorEffect)
        [self revenant_takeOverSeparators];
}

- (BOOL)cellLayoutMarginsFollowReadableWidth
{
    return [objc_getAssociatedObject(self, &RevenantFollowsReadableKey) boolValue];
}

- (void)setCellLayoutMarginsFollowReadableWidth:(BOOL)follows
{
    objc_setAssociatedObject(self, &RevenantFollowsReadableKey, @(follows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (follows)
        [self revenant_takeOverSeparators];
}

- (void)revenant_takeOverSeparators
{
    if ([objc_getAssociatedObject(self, &RevenantTableSeparatorTakenKey) boolValue])
        return;
    objc_setAssociatedObject(self, &RevenantTableSavedStyleKey, @(self.separatorStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.separatorStyle = UITableViewCellSeparatorStyleNone;
    objc_setAssociatedObject(self, &RevenantTableSeparatorTakenKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_restoreSeparatorsIfDefault
{
    if (![objc_getAssociatedObject(self, &RevenantTableSeparatorTakenKey) boolValue])
        return;
    BOOL backToDefault = UIEdgeInsetsEqualToEdgeInsets(self.separatorInset, UIEdgeInsetsMake(0, 16, 0, 0))
        && !objc_getAssociatedObject(self, &RevenantSeparatorEffectKey)
        && ![objc_getAssociatedObject(self, &RevenantFollowsReadableKey) boolValue];
    if (!backToDefault)
        return;
    NSNumber *saved = objc_getAssociatedObject(self, &RevenantTableSavedStyleKey);
    self.separatorStyle = (UITableViewCellSeparatorStyle)saved.unsignedIntegerValue;
    objc_setAssociatedObject(self, &RevenantTableSeparatorTakenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &RevenantTableSavedStyleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
