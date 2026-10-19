// differential.m - the same program, built once against the host's CoreSpotlight and once against the port's CSUserQueryContext.m
// and CSSearchQueryContext.m. It prints the class and the defaults of a user query context from each factory and from init, the
// effect of setting each subclass property alone on a copy and on a decoded archive, and the superclass properties through a copy.
// Every line must be the same on both sides.
#import <Foundation/Foundation.h>
#import <CoreSpotlight/CoreSpotlight.h>

static void defaults(const char *label, CSUserQueryContext *c)
{
    printf("%s: class=%s ranked=%d semantic=%d maxResult=%ld maxSugg=%ld maxRanked=%ld fetch=%lu filter=%s keyboard=%s\n", label,
           NSStringFromClass([c class]).UTF8String, c.enableRankedResults, c.disableSemanticSearch, (long)c.maxResultCount,
           (long)c.maxSuggestionCount, (long)c.maxRankedResultCount, (unsigned long)c.fetchAttributes.count,
           c.filterQueries ? "set" : "nil", c.keyboardLanguage ? "set" : "nil");
}

static void throughCopyAndArchive(const char *label, CSUserQueryContext *c)
{
    CSUserQueryContext *copy = [c copy];
    CSUserQueryContext *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:c]];
    printf("%s: copy=%s ranked=%d semantic=%d maxResult=%ld maxSugg=%ld maxRanked=%ld | decoded=%s ranked=%d semantic=%d maxResult=%ld maxSugg=%ld maxRanked=%ld\n",
           label, NSStringFromClass([copy class]).UTF8String, copy.enableRankedResults, copy.disableSemanticSearch, (long)copy.maxResultCount,
           (long)copy.maxSuggestionCount, (long)copy.maxRankedResultCount, NSStringFromClass([decoded class]).UTF8String,
           decoded.enableRankedResults, decoded.disableSemanticSearch, (long)decoded.maxResultCount, (long)decoded.maxSuggestionCount,
           (long)decoded.maxRankedResultCount);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        CSUserQueryContext *factory = [CSUserQueryContext userQueryContext];
        defaults("factory", factory);
        defaults("init", [[CSUserQueryContext alloc] init]);
        defaults("withSuggestionNil", [CSUserQueryContext userQueryContextWithCurrentSuggestion:nil]);
        printf("superclass=%s isSearchContext=%d\n", NSStringFromClass([CSUserQueryContext superclass]).UTF8String,
               [factory isKindOfClass:[CSSearchQueryContext class]]);

        CSUserQueryContext *ranked = [CSUserQueryContext userQueryContext];
        ranked.enableRankedResults = YES;
        throughCopyAndArchive("ranked", ranked);
        CSUserQueryContext *semantic = [CSUserQueryContext userQueryContext];
        semantic.disableSemanticSearch = YES;
        throughCopyAndArchive("semantic", semantic);
        CSUserQueryContext *results = [CSUserQueryContext userQueryContext];
        results.maxResultCount = 7;
        throughCopyAndArchive("maxResult", results);
        CSUserQueryContext *suggestions = [CSUserQueryContext userQueryContext];
        suggestions.maxSuggestionCount = 3;
        throughCopyAndArchive("maxSugg", suggestions);
        CSUserQueryContext *rankedCount = [CSUserQueryContext userQueryContext];
        rankedCount.maxRankedResultCount = 5;
        throughCopyAndArchive("maxRanked", rankedCount);

        CSUserQueryContext *inherited = [CSUserQueryContext userQueryContext];
        inherited.fetchAttributes = @[@"title"];
        inherited.filterQueries = @[@"kind == \"x\""];
        inherited.keyboardLanguage = @"en";
        CSUserQueryContext *copy = [inherited copy];
        printf("inherited: copy fetch=%s filter=%s keyboard=%s\n", [[copy.fetchAttributes componentsJoinedByString:@","] UTF8String],
               [[copy.filterQueries componentsJoinedByString:@","] UTF8String], copy.keyboardLanguage.UTF8String);
        printf("identity: equal=%d same=%d\n", [factory isEqual:copy], factory == copy);
    }
    return 0;
}
