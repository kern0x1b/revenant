#import <Foundation/Foundation.h>

NSString *revenant_url_compose(NSURLComponents *components, NSRange *ranges);

@implementation NSURLComponents (RevenantString)

- (NSString *)string
{
    return revenant_url_compose(self, NULL);
}

@end
