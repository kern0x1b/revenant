#import "UITextView+TextDragDrop11.m"

#import <objc/runtime.h>
#import "check.h"

@interface RevenantWeakProbe : UIView <UITextDraggable, UITextDroppable>
@end
@implementation RevenantWeakProbe
@synthesize textDragDelegate = _textDragDelegate;
@synthesize textDropDelegate = _textDropDelegate;
- (UITextDragOptions)textDragOptions { return UITextDragOptionsNone; }
- (void)setTextDragOptions:(UITextDragOptions)o { (void)o; }
- (id<UITextDropDelegate>)textDropDelegate { return _textDropDelegate; }
- (void)setTextDropDelegate:(id<UITextDropDelegate>)d { _textDropDelegate = d; }
- (id<UITextDragDelegate>)textDragDelegate { return _textDragDelegate; }
- (void)setTextDragDelegate:(id<UITextDragDelegate>)d { _textDragDelegate = d; }
@end

@interface RevenantCountingDragDelegate : NSObject <UITextDraggable, UITextDroppable>
@property (nonatomic, assign) int asked;
@end
@implementation RevenantCountingDragDelegate
@synthesize textDragDelegate = _textDragDelegate;
@synthesize textDropDelegate = _textDropDelegate;
- (UITextDragOptions)textDragOptions { return UITextDragOptionsNone; }
- (void)setTextDragOptions:(UITextDragOptions)o { (void)o; }
- (id<UITextDropDelegate>)textDropDelegate { return _textDropDelegate; }
- (void)setTextDropDelegate:(id<UITextDropDelegate>)d { _textDropDelegate = d; }
- (id<UITextDragDelegate>)textDragDelegate { return _textDragDelegate; }
- (void)setTextDragDelegate:(id<UITextDragDelegate>)d { _textDragDelegate = d; }
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        RevenantWeakProbe *control = [[RevenantWeakProbe alloc] init];

        @autoreleasepool {
            RevenantCountingDragDelegate *live = [[RevenantCountingDragDelegate alloc] init];
            RevenantSetTextDragDelegate(control, live);
            RevenantSetTextDropDelegate(control, live);
            revenant_check(RevenantTextDragDelegateOf(control) == live,
                         "a live drag delegate comes back as itself", nil);
            revenant_check(RevenantTextDropDelegateOf(control) == live,
                         "a live drop delegate comes back as itself", nil);
        }

        revenant_check(RevenantTextDragDelegateOf(control) == nil,
                     "a deallocated drag delegate reads back nil, as the header's weak says", nil);
        revenant_check(RevenantTextDropDelegateOf(control) == nil,
                     "a deallocated drop delegate reads back nil, as the header's weak says", nil);

        RevenantTextDragAdaptor *adaptor = [[RevenantTextDragAdaptor alloc] initWithControl:control];
        NSArray *items = nil;
        @try {
            items = (NSArray *)[adaptor revenant_itemsForDragSession:nil];
            revenant_check(YES, "starting a drag with a deallocated delegate does not crash", nil);
        } @catch (NSException *e) {
            revenant_check(NO, "starting a drag with a deallocated delegate does not crash",
                         [NSString stringWithFormat:@"%@: %@", e.name, e.reason]);
        }
        revenant_check(items == nil, "a deallocated delegate carries nothing", nil);

        @autoreleasepool {
            RevenantCountingDragDelegate *again = [[RevenantCountingDragDelegate alloc] init];
            RevenantSetTextDragDelegate(control, again);
            revenant_check(RevenantTextDragDelegateOf(control) == again,
                         "a delegate set after one is gone is the one that comes back", nil);
        }
        revenant_check(RevenantTextDragDelegateOf(control) == nil,
                     "the second delegate also reads back nil once it is gone", nil);

        RevenantSetTextDragDelegate(control, nil);
        revenant_check(RevenantTextDragDelegateOf(control) == nil, "nil clears the drag delegate", nil);
    }
    return revenant_failures ? 1 : 0;
}
