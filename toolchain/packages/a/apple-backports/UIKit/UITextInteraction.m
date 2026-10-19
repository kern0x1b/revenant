#import "CharonMenus.h"

@interface UITextInteraction (CharonGestures)
- (void)charon_tapped:(UITapGestureRecognizer *)recognizer;
- (void)charon_pressed:(UILongPressGestureRecognizer *)recognizer;
@end

@implementation UITextInteraction {
@private
    __weak id<UITextInteractionDelegate> _delegate;
    __weak UIResponder<UITextInput> *_textInput;
    __weak UIView *_view;
    UITextInteractionMode _mode;
    NSArray<UIGestureRecognizer *> *_gestures;
}

+ (instancetype)textInteractionForMode:(UITextInteractionMode)mode
{
    UITextInteraction *interaction = [[self alloc] init];
    interaction->_mode = mode;
    return interaction;
}

- (id<UITextInteractionDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UITextInteractionDelegate>)delegate
{
    _delegate = delegate;
}

- (UIResponder<UITextInput> *)textInput
{
    return _textInput;
}

- (void)setTextInput:(UIResponder<UITextInput> *)textInput
{
    _textInput = textInput;
}

- (UITextInteractionMode)textInteractionMode
{
    return _mode;
}

- (NSArray<UIGestureRecognizer *> *)gesturesForFailureRequirements
{
    return _gestures ? _gestures : @[];
}

- (UIView *)view
{
    return _view;
}

- (void)willMoveToView:(UIView *)view
{
    for (UIGestureRecognizer *recognizer in _gestures)
        [_view removeGestureRecognizer:recognizer];
    _gestures = nil;
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (!view)
        return;
    NSMutableArray *gestures = [NSMutableArray array];
    for (NSUInteger taps = 1; taps <= 3; taps++) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(charon_tapped:)];
        tap.numberOfTapsRequired = taps;
        [gestures addObject:tap];
    }
    for (NSUInteger index = 1; index < 3; index++)
        [gestures[index - 1] requireGestureRecognizerToFail:gestures[index]];
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(charon_pressed:)];
    [gestures addObject:press];
    for (UIGestureRecognizer *recognizer in gestures)
        [view addGestureRecognizer:recognizer];
    _gestures = gestures;
}

- (UIResponder<UITextInput> *)charon_input
{
    if (_textInput)
        return _textInput;
    return [_view conformsToProtocol:@protocol(UITextInput)] ? (UIResponder<UITextInput> *)_view : nil;
}

- (CGPoint)charon_pointIn:(UIResponder<UITextInput> *)input from:(UIGestureRecognizer *)recognizer
{
    CGPoint point = [recognizer locationInView:_view];
    return [input isKindOfClass:[UIView class]] && input != (id)_view ? [(UIView *)input convertPoint:point fromView:_view] : point;
}

- (BOOL)charon_begin:(CGPoint)point
{
    id<UITextInteractionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(interactionShouldBegin:atPoint:)] && ![delegate interactionShouldBegin:self atPoint:point])
        return NO;
    if ([delegate respondsToSelector:@selector(interactionWillBegin:)])
        [delegate interactionWillBegin:self];
    return YES;
}

- (void)charon_end
{
    id<UITextInteractionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(interactionDidEnd:)])
        [delegate interactionDidEnd:self];
}

- (void)charon_select:(UITextRange *)range in:(UIResponder<UITextInput> *)input
{
    [input.inputDelegate selectionWillChange:input];
    input.selectedTextRange = range;
    [input.inputDelegate selectionDidChange:input];
}

- (void)charon_tapped:(UITapGestureRecognizer *)recognizer
{
    UIResponder<UITextInput> *input = [self charon_input];
    if (!input || recognizer.state != UIGestureRecognizerStateRecognized)
        return;
    CGPoint point = [self charon_pointIn:input from:recognizer];
    if (![self charon_begin:point])
        return;
    NSUInteger taps = recognizer.numberOfTapsRequired;
    if ((_mode == UITextInteractionModeEditable || taps >= 2) && ![input isFirstResponder] && [input canBecomeFirstResponder])
        [input becomeFirstResponder];
    UITextPosition *position = [input closestPositionToPoint:point];
    if (position) {
        UITextRange *range = nil;
        if (taps == 2)
            range = [input.tokenizer rangeEnclosingPosition:position withGranularity:UITextGranularityWord inDirection:UITextStorageDirectionForward];
        else if (taps >= 3)
            range = [input.tokenizer rangeEnclosingPosition:position withGranularity:UITextGranularityParagraph inDirection:UITextStorageDirectionForward];
        if (!range)
            range = [input textRangeFromPosition:position toPosition:position];
        [self charon_select:range in:input];
        if (taps >= 2 && !range.isEmpty && [input isKindOfClass:[UIView class]]) {
            UIMenuController *menu = [UIMenuController sharedMenuController];
            [menu setTargetRect:[input firstRectForRange:range] inView:(UIView *)input];
            [menu setMenuVisible:YES animated:YES];
        }
    }
    [self charon_end];
}

- (void)charon_pressed:(UILongPressGestureRecognizer *)recognizer
{
    UIResponder<UITextInput> *input = [self charon_input];
    if (!input || _mode != UITextInteractionModeEditable)
        return;
    CGPoint point = [self charon_pointIn:input from:recognizer];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (![self charon_begin:point]) {
            recognizer.enabled = NO;
            recognizer.enabled = YES;
            return;
        }
        if (![input isFirstResponder] && [input canBecomeFirstResponder])
            [input becomeFirstResponder];
    }
    if (recognizer.state == UIGestureRecognizerStateBegan || recognizer.state == UIGestureRecognizerStateChanged) {
        UITextPosition *position = [input closestPositionToPoint:point];
        if (position)
            [self charon_select:[input textRangeFromPosition:position toPosition:position] in:input];
    } else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        [self charon_end];
    }
}

@end
