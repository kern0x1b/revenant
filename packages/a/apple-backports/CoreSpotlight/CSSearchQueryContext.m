#import <CoreSpotlight/CoreSpotlight.h>

@implementation CSSearchQueryContext

@synthesize fetchAttributes = _fetchAttributes;
@synthesize filterQueries = _filterQueries;
@synthesize keyboardLanguage = _keyboardLanguage;
@synthesize sourceOptions = _sourceOptions;

// The host starts with no attributes to fetch, an empty list, and no filter queries, nil. A nil list of attributes
// is stored as the empty list; a nil filter list is stored as nil, which its copy attribute gives on its own.
// Nothing else is coerced: the keyboard language is kept as given, and sourceOptions is the value written.
- (instancetype)init
{
    if ((self = [super init])) {
        _fetchAttributes = @[];
    }
    return self;
}

- (void)setFetchAttributes:(NSArray<NSString *> *)fetchAttributes
{
    _fetchAttributes = fetchAttributes ?: @[];
}

- (void)setFilterQueries:(NSArray<NSString *> *)filterQueries
{
    _filterQueries = [filterQueries copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    CSSearchQueryContext *copy = [[CSSearchQueryContext allocWithZone:zone] init];
    copy.fetchAttributes = self.fetchAttributes;
    copy.filterQueries = self.filterQueries;
    copy.keyboardLanguage = self.keyboardLanguage;
    copy.sourceOptions = self.sourceOptions;
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        self.fetchAttributes = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:@"fetchAttributes"];
        self.filterQueries = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:@"filterQueries"];
        _keyboardLanguage = [coder decodeObjectOfClass:[NSString class] forKey:@"keyboardLanguage"];
        _sourceOptions = (CSSearchQuerySourceOptions)[coder decodeIntegerForKey:@"sourceOptions"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.fetchAttributes forKey:@"fetchAttributes"];
    [coder encodeObject:self.filterQueries forKey:@"filterQueries"];
    [coder encodeObject:self.keyboardLanguage forKey:@"keyboardLanguage"];
    [coder encodeInteger:(NSInteger)self.sourceOptions forKey:@"sourceOptions"];
}

@end
