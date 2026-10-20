#import <MapKit/MapKit.h>
#import <MapKit/MKPointOfInterestFilter.h>

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

+ (instancetype)filterIncludingAllCategories
{
    return [[[self alloc] init] revenant_setIncluding:nil excluding:nil];
}

+ (instancetype)filterExcludingAllCategories
{
    return [[[self alloc] init] revenant_setIncluding:nil excluding:nil];
}

- (instancetype)initIncludingCategories:(NSSet<MKPointOfInterestCategory> *)categories
{
    self = [super init];
    if (self) {
        [self revenant_setIncluding:categories excluding:nil];
    }
    return self;
}

- (instancetype)initExcludingCategories:(NSSet<MKPointOfInterestCategory> *)categories
{
    self = [super init];
    if (self) {
        [self revenant_setIncluding:nil excluding:categories];
    }
    return self;
}

- (instancetype)revenant_setIncluding:(NSSet<MKPointOfInterestCategory> *)including
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
    [copy revenant_setIncluding:_includingCategories excluding:_excludingCategories];
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
        [self revenant_setIncluding:[coder decodeObjectForKey:@"MKPointOfInterestFilterIncludingCategories"]
                        excluding:[coder decodeObjectForKey:@"MKPointOfInterestFilterExcludingCategories"]];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
