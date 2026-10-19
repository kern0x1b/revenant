#import "CharonMenus.h"

@interface UISearchToken (CharonSearch)
- (instancetype)initCharonWithIcon:(UIImage *)icon text:(NSString *)text;
- (NSString *)charon_text;
- (UIImage *)charon_icon;
@end

NSArray *charon_field_tokens(UITextField *field);
void charon_field_set_tokens(UITextField *field, NSArray *tokens);
void charon_field_insert_token(UITextField *field, UISearchToken *token, NSInteger index);
void charon_field_remove_token(UITextField *field, NSInteger index);
UITextPosition *charon_field_position_of_token(UITextField *field, NSInteger index);
NSArray *charon_field_tokens_in_range(UITextField *field, UITextRange *range);
UITextRange *charon_field_textual_range(UITextField *field);
void charon_field_replace_textual_portion(UITextField *field, UITextRange *range, UISearchToken *token, NSUInteger index);
UIColor *charon_field_token_background(UITextField *field);
void charon_field_set_token_background(UITextField *field, UIColor *color);
BOOL charon_field_allows_deleting(UITextField *field);
void charon_field_set_allows_deleting(UITextField *field, BOOL allows);
BOOL charon_field_allows_copying(UITextField *field);
void charon_field_set_allows_copying(UITextField *field, BOOL allows);
BOOL charon_field_delete_last_token(UITextField *field);
CGFloat charon_field_prefix_width(UITextField *field);
void charon_field_layout_chips(UITextField *field);
