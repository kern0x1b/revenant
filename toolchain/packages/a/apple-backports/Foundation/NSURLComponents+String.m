#import <Foundation/Foundation.h>

NSString *charon_url_compose(NSURLComponents *components, NSRange *ranges);

@implementation NSURLComponents (CharonString)

- (NSString *)string
{
    return charon_url_compose(self, NULL);
}

@end
