#import <Foundation/Foundation.h>

NSString *const NSUserActivityTypeBrowsingWeb = @"NSUserActivityTypeBrowsingWeb";

@implementation NSUserActivity {
    NSString *_activityType;
    NSString *_title;
    NSDictionary *_userInfo;
    NSSet<NSString *> *_requiredUserInfoKeys;
    BOOL _needsSave;
    NSURL *_webpageURL;
    NSDate *_expirationDate;
    NSSet<NSString *> *_keywords;
    BOOL _supportsContinuationStreams;
    __weak id<NSUserActivityDelegate> _delegate;
    BOOL _eligibleForHandoff;
    BOOL _eligibleForSearch;
    BOOL _eligibleForPublicIndexing;
    BOOL _eligibleForPrediction;
    BOOL _current;
}

@dynamic referrerURL, targetContentIdentifier, persistentIdentifier;

- (instancetype)init
{
    return [self initWithActivityType:nil];
}

- (instancetype)initWithActivityType:(NSString *)activityType
{
    self = [super init];
    if (!self)
        return nil;
    if (activityType.length == 0) {
        NSArray *declared = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserActivityTypes"];
        activityType = [declared isKindOfClass:[NSArray class]] ? declared.firstObject : nil;
        if (activityType.length == 0)
            [NSException raise:NSInvalidArgumentException format:@"Caller did not provide an activityType, and this process does not have a NSUserActivityTypes in its Info.plist."];
    }
    _activityType = [activityType copy];
    _userInfo = @{};
    _needsSave = YES;
    _eligibleForHandoff = YES;
    return self;
}

- (NSString *)activityType
{
    return _activityType;
}

- (NSString *)title
{
    return _title;
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
}

- (NSDictionary *)userInfo
{
    return _userInfo;
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    _userInfo = userInfo ? [userInfo copy] : @{};
}

- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)otherDictionary
{
    if (!otherDictionary.count)
        return;
    NSMutableDictionary *merged = [_userInfo mutableCopy];
    [merged addEntriesFromDictionary:otherDictionary];
    _userInfo = [merged copy];
}

- (NSSet<NSString *> *)requiredUserInfoKeys
{
    return _requiredUserInfoKeys;
}

- (void)setRequiredUserInfoKeys:(NSSet<NSString *> *)keys
{
    _requiredUserInfoKeys = [keys copy];
}

- (BOOL)needsSave
{
    return _needsSave;
}

- (void)setNeedsSave:(BOOL)needsSave
{
    _needsSave = needsSave;
}

- (NSURL *)webpageURL
{
    return _webpageURL;
}

- (void)setWebpageURL:(NSURL *)URL
{
    if (URL) {
        NSString *scheme = URL.scheme;
        if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
            [NSException raise:NSInvalidArgumentException format:@"NSUserActivity.webpageURL scheme \"%@\" is not allowed.", scheme];
    }
    _webpageURL = [URL copy];
}

- (NSDate *)expirationDate
{
    return _expirationDate;
}

- (void)setExpirationDate:(NSDate *)date
{
    _expirationDate = [date copy];
}

- (NSSet<NSString *> *)keywords
{
    return _keywords;
}

- (void)setKeywords:(NSSet<NSString *> *)keywords
{
    _keywords = [keywords copy];
}

- (BOOL)supportsContinuationStreams
{
    return _supportsContinuationStreams;
}

- (void)setSupportsContinuationStreams:(BOOL)supports
{
    _supportsContinuationStreams = supports;
}

- (id<NSUserActivityDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<NSUserActivityDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)isEligibleForHandoff
{
    return _eligibleForHandoff;
}

- (void)setEligibleForHandoff:(BOOL)eligible
{
    _eligibleForHandoff = eligible;
}

- (BOOL)isEligibleForSearch
{
    return _eligibleForSearch;
}

- (void)setEligibleForSearch:(BOOL)eligible
{
    _eligibleForSearch = eligible;
}

- (BOOL)isEligibleForPublicIndexing
{
    return _eligibleForPublicIndexing;
}

- (void)setEligibleForPublicIndexing:(BOOL)eligible
{
    _eligibleForPublicIndexing = eligible;
}

- (BOOL)isEligibleForPrediction
{
    return _eligibleForPrediction;
}

- (void)setEligibleForPrediction:(BOOL)eligible
{
    _eligibleForPrediction = eligible;
}

- (void)becomeCurrent
{
    if (_current)
        return;
    _current = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        id<NSUserActivityDelegate> delegate = self->_delegate;
        if ([delegate respondsToSelector:@selector(userActivityWillSave:)]) {
            self->_needsSave = NO;
            [delegate userActivityWillSave:self];
        }
    });
}

- (void)resignCurrent
{
    _current = NO;
}

- (void)invalidate
{
    _current = NO;
}

- (void)getContinuationStreamsWithCompletionHandler:(void (^)(NSInputStream *, NSOutputStream *, NSError *))completionHandler
{
    completionHandler(nil, nil, [NSError errorWithDomain:NSCocoaErrorDomain code:3328 userInfo:nil]);
}

+ (void)deleteAllSavedUserActivitiesWithCompletionHandler:(void (^)(void))completionHandler
{
    NSLog(@"[revenant] +[NSUserActivity deleteAllSavedUserActivitiesWithCompletionHandler:] deletes "
           "nothing: this package keeps no saved activities");
    completionHandler();
}

+ (void)deleteSavedUserActivitiesWithPersistentIdentifiers:(NSArray<NSUserActivityPersistentIdentifier> *)persistentIdentifiers
                                         completionHandler:(void (^)(void))completionHandler
{
    NSLog(@"[revenant] +[NSUserActivity deleteSavedUserActivitiesWithPersistentIdentifiers:completionHandler:] "
           "deletes nothing: this package keeps no saved activities, so there is no store to delete from "
           "(%lu identifier(s) asked for)", (unsigned long)persistentIdentifiers.count);
    completionHandler();
}

@end
