#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

// The members of AVMetadataItem and AVMutableMetadataItem that arrived in iOS 7, 8 and 9.
//
// The classes themselves are on the release: the port's own 8.0 file, AVMetadataItem+Identifiers8.m,
// reads -key, -value, -keySpace and -locale off an AVMetadataItem without defining any of them, which
// is the evidence that they are the release's own. So these are added as a category, the way that file
// is, and the storage they need is attached rather than ivar'd, for the same reason that file uses
// objc_setAssociatedObject: a class that belongs to the release is not the port's to add ivars to.
//
// The three class methods and the two startDate properties are the corpus rows. Two of the three
// filters read the item's identifier, which the 8.0 file already computes from the item's key and key
// space, so the filters here are written in terms of that and not a second copy of the key arithmetic.

// The date a group of this item begins at, on the item itself rather than on the group that holds it.
// Stored as an associated object so that both the immutable and the mutable class answer it from one
// place and cannot disagree.
static const void *CharonAVMetadataStartDateKey = &CharonAVMetadataStartDateKey;

static NSDate *CharonAVMetadataStartDate(id item)
{
    return objc_getAssociatedObject(item, CharonAVMetadataStartDateKey);
}

// The identifier of an item, read through the port's own 8.0 member so there is one implementation of
// it. A nil identifier means the item has no key and no key space, and then no filter can match it.
static AVMetadataIdentifier CharonAVMetadataItemIdentifier(AVMetadataItem *item)
{
    return [item identifier];
}

@implementation AVMetadataItem (CharonAVMetadataStart9)

- (NSDate *)startDate
{
    return CharonAVMetadataStartDate(self);
}

@end

@implementation AVMutableMetadataItem (CharonAVMetadataStart9)

- (NSDate *)startDate
{
    return CharonAVMetadataStartDate(self);
}

- (void)setStartDate:(NSDate *)startDate
{
    objc_setAssociatedObject(self, CharonAVMetadataStartDateKey, startDate, OBJC_ASSOCIATION_COPY);
}

@end

@implementation AVMetadataItem (CharonAVMetadataFilters7)

+ (NSArray<AVMetadataItem *> *)metadataItemsFromArray:(NSArray<AVMetadataItem *> *)items
                       filteredByMetadataItemFilter:(AVMetadataItemFilter *)filter
{
    if (!items) {
        return nil;
    }
    NSArray<AVMetadataIdentifier> *wanted = filter.identifiers;
    NSMutableArray<AVMetadataItem *> *kept = [NSMutableArray arrayWithCapacity:items.count];
    for (AVMetadataItem *item in items) {
        AVMetadataIdentifier identifier = CharonAVMetadataItemIdentifier(item);
        // A filter with no identifiers keeps everything, which is what an empty allow list means: the
        // header's own +metadataItemFilterForSharing answers one, and a caller that hands that filter
        // here wants the whole array, not nothing.
        if (!wanted.count || [wanted containsObject:identifier]) {
            [kept addObject:item];
        }
    }
    return kept;
}

+ (NSArray<AVMetadataItem *> *)metadataItemsFromArray:(NSArray<AVMetadataItem *> *)items
                          filteredByIdentifier:(AVMetadataIdentifier)identifier
{
    if (!items) {
        return nil;
    }
    if (!identifier) {
        return [items copy];
    }
    NSMutableArray<AVMetadataItem *> *kept = [NSMutableArray arrayWithCapacity:items.count];
    for (AVMetadataItem *item in items) {
        if ([CharonAVMetadataItemIdentifier(item) isEqualToString:identifier]) {
            [kept addObject:item];
        }
    }
    return kept;
}

// The 9.0 member: a new item holding the named properties of a source item. The properties are read
// through the value-loading handler the caller supplies, which is how the header says they are read -
// the value of an item may be waiting on an asset, and the handler is how a caller gets at it without
// this method having a loader. The new item is an AVMutableMetadataItem, the only class the header
// lets a caller fill in.
+ (AVMetadataItem *)metadataItemWithPropertiesOfMetadataItem:(AVMetadataItem *)item
                                     valueLoadingHandler:(void (^)(id<AVAsynchronousKeyValueLoading> obj,
                                                                NSString *key, id *outValue))handler
{
    if (!item) {
        return nil;
    }
    AVMutableMetadataItem *made = [AVMutableMetadataItem metadataItem];
    if (!made) {
        return nil;
    }
    // The three properties the 9.0 method names, and nothing else: an item's identifier, locale and
    // time are what a consumer reads, and copying a whole item's value here would pull in an asset the
    // caller did not ask for.
    if (item.identifier) {
        made.identifier = item.identifier;
    }
    if (item.locale) {
        made.locale = item.locale;
    }
    if (handler) {
        // Spelled through the protocol the SDK forward-declares: the bare name is not a type here.
        void (^reading)(id<AVAsynchronousKeyValueLoading>, NSString *, id *) = handler;
        id value = nil;
        reading((id<AVAsynchronousKeyValueLoading>)item, @"value", &value);
        if ([value conformsToProtocol:@protocol(NSCopying)]) {
            made.value = value;
        }
    }
    return made;
}

@end
