#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static NSString *const RevenantSelectionKey = @"selectedRange";
static NSString *const RevenantOffsetKey = @"contentOffset";

static NSRange revenant_selection(id<UITextInput> input)
{
    UITextRange *selected = input.selectedTextRange;
    if (!selected)
        return NSMakeRange(NSNotFound, 0);
    NSInteger start = [input offsetFromPosition:input.beginningOfDocument toPosition:selected.start];
    NSInteger end = [input offsetFromPosition:input.beginningOfDocument toPosition:selected.end];
    return NSMakeRange(start, end - start);
}

static void revenant_select(id<UITextInput> input, NSRange range)
{
    UITextPosition *start = [input positionFromPosition:input.beginningOfDocument offset:range.location];
    UITextPosition *end = [input positionFromPosition:input.beginningOfDocument offset:NSMaxRange(range)];
    if (start && end)
        input.selectedTextRange = [input textRangeFromPosition:start toPosition:end];
}

@implementation UITextField (RevenantInteractionState15)

- (id)interactionState
{
    return @{RevenantSelectionKey: NSStringFromRange(revenant_selection(self))};
}

- (void)setInteractionState:(id)interactionState
{
    NSString *stored = [interactionState isKindOfClass:[NSDictionary class]] ? interactionState[RevenantSelectionKey] : nil;
    if (stored)
        revenant_select(self, NSRangeFromString(stored));
}

@end

@implementation UITextView (RevenantInteractionState15)

- (id)interactionState
{
    return @{RevenantSelectionKey: NSStringFromRange(revenant_selection(self)), RevenantOffsetKey: NSStringFromCGPoint(self.contentOffset)};
}

- (void)setInteractionState:(id)interactionState
{
    if (![interactionState isKindOfClass:[NSDictionary class]])
        return;
    NSString *selection = interactionState[RevenantSelectionKey];
    NSString *offset = interactionState[RevenantOffsetKey];
    if (selection)
        revenant_select(self, NSRangeFromString(selection));
    if (offset)
        self.contentOffset = CGPointFromString(offset);
}

@end
