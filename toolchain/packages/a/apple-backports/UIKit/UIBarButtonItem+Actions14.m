#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_action_key, revenant_menu_key, revenant_proxy_key;

@interface RevenantItemProxy : NSObject
- (instancetype)initWithItem:(UIBarButtonItem *)item;
- (void)revenant_tapped:(id)sender;
@end

@implementation RevenantItemProxy {
@private
    __weak UIBarButtonItem *_item;
}

- (instancetype)initWithItem:(UIBarButtonItem *)item
{
    if ((self = [super init]))
        _item = item;
    return self;
}

- (void)revenant_tapped:(id)sender
{
    UIBarButtonItem *item = _item;
    UIAction *action = item.primaryAction;
    if (action)
        [action revenant_performWithSender:item];
    else if (item.menu)
        revenant_show_menu(item.menu);
}

@end

static void revenant_wire(UIBarButtonItem *item)
{
    RevenantItemProxy *proxy = objc_getAssociatedObject(item, &revenant_proxy_key);
    BOOL own = item.action != NULL && !(proxy && item.target == proxy);
    BOOL wanted = item.primaryAction != nil || (item.menu != nil && !own);
    if (wanted && !proxy) {
        proxy = [[RevenantItemProxy alloc] initWithItem:item];
        objc_setAssociatedObject(item, &revenant_proxy_key, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        item.target = proxy;
        item.action = @selector(revenant_tapped:);
    } else if (!wanted && proxy) {
        if (item.target == proxy) {
            item.target = nil;
            item.action = NULL;
        }
        objc_setAssociatedObject(item, &revenant_proxy_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@implementation UIBarButtonItem (RevenantActions14)

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
    return objc_getAssociatedObject(self, &revenant_action_key);
}

- (void)setPrimaryAction:(UIAction *)primaryAction
{
    objc_setAssociatedObject(self, &revenant_action_key, [primaryAction copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (primaryAction) {
        if (primaryAction.title.length)
            self.title = primaryAction.title;
        if (primaryAction.image)
            self.image = primaryAction.image;
    }
    revenant_wire(self);
}

- (UIMenu *)menu
{
    return objc_getAssociatedObject(self, &revenant_menu_key);
}

- (void)setMenu:(UIMenu *)menu
{
    objc_setAssociatedObject(self, &revenant_menu_key, [menu copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_wire(self);
}

@end
