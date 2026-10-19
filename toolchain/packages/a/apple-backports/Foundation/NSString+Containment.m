#import <Foundation/Foundation.h>

@implementation NSString (CharonContainment)

- (BOOL)containsString:(NSString *)string
{
    return [self rangeOfString:string].location != NSNotFound;
}

- (BOOL)localizedCaseInsensitiveContainsString:(NSString *)string
{
    return [self rangeOfString:string options:NSCaseInsensitiveSearch range:NSMakeRange(0, self.length) locale:[NSLocale currentLocale]].location != NSNotFound;
}

@end
