#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RevenantTextDragDrop11.h"

typedef void (^TextDragDropRecorder)(NSString *name, NSString *value);

NSArray *textdragdrop_documented_order(NSString *host);

@interface RevenantTestDropSession : NSObject <UIDropSession>
- (instancetype)initWithPoint:(CGPoint)point;
@end

@interface RevenantTextDragAdaptor (RevenantProbe)
- (NSArray<UIDragItem *> *)revenant_itemsForDragSession:(id<UIDragSession>)session;
- (void)revenant_willAnimateLiftWithSession:(id<UIDragSession>)session;
- (void)revenant_dragSessionDidEnd:(id<UIDragSession>)session withOperation:(UIDropOperation)operation;
@end

@interface RevenantTextDropAdaptor (RevenantProbe)
- (BOOL)revenant_canHandleSession:(id<UIDropSession>)session;
- (void)revenant_updateForSession:(id<UIDropSession>)session;
- (void)revenant_sessionDidEnter:(id<UIDropSession>)session;
- (void)revenant_sessionDidExit:(id<UIDropSession>)session;
- (void)revenant_sessionDidEnd:(id<UIDropSession>)session;
@end

@interface UIView (RevenantTextProbe)
- (RevenantTextDragAdaptor *)revenant_textDragDelegateAdaptor;
- (RevenantTextDropAdaptor *)revenant_textDropDelegateAdaptor;
@end
