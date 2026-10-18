// The on-disk store CSSearchableIndex.m writes and the search bundle (SearchBundle/
// CharonSearchDatastore.m, built on its own by write_searchbundle in modules/apple/backports.lua)
// reads: one directory per indexing application, each holding plists whose "entries" map a unique
// identifier to a keyed archive of a CSSearchableItem. Both sides include this header so the path
// has one definition.
#define CHARON_SPOTLIGHT_SHARED_ROOT @"/var/mobile/Library/Caches/org.charon.corespotlight"

// The items the default index's store holds, in identifier order: what CSSearchQuery searches. The copy is taken under the
// store's lock, so a change in progress on the index's queue is never read half done.
#import <Foundation/Foundation.h>
@class CSSearchableItem;
NSArray<CSSearchableItem *> *CharonSpotlightDefaultItems(void);
