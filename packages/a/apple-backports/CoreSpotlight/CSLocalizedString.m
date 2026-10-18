#import <CoreSpotlight/CoreSpotlight.h>

// The matcher answers its first element when no localization matches. The probe is put first in the keys, and it is
// not a language, so an answer of the probe means the matcher matched nothing.
static NSString *const CharonLocalizedNoMatch = @"charon.no-match";

// The first answer of the matcher that is a key, or nil when it answers nothing (the probe comes back).
static NSString *CharonLocalizedAnswer(NSArray *probe, NSArray *preferences)
{
    NSString *answer = [[NSBundle preferredLocalizationsFromArray:probe forPreferences:preferences] firstObject];
    return [answer isEqualToString:CharonLocalizedNoMatch] ? nil : answer;
}

// The localized string for the user's languages: the first answer of NSBundle's matcher, the same call the host makes,
// over the preferred languages; with no answer, the dictionary's first enumerated key.
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

// The dictionary is copied: the host does not follow a dictionary changed after initialisation. A nil dictionary is taken
// as an empty one, so the object answers nil; the host crashes on a nil dictionary, which is not copied.
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

// The object reads as the string it localizes to, and as the empty string when that is nil.
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

// Archived as the string it reads as, so it decodes as a plain NSString, as the host's does.
- (id)replacementObjectForKeyedArchiver:(NSKeyedArchiver *)archiver
{
    return self.localizedString ?: @"";
}

@end
