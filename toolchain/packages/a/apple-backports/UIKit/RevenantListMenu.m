#import "CharonListMenu.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface CharonListMenuDelegate : NSObject <UIContextMenuInteractionDelegate>
- (instancetype)initWithView:(UIScrollView *)view;
@end

static const char charon_interaction_key, charon_delegate_key;

@implementation CharonListMenuDelegate {
@private
    __weak UIScrollView *_view;
    NSMutableDictionary *_paths;
}

- (instancetype)initWithView:(UIScrollView *)view
{
    if ((self = [super init])) {
        _view = view;
        _paths = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSIndexPath *)pathAt:(CGPoint)point
{
    UIScrollView *view = _view;
    if ([view isKindOfClass:[UITableView class]])
        return [(UITableView *)view indexPathForRowAtPoint:point];
    return [(UICollectionView *)view indexPathForItemAtPoint:point];
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    UIScrollView *view = _view;
    id delegate = [(id)view delegate];
    NSIndexPath *path = [self pathAt:location];
    if (!path || !delegate)
        return nil;
    UIContextMenuConfiguration *configuration = nil;
    if ([view isKindOfClass:[UITableView class]]) {
        SEL selector = NSSelectorFromString(@"tableView:contextMenuConfigurationForRowAtIndexPath:point:");
        if ([delegate respondsToSelector:selector])
            configuration = ((UIContextMenuConfiguration * (*)(id, SEL, id, id, CGPoint))objc_msgSend)(delegate, selector, view, path, location);
    } else {
        SEL selector = NSSelectorFromString(@"collectionView:contextMenuConfigurationForItemAtIndexPath:point:");
        if ([delegate respondsToSelector:selector])
            configuration = ((UIContextMenuConfiguration * (*)(id, SEL, id, id, CGPoint))objc_msgSend)(delegate, selector, view, path, location);
    }
    if (configuration)
        _paths[[NSValue valueWithNonretainedObject:configuration]] = path;
    return configuration;
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    UIScrollView *view = _view;
    id delegate = [(id)view delegate];
    SEL selector = NSSelectorFromString([view isKindOfClass:[UITableView class]] ? @"tableView:willDisplayContextMenuWithConfiguration:animator:"
                                                                                 : @"collectionView:willDisplayContextMenuWithConfiguration:animator:");
    if ([delegate respondsToSelector:selector])
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, selector, view, configuration, animator);
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    UIScrollView *view = _view;
    id delegate = [(id)view delegate];
    SEL selector = NSSelectorFromString([view isKindOfClass:[UITableView class]] ? @"tableView:willEndContextMenuInteractionWithConfiguration:animator:"
                                                                                 : @"collectionView:willEndContextMenuInteractionWithConfiguration:animator:");
    if ([delegate respondsToSelector:selector])
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, selector, view, configuration, animator);
    [_paths removeObjectForKey:[NSValue valueWithNonretainedObject:configuration]];
}

@end

UIContextMenuInteraction *charon_list_menu_interaction(UIScrollView *view, BOOL create)
{
    UIContextMenuInteraction *held = objc_getAssociatedObject(view, &charon_interaction_key);
    if (held || !create)
        return held;
    CharonListMenuDelegate *delegate = [[CharonListMenuDelegate alloc] initWithView:view];
    held = [[UIContextMenuInteraction alloc] initWithDelegate:delegate];
    objc_setAssociatedObject(view, &charon_delegate_key, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &charon_interaction_key, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [view addInteraction:held];
    return held;
}

static void charon_hook_delegate(Class cls, SEL setter, NSArray *selectors)
{
    Method method = class_getInstanceMethod(cls, setter);
    if (!method)
        return;
    void (*original)(id, SEL, id) = (void *)class_getMethodImplementation(cls, setter);
    class_replaceMethod(cls, setter, imp_implementationWithBlock(^(UIScrollView *view, id delegate) {
        original(view, setter, delegate);
        for (NSString *name in selectors) {
            if ([delegate respondsToSelector:NSSelectorFromString(name)]) {
                charon_list_menu_interaction(view, YES);
                return;
            }
        }
    }), method_getTypeEncoding(method));
}

@interface CharonListMenuHooks : NSObject
@end

@implementation CharonListMenuHooks

+ (void)load
{
    charon_hook_delegate([UITableView class], @selector(setDelegate:), @[@"tableView:contextMenuConfigurationForRowAtIndexPath:point:"]);
    charon_hook_delegate([UICollectionView class], @selector(setDelegate:), @[@"collectionView:contextMenuConfigurationForItemAtIndexPath:point:"]);
}

@end
