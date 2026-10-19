#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const NSInteger CharonSeparatorStyleDoubleLine = 3;

static const char CharonTableSeparatorInsetKey;
static const char CharonCellSeparatorInsetKey;
static const char CharonTableSeparatorTakenKey;
static const char CharonTableSavedStyleKey;
static const char CharonSeparatorColorKey;
static const char CharonSeparatorEffectKey;
static const char CharonFollowsReadableKey;
static const char CharonSeparatorViewKey;

@interface CharonTableSeparatorView : UIView
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) UITableViewCellSeparatorStyle style;
@property (nonatomic) CGFloat lineWidth;
@end

@implementation CharonTableSeparatorView
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
    if (_style == (UITableViewCellSeparatorStyle)CharonSeparatorStyleDoubleLine)
        line = CGRectMake(0, 1, rect.size.width, width);
    CGContextSetFillColorWithColor(context, (_color ?: [UIColor lightGrayColor]).CGColor);
    CGContextFillRect(context, line);
}
@end

@interface UITableView (CharonSeparators7)
- (void)charon_takeOverSeparators;
- (void)charon_restoreSeparatorsIfDefault;
@end

@interface UITableViewCell (CharonSeparatorLayout)
- (void)charon_layoutSeparator;
@end

@interface CharonTableSeparatorInstaller : NSObject
@end

@implementation CharonTableSeparatorInstaller

+ (void)load
{
    if ([UITableView instancesRespondToSelector:@selector(separatorEffect)])
        return;
    Class cell = [UITableViewCell class];
    Method layout = class_getInstanceMethod(cell, @selector(layoutSubviews));
    void (*original)(id, SEL) = (void (*)(id, SEL))method_getImplementation(layout);
    class_replaceMethod(cell, @selector(layoutSubviews), imp_implementationWithBlock(^(UITableViewCell *self_) {
        original(self_, @selector(layoutSubviews));
        [self_ charon_layoutSeparator];
    }), method_getTypeEncoding(layout));
}

@end

@implementation UITableViewCell (CharonSeparators7)

- (UIEdgeInsets)separatorInset
{
    NSValue *own = objc_getAssociatedObject(self, &CharonCellSeparatorInsetKey);
    if (own)
        return [own UIEdgeInsetsValue];
    NSValue *fromTable = objc_getAssociatedObject(self, &CharonTableSeparatorInsetKey);
    if (fromTable)
        return [fromTable UIEdgeInsetsValue];
    return UIEdgeInsetsMake(0, 8, 0, 8);
}

- (void)setSeparatorInset:(UIEdgeInsets)separatorInset
{
    objc_setAssociatedObject(self, &CharonCellSeparatorInsetKey, [NSValue valueWithUIEdgeInsets:separatorInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UITableView *table in [self charon_tables])
        [table charon_takeOverSeparators];
}

- (NSArray<UITableView *> *)charon_tables
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

- (void)charon_layoutSeparator
{
    UITableView *table = [self charon_tables].firstObject;
    if (!table)
        return;
    if (![objc_getAssociatedObject(table, &CharonTableSeparatorTakenKey) boolValue])
        return;
    if (![self charon_isInATableRow])
        return;
    UIEdgeInsets inset = self.separatorInset;
    CGFloat width = MAX(0, self.bounds.size.width - inset.left - inset.right);
    CGFloat height = table.separatorStyle == (UITableViewCellSeparatorStyle)CharonSeparatorStyleDoubleLine ? 2 : 1;
    CGRect frame = CGRectMake(inset.left, self.bounds.size.height - inset.bottom - height, width, height);
    if ([objc_getAssociatedObject(table, &CharonFollowsReadableKey) boolValue]) {
        UIEdgeInsets margins = table.layoutMargins;
        frame.origin.x = inset.left + margins.left;
        frame.size.width = MAX(0, self.bounds.size.width - frame.origin.x - inset.right - margins.right);
    }
    CharonTableSeparatorView *separator = objc_getAssociatedObject(self, &CharonSeparatorViewKey);
    if (!separator) {
        separator = [[CharonTableSeparatorView alloc] initWithFrame:frame];
        separator.backgroundColor = [UIColor clearColor];
        objc_setAssociatedObject(self, &CharonSeparatorViewKey, separator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *effect = objc_getAssociatedObject(table, &CharonSeparatorEffectKey);
        if (effect) {
            [self insertSubview:effect belowSubview:separator];
            effect.frame = separator.frame;
        }
        [self addSubview:separator];
    }
    separator.frame = frame;
    separator.color = objc_getAssociatedObject(table, &CharonSeparatorColorKey) ?: table.separatorColor;
    separator.style = table.separatorStyle == UITableViewCellSeparatorStyleNone ? UITableViewCellSeparatorStyleSingleLine : table.separatorStyle;
    [separator setNeedsDisplay];
}

- (BOOL)charon_isInATableRow
{
    return self.superview != nil;
}

@end

@implementation UITableView (CharonSeparators7)

- (UIEdgeInsets)separatorInset
{
    NSValue *stored = objc_getAssociatedObject(self, &CharonTableSeparatorInsetKey);
    return stored ? [stored UIEdgeInsetsValue] : UIEdgeInsetsMake(0, 16, 0, 0);
}

- (void)setSeparatorInset:(UIEdgeInsets)separatorInset
{
    BOOL wasDefault = UIEdgeInsetsEqualToEdgeInsets(self.separatorInset, UIEdgeInsetsMake(0, 16, 0, 0));
    objc_setAssociatedObject(self, &CharonTableSeparatorInsetKey, [NSValue valueWithUIEdgeInsets:separatorInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (UIEdgeInsetsEqualToEdgeInsets(separatorInset, UIEdgeInsetsMake(0, 16, 0, 0)) && wasDefault)
        return;
    [self charon_takeOverSeparators];
}

- (UIColor *)sectionIndexBackgroundColor
{
    return objc_getAssociatedObject(self, &CharonSeparatorColorKey);
}

- (void)setSectionIndexBackgroundColor:(UIColor *)sectionIndexBackgroundColor
{
    objc_setAssociatedObject(self, &CharonSeparatorColorKey, sectionIndexBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)separatorEffect
{
    return objc_getAssociatedObject(self, &CharonSeparatorEffectKey);
}

- (void)setSeparatorEffect:(UIView *)separatorEffect
{
    objc_setAssociatedObject(self, &CharonSeparatorEffectKey, separatorEffect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (separatorEffect)
        [self charon_takeOverSeparators];
}

- (BOOL)cellLayoutMarginsFollowReadableWidth
{
    return [objc_getAssociatedObject(self, &CharonFollowsReadableKey) boolValue];
}

- (void)setCellLayoutMarginsFollowReadableWidth:(BOOL)follows
{
    objc_setAssociatedObject(self, &CharonFollowsReadableKey, @(follows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (follows)
        [self charon_takeOverSeparators];
}

- (void)charon_takeOverSeparators
{
    if ([objc_getAssociatedObject(self, &CharonTableSeparatorTakenKey) boolValue])
        return;
    objc_setAssociatedObject(self, &CharonTableSavedStyleKey, @(self.separatorStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.separatorStyle = UITableViewCellSeparatorStyleNone;
    objc_setAssociatedObject(self, &CharonTableSeparatorTakenKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_restoreSeparatorsIfDefault
{
    if (![objc_getAssociatedObject(self, &CharonTableSeparatorTakenKey) boolValue])
        return;
    BOOL backToDefault = UIEdgeInsetsEqualToEdgeInsets(self.separatorInset, UIEdgeInsetsMake(0, 16, 0, 0))
        && !objc_getAssociatedObject(self, &CharonSeparatorEffectKey)
        && ![objc_getAssociatedObject(self, &CharonFollowsReadableKey) boolValue];
    if (!backToDefault)
        return;
    NSNumber *saved = objc_getAssociatedObject(self, &CharonTableSavedStyleKey);
    self.separatorStyle = (UITableViewCellSeparatorStyle)saved.unsignedIntegerValue;
    objc_setAssociatedObject(self, &CharonTableSeparatorTakenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &CharonTableSavedStyleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
