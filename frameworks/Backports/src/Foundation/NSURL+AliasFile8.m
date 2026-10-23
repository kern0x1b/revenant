#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSURL (RevenantAliasFile8)

+ (instancetype)URLByResolvingAliasFileAtURL:(NSURL *)url options:(NSURLBookmarkResolutionOptions)options error:(NSError **)error
{
    if (![url checkResourceIsReachableAndReturnError:error])
        return nil;
    NSNumber *alias = nil;
    if (![url getResourceValue:&alias forKey:NSURLIsAliasFileKey error:error])
        return nil;
    if (!alias.boolValue)
        return url;
    NSData *bookmark = [NSURL bookmarkDataWithContentsOfURL:url error:error];
    if (!bookmark)
        return nil;
    BOOL stale = NO;
    return [NSURL URLByResolvingBookmarkData:bookmark options:options & (NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting) relativeToURL:nil bookmarkDataIsStale:&stale error:error];
}

@end
