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

/* The 12.0 class method, declared by the SDK at NSUserActivity.h:108 and therefore by every
   program the port serves; the port's own class has to answer it. The store it would delete from is
   the system's, and the releases this package carries have no such service: NSUserActivity here holds
   its state in the object and nothing it writes survives the process. So the handler is called, and
   the log says so on **every** call rather than once - a caller that deletes twice must be able to
   tell the two calls apart, and a `dispatch_once` log would answer the second in silence while the
   registry's effect promises an answer a reader can tell from a delete that found nothing.
   The header's own declaration names no queue for the handler
   (`completionHandler:(void(NS_SWIFT_SENDABLE ^)(void))handler`, no queue parameter), so calling it
   on the calling thread is what the clause it is declared under asks for. */
/* The sibling the SDK's interface declares beside it (NSUserActivity.h:109), answered the same way
   and by the same argument: the store it would clear is the system's Handoff store, the releases this
   package carries have none, and the port keeps none of its own, so the handler is called and the log
   says so on every call. It is defined here rather than in a category because the class is
   implemented in this file, and a method the SDK's interface declares with no definition in the
   implementing file is a warning on every compile. Its row in the registry says `implemented` with
   the same facts pointer, so a row and the code that answers it land together. */
+ (void)deleteAllSavedUserActivitiesWithCompletionHandler:(void (^)(void))completionHandler
{
    NSLog(@"[charon] +[NSUserActivity deleteAllSavedUserActivitiesWithCompletionHandler:] deletes "
           "nothing: this package keeps no saved activities");
    completionHandler();
}

+ (void)deleteSavedUserActivitiesWithPersistentIdentifiers:(NSArray<NSUserActivityPersistentIdentifier> *)persistentIdentifiers
                                         completionHandler:(void (^)(void))completionHandler
{
    NSLog(@"[charon] +[NSUserActivity deleteSavedUserActivitiesWithPersistentIdentifiers:completionHandler:] "
           "deletes nothing: this package keeps no saved activities, so there is no store to delete from "
           "(%lu identifier(s) asked for)", (unsigned long)persistentIdentifiers.count);
    completionHandler();
}

@end
