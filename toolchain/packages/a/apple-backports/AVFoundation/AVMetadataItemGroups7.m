#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

static const void *CharonAVMetadataStartDateKey = &CharonAVMetadataStartDateKey;

static NSDate *CharonAVMetadataStartDate(id item)
{
    return objc_getAssociatedObject(item, CharonAVMetadataStartDateKey);
}

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
