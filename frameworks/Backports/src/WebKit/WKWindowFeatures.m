#if defined(REVENANT_HOST_BUILD)
#define WKWindowFeatures WKWindowFeaturesRevenant
#endif

#import <WebKit/WebKit.h>

@implementation WKWindowFeatures

- (NSNumber *)menuBarVisibility
{
    return nil;
}

- (NSNumber *)statusBarVisibility
{
    return nil;
}

- (NSNumber *)toolbarsVisibility
{
    return nil;
}

- (NSNumber *)allowsResizing
{
    return nil;
}

- (NSNumber *)x
{
    return nil;
}

- (NSNumber *)y
{
    return nil;
}

- (NSNumber *)width
{
    return nil;
}

- (NSNumber *)height
{
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
