#import <UIKit/UIKit.h>

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

@interface UIDragInteraction (CharonSessionQueries)
@property (nonatomic, strong, readonly) CharonDragSession *session;
@end

@interface UIDropInteraction (CharonSessionQueries)
@property (nonatomic, strong, readonly) CharonDropSession *currentDrop;
@end
