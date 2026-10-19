#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const char revenant_service_peer_key;
static const char revenant_browser_peer_key;

@implementation NSNetService (RevenantPeerToPeer)

- (BOOL)includesPeerToPeer
{
    return [objc_getAssociatedObject(self, &revenant_service_peer_key) boolValue];
}

- (void)setIncludesPeerToPeer:(BOOL)includesPeerToPeer
{
    objc_setAssociatedObject(self, &revenant_service_peer_key, @(includesPeerToPeer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation NSNetServiceBrowser (RevenantPeerToPeer)

- (BOOL)includesPeerToPeer
{
    return [objc_getAssociatedObject(self, &revenant_browser_peer_key) boolValue];
}

- (void)setIncludesPeerToPeer:(BOOL)includesPeerToPeer
{
    objc_setAssociatedObject(self, &revenant_browser_peer_key, @(includesPeerToPeer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
