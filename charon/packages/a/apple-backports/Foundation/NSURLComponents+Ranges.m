#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, CharonURLPart) {
    CharonURLScheme,
    CharonURLUser,
    CharonURLPassword,
    CharonURLHost,
    CharonURLPort,
    CharonURLPath,
    CharonURLQuery,
    CharonURLFragment,
    CharonURLPartCount
};

BOOL charon_url_parse(NSString *string, NSRange *ranges);

static NSRange charon_url_range(NSURLComponents *components, CharonURLPart part)
{
    NSRange ranges[CharonURLPartCount];
    NSString *string = components.string;
    if (!string || !charon_url_parse(string, ranges))
        return NSMakeRange(NSNotFound, 0);
    return ranges[part];
}

@implementation NSURLComponents (CharonRanges)

- (NSRange)rangeOfScheme
{
    return charon_url_range(self, CharonURLScheme);
}

- (NSRange)rangeOfUser
{
    return charon_url_range(self, CharonURLUser);
}

- (NSRange)rangeOfPassword
{
    return charon_url_range(self, CharonURLPassword);
}

- (NSRange)rangeOfHost
{
    return charon_url_range(self, CharonURLHost);
}

- (NSRange)rangeOfPort
{
    return charon_url_range(self, CharonURLPort);
}

- (NSRange)rangeOfPath
{
    return charon_url_range(self, CharonURLPath);
}

- (NSRange)rangeOfQuery
{
    return charon_url_range(self, CharonURLQuery);
}

- (NSRange)rangeOfFragment
{
    return charon_url_range(self, CharonURLFragment);
}

@end
