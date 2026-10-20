#import "RevenantTextContentType.h"

@implementation UISearchBar (RevenantContentType)

- (NSString *)textContentType
{
    return revenant_text_content_type(self);
}

- (void)setTextContentType:(NSString *)textContentType
{
    revenant_set_text_content_type(self, textContentType);
}

@end
