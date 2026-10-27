#if defined(REVENANT_HOST_BUILD)
#define WKOpenPanelParameters WKOpenPanelParametersRevenant
#endif

#import <WebKit/WebKit.h>

@implementation WKOpenPanelParameters

- (BOOL)allowsMultipleSelection
{
    return NO;
}

- (BOOL)allowsDirectories
{
    return NO;
}

@end
