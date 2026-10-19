#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonUserActivityReferrerKey;
static char CharonUserActivityIdentifierKey;

@implementation NSUserActivity (CharonIdentity)

- (NSURL *)referrerURL
{
    return objc_getAssociatedObject(self, &CharonUserActivityReferrerKey);
}

- (void)setReferrerURL:(NSURL *)referrerURL
{
    objc_setAssociatedObject(self, &CharonUserActivityReferrerKey, referrerURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUserActivityPersistentIdentifier)persistentIdentifier
{
    return objc_getAssociatedObject(self, &CharonUserActivityIdentifierKey);
}

- (void)setPersistentIdentifier:(NSUserActivityPersistentIdentifier)identifier
{
    objc_setAssociatedObject(self, &CharonUserActivityIdentifierKey, [identifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
