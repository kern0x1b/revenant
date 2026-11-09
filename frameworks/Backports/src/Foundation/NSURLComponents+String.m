#import <Foundation/Foundation.h>

NSString *revenant_url_compose(NSURLComponents *components, NSRange *ranges);

@interface NSURLComponents (RevenantParsedString)
- (NSString *)revenantParsedString;
@end

@implementation NSURLComponents (RevenantString)

- (NSString *)string
{
    return self.revenantParsedString ?: revenant_url_compose(self, NULL);
}

@end
