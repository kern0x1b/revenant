#import "uirest.h"

@interface FakeTap : UITapGestureRecognizer
@property (nonatomic) CGPoint fixed;
@property (nonatomic) NSUInteger taps;
@end

@implementation FakeTap

- (UIGestureRecognizerState)state
{
    return UIGestureRecognizerStateRecognized;
}

- (NSUInteger)numberOfTapsRequired
{
    return self.taps;
}

- (CGPoint)locationInView:(UIView *)view
{
    return [self.view convertPoint:self.fixed toView:view];
}

@end

@interface FakePress : UILongPressGestureRecognizer
@property (nonatomic) CGPoint fixed;
@property (nonatomic) UIGestureRecognizerState fakeState;
@end

@implementation FakePress

- (UIGestureRecognizerState)state
{
    return self.fakeState;
}

- (CGPoint)locationInView:(UIView *)view
{
    return [self.view convertPoint:self.fixed toView:view];
}

@end

@interface Watcher : NSObject <UITextInteractionDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic) BOOL allow;
@end

@implementation Watcher

- (instancetype)init
{
    if ((self = [super init])) {
        self.events = [NSMutableArray array];
        self.allow = YES;
    }
    return self;
}

- (BOOL)interactionShouldBegin:(UITextInteraction *)interaction atPoint:(CGPoint)point
{
    [self.events addObject:@"should begin"];
    return self.allow;
}

- (void)interactionWillBegin:(UITextInteraction *)interaction
{
    [self.events addObject:@"will begin"];
}

- (void)interactionDidEnd:(UITextInteraction *)interaction
{
    [self.events addObject:@"did end"];
}

@end

@interface UITextInteraction (Hidden)
- (void)charon_tapped:(UITapGestureRecognizer *)recognizer;
- (void)charon_pressed:(UILongPressGestureRecognizer *)recognizer;
@end

static NSRange selection(UITextField *field)
{
    UITextRange *range = field.selectedTextRange;
    NSInteger start = [field offsetFromPosition:field.beginningOfDocument toPosition:range.start];
    NSInteger end = [field offsetFromPosition:field.beginningOfDocument toPosition:range.end];
    return NSMakeRange((NSUInteger)start, (NSUInteger)(end - start));
}

static CGPoint center_of(UITextField *field, NSRange range)
{
    UITextPosition *a = [field positionFromPosition:field.beginningOfDocument offset:(NSInteger)range.location];
    UITextPosition *b = [field positionFromPosition:field.beginningOfDocument offset:(NSInteger)NSMaxRange(range)];
    CGRect rect = [field firstRectForRange:[field textRangeFromPosition:a toPosition:b]];
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostUITextInteraction");
        charon_check(ours != Nil, "the port's interaction is linked under its host name", @"missing");
        UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 100, 300, 30)];
        field.text = @"hello brave new world";
        field.font = [UIFont systemFontOfSize:14];
        [window addSubview:field];
        UITextInteraction *editable = [ours textInteractionForMode:UITextInteractionModeEditable];
        Watcher *watcher = [[Watcher alloc] init];
        editable.delegate = watcher;
        editable.textInput = field;
        charon_check(editable.textInteractionMode == UITextInteractionModeEditable && editable.textInput == field && editable.delegate == watcher && editable.gesturesForFailureRequirements.count == 0 && editable.view == nil,
                     "an interaction keeps its mode, input and delegate, and has no gestures before it is added", @"it does not");
        NSUInteger before = field.interactions.count;
        [field addInteraction:editable];
        charon_check(editable.view == field && field.interactions.count == before + 1 && editable.gesturesForFailureRequirements.count == 4, "an added interaction has four gestures on the view", [NSString stringWithFormat:@"%lu", (unsigned long)editable.gesturesForFailureRequirements.count]);
        for (UIGestureRecognizer *recognizer in editable.gesturesForFailureRequirements)
            charon_check([field.gestureRecognizers containsObject:recognizer], "each gesture is on the view", @"one is not");

        [window makeKeyAndVisible];
        [field becomeFirstResponder];
        ur_spin(^BOOL{ return NO; }, 0.4);
        NSRange brave = NSMakeRange(6, 5);
        FakeTap *tap = [[FakeTap alloc] init];
        [field addGestureRecognizer:tap];
        tap.fixed = center_of(field, brave);
        tap.taps = 1;
        [editable charon_tapped:tap];
        NSRange caret = selection(field);
        charon_check(caret.length == 0 && caret.location >= 6 && caret.location <= 11, "a tap puts the caret in the word under it", NSStringFromRange(caret));
        charon_check([watcher.events isEqual:@[@"should begin", @"will begin", @"did end"]], "and the delegate hears the interaction begin and end", ur_norm(watcher.events));
        [watcher.events removeAllObjects];
        tap.taps = 2;
        [editable charon_tapped:tap];
        charon_check(NSEqualRanges(selection(field), brave), "a double tap selects the word", NSStringFromRange(selection(field)));
        tap.taps = 3;
        [editable charon_tapped:tap];
        charon_check(NSEqualRanges(selection(field), NSMakeRange(0, field.text.length)), "a triple tap selects the paragraph", NSStringFromRange(selection(field)));
        [watcher.events removeAllObjects];
        watcher.allow = NO;
        tap.taps = 1;
        tap.fixed = center_of(field, NSMakeRange(0, 2));
        [editable charon_tapped:tap];
        charon_check(NSEqualRanges(selection(field), NSMakeRange(0, field.text.length)) && [watcher.events isEqual:@[@"should begin"]], "a delegate that says no leaves the selection alone", ur_norm(watcher.events));
        watcher.allow = YES;
        [watcher.events removeAllObjects];
        FakePress *press = [[FakePress alloc] init];
        [field addGestureRecognizer:press];
        press.fixed = center_of(field, NSMakeRange(0, 2));
        press.fakeState = UIGestureRecognizerStateBegan;
        [editable charon_pressed:press];
        NSRange first = selection(field);
        press.fixed = center_of(field, NSMakeRange(16, 3));
        press.fakeState = UIGestureRecognizerStateChanged;
        [editable charon_pressed:press];
        NSRange second = selection(field);
        press.fakeState = UIGestureRecognizerStateEnded;
        [editable charon_pressed:press];
        charon_check(first.length == 0 && second.length == 0 && first.location <= 2 && second.location >= 16 && [watcher.events isEqual:@[@"should begin", @"will begin", @"did end"]], "a long press moves the caret and ends once",
                     [NSString stringWithFormat:@"%@ %@ %@", NSStringFromRange(first), NSStringFromRange(second), ur_norm(watcher.events)]);
        [field removeInteraction:editable];
        charon_check(editable.view == nil && editable.gesturesForFailureRequirements.count == 0 && ![field.gestureRecognizers containsObject:tap] == NO, "removing the interaction takes its gestures away", @"they stay");
        UITextInteraction *fixed = [ours textInteractionForMode:UITextInteractionModeNonEditable];
        charon_check(fixed.textInteractionMode == UITextInteractionModeNonEditable, "a non-editable interaction says so", @"it does not");
        fixed.textInput = field;
        [field addInteraction:fixed];
        [field resignFirstResponder];
        tap.taps = 1;
        tap.fixed = center_of(field, brave);
        [fixed charon_tapped:tap];
        charon_check(![field isFirstResponder], "a tap on non-editable text does not start editing", @"it does");
    }
}
