#import <Foundation/Foundation.h>

static NSCharacterSet *charon_url_set(NSString *delimiters)
{
    NSString *unreserved = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
    return [NSCharacterSet characterSetWithCharactersInString:[unreserved stringByAppendingString:delimiters]];
}

@implementation NSCharacterSet (CharonURLUtilities)

+ (NSCharacterSet *)URLUserAllowedCharacterSet
{
    static NSCharacterSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = charon_url_set(@"!$&'()*+,;=");
    });
    return set;
}

+ (NSCharacterSet *)URLPasswordAllowedCharacterSet
{
    static NSCharacterSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = charon_url_set(@"!$&'()*+,;=");
    });
    return set;
}

+ (NSCharacterSet *)URLHostAllowedCharacterSet
{
    static NSCharacterSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = charon_url_set(@"!$&'()*+,;=:[]");
    });
    return set;
}

+ (NSCharacterSet *)URLPathAllowedCharacterSet
{
    static NSCharacterSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = charon_url_set(@"!$&'()*+,;=:@/");
    });
    return set;
}

+ (NSCharacterSet *)URLQueryAllowedCharacterSet
{
    static NSCharacterSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = charon_url_set(@"!$&'()*+,;=:@/?");
    });
    return set;
}

+ (NSCharacterSet *)URLFragmentAllowedCharacterSet
{
    static NSCharacterSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = charon_url_set(@"!$&'()*+,;=:@/?");
    });
    return set;
}

@end
