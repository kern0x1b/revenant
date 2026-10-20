#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantUserActivityReferrerKey;
static char RevenantUserActivityIdentifierKey;

@implementation NSUserActivity (RevenantIdentity)

- (NSURL *)referrerURL
{
    return objc_getAssociatedObject(self, &RevenantUserActivityReferrerKey);
}

- (void)setReferrerURL:(NSURL *)referrerURL
{
    objc_setAssociatedObject(self, &RevenantUserActivityReferrerKey, referrerURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUserActivityPersistentIdentifier)persistentIdentifier
{
    return objc_getAssociatedObject(self, &RevenantUserActivityIdentifierKey);
}

- (void)setPersistentIdentifier:(NSUserActivityPersistentIdentifier)identifier
{
    objc_setAssociatedObject(self, &RevenantUserActivityIdentifierKey, [identifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
