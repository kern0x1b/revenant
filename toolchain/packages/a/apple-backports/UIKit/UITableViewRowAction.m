#import "CharonSwipe.h"

@implementation UITableViewRowAction {
    UITableViewRowActionStyle _style;
    NSString *_title;
    UIColor *_backgroundColor;
    UIVisualEffect *_backgroundEffect;
    void (^_handler)(UITableViewRowAction *, NSIndexPath *);
}

+ (instancetype)rowActionWithStyle:(UITableViewRowActionStyle)style title:(NSString *)title handler:(void (^)(UITableViewRowAction *, NSIndexPath *))handler
{
    UITableViewRowAction *action = [[self alloc] init];
    action->_style = style;
    action->_title = [title copy];
    action->_handler = [handler copy];
    action->_backgroundColor = style == UITableViewRowActionStyleNormal ? [UIColor colorWithRed:0.78f green:0.78f blue:0.8f alpha:1] : [UIColor systemRedColor];
    return action;
}

- (id)copyWithZone:(NSZone *)zone
{
    UITableViewRowAction *copy = [[[self class] alloc] init];
    copy->_style = _style;
    copy->_title = [_title copy];
    copy->_backgroundColor = [_backgroundColor copy];
    copy->_handler = [_handler copy];
    return copy;
}

- (void)charon_performForIndexPath:(NSIndexPath *)indexPath
{
    if (_handler)
        _handler(self, indexPath);
}

- (UITableViewRowActionStyle)style
{
    return _style;
}

- (NSString *)title
{
    return _title;
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
}

- (UIColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    _backgroundColor = [backgroundColor copy];
}

- (UIVisualEffect *)backgroundEffect
{
    return _backgroundEffect;
}

- (void)setBackgroundEffect:(UIVisualEffect *)backgroundEffect
{
    _backgroundEffect = [backgroundEffect copy];
}

@end
