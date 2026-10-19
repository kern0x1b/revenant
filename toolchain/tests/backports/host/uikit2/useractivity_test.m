#import <Foundation/Foundation.h>
#import "check.h"

@protocol RevenantHostUserActivityDelegate <NSObject>
@optional
- (void)userActivityWillSave:(id)activity;
@end

@interface RevenantHostNSUserActivity : NSObject
- (instancetype)initWithActivityType:(NSString *)type;
@property (nonatomic, readonly, copy) NSString *activityType;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSDictionary *userInfo;
@property (nonatomic, copy) NSSet *requiredUserInfoKeys;
@property (nonatomic) BOOL needsSave;
@property (nonatomic, copy) NSURL *webpageURL;
@property (nonatomic, copy) NSDate *expirationDate;
@property (nonatomic, copy) NSSet *keywords;
@property (nonatomic) BOOL supportsContinuationStreams;
@property (nonatomic, weak) id delegate;
@property (nonatomic, getter=isEligibleForHandoff) BOOL eligibleForHandoff;
@property (nonatomic, getter=isEligibleForSearch) BOOL eligibleForSearch;
@property (nonatomic, getter=isEligibleForPublicIndexing) BOOL eligibleForPublicIndexing;
@property (nonatomic, getter=isEligibleForPrediction) BOOL eligibleForPrediction;
- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)dictionary;
- (void)becomeCurrent;
- (void)resignCurrent;
- (void)invalidate;
- (void)getContinuationStreamsWithCompletionHandler:(void (^)(NSInputStream *, NSOutputStream *, NSError *))handler;
@end

@interface Watcher : NSObject
@property (nonatomic, strong) NSMutableArray *log;
@end

@implementation Watcher
- (void)userActivityWillSave:(id)activity
{
    [self.log addObject:[NSString stringWithFormat:@"willSave needsSave=%d", [activity needsSave]]];
}
@end

static void spin(NSTimeInterval seconds)
{
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"none";
}

static NSString *state(id a)
{
    return [NSString stringWithFormat:@"type=%@ title=%@ info=%@ req=%@ needsSave=%d web=%@ exp=%@ kw=%@ streams=%d handoff=%d search=%d public=%d prediction=%d",
            [a activityType], [a title], [a userInfo], [a requiredUserInfoKeys], [a needsSave], [a webpageURL], [a expirationDate], [a keywords],
            [a supportsContinuationStreams], [a isEligibleForHandoff], [a isEligibleForSearch], [a isEligibleForPublicIndexing], [a isEligibleForPrediction]];
}

int main(void)
{
    @autoreleasepool {
        RevenantHostNSUserActivity *ours = [[RevenantHostNSUserActivity alloc] initWithActivityType:@"com.x.y"];
        NSUserActivity *system = [[NSUserActivity alloc] initWithActivityType:@"com.x.y"];
        revenant_check([state(ours) isEqualToString:state(system)], "a new activity has the same fields", ([NSString stringWithFormat:@"%@\n%@", state(ours), state(system)]));
        void (^both)(void (^)(id)) = ^(void (^change)(id)) {
            change(ours);
            change(system);
        };
        both(^(id a) { [a setTitle:@"T"]; [a setUserInfo:@{@"k": @1}]; [a addUserInfoEntriesFromDictionary:@{@"j": @2}]; [a setNeedsSave:NO]; });
        revenant_check([state(ours) isEqualToString:state(system)], "the title and the user info, added to, and needsSave", ([NSString stringWithFormat:@"%@\n%@", state(ours), state(system)]));
        NSMutableDictionary *mutable = [@{@"a": @1} mutableCopy];
        [ours setUserInfo:mutable];
        [system setUserInfo:mutable];
        [mutable setObject:@2 forKey:@"b"];
        revenant_check([[ours userInfo] isEqual:[system userInfo]] && [[ours userInfo] count] == 1, "the user info is copied", @"it is not");
        both(^(id a) { [a setUserInfo:nil]; [a setTitle:nil]; });
        revenant_check([[ours userInfo] isEqual:[system userInfo]] && [ours userInfo] != nil && [ours title] == [system title], "nil user info reads as an empty dictionary", ([NSString stringWithFormat:@"%@ %@", [ours userInfo], [system userInfo]]));
        both(^(id a) { [a addUserInfoEntriesFromDictionary:nil]; [a addUserInfoEntriesFromDictionary:@{@"q": @1}]; });
        revenant_check([[ours userInfo] isEqual:[system userInfo]], "adding to an empty one", @"it differs");
        for (NSString *address in @[@"https://a.b/c", @"http://x", @"ftp://x", @"file:///x", @"custom://x"]) {
            NSString *one = raised(^{ [ours setWebpageURL:[NSURL URLWithString:address]]; });
            NSString *two = raised(^{ [system setWebpageURL:[NSURL URLWithString:address]]; });
            revenant_check([one isEqualToString:two], [[@"the web page URL " stringByAppendingString:address] UTF8String], ([NSString stringWithFormat:@"%@ != %@", one, two]));
        }
        both(^(id a) { [a setWebpageURL:nil]; [a setKeywords:[NSSet setWithObjects:@"a", @"b", nil]]; [a setRequiredUserInfoKeys:[NSSet setWithObject:@"k"]]; [a setExpirationDate:[NSDate dateWithTimeIntervalSince1970:100]];
            [a setEligibleForHandoff:NO]; [a setEligibleForSearch:YES]; [a setEligibleForPublicIndexing:YES]; [a setEligibleForPrediction:NO]; [a setSupportsContinuationStreams:YES]; });
        revenant_check([state(ours) isEqualToString:state(system)], "keywords, keys, expiry, eligibility and the identifier", ([NSString stringWithFormat:@"%@\n%@", state(ours), state(system)]));
        NSString *one = raised(^{ (void)[[RevenantHostNSUserActivity alloc] initWithActivityType:@""]; });
        NSString *two = raised(^{ (void)[[NSUserActivity alloc] initWithActivityType:@""]; });
        revenant_check([one isEqualToString:two], "an activity with no type and no declared types is refused with the same reason", ([NSString stringWithFormat:@"%@ != %@", one, two]));

        Watcher *watcher = [[Watcher alloc] init];
        watcher.log = [NSMutableArray array];
        NSMutableArray *systemLog = [NSMutableArray array];
        Watcher *systemWatcher = [[Watcher alloc] init];
        systemWatcher.log = systemLog;
        RevenantHostNSUserActivity *first = [[RevenantHostNSUserActivity alloc] initWithActivityType:@"a"];
        NSUserActivity *systemFirst = [[NSUserActivity alloc] initWithActivityType:@"a"];
        first.delegate = watcher;
        systemFirst.delegate = (id)systemWatcher;
        [first becomeCurrent];
        [systemFirst becomeCurrent];
        revenant_check(watcher.log.count == 0 && systemLog.count == 0, "the delegate is not asked while becomeCurrent runs", @"it was asked at once");
        spin(0.5);
        revenant_check([watcher.log isEqual:systemLog] && watcher.log.count == 1, "the delegate is asked to save after becomeCurrent, once, and needsSave is off then", ([NSString stringWithFormat:@"%@ != %@", watcher.log, systemLog]));
        revenant_check(first.needsSave == systemFirst.needsSave, "needsSave is off after the save", @"it differs");
        [watcher.log removeAllObjects];
        [systemLog removeAllObjects];
        [first becomeCurrent];
        [systemFirst becomeCurrent];
        spin(0.3);
        revenant_check(watcher.log.count == systemLog.count, "becoming current again while current asks nothing", @"it does");
        [first resignCurrent];
        [systemFirst resignCurrent];
        [first becomeCurrent];
        [systemFirst becomeCurrent];
        spin(0.3);
        revenant_check(watcher.log.count == systemLog.count && watcher.log.count == 1, "it is asked again after resigning", ([NSString stringWithFormat:@"%lu %lu", (unsigned long)watcher.log.count, (unsigned long)systemLog.count]));
        [first invalidate];
        [systemFirst invalidate];
        [first setTitle:@"x"];
        [systemFirst setTitle:@"x"];
        revenant_check([[first title] isEqual:[systemFirst title]], "an invalidated activity still takes values", @"it does not");

        __block NSString *oneStreams = nil, *twoStreams = nil;
        [first getContinuationStreamsWithCompletionHandler:^(NSInputStream *i, NSOutputStream *o, NSError *e) { oneStreams = [NSString stringWithFormat:@"%d %d %@/%ld", i != nil, o != nil, e.domain, (long)e.code]; }];
        [systemFirst getContinuationStreamsWithCompletionHandler:^(NSInputStream *i, NSOutputStream *o, NSError *e) { twoStreams = [NSString stringWithFormat:@"%d %d %@/%ld", i != nil, o != nil, e.domain, (long)e.code]; }];
        revenant_check((oneStreams == nil) == (twoStreams == nil), "the continuation streams are answered as soon as the system answers them", ([NSString stringWithFormat:@"port %@ system %@", oneStreams, twoStreams]));
        spin(0.3);
        revenant_check(oneStreams && [oneStreams isEqualToString:twoStreams], "the streams of an activity nobody continues fail with the same error", ([NSString stringWithFormat:@"%@ != %@", oneStreams, twoStreams]));
        revenant_check([NSUserActivityTypeBrowsingWeb isEqualToString:@"NSUserActivityTypeBrowsingWeb"], "the browsing web type", @"it differs");
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures;
}
