#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "CharonMapKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKLocalSearchRequest (CharonOptions)
@property (nonatomic, copy, nullable) MKAddressFilter *addressFilter;
@property (nonatomic, assign) NSInteger regionPriority;
@end

@interface MKLocalSearchRequest (CharonResultTypes)
@property (nonatomic, assign) MKLocalSearchResultType resultTypes;
@property (nonatomic, copy, nullable) MKPointOfInterestFilter *pointOfInterestFilter;
@end

#if !CHARON_HOST_PROBE
@interface MKLocalSearchRequest (CharonRequest)
- (instancetype)initWithNaturalLanguageQuery:(NSString *)query
                                      region:(MKCoordinateRegion)region;
- (instancetype)initWithCompletion:(void (^)(MKLocalSearchResponse *response, NSError *error))completionHandler;
@end

@interface MKLocalSearch (CharonRequest)
- (instancetype)initWithPointsOfInterestRequest:(id)request;
@end
#endif

@implementation MKLocalSearchRequest (CharonRequest)

static id CharonRequestInit(MKLocalSearchRequest *request, NSString *query)
{
    request = [request init];
    [request setNaturalLanguageQuery:query];
    return request;
}

- (instancetype)initWithNaturalLanguageQuery:(NSString *)query
{
    self = CharonRequestInit(self, query);
    if (self) {
        [self setRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0), MKCoordinateSpanMake(180.0, 360.0))];
    }
    return self;
}

- (instancetype)initWithNaturalLanguageQuery:(NSString *)query region:(MKCoordinateRegion)region
{
    self = CharonRequestInit(self, query);
    if (self) {
        [self setRegion:region];
    }
    return self;
}

- (instancetype)initWithCompletion:(MKLocalSearchCompletion *)completion
{
    self = CharonRequestInit(self, @"");
    if (self) {
        objc_setAssociatedObject(self, (const void *)"charonFinishedCompletion", completion,
                                 OBJC_ASSOCIATION_RETAIN);
    }
    return self;
}

- (nullable MKLocalSearchCompletion *)charon_finishedCompletion
{
    return objc_getAssociatedObject(self, (const void *)"charonFinishedCompletion");
}

#if !CHARON_HOST_PROBE
- (void)setAddressFilter:(nullable MKAddressFilter *)filter
{
    objc_setAssociatedObject(self, (const void *)"charonAddressFilter", filter,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (nullable MKAddressFilter *)addressFilter
{
    return objc_getAssociatedObject(self, (const void *)"charonAddressFilter");
}

- (void)setRegionPriority:(NSInteger)regionPriority
{
    objc_setAssociatedObject(self, (const void *)"charonRegionPriority",
                             [NSNumber numberWithInteger:regionPriority], OBJC_ASSOCIATION_RETAIN);
}

- (NSInteger)regionPriority
{
    id value = objc_getAssociatedObject(self, (const void *)"charonRegionPriority");
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

#endif
- (void)setResultTypes:(MKLocalSearchResultType)resultTypes
{
    objc_setAssociatedObject(self, (const void *)"charonResultTypes",
                             [NSNumber numberWithUnsignedInteger:resultTypes], OBJC_ASSOCIATION_RETAIN);
}

- (MKLocalSearchResultType)resultTypes
{
    id value = objc_getAssociatedObject(self, (const void *)"charonResultTypes");
    return [value isKindOfClass:[NSNumber class]]
        ? (MKLocalSearchResultType)[value unsignedIntegerValue]
        : (MKLocalSearchResultType)(MKLocalSearchResultTypeAddress | MKLocalSearchResultTypePointOfInterest);
}

- (void)setPointOfInterestFilter:(nullable MKPointOfInterestFilter *)filter
{
    objc_setAssociatedObject(self, (const void *)"charonPointOfInterestFilter", filter,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (nullable MKPointOfInterestFilter *)pointOfInterestFilter
{
    return objc_getAssociatedObject(self, (const void *)"charonPointOfInterestFilter");
}

- (BOOL)charon_resultTypesIncludeItemOfCategory:(nullable NSString *)category
{
    MKLocalSearchResultType types = [self resultTypes];
    if ((types & (MKLocalSearchResultTypeAddress | MKLocalSearchResultTypePointOfInterest)) == 0) {
        return NO;
    }
    if (category == nil) {
        return (types & MKLocalSearchResultTypeAddress) != 0;
    }
    return (types & MKLocalSearchResultTypePointOfInterest) != 0;
}

- (BOOL)charon_pointOfInterestFilterIncludesItemOfCategory:(NSString *)category
{
    MKPointOfInterestFilter *filter = [self pointOfInterestFilter];
    if (filter == nil) {
        return YES;
    }
    return [filter includesCategory:category];
}

@end

@implementation MKLocalSearch (CharonRequest)

- (instancetype)initWithPointsOfInterestRequest:(id)request
{
    MKLocalSearchRequest *empty = CharonRequestInit([MKLocalSearchRequest alloc], @"");
    self = [self initWithRequest:empty];
    (void)request;
    return self;
}

@end

NS_ASSUME_NONNULL_END
