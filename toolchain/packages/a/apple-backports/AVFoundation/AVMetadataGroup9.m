#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

@interface AVMetadataGroup ()
@property (nonatomic, copy) NSArray<AVMetadataItem *> *charonItems;
@property (nonatomic) CMTimeRange charonTimeRange;
@end

@implementation AVMetadataGroup

@synthesize charonItems = _charonItems;
@synthesize charonTimeRange = _charonTimeRange;

- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _charonItems = [items copy] ?: @[];
        _charonTimeRange = timeRange;
    }
    return self;
}

- (NSArray<AVMetadataItem *> *)items
{
    return self.charonItems ?: @[];
}

- (CMTimeRange)timeRange
{
    return self.charonTimeRange;
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
    return [[[self class] alloc] charon_initWithItems:self.charonItems timeRange:self.charonTimeRange];
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
@property (nonatomic, copy) NSDate *charonStartDate;
@property (nonatomic, copy) NSDate *charonEndDate;
@end

@implementation AVDateRangeMetadataGroup

@synthesize charonStartDate = _charonStartDate;
@synthesize charonEndDate = _charonEndDate;

- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        self.charonItems = items;
        _charonStartDate = [startDate copy];
        _charonEndDate = [endDate copy];
    }
    return self;
}

+ (instancetype)dateRangeGroupWithItems:(NSArray<AVMetadataItem *> *)items
{
    return [[self alloc] charon_initWithItems:items startDate:nil endDate:nil];
}

- (NSDate *)startDate
{
    return self.charonStartDate;
}

- (NSDate *)endDate
{
    return self.charonEndDate;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] charon_initWithItems:self.charonItems
                                            startDate:self.charonStartDate
                                              endDate:self.charonEndDate];
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
    self.charonStartDate = startDate;
}

- (NSDate *)startDate
{
    return self.charonStartDate;
}

- (void)setEndDate:(NSDate *)endDate
{
    self.charonEndDate = endDate;
}

- (NSDate *)endDate
{
    return self.charonEndDate;
}

- (void)setItems:(NSArray<AVMetadataItem *> *)items
{
    self.charonItems = items;
}

- (NSArray<AVMetadataItem *> *)items
{
    return self.charonItems ?: @[];
}

@end
