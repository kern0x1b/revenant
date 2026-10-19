#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

@interface AVMetadataGroup ()
@property (nonatomic, copy) NSArray<AVMetadataItem *> *revenantItems;
@property (nonatomic) CMTimeRange revenantTimeRange;
@end

@implementation AVMetadataGroup

@synthesize revenantItems = _revenantItems;
@synthesize revenantTimeRange = _revenantTimeRange;

- (instancetype)revenant_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _revenantItems = [items copy] ?: @[];
        _revenantTimeRange = timeRange;
    }
    return self;
}

- (NSArray<AVMetadataItem *> *)items
{
    return self.revenantItems ?: @[];
}

- (CMTimeRange)timeRange
{
    return self.revenantTimeRange;
}

- (NSString *)classifyingLabel
{
    return nil;
}

- (NSString *)uniqueID
{
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] revenant_initWithItems:self.revenantItems timeRange:self.revenantTimeRange];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[AVMetadataGroup class]]) {
        return NO;
    }
    AVMetadataGroup *that = other;
    return [self.items isEqualToArray:that.items] && CMTimeRangeEqual(self.timeRange, that.timeRange);
}

- (NSUInteger)hash
{
    return self.items.hash;
}

@end

@interface AVDateRangeMetadataGroup ()
@property (nonatomic, copy) NSDate *revenantStartDate;
@property (nonatomic, copy) NSDate *revenantEndDate;
@end

@implementation AVDateRangeMetadataGroup

@synthesize revenantStartDate = _revenantStartDate;
@synthesize revenantEndDate = _revenantEndDate;

- (instancetype)revenant_initWithItems:(NSArray<AVMetadataItem *> *)items
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        self.revenantItems = items;
        _revenantStartDate = [startDate copy];
        _revenantEndDate = [endDate copy];
    }
    return self;
}

+ (instancetype)dateRangeGroupWithItems:(NSArray<AVMetadataItem *> *)items
{
    return [[self alloc] revenant_initWithItems:items startDate:nil endDate:nil];
}

- (NSDate *)startDate
{
    return self.revenantStartDate;
}

- (NSDate *)endDate
{
    return self.revenantEndDate;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] revenant_initWithItems:self.revenantItems
                                            startDate:self.revenantStartDate
                                              endDate:self.revenantEndDate];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[AVDateRangeMetadataGroup class]]) {
        return NO;
    }
    AVDateRangeMetadataGroup *that = other;
    BOOL sameStart = (self.startDate == that.startDate) || [self.startDate isEqualToDate:that.startDate];
    BOOL sameEnd = (self.endDate == that.endDate) || [self.endDate isEqualToDate:that.endDate];
    return [self.items isEqualToArray:that.items] && sameStart && sameEnd;
}

- (NSUInteger)hash
{
    return self.items.hash;
}

@end

@implementation AVMutableDateRangeMetadataGroup

- (void)setStartDate:(NSDate *)startDate
{
    self.revenantStartDate = startDate;
}

- (NSDate *)startDate
{
    return self.revenantStartDate;
}

- (void)setEndDate:(NSDate *)endDate
{
    self.revenantEndDate = endDate;
}

- (NSDate *)endDate
{
    return self.revenantEndDate;
}

- (void)setItems:(NSArray<AVMetadataItem *> *)items
{
    self.revenantItems = items;
}

- (NSArray<AVMetadataItem *> *)items
{
    return self.revenantItems ?: @[];
}

@end
