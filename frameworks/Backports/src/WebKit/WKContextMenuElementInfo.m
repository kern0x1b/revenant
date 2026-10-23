#import <WebKit/WebKit.h>

@implementation WKContextMenuElementInfo {
    NSURL *_linkURL;
}

- (NSURL *)linkURL
{
    return _linkURL;
}

@end
