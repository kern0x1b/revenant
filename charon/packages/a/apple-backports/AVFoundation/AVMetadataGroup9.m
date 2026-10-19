#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

// The metadata groups, iOS 9.
//
// A group is a list of metadata items over a CMTimeRange, and the two families here are the same
// thing with a different name for where the range comes from:
//
//   AVMetadataGroup             the range it was built with
//   AVDateRangeMetadataGroup    between two NSDate, which is what a QuickTime range metadata group
//                               carries; a nil end date means the range is still open
//
// **AVTimedMetadataGroup is NOT in this file and the measurement is why.** The held caches say the
// 4.3 armv7 release already exports `_OBJC_CLASS_$_AVTimedMetadataGroup` and its metaclass, and
// nothing earlier in the ladder does - so the release has the class on every band this port builds
// for, and a port that DEFINES it is a class shadowing a release's. That is the same failure release
// -split reported on the object this file used to hold ("mix more than one release's symbols": the
// timed groups at 4.3 beside the rest at 9.0), and the fix is not a split but a category: the two
// members the corpus carries go in AVTimedMetadataGroup4.m, on the release's class.
//
// The empty range is the one the framework answers for a group with no items and no range: measured on
// the host, -timeRange of a freshly built AVTimedMetadataGroup is {{INVALID}, {INVALID}}, and that is
// what a group answers before it is given one.

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

// The header's 9.3 pair. Neither is an absent corpus row, and neither is a claim this port can make:
// a unique id is issued by the asset's reader, and a classifying label by the type of the group, so
// with no reader there is no id to hand back and no label to classify. nil for both is what the header
// says for "none", and it is the honest answer here rather than a number that would read as one.
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

// The header's 9.0 factory, kept under its own name because it is the header's and not the port's.
+ (instancetype)dateRangeGroupWithItems:(NSArray<AVMetadataItem *> *)items
{
    // With no dates to read from the items, the range is open: Apple's own answer for a group built
    // from items that carry no range is the invalid range, and the dates are nil.
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
