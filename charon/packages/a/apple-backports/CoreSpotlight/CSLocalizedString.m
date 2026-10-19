#import <CoreSpotlight/CoreSpotlight.h>

static NSString *const CharonLocalizedNoMatch = @"charon.no-match";

static NSString *CharonLocalizedAnswer(NSArray *probe, NSArray *preferences)
{
    NSString *answer = [[NSBundle preferredLocalizationsFromArray:probe forPreferences:preferences] firstObject];
    return [answer isEqualToString:CharonLocalizedNoMatch] ? nil : answer;
}

static NSString *CharonLocalizedValue(NSDictionary *localizedStrings)
{
    if (localizedStrings.count == 0)
        return nil;
    NSArray *keys = [[localizedStrings keyEnumerator] allObjects];
    NSMutableArray *probe = [NSMutableArray arrayWithObject:CharonLocalizedNoMatch];
    [probe addObjectsFromArray:keys];
    NSArray *preferences = [[NSUserDefaults standardUserDefaults] arrayForKey:@"AppleLanguages"] ?: @[];
    NSString *answer = CharonLocalizedAnswer(probe, preferences);
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
    return CharonLocalizedValue(_localizedStrings);
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
