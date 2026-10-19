#import <UIKit/UIKit.h>
#import <UIKit/UIDragSession.h>
#import <UIKit/UITextDragging.h>
#import <UIKit/UITextDropping.h>

@interface CharonTextDragRequest : NSObject <UITextDragRequest>
@property (nonatomic, strong) id<UIDragSession> session;
@property (nonatomic, strong) UITextRange *range;
@property (nonatomic, copy) NSArray<UIDragItem *> *suggested;
@property (nonatomic, copy) NSArray<UIDragItem *> *existing;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
- (instancetype)initWithSession:(id<UIDragSession>)session;
@end

@interface CharonTextDropRequest : NSObject <UITextDropRequest>
@property (nonatomic, strong) id<UIDropSession> session;
@property (nonatomic, strong) UITextPosition *position;
@property (nonatomic, strong) UITextDropProposal *proposal;
@property (nonatomic, assign, getter=isSameView) BOOL sameView;
- (instancetype)initWithSession:(id<UIDropSession>)session;
@end

@interface CharonTextDragAdaptor : NSObject <UIDragInteractionDelegate>
@property (nonatomic, weak) UIView<UITextDraggable, UITextDroppable> *control;
- (instancetype)initWithControl:(UIView<UITextDraggable, UITextDroppable> *)control;
@end

@interface CharonTextDropAdaptor : NSObject <UIDropInteractionDelegate>
@property (nonatomic, weak) UIView<UITextDraggable, UITextDroppable> *control;
- (instancetype)initWithControl:(UIView<UITextDraggable, UITextDroppable> *)control;
@end

@interface UIView (CharonTextDragDropAdaptors)
- (CharonTextDragAdaptor *)charon_textDragDelegateAdaptor;
- (CharonTextDropAdaptor *)charon_textDropDelegateAdaptor;
@end
