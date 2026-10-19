#import <objc/runtime.h>
#import "RevenantDragDrop.h"

@implementation RevenantDragDropBox
@end

static const char RevenantDragDropKey;
static BOOL RevenantDragInteractionDefault = NO;

RevenantDragDropBox *revenant_drag_drop_box(id object)
{
    RevenantDragDropBox *box = objc_getAssociatedObject(object, &RevenantDragDropKey);
    if (!box) {
        box = [[RevenantDragDropBox alloc] init];
        objc_setAssociatedObject(object, &RevenantDragDropKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return box;
}

BOOL revenant_drag_interaction_enabled(id object)
{
    RevenantDragDropBox *box = objc_getAssociatedObject(object, &RevenantDragDropKey);
    return box && box->didSetDragInteractionEnabled ? box->dragInteractionEnabled : RevenantDragInteractionDefault;
}

void revenant_set_drag_interaction_enabled_default(BOOL enabled)
{
    RevenantDragInteractionDefault = enabled;
}

void revenant_set_drag_interaction_enabled(id object, BOOL enabled)
{
    RevenantDragDropBox *box = revenant_drag_drop_box(object);
    box->didSetDragInteractionEnabled = YES;
    box->dragInteractionEnabled = enabled;
}
