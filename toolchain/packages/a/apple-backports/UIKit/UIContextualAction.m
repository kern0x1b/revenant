#import <UIKit/UIKit.h>

static UIColor *charon_default_background(UIContextualActionStyle style)
{
    if (style == UIContextualActionStyleNormal)
        return [UIColor colorWithRed:0.78f green:0.78f blue:0.8f alpha:1];
    if (style == UIContextualActionStyleDestructive)
        return [UIColor systemRedColor];
    return nil;
}

@implementation UIContextualAction {
    UIContextualActionStyle _style;
    UIContextualActionHandler _handler;
    NSString *_title;
    UIColor *_backgroundColor;
    UIImage *_image;
}

+ (instancetype)contextualActionWithStyle:(UIContextualActionStyle)style title:(NSString *)title handler:(UIContextualActionHandler)handler
{
    UIContextualAction *action = [[self alloc] init];
    action->_style = style;
    action->_title = [title copy];
    action->_handler = [handler copy];
    action->_backgroundColor = charon_default_background(style);
    return action;
}

- (UIContextualActionStyle)style
{
    return _style;
}

- (UIContextualActionHandler)handler
{
    return _handler;
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
    _backgroundColor = backgroundColor ? [backgroundColor copy] : charon_default_background(_style);
}

- (UIImage *)image
{
    return _image;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
}

@end
