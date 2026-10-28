#if defined(REVENANT_HOST_BUILD)
#define WKSecurityOrigin WKSecurityOriginRevenant
#endif

#import <WebKit/WebKit.h>

@implementation WKSecurityOrigin {
    NSString *_protocol;
    NSString *_host;
    NSInteger _port;
}

+ (instancetype)revenant_originWithURL:(NSURL *)url
{
    WKSecurityOrigin *origin = [self alloc];
    origin->_protocol = [url.scheme lowercaseString] ?: @"";
    origin->_host = [url.host lowercaseString] ?: @"";
    origin->_port = url.port ? url.port.integerValue : 0;
    return origin;
}

- (NSString *)protocol
{
    return _protocol;
}

- (NSString *)host
{
    return _host;
}

- (NSInteger)port
{
    return _port;
}

@end
