#import <UIKit/UIKit.h>

@interface CharonDragDropBox : NSObject {
@public
    __weak id dragDelegate;
    __weak id dropDelegate;
    BOOL didSetDragInteractionEnabled;
    BOOL dragInteractionEnabled;
}
@end

CharonDragDropBox *charon_drag_drop_box(id object);
BOOL charon_drag_interaction_enabled(id object);
void charon_set_drag_interaction_enabled_default(BOOL enabled);
void charon_set_drag_interaction_enabled(id object, BOOL enabled);
