#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, RevenantURLPart) {
    RevenantURLScheme,
    RevenantURLUser,
    RevenantURLPassword,
    RevenantURLHost,
    RevenantURLPort,
    RevenantURLPath,
    RevenantURLQuery,
    RevenantURLFragment,
    RevenantURLPartCount
};

BOOL revenant_url_parse(NSString *string, NSRange *ranges);

static NSRange revenant_url_range(NSURLComponents *components, RevenantURLPart part)
{
    NSRange ranges[RevenantURLPartCount];
    NSString *string = components.string;
    if (!string || !revenant_url_parse(string, ranges))
        return NSMakeRange(NSNotFound, 0);
    return ranges[part];
}

@implementation NSURLComponents (RevenantRanges)

- (NSRange)rangeOfScheme
{
    return revenant_url_range(self, RevenantURLScheme);
}

- (NSRange)rangeOfUser
{
    return revenant_url_range(self, RevenantURLUser);
}

- (NSRange)rangeOfPassword
{
    return revenant_url_range(self, RevenantURLPassword);
}

- (NSRange)rangeOfHost
{
    return revenant_url_range(self, RevenantURLHost);
}

- (NSRange)rangeOfPort
{
    return revenant_url_range(self, RevenantURLPort);
}

- (NSRange)rangeOfPath
{
    return revenant_url_range(self, RevenantURLPath);
}

- (NSRange)rangeOfQuery
{
    return revenant_url_range(self, RevenantURLQuery);
}

- (NSRange)rangeOfFragment
{
    return revenant_url_range(self, RevenantURLFragment);
}

@end
