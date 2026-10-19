#import "RevenantMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wprotocol"

@interface RevenantMenuHost : NSObject <UIContextMenuInteractionDelegate>
@end

@implementation RevenantMenuHost {
@private
    UIMenu *_menu;
    UIView *_view;
    UIContextMenuInteraction *_interaction;
}

+ (NSMutableSet *)live
{
    static NSMutableSet *live;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        live = [[NSMutableSet alloc] init];
    });
    return live;
}

- (BOOL)showMenu:(UIMenu *)menu
{
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window)
        return NO;
    _menu = menu;
    CGRect bounds = window.bounds;
    _view = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1, 1)];
    _view.hidden = YES;
    [window addSubview:_view];
    _interaction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [_view addInteraction:_interaction];
    [[RevenantMenuHost live] addObject:self];
    [_interaction revenant_beginAtLocation:CGPointZero];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_view && ![_interaction revenant_visibleMenu])
            [self finish];
    });
    return YES;
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    UIMenu *menu = _menu;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        return menu;
    }];
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [animator addCompletion:^{
        [self finish];
    }];
}

- (void)finish
{
    [_view removeInteraction:_interaction];
    [_view removeFromSuperview];
    _view = nil;
    _interaction = nil;
    [[RevenantMenuHost live] removeObject:self];
}

@end

void revenant_show_menu(UIMenu *menu)
{
    [[[RevenantMenuHost alloc] init] showMenu:menu];
}

static const char revenant_interaction_key, revenant_primary_key, revenant_trigger_key;

@interface RevenantMenuTrigger : NSObject
- (instancetype)initWithControl:(UIControl *)control;
- (void)revenant_fire:(id)sender;
@end

@implementation RevenantMenuTrigger {
@private
    __weak UIControl *_control;
}

- (instancetype)initWithControl:(UIControl *)control
{
    if ((self = [super init]))
        _control = control;
    return self;
}

- (void)revenant_fire:(id)sender
{
    UIControl *control = _control;
    UIContextMenuInteraction *interaction = control.contextMenuInteraction;
    if (interaction)
        [interaction revenant_beginAtLocation:CGPointMake(CGRectGetMidX(control.bounds), CGRectGetMidY(control.bounds))];
}

@end

static void revenant_update_trigger(UIControl *control)
{
    RevenantMenuTrigger *trigger = objc_getAssociatedObject(control, &revenant_trigger_key);
    BOOL wanted = control.showsMenuAsPrimaryAction && control.contextMenuInteraction;
    if (wanted && !trigger) {
        trigger = [[RevenantMenuTrigger alloc] initWithControl:control];
        objc_setAssociatedObject(control, &revenant_trigger_key, trigger, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [control addTarget:trigger action:@selector(revenant_fire:) forControlEvents:UIControlEventTouchUpInside];
    } else if (!wanted && trigger) {
        [control removeTarget:trigger action:NULL forControlEvents:UIControlEventAllEvents];
        objc_setAssociatedObject(control, &revenant_trigger_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@interface UIControl (RevenantMenus14) <UIContextMenuInteractionDelegate>
@end

@implementation UIControl (RevenantMenus14)

- (UIContextMenuInteraction *)contextMenuInteraction
{
    return objc_getAssociatedObject(self, &revenant_interaction_key);
}

- (BOOL)isContextMenuInteractionEnabled
{
    return self.contextMenuInteraction != nil;
}

- (void)setContextMenuInteractionEnabled:(BOOL)contextMenuInteractionEnabled
{
    UIContextMenuInteraction *held = self.contextMenuInteraction;
    if (contextMenuInteractionEnabled && !held) {
        held = [[UIContextMenuInteraction alloc] initWithDelegate:(id<UIContextMenuInteractionDelegate>)self];
        objc_setAssociatedObject(self, &revenant_interaction_key, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self addInteraction:held];
    } else if (!contextMenuInteractionEnabled && held) {
        [self removeInteraction:held];
        objc_setAssociatedObject(self, &revenant_interaction_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    revenant_update_trigger(self);
}

- (BOOL)showsMenuAsPrimaryAction
{
    return [objc_getAssociatedObject(self, &revenant_primary_key) boolValue];
}

- (void)setShowsMenuAsPrimaryAction:(BOOL)showsMenuAsPrimaryAction
{
    objc_setAssociatedObject(self, &revenant_primary_key, @(showsMenuAsPrimaryAction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_update_trigger(self);
}

- (CGPoint)menuAttachmentPointForConfiguration:(UIContextMenuConfiguration *)configuration
{
    return CGPointZero;
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    return nil;
}

- (UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return nil;
}

- (UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction previewForDismissingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return nil;
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
}

@end
