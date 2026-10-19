#import <UIKit/UIKit.h>
#import "../RevenantSayOnce.h"

static inline void revenant_menus_say_once(NSString *key, NSString *text)
{
    revenant_say_once_for(key, text);
}

static inline NSString *revenant_short_description(id object)
{
    return object ? [NSString stringWithFormat:@"<%@: %p>", [object class], object] : @"(null)";
}

static inline UIWindow *revenant_window_of(UIView *view)
{
    return [view isKindOfClass:[UIWindow class]] ? (UIWindow *)view : view.window;
}

NSString *revenant_menu_attributes_text(NSUInteger attributes);

@interface UIMenuElement (RevenantMenus)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(UIImage *)image;
- (void)revenant_setTitle:(NSString *)title;
- (void)revenant_setImage:(UIImage *)image;
@end

typedef NS_ENUM(NSInteger, UIActionRepeatBehavior) {
    UIActionRepeatBehaviorDisabled = 0,
    UIActionRepeatBehaviorEnabled = 1,
};

@interface UIAction (RevenantMenus)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier handler:(UIActionHandler)handler;
- (void)revenant_performWithSender:(id)sender;
@end

@interface UICommand (RevenantMenus)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)propertyList alternates:(NSArray *)alternates;
- (void)revenant_performWithSender:(id)sender target:(id)target;
@end

@interface UIMenu (RevenantMenus)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier options:(UIMenuOptions)options
                            children:(NSArray<UIMenuElement *> *)children;
@end

@interface UIDeferredMenuElement (RevenantMenus)
- (void)revenant_fulfillWithCompletion:(void (^)(NSArray<UIMenuElement *> *elements))completion;
@end

@interface UIContextMenuConfiguration (RevenantMenus)
- (UIContextMenuActionProvider)revenant_actionProvider;
@end

@interface UIContextMenuInteraction (RevenantMenus)
- (UIMenu *)revenant_visibleMenu;
- (void)revenant_replaceVisibleMenu:(UIMenu *)menu;
- (void)revenant_beginAtLocation:(CGPoint)location;
@end


@interface RevenantControlProxy : NSObject
- (instancetype)initWithControl:(UIControl *)control action:(UIAction *)action;
- (void)revenant_fire:(id)sender;
@property (nonatomic, weak) UIControl *control;
@property (nonatomic, strong) UIAction *action;
@end

void revenant_show_menu(UIMenu *menu);
