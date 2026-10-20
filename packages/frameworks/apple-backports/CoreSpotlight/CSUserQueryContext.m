#import <CoreSpotlight/CoreSpotlight.h>

@implementation CSUserQueryContext
{
    BOOL _enableRankedResults;
    BOOL _disableSemanticSearch;
    NSInteger _maxResultCount;
    NSInteger _maxSuggestionCount;
    NSInteger _maxRankedResultCount;
}

@synthesize enableRankedResults = _enableRankedResults;
@synthesize maxResultCount = _maxResultCount;
@synthesize maxSuggestionCount = _maxSuggestionCount;

- (BOOL)disableSemanticSearch
{
    return _disableSemanticSearch;
}

- (void)setDisableSemanticSearch:(BOOL)disableSemanticSearch
{
    _disableSemanticSearch = disableSemanticSearch;
}

- (NSInteger)maxRankedResultCount
{
    return _maxRankedResultCount;
}

- (void)setMaxRankedResultCount:(NSInteger)maxRankedResultCount
{
    _maxRankedResultCount = maxRankedResultCount;
}

+ (CSUserQueryContext *)userQueryContext
{
    CSUserQueryContext *context = [[CSUserQueryContext alloc] init];
    context->_maxRankedResultCount = 100;
    return context;
}

+ (CSUserQueryContext *)userQueryContextWithCurrentSuggestion:(CSSuggestion *)currentSuggestion
{
    CSUserQueryContext *context = [CSUserQueryContext userQueryContext];
    if (!currentSuggestion)
        context->_maxSuggestionCount = 10;
    return context;
}

- (id)copyWithZone:(NSZone *)zone
{
    CSUserQueryContext *copy = [[CSUserQueryContext allocWithZone:zone] init];
    copy.fetchAttributes = self.fetchAttributes;
    copy.filterQueries = self.filterQueries;
    copy.keyboardLanguage = self.keyboardLanguage;
    copy.sourceOptions = self.sourceOptions;
    copy->_disableSemanticSearch = _disableSemanticSearch;
    copy->_maxSuggestionCount = _maxSuggestionCount;
    copy->_maxRankedResultCount = _maxRankedResultCount;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeBool:_disableSemanticSearch forKey:@"disableSemanticSearch"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _disableSemanticSearch = [coder decodeBoolForKey:@"disableSemanticSearch"];
    }
    return self;
}

@end
