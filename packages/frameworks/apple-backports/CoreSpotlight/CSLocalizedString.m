#import <CoreSpotlight/CoreSpotlight.h>

static NSString *const RevenantLocalizedNoMatch = @"revenant.no-match";

static NSString *RevenantLocalizedAnswer(NSArray *probe, NSArray *preferences)
{
    NSString *answer = [[NSBundle preferredLocalizationsFromArray:probe forPreferences:preferences] firstObject];
    return [answer isEqualToString:RevenantLocalizedNoMatch] ? nil : answer;
}

static NSString *RevenantLocalizedValue(NSDictionary *localizedStrings)
{
    if (localizedStrings.count == 0)
        return nil;
    NSArray *keys = [[localizedStrings keyEnumerator] allObjects];
    NSMutableArray *probe = [NSMutableArray arrayWithObject:RevenantLocalizedNoMatch];
    [probe addObjectsFromArray:keys];
    NSArray *preferences = [[NSUserDefaults standardUserDefaults] arrayForKey:@"AppleLanguages"] ?: @[];
    NSString *answer = RevenantLocalizedAnswer(probe, preferences);
    if (!answer)
        answer = keys[0];
    return localizedStrings[answer];
}

@implementation CSLocalizedString {
    NSDictionary *_localizedStrings;
}

- (instancetype)initWithLocalizedStrings:(NSDictionary *)localizedStrings
{
    if ((self = [super init])) {
        _localizedStrings = [localizedStrings copy];
    }
    return self;
}

- (NSString *)localizedString
{
    return RevenantLocalizedValue(_localizedStrings);
}

- (NSUInteger)length
{
    return [self.localizedString length];
}

- (unichar)characterAtIndex:(NSUInteger)index
{
    return [self.localizedString characterAtIndex:index];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[CSLocalizedString allocWithZone:zone] initWithLocalizedStrings:_localizedStrings];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [(self.localizedString ?: @"") mutableCopyWithZone:zone];
}

- (id)replacementObjectForKeyedArchiver:(NSKeyedArchiver *)archiver
{
    return self.localizedString ?: @"";
}

@end
