#import "CharonSearch.h"
#import <objc/runtime.h>

static const char CharonTokenStateKey;
static const char CharonTextualRangeKey;

@interface CharonTokenState : NSObject {
@public
    NSMutableArray *tokens;
    NSMutableArray *chips;
    UIColor *background;
    BOOL allowsDeleting;
    BOOL allowsCopying;
}
@end

@implementation CharonTokenState

- (instancetype)init
{
    if ((self = [super init])) {
        tokens = [NSMutableArray array];
        chips = [NSMutableArray array];
        allowsDeleting = YES;
        allowsCopying = YES;
    }
    return self;
}

@end

static CharonTokenState *charon_state(UITextField *field)
{
    CharonTokenState *state = objc_getAssociatedObject(field, &CharonTokenStateKey);
    if (!state) {
        state = [[CharonTokenState alloc] init];
        objc_setAssociatedObject(field, &CharonTokenStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

static UIColor *charon_default_token_background(void)
{
    return [UIColor colorWithRed:142.0f / 255 green:142.0f / 255 blue:147.0f / 255 alpha:1];
}

static void charon_needs(BOOL held, NSString *condition)
{
    if (!held)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: %@", condition];
}

static void charon_range_check(NSInteger index, NSUInteger count)
{
    if (index < 0 || (NSUInteger)index > count + 1)
        [NSException raise:NSRangeException format:@"Token index %ld out of range: [0, %lu)", (long)index, (unsigned long)count];
    if ((NSUInteger)index == count + 1)
        [NSException raise:NSRangeException format:@"NSMutableRLEArray insertObject:range:: Out of bounds"];
}

static void charon_changed(UITextField *field)
{
    [field setNeedsLayout];
}

NSArray *charon_field_tokens(UITextField *field)
{
    return [NSArray arrayWithArray:charon_state(field)->tokens];
}

void charon_field_set_tokens(UITextField *field, NSArray *tokens)
{
    for (id token in tokens) {
        if (![token isKindOfClass:[UISearchToken class]])
            [NSException raise:NSInvalidArgumentException format:@"tokens holds %@, which is not a UISearchToken", [token class]];
    }
    CharonTokenState *state = charon_state(field);
    state->tokens = tokens ? [tokens mutableCopy] : [NSMutableArray array];
    charon_changed(field);
}

void charon_field_insert_token(UITextField *field, UISearchToken *token, NSInteger index)
{
    charon_needs(token != nil, @"token != nil");
    CharonTokenState *state = charon_state(field);
    charon_range_check(index, state->tokens.count);
    [state->tokens insertObject:token atIndex:(NSUInteger)index];
    charon_changed(field);
}

void charon_field_remove_token(UITextField *field, NSInteger index)
{
    charon_needs(index >= 0, @"tokenIndex >= 0");
    CharonTokenState *state = charon_state(field);
    if ((NSUInteger)index > state->tokens.count)
        [NSException raise:NSRangeException format:@"Token index %ld out of range: [0, %lu)", (long)index, (unsigned long)state->tokens.count];
    if ((NSUInteger)index == state->tokens.count)
        [NSException raise:NSRangeException format:@"NSMutableRLEArray replaceObjectsInRange:withObject:length:: Out of bounds"];
    [state->tokens removeObjectAtIndex:(NSUInteger)index];
    charon_changed(field);
}

UITextPosition *charon_field_position_of_token(UITextField *field, NSInteger index)
{
    charon_needs(index >= 0, @"tokenIndex >= 0");
    NSUInteger count = charon_state(field)->tokens.count;
    if ((NSUInteger)index >= count)
        [NSException raise:NSInvalidArgumentException format:@"Token index %ld out of range [0, %lu)", (long)index, (unsigned long)count];
    return field.beginningOfDocument;
}

NSArray *charon_field_tokens_in_range(UITextField *field, UITextRange *range)
{
    charon_needs(range != nil, @"textRange != nil");
    if (objc_getAssociatedObject(range, &CharonTextualRangeKey) || [field offsetFromPosition:field.beginningOfDocument toPosition:range.start] != 0)
        return @[];
    return charon_field_tokens(field);
}

UITextRange *charon_field_textual_range(UITextField *field)
{
    UITextRange *range = [field textRangeFromPosition:field.beginningOfDocument toPosition:field.endOfDocument];
    objc_setAssociatedObject(range, &CharonTextualRangeKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return range;
}

void charon_field_replace_textual_portion(UITextField *field, UITextRange *range, UISearchToken *token, NSUInteger index)
{
    charon_needs(range != nil, @"textRange != nil");
    charon_needs(token != nil, @"token != nil");
    charon_range_check((NSInteger)index, charon_state(field)->tokens.count);
    [field replaceRange:range withText:@""];
    charon_field_insert_token(field, token, (NSInteger)index);
}

UIColor *charon_field_token_background(UITextField *field)
{
    return charon_state(field)->background ?: charon_default_token_background();
}

void charon_field_set_token_background(UITextField *field, UIColor *color)
{
    charon_state(field)->background = color;
    charon_changed(field);
}

BOOL charon_field_allows_deleting(UITextField *field)
{
    return charon_state(field)->allowsDeleting;
}

void charon_field_set_allows_deleting(UITextField *field, BOOL allows)
{
    charon_state(field)->allowsDeleting = allows;
}

BOOL charon_field_allows_copying(UITextField *field)
{
    return charon_state(field)->allowsCopying;
}

void charon_field_set_allows_copying(UITextField *field, BOOL allows)
{
    charon_state(field)->allowsCopying = allows;
}

BOOL charon_field_delete_last_token(UITextField *field)
{
    CharonTokenState *state = charon_state(field);
    UITextRange *selected = field.selectedTextRange;
    if (!state->allowsDeleting || !state->tokens.count || !selected || !selected.empty || [field offsetFromPosition:field.beginningOfDocument toPosition:selected.start] != 0)
        return NO;
    [state->tokens removeLastObject];
    charon_changed(field);
    [field sendActionsForControlEvents:UIControlEventEditingChanged];
    return YES;
}

static const CGFloat CharonChipPadding = 6;
static const CGFloat CharonChipGap = 4;
static const CGFloat CharonChipLimit = 120;

static CGFloat charon_chips_origin(UITextField *field)
{
    return field.leftView ? CGRectGetMaxX([field leftViewRectForBounds:field.bounds]) : 0;
}

static UIFont *charon_chip_font(UITextField *field)
{
    return field.font ?: [UIFont systemFontOfSize:15];
}

static CGFloat charon_chip_width(UITextField *field, UISearchToken *token)
{
    static UILabel *measure;
    if (!measure)
        measure = [[UILabel alloc] init];
    measure.font = charon_chip_font(field);
    measure.text = [token charon_text];
    return MIN([measure sizeThatFits:CGSizeMake(CharonChipLimit * 4, 1000)].width + 2 * CharonChipPadding, CharonChipLimit);
}

CGFloat charon_field_prefix_width(UITextField *field)
{
    NSArray *tokens = charon_state(field)->tokens;
    if (!tokens.count)
        return 0;
    CGFloat width = CharonChipGap;
    for (UISearchToken *token in tokens)
        width += charon_chip_width(field, token) + CharonChipGap;
    return width;
}

void charon_field_layout_chips(UITextField *field)
{
    CharonTokenState *state = charon_state(field);
    NSArray *tokens = state->tokens;
    while (state->chips.count > tokens.count) {
        [[state->chips lastObject] removeFromSuperview];
        [state->chips removeLastObject];
    }
    UIFont *font = charon_chip_font(field);
    CGFloat height = MIN(CGRectGetHeight(field.bounds) - 8, font.lineHeight + 6);
    CGFloat x = charon_chips_origin(field) + CharonChipGap;
    for (NSUInteger index = 0; index < tokens.count; index++) {
        UILabel *chip;
        if (index < state->chips.count) {
            chip = state->chips[index];
        } else {
            chip = [[UILabel alloc] init];
            chip.textAlignment = NSTextAlignmentCenter;
            chip.textColor = [UIColor whiteColor];
            chip.layer.cornerRadius = 5;
            chip.layer.masksToBounds = YES;
            chip.userInteractionEnabled = NO;
            [state->chips addObject:chip];
            [field addSubview:chip];
        }
        NSString *text = [tokens[index] charon_text];
        if (![chip.font isEqual:font])
            chip.font = font;
        if (!(chip.text == text || [chip.text isEqual:text]))
            chip.text = text;
        UIColor *background = charon_field_token_background(field);
        if (![chip.backgroundColor isEqual:background])
            chip.backgroundColor = background;
        CGFloat width = charon_chip_width(field, tokens[index]);
        CGRect frame = CGRectMake(x, (CGRectGetHeight(field.bounds) - height) / 2, width, height);
        if (!CGRectEqualToRect(chip.frame, frame))
            chip.frame = frame;
        x += width + CharonChipGap;
    }
}

static UIImage *charon_magnifier_image(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, charon_default_token_background().CGColor);
    CGContextSetLineWidth(context, 2);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextStrokeEllipseInRect(context, CGRectMake(3, 3, 10, 10));
    CGContextMoveToPoint(context, 11.5f, 11.5f);
    CGContextAddLineToPoint(context, 17, 17);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static CGRect charon_shifted(CGRect rect, UITextField *field)
{
    CGFloat shift = MIN(charon_field_prefix_width(field), MAX(0, CGRectGetWidth(rect) - 30));
    rect.origin.x += shift;
    rect.size.width -= shift;
    return rect;
}

@implementation UISearchTextField

@dynamic searchSuggestions;

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.borderStyle = UITextBorderStyleRoundedRect;
        self.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.leftView = [[UIImageView alloc] initWithImage:charon_magnifier_image()];
        self.leftViewMode = UITextFieldViewModeAlways;
    }
    return self;
}

- (NSArray<UISearchToken *> *)tokens
{
    return charon_field_tokens(self);
}

- (void)setTokens:(NSArray<UISearchToken *> *)tokens
{
    charon_field_set_tokens(self, tokens);
}

- (void)insertToken:(UISearchToken *)token atIndex:(NSInteger)tokenIndex
{
    charon_field_insert_token(self, token, tokenIndex);
}

- (void)removeTokenAtIndex:(NSInteger)tokenIndex
{
    charon_field_remove_token(self, tokenIndex);
}

- (UITextPosition *)positionOfTokenAtIndex:(NSInteger)tokenIndex
{
    return charon_field_position_of_token(self, tokenIndex);
}

- (NSArray<UISearchToken *> *)tokensInRange:(UITextRange *)textRange
{
    return charon_field_tokens_in_range(self, textRange);
}

- (UITextRange *)textualRange
{
    return charon_field_textual_range(self);
}

- (void)replaceTextualPortionOfRange:(UITextRange *)textRange withToken:(UISearchToken *)token atIndex:(NSUInteger)tokenIndex
{
    charon_field_replace_textual_portion(self, textRange, token, tokenIndex);
}

- (UIColor *)tokenBackgroundColor
{
    return charon_field_token_background(self);
}

- (void)setTokenBackgroundColor:(UIColor *)tokenBackgroundColor
{
    charon_field_set_token_background(self, tokenBackgroundColor);
}

- (BOOL)allowsDeletingTokens
{
    return charon_field_allows_deleting(self);
}

- (void)setAllowsDeletingTokens:(BOOL)allowsDeletingTokens
{
    charon_field_set_allows_deleting(self, allowsDeletingTokens);
}

- (BOOL)allowsCopyingTokens
{
    return charon_field_allows_copying(self);
}

- (void)setAllowsCopyingTokens:(BOOL)allowsCopyingTokens
{
    charon_field_set_allows_copying(self, allowsCopyingTokens);
}

- (void)deleteBackward
{
    if (!charon_field_delete_last_token(self) && [UITextField instancesRespondToSelector:@selector(deleteBackward)])
        [super deleteBackward];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    charon_field_layout_chips(self);
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
    return charon_shifted([super textRectForBounds:bounds], self);
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return charon_shifted([super editingRectForBounds:bounds], self);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return charon_shifted([super placeholderRectForBounds:bounds], self);
}

@end
