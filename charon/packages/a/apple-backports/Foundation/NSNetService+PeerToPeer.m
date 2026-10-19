#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const char charon_service_peer_key;
static const char charon_browser_peer_key;

@implementation NSNetService (CharonPeerToPeer)

- (BOOL)includesPeerToPeer
{
    return [objc_getAssociatedObject(self, &charon_service_peer_key) boolValue];
}

- (void)setIncludesPeerToPeer:(BOOL)includesPeerToPeer
{
    objc_setAssociatedObject(self, &charon_service_peer_key, @(includesPeerToPeer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation NSNetServiceBrowser (CharonPeerToPeer)

- (BOOL)includesPeerToPeer
{
    return [objc_getAssociatedObject(self, &charon_browser_peer_key) boolValue];
}

- (void)setIncludesPeerToPeer:(BOOL)includesPeerToPeer
{
    objc_setAssociatedObject(self, &charon_browser_peer_key, @(includesPeerToPeer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
