#import <UIKit/UIKit.h>

@interface RevenantDragDropBox : NSObject {
@public
    __weak id dragDelegate;
    __weak id dropDelegate;
    BOOL didSetDragInteractionEnabled;
    BOOL dragInteractionEnabled;
}
@end

RevenantDragDropBox *revenant_drag_drop_box(id object);
BOOL revenant_drag_interaction_enabled(id object);
void revenant_set_drag_interaction_enabled_default(BOOL enabled);
void revenant_set_drag_interaction_enabled(id object, BOOL enabled);
