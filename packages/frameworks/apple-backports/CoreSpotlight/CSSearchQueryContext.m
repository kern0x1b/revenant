#import <CoreSpotlight/CoreSpotlight.h>

@implementation CSSearchQueryContext

@synthesize fetchAttributes = _fetchAttributes;
@synthesize filterQueries = _filterQueries;
@synthesize keyboardLanguage = _keyboardLanguage;
@synthesize sourceOptions = _sourceOptions;

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
        self.fetchAttributes = [coder decodeObjectForKey:@"fetchAttributes"];
        self.filterQueries = [coder decodeObjectForKey:@"filterQueries"];
        _keyboardLanguage = [coder decodeObjectForKey:@"keyboardLanguage"];
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
