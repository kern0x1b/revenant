#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* The two members of a user activity that are the activity's own: the URL it came from, and the
   identifier that keeps it the same activity across a save. NSUserActivity.m declares both @dynamic
   and implements neither, which is the shape the ledger reads as missing, and they are here.

   The referrer is the URL the activity arrived from, kept as it is set. The persistent identifier is
   the string that names this activity in a store; the port does not keep a store of its own (the
   release's Handoff daemon has the only one there is, and no entry point of it reaches an
   application), so the identifier is kept per activity and handed back unchanged, which is the whole
   of what the property promises on this release. */

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
