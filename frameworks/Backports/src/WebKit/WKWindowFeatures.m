#import "RevenantWebKit.h"

// UIWebView reports no window features, and it never asks the delegate to open a window, so every
// feature a page could request reads as unset.
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
