#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "CharonMapKit.h"

static const NSTimeInterval MKCharonCompleterPause = 0.35;

@implementation MKLocalSearchCompleter {
    NSString *_queryFragment;
    MKLocalSearchRegionPriority _regionPriority;
    MKLocalSearchCompleterResultType _resultTypes;
    MKPointOfInterestFilter *_pointOfInterestFilter;
    __weak id<MKLocalSearchCompleterDelegate> _delegate;
    MKCoordinateRegion _region;
    MKLocalSearch *_search;
    NSArray<MKLocalSearchCompletion *> *_results;
    NSTimer *_pause;
    BOOL _searching;
}

@synthesize queryFragment = _queryFragment;
@synthesize resultTypes = _resultTypes;
@synthesize pointOfInterestFilter = _pointOfInterestFilter;
@synthesize delegate = _delegate;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _results = @[];
        _regionPriority = 0;
    }
    return self;
}

- (void)dealloc
{
    [_search cancel];
    [_pause invalidate];
}

- (void)setQueryFragment:(NSString *)queryFragment
{
    _queryFragment = [queryFragment copy];
    [self charon_schedule];
}

- (void)charon_schedule
{
    [_pause invalidate];
    _pause = nil;
    [_search cancel];
    _search = nil;
    NSString *fragment = [_queryFragment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (fragment.length == 0) {
        [self charon_finishWithResults:@[]];
        return;
    }
    _pause = [NSTimer scheduledTimerWithTimeInterval:MKCharonCompleterPause
                                              target:self
                                            selector:@selector(charon_search)
                                            userInfo:fragment
                                             repeats:NO];
}

- (void)charon_search
{
    NSString *fragment = [_pause userInfo];
    _pause = nil;
    if (fragment.length == 0) {
        return;
    }
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    [request setValue:fragment forKey:@"naturalLanguageQuery"];
    if ([self regionPriority] == 1) {
        [request setValue:[NSValue valueWithBytes:&_region objCType:@encode(MKCoordinateRegion)] forKey:@"region"];
    }
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    _search = search;
    _searching = YES;
    __weak MKLocalSearchCompleter *weak = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        MKLocalSearchCompleter *strong = weak;
        if (!strong) {
            return;
        }
        strong->_searching = NO;
        if (error) {
            (void)error;
            strong->_searching = NO;
            [strong charon_finishWithResults:@[]];
            return;
        }
        [strong charon_finishWithResults:[strong charon_completionsOf:response forFragment:fragment]];
    }];
}

- (NSArray<MKLocalSearchCompletion *> *)charon_completionsOf:(MKLocalSearchResponse *)response
                                                forFragment:(NSString *)fragment
{
    NSMutableArray *made = [NSMutableArray array];
    for (MKMapItem *item in response.mapItems) {
        MKLocalSearchCompletion *completion = [[MKLocalSearchCompletion alloc] init];
        NSString *title = [self charon_titleOf:item];
        NSString *subtitle = [self charon_subtitleOf:item];
        [completion setValue:title forKey:@"title"];
        [completion setValue:subtitle forKey:@"subtitle"];
        NSRange found = [title rangeOfString:fragment options:NSCaseInsensitiveSearch];
        if (found.location != NSNotFound) {
            NSValue *wrapped = [NSValue valueWithBytes:&found objCType:@encode(NSRange)];
            [completion setValue:[NSArray arrayWithObject:wrapped] forKey:@"titleHighlightRanges"];
        }
        [made addObject:completion];
    }
    return made;
}

- (NSString *)charon_titleOf:(MKMapItem *)item
{
    NSString *named = [item name];
    if (named.length > 0) {
        return named;
    }
    MKPlacemark *placemark = [item placemark];
    NSString *thoroughfare = placemark.thoroughfare;
    NSString *locality = placemark.locality;
    if (thoroughfare.length > 0 && locality.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", thoroughfare, locality];
    }
    if (thoroughfare.length > 0) {
        return thoroughfare;
    }
    if (locality.length > 0) {
        return locality;
    }
    return placemark.name ?: @"";
}

- (NSString *)charon_subtitleOf:(MKMapItem *)item
{
    MKPlacemark *placemark = [item placemark];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [placemark valueForKey:@"formattedAddressLines"]) {
        if (line.length > 0) {
            [lines addObject:line];
        }
    }
    if (lines.count > 0) {
        return [lines componentsJoinedByString:@", "];
    }
    NSString *locality = placemark.locality;
    NSString *country = placemark.ISOcountryCode;
    if (locality.length > 0 && country.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", locality, country];
    }
    return locality.length > 0 ? locality : (country ?: @"");
}

- (void)charon_finishWithResults:(NSArray<MKLocalSearchCompletion *> *)results
{
    _results = [results copy];
    [self charon_delegateDidUpdate];
}

- (void)charon_delegateDidUpdate
{
    id delegate = self.delegate;
    SEL updated = NSSelectorFromString(@"completerDidUpdateResults:");
    if ([delegate respondsToSelector:updated]) {
        void (*send)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        send(delegate, updated, self);
    }
}

- (void)charon_delegateDidFail:(NSError *)error
{
    id delegate = self.delegate;
    SEL failed = NSSelectorFromString(@"completer:didFailWithError:");
    if ([delegate respondsToSelector:failed]) {
        void (*send)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
        send(delegate, failed, self, error);
    }
}

- (NSArray<MKLocalSearchCompletion *> *)results
{
    return _results;
}

- (BOOL)isSearching
{
    return _searching;
}

- (void)cancel
{
    [_pause invalidate];
    _pause = nil;
    [_search cancel];
    _search = nil;
    _searching = NO;
    [self charon_finishWithResults:@[]];
}

- (MKCoordinateRegion)region
{
    return _region;
}

- (void)setRegion:(MKCoordinateRegion)region
{
    _region = region;
    [self charon_schedule];
}

- (MKLocalSearchCompleterResultType)resultTypes
{
    return _resultTypes;
}

- (void)setResultTypes:(MKLocalSearchCompleterResultType)resultTypes
{
    _resultTypes = resultTypes;
    [self charon_schedule];
}

- (void)setPointOfInterestFilter:(MKPointOfInterestFilter *)pointOfInterestFilter
{
    _pointOfInterestFilter = [pointOfInterestFilter copy];
    [self charon_schedule];
}

- (MKPointOfInterestFilter *)pointOfInterestFilter
{
    return _pointOfInterestFilter;
}

- (void)setFilterType:(MKSearchCompletionFilterType)filterType
{
    _resultTypes = filterType == MKSearchCompletionFilterTypeLocationsOnly
        ? MKLocalSearchCompleterResultTypeAddress
        : (MKLocalSearchCompleterResultTypeAddress | MKLocalSearchCompleterResultTypePointOfInterest |
           MKLocalSearchCompleterResultTypeQuery);
}

- (MKSearchCompletionFilterType)filterType
{
    return _resultTypes == MKLocalSearchCompleterResultTypeAddress
        ? MKSearchCompletionFilterTypeLocationsOnly
        : MKSearchCompletionFilterTypeLocationsAndQueries;
}

@end

@implementation MKLocalSearchCompleter (CharonPriority)

- (NSInteger)charon_priority
{
    return [[objc_getAssociatedObject(self, (const void *)"charonPriority") description] intValue];
}

- (void)charon_setPriority:(NSInteger)priority
{
    objc_setAssociatedObject(self, (const void *)"charonPriority", [NSNumber numberWithInteger:priority],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)regionPriority
{
    return [self charon_priority];
}

- (void)setRegionPriority:(NSInteger)regionPriority
{
    [self charon_setPriority:regionPriority];
    [self charon_schedule];
}

- (MKAddressFilter *)addressFilter
{
    return objc_getAssociatedObject(self, (const void *)"charonAddressFilter");
}

- (void)setAddressFilter:(MKAddressFilter *)addressFilter
{
    objc_setAssociatedObject(self, (const void *)"charonAddressFilter", [addressFilter copy],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self charon_schedule];
}

@end
