#import <UIKit/UIKit.h>
#import "check.h"
#import "textdragdrop-cases.h"

static NSString *const results_folder = @"/private/var/backports";

// Drives a text control's drag and drop through the port's own interactions with a delegate that
// records every question it is asked and in what order, and asserts that order against Apple's.
//
// The order is a literal in textdragdrop-cases.m beside the reason from the two headers; nothing here
// reads the port's own sequence, so a change in the order it asks in fails this rather than agreeing
// with itself.
@interface TextProbe : NSObject <UITextDragDelegate, UITextDropDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *log;
@property (nonatomic, strong) UITextView *control;
@property (nonatomic, strong) NSArray<NSString *> *expected;
@property (nonatomic, strong) NSString *host;
@end

@implementation TextProbe
@synthesize log = _log;
@synthesize control = _control;
@synthesize expected = _expected;
@synthesize host = _host;

- (void)note:(NSString *)line
{
    [_log addObject:line];
}

// The drag delegate, in the header's order.
- (NSArray<UIDragItem *> *)textDraggableView:(UIView<UITextDraggable> *)view itemsForDrag:(id<UITextDragRequest>)request
{
    [self note:[NSString stringWithFormat:@"%@.itemsForDrag", self.host]];
    NSItemProvider *provider = [[NSItemProvider alloc] initWithObject:@"charon text"];
    return @[[[UIDragItem alloc] initWithItemProvider:provider]];
}

- (UITargetedDragPreview *)textDraggableView:(UIView<UITextDraggable> *)view
                  dragPreviewForLiftingItem:(UIDragItem *)item
                                   session:(id<UIDragSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dragPreviewForLiftingItem", self.host]];
    return nil;
}

- (void)textDraggableView:(UIView<UITextDraggable> *)view
    willAnimateLiftWithAnimator:(id<UIDragAnimating>)animator
                      session:(id<UIDragSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.willAnimateLiftWithAnimator", self.host]];
}

- (void)textDraggableView:(UIView<UITextDraggable> *)view dragSessionWillBegin:(id<UIDragSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dragSessionWillBegin", self.host]];
}

- (void)textDraggableView:(UIView<UITextDraggable> *)view
         dragSessionDidEnd:(id<UIDragSession>)session
           withOperation:(UIDropOperation)operation
{
    [self note:[NSString stringWithFormat:@"%@.dragSessionDidEnd", self.host]];
}

// The drop delegate, in the header's order. The gate is answered yes, so the questions after it are
// asked: a control that would not take the text is never asked what it would do with it.
- (UITextDropEditability)textDroppableView:(UIView<UITextDroppable> *)view willBecomeEditableForDrop:(id<UITextDropRequest>)drop
{
    [self note:[NSString stringWithFormat:@"%@.willBecomeEditableForDrop", self.host]];
    return UITextDropEditabilityYes;
}

- (UITextDropProposal *)textDroppableView:(UIView<UITextDroppable> *)view proposalForDrop:(id<UITextDropRequest>)drop
{
    [self note:[NSString stringWithFormat:@"%@.proposalForDrop", self.host]];
    return [[UITextDropProposal alloc] initWithDropOperation:UIDropOperationCopy];
}

- (void)textDroppableView:(UIView<UITextDroppable> *)view willPerformDrop:(id<UITextDropRequest>)drop
{
    [self note:[NSString stringWithFormat:@"%@.willPerformDrop", self.host]];
}

- (UITargetedDragPreview *)textDroppableView:(UIView<UITextDroppable> *)view
             previewForDroppingAllItemsWithDefault:(UITargetedDragPreview *)defaultPreview
{
    [self note:[NSString stringWithFormat:@"%@.previewForDroppingAllItemsWithDefault", self.host]];
    return nil;
}

- (void)textDroppableView:(UIView<UITextDroppable> *)view dropSessionDidEnter:(id<UIDropSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dropSessionDidEnter", self.host]];
}

- (void)textDroppableView:(UIView<UITextDroppable> *)view dropSessionDidUpdate:(id<UIDropSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dropSessionDidUpdate", self.host]];
}

- (void)textDroppableView:(UIView<UITextDroppable> *)view dropSessionDidExit:(id<UIDropSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dropSessionDidExit", self.host]];
}

- (void)textDroppableView:(UIView<UITextDroppable> *)view dropSessionDidEnd:(id<UIDropSession>)session
{
    [self note:[NSString stringWithFormat:@"%@.dropSessionDidEnd", self.host]];
}

@end

// The two order lists, as a fact about the two headers rather than a copy of their text.
//
// UITextDragging.h: itemsForDrag: is what a drag is and is asked first; the preview comes before the
// animator because an application that has a preview animates it, and the session beginning is last of
// the three because it is once the items exist and the lift is about to run. dragSessionDidEnd comes
// when the drag is over and is not part of the beginning.
//
// UITextDropping.h: willBecomeEditableForDrop: is the gate, so a control that will not take the text
// is never asked what it would do with it, and the proposal and the drop and the all-items preview
// follow; the four session messages then report the drag moving over the control.
NSArray *textdragdrop_documented_order(NSString *host)
{
    return @[[NSString stringWithFormat:@"%@.itemsForDrag", host],
             [NSString stringWithFormat:@"%@.dragPreviewForLiftingItem", host],
             [NSString stringWithFormat:@"%@.willAnimateLiftWithAnimator", host],
             [NSString stringWithFormat:@"%@.dragSessionWillBegin", host],
             [NSString stringWithFormat:@"%@.dragSessionDidEnd", host],
             [NSString stringWithFormat:@"%@.willBecomeEditableForDrop", host],
             [NSString stringWithFormat:@"%@.proposalForDrop", host],
             [NSString stringWithFormat:@"%@.willPerformDrop", host],
             [NSString stringWithFormat:@"%@.previewForDroppingAllItemsWithDefault", host],
             [NSString stringWithFormat:@"%@.dropSessionDidEnter", host],
             [NSString stringWithFormat:@"%@.dropSessionDidUpdate", host],
             [NSString stringWithFormat:@"%@.dropSessionDidExit", host],
             [NSString stringWithFormat:@"%@.dropSessionDidEnd", host]];
}

static int gCharonExit = 0;
static NSMutableArray<NSString *> *_asked = nil;

@interface TextDriver : NSObject
@end

@implementation TextDriver

- (void)finish
{
    NSMutableString *asked = [NSMutableString string];
    for (NSString *line in _asked)
        [asked appendFormat:@"%@\n", line];
    [asked writeToFile:[results_folder stringByAppendingPathComponent:@"textdragdrop.asked"]
           atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n",
                         charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"textdragdrop.done"]
              atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    gCharonExit = charon_failures ? 1 : 0;
}

- (void)run
{
    TextProbe *probe = [[TextProbe alloc] init];
    probe.log = [NSMutableArray array];
    _asked = [NSMutableArray array];

    // A text control with a selected range, so a drag has something to carry and the renderer has
    // glyphs to measure.
    UITextView *control = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    control.text = @"a line of text to drag";
    control.selectedRange = NSMakeRange(2, 6);
    probe.control = control;
    probe.host = @"text";

    control.textDragDelegate = probe;
    control.textDropDelegate = probe;
    control.textDragOptions = UITextDragOptionsNone;

    // The interactions the port installs through the two protocols' properties, and what they say.
    charon_check(control.textDragInteraction != nil,
                 "a text control has the drag interaction the header describes", nil);
    charon_check(control.textDropInteraction != nil,
                 "a text control has the drop interaction the header describes", nil);
    charon_check(!control.isTextDragActive, "no drag is under way before one is begun", nil);
    charon_check(!control.isTextDropActive, "no drop is under way before one arrives", nil);

    // Ask the adaptor for the drag, then the drop, through the same public path an application
    // would use, and record what the delegates heard.
    CharonTextDragAdaptor *dragAdaptor = [control charon_textDragDelegateAdaptor];
    CharonTextDropAdaptor *dropAdaptor = [control charon_textDropDelegateAdaptor];
    // the port's own session, made the way the drop side makes one
    CharonTestDropSession *session = [[CharonTestDropSession alloc] initWithPoint:CGPointMake(20, 20)];

    [dragAdaptor charon_itemsForDragSession:nil];
    [dragAdaptor charon_willAnimateLiftWithSession:nil];
    [dragAdaptor charon_dragSessionDidEnd:nil withOperation:UIDropOperationMove];

    [dropAdaptor charon_canHandleSession:session];
    [dropAdaptor charon_updateForSession:session];
    [dropAdaptor charon_sessionDidEnter:session];
    [dropAdaptor charon_sessionDidExit:session];
    [dropAdaptor charon_sessionDidEnd:session];

    NSArray *asked = probe.log;
    NSArray *expected = textdragdrop_documented_order(@"text");
    charon_check([asked isEqualToArray:expected],
                 "a text control asks its two delegates in the order their headers give",
                 [NSString stringWithFormat:@"\n    asked   %@\n    expect  %@", asked, expected]);
    printf("asked %lu, expected %lu\n", (unsigned long)asked.count, (unsigned long)expected.count);
    [self finish];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"textdragdrop.done"] error:NULL];
        TextDriver *driver = [[TextDriver alloc] init];
        [driver run];
    }
    return gCharonExit;
}
