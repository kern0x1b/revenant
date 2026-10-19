#import "RevenantMenus.h"

@interface UISearchToken (RevenantSearch)
- (instancetype)initRevenantWithIcon:(UIImage *)icon text:(NSString *)text;
- (NSString *)revenant_text;
- (UIImage *)revenant_icon;
@end

NSArray *revenant_field_tokens(UITextField *field);
void revenant_field_set_tokens(UITextField *field, NSArray *tokens);
void revenant_field_insert_token(UITextField *field, UISearchToken *token, NSInteger index);
void revenant_field_remove_token(UITextField *field, NSInteger index);
UITextPosition *revenant_field_position_of_token(UITextField *field, NSInteger index);
NSArray *revenant_field_tokens_in_range(UITextField *field, UITextRange *range);
UITextRange *revenant_field_textual_range(UITextField *field);
void revenant_field_replace_textual_portion(UITextField *field, UITextRange *range, UISearchToken *token, NSUInteger index);
UIColor *revenant_field_token_background(UITextField *field);
void revenant_field_set_token_background(UITextField *field, UIColor *color);
BOOL revenant_field_allows_deleting(UITextField *field);
void revenant_field_set_allows_deleting(UITextField *field, BOOL allows);
BOOL revenant_field_allows_copying(UITextField *field);
void revenant_field_set_allows_copying(UITextField *field, BOOL allows);
BOOL revenant_field_delete_last_token(UITextField *field);
CGFloat revenant_field_prefix_width(UITextField *field);
void revenant_field_layout_chips(UITextField *field);
