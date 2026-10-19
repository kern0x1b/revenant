// MKPointOfInterestFilter: what a map shows besides its roads, of iOS 13.4. MKIconStyle and
// MKMapFeatureAnnotation, which iOS 16.0 added, are in MKIconStyle160.m.
//
// A filter is a set of two lists -- the categories included and the categories excluded -- and the
// two agree with each other: a category that is in both is not in the filter, and a category that
// is in neither is in it, which is what including all categories means. The categories themselves
// are the strings Apple's own map uses (MKPointOfInterestCategoryAirport is "airport"), named by the
// constants of the same framework, so a filter built here compares equal to one built anywhere
// else. The category strings are in their own object file, MKPointOfInterestCategories134.m, measured
// out of a release cache.
#import <MapKit/MapKit.h>
#import <MapKit/MKPointOfInterestFilter.h>

// The two lists the iOS 13 header declares and the 16.4 one does not: the categories a filter
// includes and the categories it excludes, and nil for either is "no opinion on that end".
@interface MKPointOfInterestFilter ()
@property (nonatomic, copy) NSSet<MKPointOfInterestCategory> *includingCategories;
@property (nonatomic, copy) NSSet<MKPointOfInterestCategory> *excludingCategories;
@end

@implementation MKPointOfInterestFilter {
    NSSet<MKPointOfInterestCategory> *_includingCategories;
    NSSet<MKPointOfInterestCategory> *_excludingCategories;
}

@synthesize includingCategories = _includingCategories;
@synthesize excludingCategories = _excludingCategories;

// A filter that includes no category and excludes none is the filter of a map that shows every
// point of interest, which is the release's own map: iOS 6's map view has no category to hide.
+ (instancetype)filterIncludingAllCategories
{
    return [[[self alloc] init] charon_setIncluding:nil excluding:nil];
}

+ (instancetype)filterExcludingAllCategories
{
    return [[[self alloc] init] charon_setIncluding:nil excluding:nil];
}

- (instancetype)initIncludingCategories:(NSSet<MKPointOfInterestCategory> *)categories
{
    self = [super init];
    if (self) {
        [self charon_setIncluding:categories excluding:nil];
    }
    return self;
}

- (instancetype)initExcludingCategories:(NSSet<MKPointOfInterestCategory> *)categories
{
    self = [super init];
    if (self) {
        [self charon_setIncluding:nil excluding:categories];
    }
    return self;
}

- (instancetype)charon_setIncluding:(NSSet<MKPointOfInterestCategory> *)including
                           excluding:(NSSet<MKPointOfInterestCategory> *)excluding
{
    _includingCategories = [including copy];
    _excludingCategories = [excluding copy];
    return self;
}

- (BOOL)includesCategory:(MKPointOfInterestCategory)category
{
    if (!category) {
        return NO;
    }
    if (_excludingCategories && [_excludingCategories containsObject:category]) {
        return NO;
    }
    if (!_includingCategories) {
        return YES;
    }
    return [_includingCategories containsObject:category];
}

- (BOOL)excludesCategory:(MKPointOfInterestCategory)category
{
    if (!category) {
        return NO;
    }
    if (_excludingCategories && [_excludingCategories containsObject:category]) {
        return YES;
    }
    if (!_includingCategories) {
        return NO;
    }
    return ![_includingCategories containsObject:category];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[MKPointOfInterestFilter class]]) {
        return NO;
    }
    MKPointOfInterestFilter *filter = other;
    return filter.includingCategories == _includingCategories && filter.excludingCategories == _excludingCategories;
}

- (NSUInteger)hash
{
    return _includingCategories.hash ^ _excludingCategories.hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MKPointOfInterestFilter *copy = [[[self class] allocWithZone:zone] initIncludingCategories:_includingCategories];
    [copy charon_setIncluding:_includingCategories excluding:_excludingCategories];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_includingCategories forKey:@"MKPointOfInterestFilterIncludingCategories"];
    [coder encodeObject:_excludingCategories forKey:@"MKPointOfInterestFilterExcludingCategories"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        [self charon_setIncluding:[coder decodeObjectForKey:@"MKPointOfInterestFilterIncludingCategories"]
                        excluding:[coder decodeObjectForKey:@"MKPointOfInterestFilterExcludingCategories"]];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
