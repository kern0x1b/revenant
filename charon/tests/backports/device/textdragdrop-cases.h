#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CharonTextDragDrop11.h"

typedef void (^TextDragDropRecorder)(NSString *name, NSString *value);

// The order a text control's drag and drop delegates are asked in, as a literal, beside the reason
// from the two headers. Apple's order and not the port's: a drag is itemsForDrag:, then the preview,
// the animator and the session beginning, then the session ending; a drop is willBecomeEditableForDrop:
// as the gate, then the proposal, the drop and the all-items preview, then the four session messages.
NSArray *textdragdrop_documented_order(NSString *host);

// What the two adaptors ask, named so this test drives the port's real path rather than a copy of it.
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
