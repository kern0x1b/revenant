// The weak contract of the two text drag/drop delegates, measured on a guest that cannot construct
// a UITextView or a UITextField at all -- so nothing here allocates one, and nothing here
// reimplements the port's storage either.
//
// The port keeps the two delegates in static functions typed against id<UITextDraggable> and
// id<UITextDroppable>, and those are the functions under test. They touch nothing but the control's
// associated objects, so a test-local object that adopts the two protocols and nothing else is a
// valid argument for them: this drives the port's own storage code, not a stand-in for a member.
#import "UITextView+TextDragDrop11.m"

#import <objc/runtime.h>
#import "check.h"

// A UIView, because the adaptor is typed against one, and nothing more: it is not a text view and
// it is not a label, so the guest's inability to construct those is not touched. A UIView allocates
// on this guest, which the control table measured.
@interface CharonWeakProbe : UIView <UITextDraggable, UITextDroppable>
@end
@implementation CharonWeakProbe
@synthesize textDragDelegate = _textDragDelegate;
@synthesize textDropDelegate = _textDropDelegate;
- (UITextDragOptions)textDragOptions { return UITextDragOptionsNone; }
- (void)setTextDragOptions:(UITextDragOptions)o { (void)o; }
- (id<UITextDropDelegate>)textDropDelegate { return _textDropDelegate; }
- (void)setTextDropDelegate:(id<UITextDropDelegate>)d { _textDropDelegate = d; }
- (id<UITextDragDelegate>)textDragDelegate { return _textDragDelegate; }
- (void)setTextDragDelegate:(id<UITextDragDelegate>)d { _textDragDelegate = d; }
@end

// A delegate that counts nothing and answers nothing: what matters is whether the port can still
// reach it after it is gone, and whether reaching it is safe.
@interface CharonCountingDragDelegate : NSObject <UITextDraggable, UITextDroppable>
@property (nonatomic, assign) int asked;
@end
@implementation CharonCountingDragDelegate
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
        CharonWeakProbe *control = [[CharonWeakProbe alloc] init];

        // While the delegate lives, the port hands back the very object it was given.
        @autoreleasepool {
            CharonCountingDragDelegate *live = [[CharonCountingDragDelegate alloc] init];
            CharonSetTextDragDelegate(control, live);
            CharonSetTextDropDelegate(control, live);
            charon_check(CharonTextDragDelegateOf(control) == live,
                         "a live drag delegate comes back as itself", nil);
            charon_check(CharonTextDropDelegateOf(control) == live,
                         "a live drop delegate comes back as itself", nil);
        }

        // The delegate is gone. Both headers declare it weak, so the port must now answer nil --
        // not a freed address, which is what an unowned slot would hand back.
        charon_check(CharonTextDragDelegateOf(control) == nil,
                     "a deallocated drag delegate reads back nil, as the header's weak says", nil);
        charon_check(CharonTextDropDelegateOf(control) == nil,
                     "a deallocated drop delegate reads back nil, as the header's weak says", nil);

        // And asking the port to start a drag with no delegate must be answered, not messaged at a
        // stale address: the adaptor asks the delegate whether it responds, and nil answers no.
        CharonTextDragAdaptor *adaptor = [[CharonTextDragAdaptor alloc] initWithControl:control];
        NSArray *items = nil;
        @try {
            items = (NSArray *)[adaptor charon_itemsForDragSession:nil];
            charon_check(YES, "starting a drag with a deallocated delegate does not crash", nil);
        } @catch (NSException *e) {
            charon_check(NO, "starting a drag with a deallocated delegate does not crash",
                         [NSString stringWithFormat:@"%@: %@", e.name, e.reason]);
        }
        charon_check(items == nil, "a deallocated delegate carries nothing", nil);

        // A delegate set again replaces the box rather than pointing at the old one.
        @autoreleasepool {
            CharonCountingDragDelegate *again = [[CharonCountingDragDelegate alloc] init];
            CharonSetTextDragDelegate(control, again);
            charon_check(CharonTextDragDelegateOf(control) == again,
                         "a delegate set after one is gone is the one that comes back", nil);
        }
        charon_check(CharonTextDragDelegateOf(control) == nil,
                     "the second delegate also reads back nil once it is gone", nil);

        // And nil clears the slot outright.
        CharonSetTextDragDelegate(control, nil);
        charon_check(CharonTextDragDelegateOf(control) == nil, "nil clears the drag delegate", nil);
    }
    return charon_failures ? 1 : 0;
}
