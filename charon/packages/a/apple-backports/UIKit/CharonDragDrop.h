#import <UIKit/UIKit.h>

// What UITableView and UICollectionView keep for their drag and drop properties. Each class's category
// is a file of its own, since UICollectionView arrives in 6.0 and UITableView is there from 2.0.
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
// The class's own default, supplied by the drag and drop object: this header is included by files
// carried from every band, so it must not name an iOS 11 class itself.
void charon_set_drag_interaction_enabled_default(BOOL enabled);
void charon_set_drag_interaction_enabled(id object, BOOL enabled);
