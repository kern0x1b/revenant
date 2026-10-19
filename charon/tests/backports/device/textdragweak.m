#import "UITextView+TextDragDrop11.m"

#import <objc/runtime.h>
#import "check.h"

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

        @autoreleasepool {
            CharonCountingDragDelegate *live = [[CharonCountingDragDelegate alloc] init];
            CharonSetTextDragDelegate(control, live);
            CharonSetTextDropDelegate(control, live);
            charon_check(CharonTextDragDelegateOf(control) == live,
                         "a live drag delegate comes back as itself", nil);
            charon_check(CharonTextDropDelegateOf(control) == live,
                         "a live drop delegate comes back as itself", nil);
        }

        charon_check(CharonTextDragDelegateOf(control) == nil,
                     "a deallocated drag delegate reads back nil, as the header's weak says", nil);
        charon_check(CharonTextDropDelegateOf(control) == nil,
                     "a deallocated drop delegate reads back nil, as the header's weak says", nil);

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

        @autoreleasepool {
            CharonCountingDragDelegate *again = [[CharonCountingDragDelegate alloc] init];
            CharonSetTextDragDelegate(control, again);
            charon_check(CharonTextDragDelegateOf(control) == again,
                         "a delegate set after one is gone is the one that comes back", nil);
        }
        charon_check(CharonTextDragDelegateOf(control) == nil,
                     "the second delegate also reads back nil once it is gone", nil);

        CharonSetTextDragDelegate(control, nil);
        charon_check(CharonTextDragDelegateOf(control) == nil, "nil clears the drag delegate", nil);
    }
    return charon_failures ? 1 : 0;
}
