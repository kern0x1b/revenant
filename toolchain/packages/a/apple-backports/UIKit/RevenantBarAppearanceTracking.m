#import "CharonBarAppearance.h"
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

static const void *CharonWatcherKey = &CharonWatcherKey;
static const void *CharonSignatureKey = &CharonSignatureKey;

id charon_first_appearance(id first, id second, id third, id fourth, id fifth, id sixth)
{
    return first ?: second ?: third ?: fourth ?: fifth ?: sixth;
}

void charon_appearance_store_observed(id owner, const void *key, id appearance, SEL changed)
{
    id stored = [appearance copy];
    if (stored) {
        __weak id weak = owner;
        [stored charon_setChangeObserver:^{
            id strong = weak;
            if (strong)
                ((void (*)(id, SEL))objc_msgSend)(strong, changed);
        }];
    }
    objc_setAssociatedObject(owner, key, stored, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL charon_scroll_at_edge(UIScrollView *scroll, BOOL bottom)
{
    UIEdgeInsets inset = [scroll respondsToSelector:@selector(adjustedContentInset)] ? [scroll adjustedContentInset] : scroll.contentInset;
    if (!bottom)
        return scroll.contentOffset.y + inset.top <= 0.5;
    return scroll.contentOffset.y + scroll.bounds.size.height - inset.bottom >= scroll.contentSize.height - 0.5;
}

static UIScrollView *charon_find_scroll_view(UIView *root)
{
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    for (NSUInteger index = 0; index < queue.count && index < 200; index++) {
        UIView *view = queue[index];
        if ([view isKindOfClass:[UIScrollView class]])
            return (UIScrollView *)view;
        if ([view isKindOfClass:[UINavigationBar class]] || [view isKindOfClass:[UITabBar class]] || [view isKindOfClass:[UIToolbar class]])
            continue;
        [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

UIScrollView *charon_bar_scroll_view(UIView *bar)
{
    UIResponder *responder = bar.nextResponder;
    while (responder && ![responder isKindOfClass:[UIViewController class]])
        responder = responder.nextResponder;
    UIViewController *controller = (UIViewController *)responder;
    for (int depth = 0; controller && depth < 8; depth++) {
        if ([controller isKindOfClass:[UINavigationController class]])
            controller = [(UINavigationController *)controller topViewController];
        else if ([controller isKindOfClass:[UITabBarController class]])
            controller = [(UITabBarController *)controller selectedViewController];
        else
            break;
    }
    return controller && controller.isViewLoaded ? charon_find_scroll_view(controller.view) : nil;
}

@interface CharonScrollWatcher : NSObject
- (instancetype)initWithBar:(UIView *)bar scrollView:(UIScrollView *)scroll bottom:(BOOL)bottom;
- (UIScrollView *)scrollView;
- (BOOL)bottom;
- (void)stop;
@end

@implementation CharonScrollWatcher {
    __weak UIView *_bar;
    __weak UIScrollView *_scroll;
    BOOL _bottom;
    BOOL _edge;
    BOOL _running;
}

- (instancetype)initWithBar:(UIView *)bar scrollView:(UIScrollView *)scroll bottom:(BOOL)bottom
{
    if ((self = [super init])) {
        _bar = bar;
        _scroll = scroll;
        _bottom = bottom;
        _edge = charon_scroll_at_edge(scroll, bottom);
        for (NSString *path in @[@"contentOffset", @"contentSize", @"contentInset"])
            [scroll addObserver:self forKeyPath:path options:0 context:(__bridge void *)self];
        _running = YES;
    }
    return self;
}

- (UIScrollView *)scrollView
{
    return _scroll;
}

- (BOOL)bottom
{
    return _bottom;
}

- (void)stop
{
    if (!_running)
        return;
    _running = NO;
    UIScrollView *scroll = _scroll;
    for (NSString *path in @[@"contentOffset", @"contentSize", @"contentInset"])
        [scroll removeObserver:self forKeyPath:path context:(__bridge void *)self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != (__bridge void *)self)
        return;
    BOOL edge = charon_scroll_at_edge(object, _bottom);
    if (edge == _edge)
        return;
    _edge = edge;
    UIView *bar = _bar;
    if ([bar respondsToSelector:@selector(charon_refreshForced:)])
        [(id)bar charon_refreshForced:NO];
}

- (void)dealloc
{
    [self stop];
}

@end

BOOL charon_bar_at_edge(UIView *bar, BOOL bottom)
{
    UIScrollView *scroll = charon_bar_scroll_view(bar);
    CharonScrollWatcher *watcher = objc_getAssociatedObject(bar, CharonWatcherKey);
    if (watcher && (watcher.scrollView != scroll || watcher.bottom != bottom)) {
        [watcher stop];
        watcher = nil;
        objc_setAssociatedObject(bar, CharonWatcherKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (scroll && !watcher)
        objc_setAssociatedObject(bar, CharonWatcherKey, [[CharonScrollWatcher alloc] initWithBar:bar scrollView:scroll bottom:bottom], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return scroll ? charon_scroll_at_edge(scroll, bottom) : YES;
}

BOOL charon_bar_needs_refresh(UIView *bar, NSString *signature)
{
    NSString *last = objc_getAssociatedObject(bar, CharonSignatureKey);
    if ([last isEqual:signature])
        return NO;
    objc_setAssociatedObject(bar, CharonSignatureKey, signature, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static NSHashTable *charon_tracked(void)
{
    static NSHashTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSHashTable weakObjectsHashTable];
    });
    return table;
}

void charon_track_bar(UIView *bar)
{
    @synchronized (charon_tracked()) {
        [charon_tracked() addObject:bar];
    }
}

void charon_refresh_bars_showing(id item)
{
    NSArray *bars;
    @synchronized (charon_tracked()) {
        bars = charon_tracked().allObjects;
    }
    for (UIView *bar in bars) {
        BOOL shows = ([bar isKindOfClass:[UINavigationBar class]] && [(UINavigationBar *)bar topItem] == item) || ([bar isKindOfClass:[UITabBar class]] && [(UITabBar *)bar selectedItem] == item);
        if (shows && [bar respondsToSelector:@selector(charon_refreshForced:)])
            [(id)bar charon_refreshForced:YES];
    }
}

static void charon_bar_changed(UIView *bar, BOOL later)
{
    charon_track_bar(bar);
    [(id)bar charon_refreshForced:NO];
    if (!later)
        return;
    __weak UIView *weak = bar;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strong = weak;
        if (strong)
            [(id)strong charon_refreshForced:NO];
    });
}

@interface CharonBarAppearanceInstaller : NSObject
@end

@implementation CharonBarAppearanceInstaller

+ (void)load
{
    Dl_info info;
    if (!dladdr((__bridge const void *)[UINavigationBarAppearance class], &info) || !strstr(info.dli_fname, "Backports"))
        return;
    [self hook:[UINavigationBar class] selector:@selector(layoutSubviews) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar) {
            ((void (*)(id, SEL))original)(bar, selector);
            charon_bar_changed(bar, NO);
        });
    }];
    [self hook:[UINavigationBar class] selector:@selector(didMoveToWindow) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar) {
            ((void (*)(id, SEL))original)(bar, selector);
            charon_bar_changed(bar, YES);
        });
    }];
    [self hook:[UINavigationBar class] selector:@selector(pushNavigationItem:animated:) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar, id item, BOOL animated) {
            ((void (*)(id, SEL, id, BOOL))original)(bar, selector, item, animated);
            charon_bar_changed(bar, YES);
        });
    }];
    [self hook:[UINavigationBar class] selector:@selector(popNavigationItemAnimated:) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^id(UIView *bar, BOOL animated) {
            id popped = ((id (*)(id, SEL, BOOL))original)(bar, selector, animated);
            charon_bar_changed(bar, YES);
            return popped;
        });
    }];
    [self hook:[UINavigationBar class] selector:@selector(setItems:animated:) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar, NSArray *items, BOOL animated) {
            ((void (*)(id, SEL, id, BOOL))original)(bar, selector, items, animated);
            charon_bar_changed(bar, YES);
        });
    }];
    [self hook:[UITabBar class] selector:@selector(layoutSubviews) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar) {
            ((void (*)(id, SEL))original)(bar, selector);
            charon_bar_changed(bar, NO);
        });
    }];
    [self hook:[UITabBar class] selector:@selector(didMoveToWindow) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar) {
            ((void (*)(id, SEL))original)(bar, selector);
            charon_bar_changed(bar, YES);
        });
    }];
    [self hook:[UITabBar class] selector:@selector(setSelectedItem:) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar, id item) {
            ((void (*)(id, SEL, id))original)(bar, selector, item);
            charon_bar_changed(bar, YES);
        });
    }];
    [self hook:[UITabBar class] selector:@selector(setItems:animated:) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar, NSArray *items, BOOL animated) {
            ((void (*)(id, SEL, id, BOOL))original)(bar, selector, items, animated);
            charon_bar_changed(bar, YES);
        });
    }];
    [self hook:[UIToolbar class] selector:@selector(layoutSubviews) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar) {
            ((void (*)(id, SEL))original)(bar, selector);
            charon_bar_changed(bar, NO);
        });
    }];
    [self hook:[UIToolbar class] selector:@selector(didMoveToWindow) make:^IMP(IMP original, SEL selector) {
        return imp_implementationWithBlock(^(UIView *bar) {
            ((void (*)(id, SEL))original)(bar, selector);
            charon_bar_changed(bar, YES);
        });
    }];
}

+ (void)hook:(Class)target selector:(SEL)selector make:(IMP (^)(IMP original, SEL selector))make
{
    Method method = class_getInstanceMethod(target, selector);
    if (!method)
        return;
    class_replaceMethod(target, selector, make(method_getImplementation(method), selector), method_getTypeEncoding(method));
}

@end
