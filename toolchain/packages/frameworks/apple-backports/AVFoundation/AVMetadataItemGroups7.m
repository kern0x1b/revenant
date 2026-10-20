#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

static const void *RevenantAVMetadataStartDateKey = &RevenantAVMetadataStartDateKey;

static NSDate *RevenantAVMetadataStartDate(id item)
{
    return objc_getAssociatedObject(item, RevenantAVMetadataStartDateKey);
}

static AVMetadataIdentifier RevenantAVMetadataItemIdentifier(AVMetadataItem *item)
{
    return [item identifier];
}

@implementation AVMetadataItem (RevenantAVMetadataStart9)

- (NSDate *)startDate
{
    return RevenantAVMetadataStartDate(self);
}

@end

@implementation AVMutableMetadataItem (RevenantAVMetadataStart9)

- (NSDate *)startDate
{
    return RevenantAVMetadataStartDate(self);
}

- (void)setStartDate:(NSDate *)startDate
{
    objc_setAssociatedObject(self, RevenantAVMetadataStartDateKey, startDate, OBJC_ASSOCIATION_COPY);
}

@end

@implementation AVMetadataItem (RevenantAVMetadataFilters7)

+ (NSArray<AVMetadataItem *> *)metadataItemsFromArray:(NSArray<AVMetadataItem *> *)items
                       filteredByMetadataItemFilter:(AVMetadataItemFilter *)filter
{
    if (!items) {
        return nil;
    }
    NSArray<AVMetadataIdentifier> *wanted = filter.identifiers;
    NSMutableArray<AVMetadataItem *> *kept = [NSMutableArray arrayWithCapacity:items.count];
    for (AVMetadataItem *item in items) {
        AVMetadataIdentifier identifier = RevenantAVMetadataItemIdentifier(item);
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
        if ([RevenantAVMetadataItemIdentifier(item) isEqualToString:identifier]) {
            [kept addObject:item];
        }
    }
    return kept;
}

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
    if (item.identifier) {
        made.identifier = item.identifier;
    }
    if (item.locale) {
        made.locale = item.locale;
    }
    if (handler) {
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
