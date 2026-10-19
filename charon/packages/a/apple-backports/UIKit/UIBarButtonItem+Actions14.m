#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_action_key, charon_menu_key, charon_proxy_key;

@interface CharonItemProxy : NSObject
- (instancetype)initWithItem:(UIBarButtonItem *)item;
- (void)charon_tapped:(id)sender;
@end

@implementation CharonItemProxy {
@private
    __weak UIBarButtonItem *_item;
}

- (instancetype)initWithItem:(UIBarButtonItem *)item
{
    if ((self = [super init]))
        _item = item;
    return self;
}

- (void)charon_tapped:(id)sender
{
    UIBarButtonItem *item = _item;
    UIAction *action = item.primaryAction;
    if (action)
        [action charon_performWithSender:item];
    else if (item.menu)
        charon_show_menu(item.menu);
}

@end

static void charon_wire(UIBarButtonItem *item)
{
    CharonItemProxy *proxy = objc_getAssociatedObject(item, &charon_proxy_key);
    // A menu does not take the tap from an action of the application's own:
    // UIKit shows it on a long press then, which an item of the release has none of.
    BOOL own = item.action != NULL && !(proxy && item.target == proxy);
    BOOL wanted = item.primaryAction != nil || (item.menu != nil && !own);
    if (wanted && !proxy) {
        proxy = [[CharonItemProxy alloc] initWithItem:item];
        objc_setAssociatedObject(item, &charon_proxy_key, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        item.target = proxy;
        item.action = @selector(charon_tapped:);
    } else if (!wanted && proxy) {
        if (item.target == proxy) {
            item.target = nil;
            item.action = NULL;
        }
        objc_setAssociatedObject(item, &charon_proxy_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@implementation UIBarButtonItem (CharonActions14)

+ (instancetype)fixedSpaceItemOfWidth:(CGFloat)width
{
    UIBarButtonItem *item = [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:NULL];
    item.width = width;
    return item;
}

+ (instancetype)flexibleSpaceItem
{
    return [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
}

- (instancetype)initWithPrimaryAction:(UIAction *)primaryAction
{
    if ((self = [self initWithTitle:primaryAction.title style:UIBarButtonItemStylePlain target:nil action:NULL])) {
        if (primaryAction.image)
            self.image = primaryAction.image;
        [self setPrimaryAction:primaryAction];
    }
    return self;
}

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem primaryAction:(UIAction *)primaryAction
{
    if ((self = [self initWithBarButtonSystemItem:systemItem target:nil action:NULL]))
        [self setPrimaryAction:primaryAction];
    return self;
}

- (instancetype)initWithTitle:(NSString *)title menu:(UIMenu *)menu
{
    if ((self = [self initWithTitle:title style:UIBarButtonItemStylePlain target:nil action:NULL]))
        [self setMenu:menu];
    return self;
}

- (instancetype)initWithImage:(UIImage *)image menu:(UIMenu *)menu
{
    if ((self = [self initWithImage:image style:UIBarButtonItemStylePlain target:nil action:NULL]))
        [self setMenu:menu];
    return self;
}

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem menu:(UIMenu *)menu
{
    if ((self = [self initWithBarButtonSystemItem:systemItem target:nil action:NULL]))
        [self setMenu:menu];
    return self;
}

- (UIAction *)primaryAction
{
    return objc_getAssociatedObject(self, &charon_action_key);
}

- (void)setPrimaryAction:(UIAction *)primaryAction
{
    objc_setAssociatedObject(self, &charon_action_key, [primaryAction copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (primaryAction) {
        if (primaryAction.title.length)
            self.title = primaryAction.title;
        if (primaryAction.image)
            self.image = primaryAction.image;
    }
    charon_wire(self);
}

- (UIMenu *)menu
{
    return objc_getAssociatedObject(self, &charon_menu_key);
}

- (void)setMenu:(UIMenu *)menu
{
    objc_setAssociatedObject(self, &charon_menu_key, [menu copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_wire(self);
}

@end
