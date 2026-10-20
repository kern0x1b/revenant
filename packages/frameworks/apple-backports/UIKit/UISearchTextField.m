#import "RevenantSearch.h"
#import <objc/runtime.h>

static const char RevenantTokenStateKey;
static const char RevenantTextualRangeKey;

@interface RevenantTokenState : NSObject {
@public
    NSMutableArray *tokens;
    NSMutableArray *chips;
    UIColor *background;
    BOOL allowsDeleting;
    BOOL allowsCopying;
}
@end

@implementation RevenantTokenState

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

static RevenantTokenState *revenant_state(UITextField *field)
{
    RevenantTokenState *state = objc_getAssociatedObject(field, &RevenantTokenStateKey);
    if (!state) {
        state = [[RevenantTokenState alloc] init];
        objc_setAssociatedObject(field, &RevenantTokenStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

static UIColor *revenant_default_token_background(void)
{
    return [UIColor colorWithRed:142.0f / 255 green:142.0f / 255 blue:147.0f / 255 alpha:1];
}

static void revenant_needs(BOOL held, NSString *condition)
{
    if (!held)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: %@", condition];
}

static void revenant_range_check(NSInteger index, NSUInteger count)
{
    if (index < 0 || (NSUInteger)index > count + 1)
        [NSException raise:NSRangeException format:@"Token index %ld out of range: [0, %lu)", (long)index, (unsigned long)count];
    if ((NSUInteger)index == count + 1)
        [NSException raise:NSRangeException format:@"NSMutableRLEArray insertObject:range:: Out of bounds"];
}

static void revenant_changed(UITextField *field)
{
    [field setNeedsLayout];
}

NSArray *revenant_field_tokens(UITextField *field)
{
    return [NSArray arrayWithArray:revenant_state(field)->tokens];
}

void revenant_field_set_tokens(UITextField *field, NSArray *tokens)
{
    for (id token in tokens) {
        if (![token isKindOfClass:[UISearchToken class]])
            [NSException raise:NSInvalidArgumentException format:@"tokens holds %@, which is not a UISearchToken", [token class]];
    }
    RevenantTokenState *state = revenant_state(field);
    state->tokens = tokens ? [tokens mutableCopy] : [NSMutableArray array];
    revenant_changed(field);
}

void revenant_field_insert_token(UITextField *field, UISearchToken *token, NSInteger index)
{
    revenant_needs(token != nil, @"token != nil");
    RevenantTokenState *state = revenant_state(field);
    revenant_range_check(index, state->tokens.count);
    [state->tokens insertObject:token atIndex:(NSUInteger)index];
    revenant_changed(field);
}

void revenant_field_remove_token(UITextField *field, NSInteger index)
{
    revenant_needs(index >= 0, @"tokenIndex >= 0");
    RevenantTokenState *state = revenant_state(field);
    if ((NSUInteger)index > state->tokens.count)
        [NSException raise:NSRangeException format:@"Token index %ld out of range: [0, %lu)", (long)index, (unsigned long)state->tokens.count];
    if ((NSUInteger)index == state->tokens.count)
        [NSException raise:NSRangeException format:@"NSMutableRLEArray replaceObjectsInRange:withObject:length:: Out of bounds"];
    [state->tokens removeObjectAtIndex:(NSUInteger)index];
    revenant_changed(field);
}

UITextPosition *revenant_field_position_of_token(UITextField *field, NSInteger index)
{
    revenant_needs(index >= 0, @"tokenIndex >= 0");
    NSUInteger count = revenant_state(field)->tokens.count;
    if ((NSUInteger)index >= count)
        [NSException raise:NSInvalidArgumentException format:@"Token index %ld out of range [0, %lu)", (long)index, (unsigned long)count];
    return field.beginningOfDocument;
}

NSArray *revenant_field_tokens_in_range(UITextField *field, UITextRange *range)
{
    revenant_needs(range != nil, @"textRange != nil");
    if (objc_getAssociatedObject(range, &RevenantTextualRangeKey) || [field offsetFromPosition:field.beginningOfDocument toPosition:range.start] != 0)
        return @[];
    return revenant_field_tokens(field);
}

UITextRange *revenant_field_textual_range(UITextField *field)
{
    UITextRange *range = [field textRangeFromPosition:field.beginningOfDocument toPosition:field.endOfDocument];
    objc_setAssociatedObject(range, &RevenantTextualRangeKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return range;
}

void revenant_field_replace_textual_portion(UITextField *field, UITextRange *range, UISearchToken *token, NSUInteger index)
{
    revenant_needs(range != nil, @"textRange != nil");
    revenant_needs(token != nil, @"token != nil");
    revenant_range_check((NSInteger)index, revenant_state(field)->tokens.count);
    [field replaceRange:range withText:@""];
    revenant_field_insert_token(field, token, (NSInteger)index);
}

UIColor *revenant_field_token_background(UITextField *field)
{
    return revenant_state(field)->background ?: revenant_default_token_background();
}

void revenant_field_set_token_background(UITextField *field, UIColor *color)
{
    revenant_state(field)->background = color;
    revenant_changed(field);
}

BOOL revenant_field_allows_deleting(UITextField *field)
{
    return revenant_state(field)->allowsDeleting;
}

void revenant_field_set_allows_deleting(UITextField *field, BOOL allows)
{
    revenant_state(field)->allowsDeleting = allows;
}

BOOL revenant_field_allows_copying(UITextField *field)
{
    return revenant_state(field)->allowsCopying;
}

void revenant_field_set_allows_copying(UITextField *field, BOOL allows)
{
    revenant_state(field)->allowsCopying = allows;
}

BOOL revenant_field_delete_last_token(UITextField *field)
{
    RevenantTokenState *state = revenant_state(field);
    UITextRange *selected = field.selectedTextRange;
    if (!state->allowsDeleting || !state->tokens.count || !selected || !selected.empty || [field offsetFromPosition:field.beginningOfDocument toPosition:selected.start] != 0)
        return NO;
    [state->tokens removeLastObject];
    revenant_changed(field);
    [field sendActionsForControlEvents:UIControlEventEditingChanged];
    return YES;
}

static const CGFloat RevenantChipPadding = 6;
static const CGFloat RevenantChipGap = 4;
static const CGFloat RevenantChipLimit = 120;

static CGFloat revenant_chips_origin(UITextField *field)
{
    return field.leftView ? CGRectGetMaxX([field leftViewRectForBounds:field.bounds]) : 0;
}

static UIFont *revenant_chip_font(UITextField *field)
{
    return field.font ?: [UIFont systemFontOfSize:15];
}

static CGFloat revenant_chip_width(UITextField *field, UISearchToken *token)
{
    static UILabel *measure;
    if (!measure)
        measure = [[UILabel alloc] init];
    measure.font = revenant_chip_font(field);
    measure.text = [token revenant_text];
    return MIN([measure sizeThatFits:CGSizeMake(RevenantChipLimit * 4, 1000)].width + 2 * RevenantChipPadding, RevenantChipLimit);
}

CGFloat revenant_field_prefix_width(UITextField *field)
{
    NSArray *tokens = revenant_state(field)->tokens;
    if (!tokens.count)
        return 0;
    CGFloat width = RevenantChipGap;
    for (UISearchToken *token in tokens)
        width += revenant_chip_width(field, token) + RevenantChipGap;
    return width;
}

void revenant_field_layout_chips(UITextField *field)
{
    RevenantTokenState *state = revenant_state(field);
    NSArray *tokens = state->tokens;
    while (state->chips.count > tokens.count) {
        [[state->chips lastObject] removeFromSuperview];
        [state->chips removeLastObject];
    }
    UIFont *font = revenant_chip_font(field);
    CGFloat height = MIN(CGRectGetHeight(field.bounds) - 8, font.lineHeight + 6);
    CGFloat x = revenant_chips_origin(field) + RevenantChipGap;
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
        NSString *text = [tokens[index] revenant_text];
        if (![chip.font isEqual:font])
            chip.font = font;
        if (!(chip.text == text || [chip.text isEqual:text]))
            chip.text = text;
        UIColor *background = revenant_field_token_background(field);
        if (![chip.backgroundColor isEqual:background])
            chip.backgroundColor = background;
        CGFloat width = revenant_chip_width(field, tokens[index]);
        CGRect frame = CGRectMake(x, (CGRectGetHeight(field.bounds) - height) / 2, width, height);
        if (!CGRectEqualToRect(chip.frame, frame))
            chip.frame = frame;
        x += width + RevenantChipGap;
    }
}

static UIImage *revenant_magnifier_image(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, revenant_default_token_background().CGColor);
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

static CGRect revenant_shifted(CGRect rect, UITextField *field)
{
    CGFloat shift = MIN(revenant_field_prefix_width(field), MAX(0, CGRectGetWidth(rect) - 30));
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
        self.leftView = [[UIImageView alloc] initWithImage:revenant_magnifier_image()];
        self.leftViewMode = UITextFieldViewModeAlways;
    }
    return self;
}

- (NSArray<UISearchToken *> *)tokens
{
    return revenant_field_tokens(self);
}

- (void)setTokens:(NSArray<UISearchToken *> *)tokens
{
    revenant_field_set_tokens(self, tokens);
}

- (void)insertToken:(UISearchToken *)token atIndex:(NSInteger)tokenIndex
{
    revenant_field_insert_token(self, token, tokenIndex);
}

- (void)removeTokenAtIndex:(NSInteger)tokenIndex
{
    revenant_field_remove_token(self, tokenIndex);
}

- (UITextPosition *)positionOfTokenAtIndex:(NSInteger)tokenIndex
{
    return revenant_field_position_of_token(self, tokenIndex);
}

- (NSArray<UISearchToken *> *)tokensInRange:(UITextRange *)textRange
{
    return revenant_field_tokens_in_range(self, textRange);
}

- (UITextRange *)textualRange
{
    return revenant_field_textual_range(self);
}

- (void)replaceTextualPortionOfRange:(UITextRange *)textRange withToken:(UISearchToken *)token atIndex:(NSUInteger)tokenIndex
{
    revenant_field_replace_textual_portion(self, textRange, token, tokenIndex);
}

- (UIColor *)tokenBackgroundColor
{
    return revenant_field_token_background(self);
}

- (void)setTokenBackgroundColor:(UIColor *)tokenBackgroundColor
{
    revenant_field_set_token_background(self, tokenBackgroundColor);
}

- (BOOL)allowsDeletingTokens
{
    return revenant_field_allows_deleting(self);
}

- (void)setAllowsDeletingTokens:(BOOL)allowsDeletingTokens
{
    revenant_field_set_allows_deleting(self, allowsDeletingTokens);
}

- (BOOL)allowsCopyingTokens
{
    return revenant_field_allows_copying(self);
}

- (void)setAllowsCopyingTokens:(BOOL)allowsCopyingTokens
{
    revenant_field_set_allows_copying(self, allowsCopyingTokens);
}

- (void)deleteBackward
{
    if (!revenant_field_delete_last_token(self) && [UITextField instancesRespondToSelector:@selector(deleteBackward)])
        [super deleteBackward];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    revenant_field_layout_chips(self);
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
    return revenant_shifted([super textRectForBounds:bounds], self);
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return revenant_shifted([super editingRectForBounds:bounds], self);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return revenant_shifted([super placeholderRectForBounds:bounds], self);
}

@end
