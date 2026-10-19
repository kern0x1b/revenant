#import "CharonTextContentType.h"

@implementation UISearchBar (CharonContentType)

- (NSString *)textContentType
{
    return charon_text_content_type(self);
}

- (void)setTextContentType:(NSString *)textContentType
{
    charon_set_text_content_type(self, textContentType);
}

@end
