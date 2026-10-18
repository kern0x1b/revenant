#import <CoreSpotlight/CoreSpotlight.h>

// The host's copy keeps three of the five subclass properties and returns the subclass; the other two come back as their
// initial values. Coding keeps none of them, so a decoded context reads zero for all five, which is what the host answers.
@implementation CSUserQueryContext
{
    BOOL _enableRankedResults;
    BOOL _disableSemanticSearch;
    NSInteger _maxResultCount;
    NSInteger _maxSuggestionCount;
    NSInteger _maxRankedResultCount;
}

@synthesize enableRankedResults = _enableRankedResults;
@synthesize disableSemanticSearch = _disableSemanticSearch;
@synthesize maxResultCount = _maxResultCount;
@synthesize maxSuggestionCount = _maxSuggestionCount;
@synthesize maxRankedResultCount = _maxRankedResultCount;

// The defaults are set by the factories: a context from init or from coding reads zero for the subclass's properties.
+ (CSUserQueryContext *)userQueryContext
{
    CSUserQueryContext *context = [[CSUserQueryContext alloc] init];
    context->_maxRankedResultCount = 100;
    return context;
}

// With no suggestion, the host's factory sets the maximum suggestion count to 10 (measured). A non-nil suggestion is not
// measured: a CSSuggestion only comes from a user query, which this port does not answer with suggestions (registry row).
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

// Coding keeps disableSemanticSearch and no other subclass property: a decoded context reads zero for the rest.
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
