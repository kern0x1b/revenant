#import <UIKit/UIKit.h>

BOOL revenant_menu_leaf(UIMenuElement *element);
UIMenuElementAttributes revenant_menu_attributes(UIMenuElement *element);
UIMenuElementState revenant_menu_state(UIMenuElement *element);
void revenant_menu_collect_deferred(NSArray *elements, NSMutableArray *found);
BOOL revenant_menu_has_content(UIMenu *menu, NSDictionary *resolved);
void revenant_menu_flatten(NSArray *elements, NSDictionary *resolved, NSMutableArray *out);
NSString *revenant_menu_button_title(UIMenuElement *element);
BOOL revenant_menu_destructive(UIMenuElement *element);

@interface UIAction (RevenantMenuElements)
- (void)revenant_performWithSender:(id)sender;
@end
