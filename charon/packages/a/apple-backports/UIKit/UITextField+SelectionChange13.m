#import <UIKit/UIKit.h>

@interface CharonSelectionWatcher : NSObject
@end

@implementation CharonSelectionWatcher

static __weak UITextField *charon_field;
static NSInteger charon_start, charon_end;
static CFRunLoopObserverRef charon_observer;

static void charon_offsets(UITextField *field, NSInteger *start, NSInteger *end)
{
    UITextRange *range = field.selectedTextRange;
    if (!range) {
        *start = *end = -1;
        return;
    }
    *start = [field offsetFromPosition:field.beginningOfDocument toPosition:range.start];
    *end = [field offsetFromPosition:field.beginningOfDocument toPosition:range.end];
}

static void charon_check(void)
{
    UITextField *field = charon_field;
    if (!field)
        return;
    NSInteger start, end;
    charon_offsets(field, &start, &end);
    if (start == charon_start && end == charon_end)
        return;
    charon_start = start;
    charon_end = end;
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
    charon_field = notification.object;
    charon_start = charon_end = -2;
    if (!charon_observer) {
        charon_observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            charon_check();
        });
        CFRunLoopAddObserver(CFRunLoopGetMain(), charon_observer, kCFRunLoopCommonModes);
    }
    charon_check();
}

+ (void)ended:(NSNotification *)notification
{
    charon_check();
    if (charon_field == notification.object)
        charon_field = nil;
    if (charon_observer && !charon_field) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), charon_observer, kCFRunLoopCommonModes);
        CFRelease(charon_observer);
        charon_observer = NULL;
    }
}

@end
