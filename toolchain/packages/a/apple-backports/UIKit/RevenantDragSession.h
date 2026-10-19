#import <UIKit/UIKit.h>

@interface RevenantDragSession : NSObject <UIDragSession>
@property (nonatomic, strong) NSMutableArray<UIDragItem *> *items;
@property (nonatomic, strong) id localContext;
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign) BOOL allowsMoveOperation;
@property (nonatomic, weak) UIDragInteraction *interaction;
- (instancetype)initWithItems:(NSArray<UIDragItem *> *)items interaction:(UIDragInteraction *)interaction;
@end

@interface RevenantDropSession : NSObject <UIDropSession>
@property (nonatomic, strong) RevenantDragSession *dragSession;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, assign) UIDropSessionProgressIndicatorStyle progressIndicatorStyle;
@property (nonatomic, weak) UIDropInteraction *interaction;
- (instancetype)initWithDragSession:(RevenantDragSession *)dragSession interaction:(UIDropInteraction *)interaction;
@end

@interface UIDragInteraction (RevenantSessionQueries)
@property (nonatomic, strong, readonly) RevenantDragSession *session;
@end

@interface UIDropInteraction (RevenantSessionQueries)
@property (nonatomic, strong, readonly) RevenantDropSession *currentDrop;
@end
