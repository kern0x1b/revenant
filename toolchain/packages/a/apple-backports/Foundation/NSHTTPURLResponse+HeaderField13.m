#import <Foundation/Foundation.h>

@implementation NSHTTPURLResponse (CharonHeaderField)

- (NSString *)valueForHTTPHeaderField:(NSString *)field
{
    if (![field isKindOfClass:[NSString class]])
        return nil;
    NSDictionary *headers = self.allHeaderFields;
    id exact = headers[field];
    if ([exact isKindOfClass:[NSString class]])
        return exact;
    __block NSString *found = nil;
    NSString *wanted = field.lowercaseString;
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]] && [[key lowercaseString] isEqualToString:wanted]) {
            found = value;
            *stop = YES;
        }
    }];
    return found;
}

@end
