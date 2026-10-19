#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CharonTextDragDrop11.h"

typedef void (^TextDragDropRecorder)(NSString *name, NSString *value);

NSArray *textdragdrop_documented_order(NSString *host);

@interface CharonTestDropSession : NSObject <UIDropSession>
- (instancetype)initWithPoint:(CGPoint)point;
@end

@interface CharonTextDragAdaptor (CharonProbe)
- (NSArray<UIDragItem *> *)charon_itemsForDragSession:(id<UIDragSession>)session;
- (void)charon_willAnimateLiftWithSession:(id<UIDragSession>)session;
- (void)charon_dragSessionDidEnd:(id<UIDragSession>)session withOperation:(UIDropOperation)operation;
@end

@interface CharonTextDropAdaptor (CharonProbe)
- (BOOL)charon_canHandleSession:(id<UIDropSession>)session;
- (void)charon_updateForSession:(id<UIDropSession>)session;
- (void)charon_sessionDidEnter:(id<UIDropSession>)session;
- (void)charon_sessionDidExit:(id<UIDropSession>)session;
- (void)charon_sessionDidEnd:(id<UIDropSession>)session;
@end

@interface UIView (CharonTextProbe)
- (CharonTextDragAdaptor *)charon_textDragDelegateAdaptor;
- (CharonTextDropAdaptor *)charon_textDropDelegateAdaptor;
@end
