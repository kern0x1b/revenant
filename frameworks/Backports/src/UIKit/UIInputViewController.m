#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wprotocol"

static const void *RevenantDocumentIdentifierKey = &RevenantDocumentIdentifierKey;
static __weak UIResponder *RevenantCapturedResponder;

@interface UIResponder (RevenantFirstResponder)
- (void)revenant_captureFirstResponder:(id)sender;
@end

@implementation UIResponder (RevenantFirstResponder)

- (void)revenant_captureFirstResponder:(id)sender
{
    RevenantCapturedResponder = self;
}

@end

static UIResponder *revenant_first_responder(void)
{
    RevenantCapturedResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(revenant_captureFirstResponder:) to:nil from:nil forEvent:nil];
    return RevenantCapturedResponder;
}

static id<UITextInput> revenant_text_input(void)
{
    UIResponder *responder = revenant_first_responder();
    return [responder conformsToProtocol:@protocol(UITextInput)] ? (id<UITextInput>)responder : nil;
}

static NSString *revenant_nil_if_empty(NSString *text)
{
    return text.length ? text : nil;
}

@interface RevenantTextDocumentProxy : NSObject <UITextDocumentProxy>
@end

@implementation RevenantTextDocumentProxy

- (NSString *)documentContextBeforeInput
{
    id<UITextInput> input = revenant_text_input();
    UITextRange *selected = input.selectedTextRange;
    if (!selected)
        return nil;
    NSString *text = [input textInRange:[input textRangeFromPosition:input.beginningOfDocument toPosition:selected.start]];
    NSRange paragraph = [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSBackwardsSearch];
    return revenant_nil_if_empty(paragraph.location == NSNotFound ? text : [text substringFromIndex:NSMaxRange(paragraph)]);
}

- (NSString *)documentContextAfterInput
{
    id<UITextInput> input = revenant_text_input();
    UITextRange *selected = input.selectedTextRange;
    if (!selected)
        return nil;
    NSString *text = [input textInRange:[input textRangeFromPosition:selected.end toPosition:input.endOfDocument]];
    NSRange paragraph = [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
    return revenant_nil_if_empty(paragraph.location == NSNotFound ? text : [text substringToIndex:paragraph.location]);
}

- (NSString *)selectedText
{
    id<UITextInput> input = revenant_text_input();
    UITextRange *selected = input.selectedTextRange;
    return selected && !selected.isEmpty ? revenant_nil_if_empty([input textInRange:selected]) : nil;
}

- (UITextInputMode *)documentInputMode
{
    return [UITextInputMode currentInputMode];
}

- (NSUUID *)documentIdentifier
{
    UIResponder *responder = revenant_first_responder();
    if (!responder) {
        static NSUUID *none;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            none = [[NSUUID alloc] init];
        });
        return none;
    }
    NSUUID *identifier = objc_getAssociatedObject(responder, RevenantDocumentIdentifierKey);
    if (!identifier) {
        identifier = [[NSUUID alloc] init];
        objc_setAssociatedObject(responder, RevenantDocumentIdentifierKey, identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return identifier;
}

- (void)adjustTextPositionByCharacterOffset:(NSInteger)offset
{
    id<UITextInput> input = revenant_text_input();
    UITextRange *selected = input.selectedTextRange;
    UITextPosition *moved = selected ? [input positionFromPosition:selected.start offset:offset] : nil;
    if (moved)
        input.selectedTextRange = [input textRangeFromPosition:moved toPosition:moved];
}

- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange
{
    [revenant_text_input() setMarkedText:markedText selectedRange:selectedRange];
}

- (void)unmarkText
{
    [revenant_text_input() unmarkText];
}

- (BOOL)hasText
{
    UIResponder<UIKeyInput> *responder = (UIResponder<UIKeyInput> *)revenant_first_responder();
    return [responder conformsToProtocol:@protocol(UIKeyInput)] && [responder hasText];
}

- (void)insertText:(NSString *)text
{
    UIResponder<UIKeyInput> *responder = (UIResponder<UIKeyInput> *)revenant_first_responder();
    if ([responder conformsToProtocol:@protocol(UIKeyInput)])
        [responder insertText:text];
}

- (void)deleteBackward
{
    UIResponder<UIKeyInput> *responder = (UIResponder<UIKeyInput> *)revenant_first_responder();
    if ([responder conformsToProtocol:@protocol(UIKeyInput)])
        [responder deleteBackward];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [revenant_first_responder() respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    UIResponder *responder = revenant_first_responder();
    return [responder respondsToSelector:selector] ? responder : [super forwardingTargetForSelector:selector];
}

@end

@implementation UIInputViewController {
    RevenantTextDocumentProxy *_documentProxy;
    NSString *_primaryLanguage;
    BOOL _hasDictationKey;
}

- (void)loadView
{
    self.view = [[UIInputView alloc] initWithFrame:CGRectZero inputViewStyle:UIInputViewStyleKeyboard];
}

- (UIInputView *)inputView
{
    return [self.view isKindOfClass:[UIInputView class]] ? (UIInputView *)self.view : nil;
}

- (void)setInputView:(UIInputView *)inputView
{
    self.view = inputView;
}

- (id<UITextDocumentProxy>)textDocumentProxy
{
    if (!_documentProxy)
        _documentProxy = [[RevenantTextDocumentProxy alloc] init];
    return _documentProxy;
}

- (NSString *)primaryLanguage
{
    return _primaryLanguage ?: [UITextInputMode currentInputMode].primaryLanguage;
}

- (void)setPrimaryLanguage:(NSString *)primaryLanguage
{
    _primaryLanguage = [primaryLanguage copy];
}

- (BOOL)hasDictationKey
{
    return _hasDictationKey;
}

- (void)setHasDictationKey:(BOOL)hasDictationKey
{
    _hasDictationKey = hasDictationKey;
}

- (BOOL)hasFullAccess
{
    return YES;
}

- (void)dismissKeyboard
{
    [revenant_first_responder() resignFirstResponder];
}

- (void)selectionWillChange:(id<UITextInput>)textInput
{
}

- (void)selectionDidChange:(id<UITextInput>)textInput
{
}

- (void)textWillChange:(id<UITextInput>)textInput
{
}

- (void)textDidChange:(id<UITextInput>)textInput
{
}

@end
