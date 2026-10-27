#if defined(REVENANT_HOST_BUILD)
#define WKOpenPanelParameters WKOpenPanelParametersRevenant
#endif

#import <WebKit/WebKit.h>

// The engine shows no file picker, so it never asks the delegate to open one and no parameters are created.
// The defaults a caller reads are the ones for a single file.
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
