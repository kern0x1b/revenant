#import <UIKit/UIKit.h>

// The two sessions a drag is made of, shared between the file that builds them and the file that
// drives them, the way CharonDragDrop.h and CharonBlur.h are shared here. A header and not a
// category: the release has no such class, so this is one of the port's own.
@interface CharonDragSession : NSObject <UIDragSession>
@property (nonatomic, strong) NSMutableArray<UIDragItem *> *items;
@property (nonatomic, strong) id localContext;
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign) BOOL allowsMoveOperation;
@property (nonatomic, weak) UIDragInteraction *interaction;
- (instancetype)initWithItems:(NSArray<UIDragItem *> *)items interaction:(UIDragInteraction *)interaction;
@end

@interface CharonDropSession : NSObject <UIDropSession>
@property (nonatomic, strong) CharonDragSession *dragSession;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, assign) UIDropSessionProgressIndicatorStyle progressIndicatorStyle;
@property (nonatomic, weak) UIDropInteraction *interaction;
- (instancetype)initWithDragSession:(CharonDragSession *)dragSession interaction:(UIDropInteraction *)interaction;
@end

// The two things a view asks an interaction when it wants to know whether a drag is under way: the
// session the drag is carrying, and the session the drop is holding. Declared here so the view side
// and the interaction side agree on them.
@interface UIDragInteraction (CharonSessionQueries)
@property (nonatomic, strong, readonly) CharonDragSession *session;
@end

@interface UIDropInteraction (CharonSessionQueries)
@property (nonatomic, strong, readonly) CharonDropSession *currentDrop;
@end
