#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// A table view's separators, and a cell's own inset for them, and the effect and readable width that
// go with them. All of it arrived with iOS 7, where the separator stopped running the full width of
// the cell and became something a table and a cell could move.
//
// The defaults are measured and none of them is the one a guess gives: a table made by hand answers
// {0, 16, 0, 0}, a cell answers {0, 8, 0, 8}, the style is SingleLine and the colour is set
// (tests/backports/host/uikitscroll, the table.separator*, cell.separatorInset* and screen.scale
// cases).
//
// How the port draws an inset separator is the release's own mechanism used the other way round.
// The release draws a table's separator itself and offers no way to move it, and it draws **none at
// all** when the table's separatorStyle is None. So when a table or a cell asks for anything that is
// not the default, the port sets that style to None for that table only, remembering what it was,
// and draws the separator in a view of its own inside each cell at the inset that was asked for,
// with the table's own colour and style. When every value is back at its default the release draws as
// it always did, so nothing about a plain table's look changes.

// The style value iOS 7 through 12 named (UITableViewCellSeparatorStyle)CharonSeparatorStyleDoubleLine, before iOS 13
// removed the case. The port's header declares only None, SingleLine and the deprecated etched one,
// so the double line is reached by the value it had rather than by a name this port's headers do not
// carry; an application compiled against those headers cannot ask for it either.
static const NSInteger CharonSeparatorStyleDoubleLine = 3;

static const char CharonTableSeparatorInsetKey;   // UIEdgeInsets, on the table
static const char CharonCellSeparatorInsetKey;    // UIEdgeInsets, on the cell
static const char CharonTableSeparatorTakenKey;   // BOOL, on the table: the port is drawing
static const char CharonTableSavedStyleKey;       // NSNumber, on the table: the release's style
static const char CharonSeparatorColorKey;        // UIColor, on the table
static const char CharonSeparatorEffectKey;       // UIView, on the table
static const char CharonFollowsReadableKey;       // BOOL, on the table
static const char CharonSeparatorViewKey;         // the port's separator view, on the cell

// The separator the port draws: a line of the release's own colour, in the table's own style, at the
// inset the table or the cell asked for.
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
    // A single line is one point of the release's own separator, and a double line is that with a
    // second one a point below it, which is what the release's two styles look like.
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

// Declared here because the installer's +load runs before this category is attached, and it calls
// this on the cell.
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
    // Wrapped with the original kept and called, the way UINavigationController+InteractivePop.m
    // wraps -viewDidLoad: a block needs no category to be attached, so +load cannot run too early for
    // it. The cell's layout pass is where its separator has to be placed, and only when the table it
    // is in has asked the port to draw it.
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

// A cell's own inset, and the table's when the cell has none of its own: the header says a cell's
// wins over the table's, and a cell made by hand has neither, which is the 8 a guess would miss.
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
    // The table a cell is in, found by walking up: a cell knows its superview, not its table, and
    // the tree keeps no other link.
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
        return;   // the release is drawing this table's separators, and does so as it always did
    if (![self charon_isInATableRow])
        return;
    UIEdgeInsets inset = self.separatorInset;
    CGFloat width = MAX(0, self.bounds.size.width - inset.left - inset.right);
    CGFloat height = table.separatorStyle == (UITableViewCellSeparatorStyle)CharonSeparatorStyleDoubleLine ? 2 : 1;
    CGRect frame = CGRectMake(inset.left, self.bounds.size.height - inset.bottom - height, width, height);
    // The readable width, when the table follows it, narrows the separator the way it narrows the
    // cell's own margins: the same inset the table's layout margins give.
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
        // The effect, when the table has one, goes behind the line rather than replacing it, which is
        // what an effect behind a separator is.
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
    // A cell that is not showing a row draws no separator: a cell reused and not yet placed, or one
    // an application made for its own use, has no row to put a line under.
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

// The port takes the separator over for this table by asking the release to draw none, which is the
// release's own answer for a table with no separator. What it was is remembered, so putting every
// value back at its default gives the release its own separator back and the table its old look.
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
