// MKLocalSearchCompleter: what a program shows while the user types.
//
// The release has MKLocalSearch itself -- apple.dyld's first_releases puts MKLocalSearch,
// MKLocalSearchRequest and MKLocalSearchResponse at 6.1, and its own MKLocalSearchRequest carries
// -naturalLanguageQuery and -region and its own MKLocalSearch carries -initWithRequest:,
// -startWithCompletionHandler:, -cancel and -isSearching (all measured with apple.objc.inventory on
// the armv7 cache of 6.1.3). So the search behind every completion here is Apple's own search running
// on the release, and this file is only what the release has no answer for: the debounce, the
// cancellation, the result list and the delegate message.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "CharonMapKit.h"

// How long a keystroke has to be quiet before the search runs, in seconds. Apple's own is a fraction
// of a second; a network search on this release is slower, so the pause is longer and the user is
// not billed for every letter.
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

// The pause, then the search. The pause is a timer on the main run loop, which is where a
// user-driven search belongs, and a new fragment cancels the one before it, so only the last of a
// burst of keystrokes is searched for. Charon's own, so it carries no API.
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
        // Required means the answer has to be inside the region, and the release's own request takes
        // one through -setRegion:, which is the only way it has. Priority 0 is the header's own
        // MKLocalSearchRegionPriorityDefault, where the region is a hint.
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
            // A search that came back with NOTHING is not a failure to Apple's own completer, and the
            // host says so: measured on the host, a query that finds nothing gives
            //   call 1: completerDidUpdateResults: results=0
            // and NO didFailWithError at all. So this port sends the update message with an empty
            // list and nothing else, which is what the host does, and the failure message is
            // reserved for a search that could not be run at all.
            (void)error;
            strong->_searching = NO;
            [strong charon_finishWithResults:@[]];
            return;
        }
        [strong charon_finishWithResults:[strong charon_completionsOf:response forFragment:fragment]];
    }];
}

// One completion per map item the release's own search found, with the header's own highlight
// ranges: the part of the title that matched what the user typed, in the release's own UTF-16 range
// and wrapped in an NSValue, as the SDK's own header documents. Charon's own, so it carries no API.
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

// A place's own name, out of the release's own map item and its own placemark, which is where the
// release's search puts what it found. Charon's own, so it carries no API.
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
    // The release's own placemark, whose address lines are what the release's own search put there.
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
    // ONE place hands the delegate its answer, for a finished search and for an empty one alike, so the
    // two cannot drift apart and there is a single point the host differential can mutate.
    [self charon_delegateDidUpdate];
}

// (1) The update message, DEFINED on the class. It was called but never defined -- which is exactly
// what the host probe found at run time, and why the port's side of the differential could not run.
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
    // The header's own deprecated spelling of resultTypes: locations only is the address bit alone,
    // and locations and queries is every bit the release's own search can answer.
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

// The two iOS 18 properties: how hard the region matters (0 default, 1 required, which is what the
// header's own MKLocalSearchRegionPriority says), and which parts of an address the search is about.
// Both send the completer back to its search, which is the release's own.
// A category cannot add an ivar, so the two values are held beside the object, and the class reads
// them through these accessors, which is where they are written. Charon's own, so it carries no API.
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
