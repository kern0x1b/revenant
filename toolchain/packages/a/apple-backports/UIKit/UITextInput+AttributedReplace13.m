#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static void charon_replace(UIView<UITextInput> *input, UITextRange *range, NSAttributedString *text, NSAttributedString *(^get)(void), void (^set)(NSAttributedString *))
{
    NSInteger start = [input offsetFromPosition:input.beginningOfDocument toPosition:range.start];
    NSInteger end = [input offsetFromPosition:input.beginningOfDocument toPosition:range.end];
    if (start < 0 || end < start)
        return;
    NSAttributedString *before = get();
    NSInteger length = (NSInteger)before.length;
    NSRange target = NSMakeRange((NSUInteger)MIN(start, length), (NSUInteger)(MIN(end, length) - MIN(start, length)));
    NSMutableAttributedString *changed = [before mutableCopy];
    [changed replaceCharactersInRange:target withAttributedString:text ? text : [[NSAttributedString alloc] init]];
    set(changed);
    UITextPosition *caret = [input positionFromPosition:input.beginningOfDocument offset:(NSInteger)target.location + (NSInteger)(text ? text.length : 0)];
    if (caret)
        input.selectedTextRange = [input textRangeFromPosition:caret toPosition:caret];
}

@implementation UITextView (CharonAttributedReplace)

- (void)replaceRange:(UITextRange *)range withAttributedText:(NSAttributedString *)attributedText
{
    charon_replace(self, range, attributedText, ^NSAttributedString *{ return self.attributedText; }, ^(NSAttributedString *changed) { self.attributedText = changed; });
}

@end

@implementation UITextField (CharonAttributedReplace)

- (void)replaceRange:(UITextRange *)range withAttributedText:(NSAttributedString *)attributedText
{
    charon_replace(self, range, attributedText, ^NSAttributedString *{ return self.attributedText; }, ^(NSAttributedString *changed) { self.attributedText = changed; });
}

@end
