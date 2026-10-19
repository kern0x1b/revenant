#import <UIKit/UIKit.h>

@implementation UIAlertAction {
    NSString *_title;
    UIAlertActionStyle _style;
    BOOL _enabled;
    void (^_handler)(UIAlertAction *action);
}

+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler
{
    UIAlertAction *action = [[self alloc] init];
    action->_title = [title copy];
    action->_style = style;
    action->_enabled = YES;
    action->_handler = [handler copy];
    return action;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIAlertAction *copy = [[[self class] allocWithZone:zone] init];
    copy->_title = _title;
    copy->_style = _style;
    copy->_enabled = _enabled;
    copy->_handler = _handler;
    return copy;
}

- (NSString *)title
{
    return _title;
}

- (UIAlertActionStyle)style
{
    return _style;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
}

- (void (^)(UIAlertAction *action))charon_handler
{
    return _handler;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p Title = \"%@\">", [self class], self, _title];
}

@end
