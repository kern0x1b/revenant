#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wnonnull"

void charon_windowed_run(UIWindow *window);

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    text = [text stringByReplacingOccurrencesOfString:@"_UISearchToken" withString:@"UISearchToken"];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
}

static NSString *raised(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@ %@", exception.name, norm(exception.reason)];
    }
}

static NSString *raised_name(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@", exception.name];
    }
}

static void agree(NSString *name, NSArray *ours, NSArray *system)
{
    NSMutableString *detail = [NSMutableString string];
    for (NSUInteger index = 0; index < MAX(ours.count, system.count); index++) {
        NSString *a = index < ours.count ? ours[index] : @"<none>", *b = index < system.count ? system[index] : @"<none>";
        if (![a isEqual:b])
            [detail appendFormat:@"\n    port   %@\n    system %@", a, b];
    }
    charon_check(detail.length == 0, name.UTF8String, detail);
}

static NSString *line(NSString *label, id value)
{
    return [NSString stringWithFormat:@"%@ %@", label, norm(value)];
}

static NSString *yes(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static NSString *color_text(UIColor *color)
{
    if ([color respondsToSelector:@selector(resolvedColorWithTraitCollection:)])
        color = [color resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]];
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"%.3f %.3f %.3f %.3f", red, green, blue, alpha];
}

static NSArray *token_lines(Class token, NSString *(^text_of)(id))
{
    NSMutableArray *lines = [NSMutableArray array];
    UISearchToken *plain = [token tokenWithIcon:nil text:@"abc"];
    [lines addObject:line(@"plain", @[plain, text_of(plain), plain.representedObject ?: @"no object", yes([plain isEqual:plain]), yes([plain isEqual:[token tokenWithIcon:nil text:@"abc"]])])];
    [lines addObject:line(@"nil text", @[[token tokenWithIcon:nil text:nil], text_of([token tokenWithIcon:nil text:nil]) ?: @"nil"])];
    UIImage *icon = [[UIImage alloc] init];
    UISearchToken *with_icon = [token tokenWithIcon:icon text:@"x"];
    [lines addObject:line(@"icon", @[with_icon, text_of(with_icon)])];
    NSMutableString *text = [NSMutableString stringWithString:@"q"];
    UISearchToken *copied = [token tokenWithIcon:nil text:text];
    [text appendString:@"z"];
    [lines addObject:line(@"the text is a copy", text_of(copied))];
    plain.representedObject = @5;
    [lines addObject:line(@"represented object", plain.representedObject)];
    plain.representedObject = nil;
    [lines addObject:line(@"cleared", plain.representedObject ?: @"nil")];
    [lines addObject:raised_name(^id { return [plain copy]; })];
    [lines addObject:line(@"conforms", @[yes([token conformsToProtocol:@protocol(NSCopying)]), yes([token conformsToProtocol:@protocol(NSSecureCoding)])])];
    [lines addObject:line(@"blank", [[token alloc] performSelector:NSSelectorFromString(@"init")])];
    return lines;
}

static NSInteger offset(UITextField *field, UITextPosition *position)
{
    return [field offsetFromPosition:field.beginningOfDocument toPosition:position];
}

static NSArray *field_lines(Class field_class, UIWindow *window, Class token, BOOL ours)
{
    NSMutableArray *lines = [NSMutableArray array];
    UISearchTextField *field = [[field_class alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    [window addSubview:field];
    [lines addObject:line(@"defaults", @[@(field.tokens.count), yes(field.allowsCopyingTokens), yes(field.allowsDeletingTokens), color_text(field.tokenBackgroundColor), field.text ?: @"nil text",
                                          @(field.borderStyle), @(field.clearButtonMode), @(field.leftViewMode), NSStringFromClass([field.leftView class]), field.placeholder ?: @"no placeholder",
                                          @(field.autocorrectionType), @(field.autocapitalizationType), @(field.returnKeyType), @(field.keyboardType), @(field.enablesReturnKeyAutomatically),
                                          [field.textualRange isEmpty] ? @"empty range" : @"range"])];
    [lines addObject:line(@"tokens is a copy", @[[field.tokens class] == [NSArray class] || [field.tokens isKindOfClass:[NSArray class]] ? @"array" : @"other"])];
    UISearchToken *a = [token tokenWithIcon:nil text:@"A"], *b = [token tokenWithIcon:nil text:@"B"], *c = [token tokenWithIcon:nil text:@"C"];
    [field insertToken:a atIndex:0];
    [field insertToken:b atIndex:1];
    [field insertToken:c atIndex:0];
    [lines addObject:line(@"inserted", @[@(field.tokens.count), yes(field.tokens[0] == c), yes(field.tokens[1] == a), yes(field.tokens[2] == b), field.text])];
    [field insertToken:a atIndex:3];
    [lines addObject:line(@"inserted at the end", @[@(field.tokens.count), yes(field.tokens[3] == a)])];
    [lines addObject:line(@"position", yes([field positionOfTokenAtIndex:0] != nil && [field positionOfTokenAtIndex:3] != nil))];
    for (NSNumber *index in @[@4, @9, @-1])
        [lines addObject:raised(^id { return [field positionOfTokenAtIndex:index.integerValue]; })];
    for (NSNumber *index in @[@10, @-1])
        [lines addObject:raised(^id { [field insertToken:a atIndex:index.integerValue]; return @(field.tokens.count); })];
    [lines addObject:raised(^id { [field insertToken:nil atIndex:0]; return @(field.tokens.count); })];
    for (NSNumber *index in @[@50, @-1, @4])
        [lines addObject:raised(^id { [field removeTokenAtIndex:index.integerValue]; return @(field.tokens.count); })];
    [lines addObject:raised(^id { return @([field tokensInRange:nil].count); })];
    UITextRange *whole = [field textRangeFromPosition:field.beginningOfDocument toPosition:field.endOfDocument];
    [lines addObject:line(@"tokens in the whole document", @([field tokensInRange:whole].count))];
    [lines addObject:line(@"tokens in the textual range", @([field tokensInRange:field.textualRange].count))];
    [field removeTokenAtIndex:1];
    [lines addObject:line(@"removed", @[@(field.tokens.count), yes(field.tokens[0] == c), yes(field.tokens[1] == b), field.text])];
    field.text = @"hello";
    [lines addObject:line(@"typed", @[field.text, @(field.tokens.count)])];
    field.text = @"";
    [lines addObject:line(@"cleared", @[field.text, @(field.tokens.count)])];
    field.tokens = @[a, b];
    [lines addObject:line(@"set", @[@(field.tokens.count), yes(field.tokens[0] == a), field.text])];
    NSMutableArray *held = [NSMutableArray arrayWithObject:a];
    field.tokens = held;
    [held addObject:b];
    [lines addObject:line(@"set copies", @(field.tokens.count))];
    field.tokens = nil;
    [lines addObject:line(@"set nil", @(field.tokens.count))];
    field.tokens = @[a, a];
    [lines addObject:line(@"the same token twice", @(field.tokens.count))];
    field.tokens = @[];
    field.text = @"hello";
    UITextRange *middle = [field textRangeFromPosition:[field positionFromPosition:field.beginningOfDocument offset:1] toPosition:[field positionFromPosition:field.beginningOfDocument offset:3]];
    [field replaceTextualPortionOfRange:middle withToken:a atIndex:0];
    [lines addObject:line(@"replaced a portion", @[field.text, @(field.tokens.count)])];
    field.text = @"hello";
    field.tokens = @[];
    [field replaceTextualPortionOfRange:field.textualRange withToken:b atIndex:0];
    [lines addObject:line(@"replaced the textual range", @[field.text, @(field.tokens.count)])];
    field.text = @"hello";
    [field replaceTextualPortionOfRange:field.textualRange withToken:c atIndex:1];
    [lines addObject:line(@"replaced with tokens present", @[field.text, @(field.tokens.count), yes(field.tokens[1] == c)])];
    [lines addObject:raised(^id { [field replaceTextualPortionOfRange:nil withToken:b atIndex:0]; return @(field.tokens.count); })];
    [lines addObject:raised(^id { [field replaceTextualPortionOfRange:field.textualRange withToken:nil atIndex:0]; return @(field.tokens.count); })];
    for (NSNumber *index in @[@9, @(-1)])
        [lines addObject:raised(^id { [field replaceTextualPortionOfRange:field.textualRange withToken:b atIndex:index.integerValue]; return @(field.tokens.count); })];
    UIColor *red = [UIColor redColor];
    field.tokenBackgroundColor = red;
    NSString *kept = yes(field.tokenBackgroundColor == red);
    field.tokenBackgroundColor = nil;
    [lines addObject:line(@"token background", @[kept, color_text(field.tokenBackgroundColor)])];
    field.allowsCopyingTokens = NO;
    field.allowsDeletingTokens = NO;
    [lines addObject:line(@"flags", @[yes(field.allowsCopyingTokens), yes(field.allowsDeletingTokens)])];
    [field removeFromSuperview];
    return lines;
}

void charon_windowed_run(UIWindow *window)
{
    Class ourToken = NSClassFromString(@"CharonHostUISearchToken"), ourField = NSClassFromString(@"CharonHostUISearchTextField");
    charon_check(ourToken && ourField, "the port's classes are linked under their host names", @"one is missing");
    charon_check(class_getSuperclass(ourToken) == [NSObject class] && class_getSuperclass(ourField) == [UITextField class], "the classes descend as the system's do", @"a superclass differs");
    agree(@"search token", token_lines(ourToken, ^NSString *(id token) { return ((id (*)(id, SEL))objc_msgSend)(token, NSSelectorFromString(@"charon_text")); }),
          token_lines([UISearchToken class], ^NSString *(id token) { return [token valueForKey:@"text"]; }));
    agree(@"search text field", field_lines(ourField, window, ourToken, YES), field_lines([UISearchTextField class], window, [UISearchToken class], NO));
    charon_check(![ourField instancesRespondToSelector:@selector(searchSuggestions)] && [UISearchTextField instancesRespondToSelector:@selector(searchSuggestions)],
                 "the search text field leaves the suggestions of iOS 16 to the release", @"it answers them");

    UISearchTextField *field = [[ourField alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    field.font = [UIFont systemFontOfSize:15];
    [window addSubview:field];
    field.tokens = @[[ourToken tokenWithIcon:nil text:@"Alpha"], [ourToken tokenWithIcon:nil text:@"Beta"]];
    [field layoutIfNeeded];
    NSMutableArray *chips = [NSMutableArray array];
    for (UIView *sub in field.subviews)
        if ([sub isKindOfClass:[UILabel class]])
            [chips addObject:sub];
    charon_check(chips.count == 2 && [[chips[0] text] isEqual:@"Alpha"] && [[chips[1] text] isEqual:@"Beta"] && CGRectGetMinX([chips[1] frame]) > CGRectGetMaxX([chips[0] frame]),
                 "each token is drawn as a chip, side by side", ([NSString stringWithFormat:@"%@", chips]));
    CGRect text_rect = [field textRectForBounds:field.bounds], edit_rect = [field editingRectForBounds:field.bounds];
    charon_check(CGRectGetMinX(text_rect) >= CGRectGetMaxX([chips[1] frame]) && CGRectGetMinX(edit_rect) >= CGRectGetMaxX([chips[1] frame]) && CGRectGetWidth(text_rect) >= 30,
                 "the text starts after the chips", ([NSString stringWithFormat:@"%@ %@", NSStringFromCGRect(text_rect), NSStringFromCGRect([chips[1] frame])]));
    field.tokens = @[[ourToken tokenWithIcon:nil text:@"Alpha"]];
    [field layoutIfNeeded];
    NSUInteger left = 0;
    for (UIView *sub in field.subviews)
        if ([sub isKindOfClass:[UILabel class]])
            left++;
    charon_check(left == 1, "a token taken away takes its chip away", ([NSString stringWithFormat:@"%lu chips", (unsigned long)left]));
    field.tokens = @[];
    [field layoutIfNeeded];
    charon_check(CGRectGetMinX([field textRectForBounds:field.bounds]) < CGRectGetMinX(text_rect), "and the text moves back", @"it does not");
    field.tokens = @[[ourToken tokenWithIcon:nil text:@"One"], [ourToken tokenWithIcon:nil text:@"Two"]];
    field.text = @"ab";
    UITextRange *at_end = [field textRangeFromPosition:field.endOfDocument toPosition:field.endOfDocument];
    [field becomeFirstResponder];
    field.selectedTextRange = at_end;
    if (field.selectedTextRange) {
        [field deleteBackward];
        charon_check(field.tokens.count == 2 && [field.text isEqual:@"a"], "a backspace after text deletes the text and no token", ([NSString stringWithFormat:@"%lu %@", (unsigned long)field.tokens.count, field.text]));
        field.text = @"";
        field.selectedTextRange = [field textRangeFromPosition:field.beginningOfDocument toPosition:field.beginningOfDocument];
        field.allowsDeletingTokens = NO;
        [field deleteBackward];
        charon_check(field.tokens.count == 2, "a backspace at the start does not delete a token when the field does not allow it", ([NSString stringWithFormat:@"%lu", (unsigned long)field.tokens.count]));
        field.allowsDeletingTokens = YES;
        [field deleteBackward];
        charon_check(field.tokens.count == 1 && [[field.tokens[0] valueForKey:@"charon_text"] isEqual:@"One"], "a backspace at the start of an empty field deletes the last token", ([NSString stringWithFormat:@"%lu", (unsigned long)field.tokens.count]));
    } else {
        charon_check(NO, "the field has a selection while editing", @"it has none");
    }
    [field resignFirstResponder];
    [field removeFromSuperview];
}
