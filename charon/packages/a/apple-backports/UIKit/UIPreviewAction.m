#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface UIPreviewAction (CharonPreviewAction)
@property (nonatomic, readonly) UIPreviewActionStyle style;
@end

@interface UIPreviewActionGroup (CharonPreviewAction)
@property (nonatomic, readonly) UIPreviewActionStyle style;
@property (nonatomic, readonly, copy) NSArray<UIPreviewAction *> *actions;
@end

@implementation UIPreviewAction {
@private
    NSString *_title;
    UIPreviewActionStyle _style;
    void (^_handler)(id<UIPreviewActionItem>, UIViewController *);
}

+ (instancetype)actionWithTitle:(NSString *)title style:(UIPreviewActionStyle)style handler:(void (^)(UIPreviewAction *, UIViewController *))handler
{
    UIPreviewAction *action = [[self alloc] init];
    action->_title = [title copy];
    action->_style = style;
    action->_handler = [handler copy];
    return action;
}

- (NSString *)title
{
    return _title;
}

- (UIPreviewActionStyle)style
{
    return _style;
}

- (void (^)(id<UIPreviewActionItem>, UIViewController *))handler
{
    return _handler;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPreviewAction *copy = [[[self class] allocWithZone:zone] init];
    copy->_title = [_title copy];
    copy->_style = _style;
    copy->_handler = [_handler copy];
    return copy;
}

@end

@implementation UIPreviewActionGroup {
@private
    NSString *_title;
    UIPreviewActionStyle _style;
    NSArray<UIPreviewAction *> *_actions;
}

+ (instancetype)actionGroupWithTitle:(NSString *)title style:(UIPreviewActionStyle)style actions:(NSArray<UIPreviewAction *> *)actions
{
    UIPreviewActionGroup *group = [[self alloc] init];
    group->_title = [title copy];
    group->_style = style;
    group->_actions = [actions copy];
    return group;
}

- (NSString *)title
{
    return _title;
}

- (UIPreviewActionStyle)style
{
    return _style;
}

- (NSArray<UIPreviewAction *> *)actions
{
    return _actions;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIPreviewActionGroup *copy = [[[self class] allocWithZone:zone] init];
    copy->_title = [_title copy];
    copy->_style = _style;
    copy->_actions = [_actions copy];
    return copy;
}

@end

@interface UIViewController (CharonPreviewActionItems)
@end

@implementation UIViewController (CharonPreviewActionItems)

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    return @[];
}

@end
