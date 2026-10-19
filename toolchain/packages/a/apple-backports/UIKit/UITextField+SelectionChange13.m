#import <UIKit/UIKit.h>

@interface RevenantSelectionWatcher : NSObject
@end

@implementation RevenantSelectionWatcher

static __weak UITextField *revenant_field;
static NSInteger revenant_start, revenant_end;
static CFRunLoopObserverRef revenant_observer;

static void revenant_offsets(UITextField *field, NSInteger *start, NSInteger *end)
{
    UITextRange *range = field.selectedTextRange;
    if (!range) {
        *start = *end = -1;
        return;
    }
    *start = [field offsetFromPosition:field.beginningOfDocument toPosition:range.start];
    *end = [field offsetFromPosition:field.beginningOfDocument toPosition:range.end];
}

static void revenant_check(void)
{
    UITextField *field = revenant_field;
    if (!field)
        return;
    NSInteger start, end;
    revenant_offsets(field, &start, &end);
    if (start == revenant_start && end == revenant_end)
        return;
    revenant_start = start;
    revenant_end = end;
    id<UITextFieldDelegate> delegate = field.delegate;
    if ([delegate respondsToSelector:@selector(textFieldDidChangeSelection:)])
        [delegate textFieldDidChangeSelection:field];
}

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(began:) name:UITextFieldTextDidBeginEditingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ended:) name:UITextFieldTextDidEndEditingNotification object:nil];
}

+ (void)began:(NSNotification *)notification
{
    revenant_field = notification.object;
    revenant_start = revenant_end = -2;
    if (!revenant_observer) {
        revenant_observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            revenant_check();
        });
        CFRunLoopAddObserver(CFRunLoopGetMain(), revenant_observer, kCFRunLoopCommonModes);
    }
    revenant_check();
}

+ (void)ended:(NSNotification *)notification
{
    revenant_check();
    if (revenant_field == notification.object)
        revenant_field = nil;
    if (revenant_observer && !revenant_field) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), revenant_observer, kCFRunLoopCommonModes);
        CFRelease(revenant_observer);
        revenant_observer = NULL;
    }
}

@end
