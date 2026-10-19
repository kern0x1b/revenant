#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const results_folder = @"/private/var/backports";

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static NSError *added(UNNotificationRequest *request)
{
    __block BOOL finished = NO;
    __block NSError *failure = nil;
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        failure = error;
        finished = YES;
    }];
    wait_until(^{ return finished; }, 5);
    return failure;
}

static NSArray *pending(void)
{
    __block NSArray *found = nil;
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray *requests) {
        found = requests;
    }];
    wait_until(^{ return (BOOL)(found != nil); }, 5);
    return found;
}

static UNNotificationSettings *settings(void)
{
    __block UNNotificationSettings *found = nil;
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *answer) {
        found = answer;
    }];
    wait_until(^{ return (BOOL)(found != nil); }, 5);
    return found;
}

static UILocalNotification *native_of(NSString *identifier)
{
    for (UILocalNotification *local in [UIApplication sharedApplication].scheduledLocalNotifications)
        for (UNNotificationRequest *request in pending())
            if ([request.identifier isEqualToString:identifier] && [local.alertBody isEqualToString:request.content.body])
                return local;
    return nil;
}

static UNNotificationRequest *request_named(NSString *identifier, NSString *body, UNNotificationTrigger *trigger)
{
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = @"A title";
    content.subtitle = @"A subtitle";
    content.body = body;
    content.badge = @5;
    content.sound = [UNNotificationSound defaultSound];
    content.userInfo = @{@"key": @1};
    return [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
}

@interface CharonNotificationsDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray *presented;
@property (nonatomic) BOOL presentedOnMain;
@end

@implementation CharonNotificationsDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    self.presentedOnMain = [NSThread isMainThread];
    [self.presented addObject:notification];
    completionHandler(UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionAlert);
}

- (void)run
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    CHECK(center == [UNUserNotificationCenter currentNotificationCenter], "there is one notification center");
    center.delegate = self;
    CHECK(center.delegate == self, "it keeps its delegate");
    CHECK(!center.supportsContentExtensions, "it supports no content extensions, which iOS 6 has not got");
    for (NSString *later in @[@"getDeliveredNotificationsWithCompletionHandler:", @"removeAllDeliveredNotifications",
                              @"setBadgeCount:withCompletionHandler:"])
        charon_check(![center respondsToSelector:NSSelectorFromString(later)],
                     [later stringByAppendingString:@" is not there, since iOS 6 cannot do it"].UTF8String, @"it is");
    CHECK(NSClassFromString(@"UNNotificationAttachment") == Nil,
          "the class iOS 6 cannot carry is not there, since a notification of this release shows no image or film");
    CLRegion *region = [[CLRegion alloc] initCircularRegionWithCenter:CLLocationCoordinate2DMake(0, 0) radius:100000
                                                           identifier:@"charon-notifications"];
    UNLocationNotificationTrigger *arriving = [UNLocationNotificationTrigger triggerWithRegion:region repeats:NO];
    CHECK([arriving isKindOfClass:[UNNotificationTrigger class]] && arriving.region == region && !arriving.repeats,
          "a location trigger is there and keeps the region and the repeats it was given");
    Class pushed = NSClassFromString(@"UNPushNotificationTrigger");
    CHECK(pushed && [pushed isSubclassOfClass:[UNNotificationTrigger class]],
          "and a push trigger is there, as the marker a pushed notification is delivered with");

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"org.charon.apple-backports.UIUserNotificationTypes"];
    CHECK(settings().authorizationStatus == UNAuthorizationStatusNotDetermined, "before asking, nothing is determined");
    __block BOOL answered = NO, granted = NO, onMain = YES;
    [center requestAuthorizationWithOptions:UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert
                          completionHandler:^(BOOL ok, NSError *error) {
        granted = ok && !error;
        onMain = [NSThread isMainThread];
        answered = YES;
    }];
    CHECK(wait_until(^{ return answered; }, 5) && granted, "asking for badge, sound and alert is granted");
    CHECK(!onMain, "and answered off the main thread, as iOS 10 answers");
    UNNotificationSettings *now = settings();
    CHECK(now.authorizationStatus == UNAuthorizationStatusAuthorized && now.badgeSetting == UNNotificationSettingEnabled
          && now.soundSetting == UNNotificationSettingEnabled && now.alertSetting == UNNotificationSettingEnabled
          && now.alertStyle == UNAlertStyleBanner && now.carPlaySetting == UNNotificationSettingNotSupported,
          "the settings then say what was granted");

    [center removeAllPendingNotificationRequests];
    UILocalNotification *foreign = [[UILocalNotification alloc] init];
    foreign.fireDate = [NSDate dateWithTimeIntervalSinceNow:3600];
    foreign.alertBody = @"scheduled without UserNotifications";
    [[UIApplication sharedApplication] scheduleLocalNotification:foreign];

    CHECK(added(request_named(@"later", @"first body", [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:600 repeats:NO])) == nil,
          "a request ten minutes ahead is added");
    CHECK(added(request_named(@"later", @"second body", [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:600 repeats:NO])) == nil,
          "and added again under the same identifier");
    NSArray *requests = pending();
    NSUInteger laters = [[requests valueForKey:@"identifier"] indexesOfObjectsPassingTest:^BOOL(id name, NSUInteger index, BOOL *stop) {
        return [name isEqual:@"later"];
    }].count;
    CHECK(laters == 1, "the second replaces the first");
    UNNotificationRequest *kept = nil;
    for (UNNotificationRequest *request in requests)
        if ([request.identifier isEqual:@"later"])
            kept = request;
    CHECK([kept.content.body isEqual:@"second body"] && [kept.content.title isEqual:@"A title"]
          && [kept.content.subtitle isEqual:@"A subtitle"] && [kept.content.userInfo isEqual:@{@"key": @1}]
          && [kept.trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]],
          "the pending request comes back whole, title and subtitle included");
    UILocalNotification *native = native_of(@"later");
    CHECK(native && [native.alertBody isEqual:@"second body"] && native.applicationIconBadgeNumber == 5
          && [native.soundName isEqual:UILocalNotificationDefaultSoundName] && [native.userInfo[@"key"] isEqual:@1],
          "iOS 6 is given the body, the badge, the sound and the user info");
    CHECK(fabs([native.fireDate timeIntervalSinceNow] - 600) < 5, "and the date ten minutes ahead");
    CHECK(![native respondsToSelector:NSSelectorFromString(@"alertTitle")] || [native valueForKey:@"alertTitle"] == nil,
          "and no title, which iOS 6 does not show");

    CHECK(added(request_named(@"hourly", @"every hour", [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:3600 repeats:YES])) == nil,
          "a request repeating every hour is added");
    CHECK(native_of(@"hourly").repeatInterval == NSHourCalendarUnit, "and iOS 6 repeats it every hour");
    NSError *refused = added(request_named(@"odd", @"every 90 seconds", [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:90 repeats:YES]));
    CHECK(refused.code == NSFeatureUnsupportedError && [refused.domain isEqual:NSCocoaErrorDomain],
          "a repeat iOS 6 cannot keep is refused rather than bent");
    NSDateComponents *nine = [[NSDateComponents alloc] init];
    nine.hour = 9;
    CHECK(added(request_named(@"daily", @"at nine", [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:nine repeats:YES])) == nil
          && native_of(@"daily").repeatInterval == NSDayCalendarUnit, "a daily calendar request repeats every day");
    NSDateComponents *last = [[NSDateComponents alloc] init];
    last.day = 31;
    CHECK(added(request_named(@"monthly", @"on the 31st", [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:last repeats:YES])).code
              == NSFeatureUnsupportedError, "a monthly repeat on a day some months lack is refused");
    NSDateComponents *past = [[NSDateComponents alloc] init];
    past.year = 2001;
    NSError *never = added(request_named(@"never", @"in 2001", [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:past repeats:NO]));
    CHECK([never.domain isEqual:UNErrorDomain] && never.code == UNErrorCodeNotificationInvalidNoDate,
          "a date that will not come again is refused as iOS 10 refuses it");

    CHECK(added(request_named(@"where", @"on arriving", [UNLocationNotificationTrigger triggerWithRegion:region repeats:NO])) == nil,
          "a request whose trigger is a region is added");
    UNNotificationRequest *under = nil;
    for (UNNotificationRequest *request in pending())
        if ([request.identifier isEqual:@"where"])
            under = request;
    CHECK(under && [under.trigger isKindOfClass:[UNLocationNotificationTrigger class]]
          && [((UNLocationNotificationTrigger *)under.trigger).region.identifier isEqual:@"charon-notifications"]
          && [under.content.body isEqual:@"on arriving"],
          "and comes back pending, with the region and the content it was added with");
    CHECK(![UIApplication sharedApplication].scheduledLocalNotifications
          || ![[[UIApplication sharedApplication].scheduledLocalNotifications valueForKey:@"alertBody"] containsObject:@"on arriving"],
          "and iOS 6 is given nothing to schedule for it, since a region has no date");

    [center removePendingNotificationRequestsWithIdentifiers:@[@"hourly"]];
    CHECK(![[pending() valueForKey:@"identifier"] containsObject:@"hourly"], "a pending request is removed by identifier");
    [center removeAllPendingNotificationRequests];
    CHECK(pending().count == 0, "and all of them at once");
    BOOL foreignKept = NO;
    for (UILocalNotification *local in [UIApplication sharedApplication].scheduledLocalNotifications)
        foreignKept = foreignKept || [local.alertBody isEqual:foreign.alertBody];
    CHECK(foreignKept, "leaving a notification the application scheduled itself");
    [[UIApplication sharedApplication] cancelLocalNotification:foreign];

    self.presented = [NSMutableArray array];
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    CHECK(added(request_named(@"soon", @"in three seconds", [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:3 repeats:NO])) == nil,
          "a request three seconds ahead is added");
    CHECK(wait_until(^{ return (BOOL)(self.presented.count > 0); }, 15), "it arrives while the application is in front");
    UNNotification *arrived = self.presented.firstObject;
    CHECK([arrived.request.identifier isEqual:@"soon"] && [arrived.request.content.title isEqual:@"A title"],
          "as the request it was added as");
    CHECK(fabs([arrived.date timeIntervalSinceNow]) < 15, "dated when it arrived");
    CHECK(self.presentedOnMain, "and the delegate hears of it on the main thread");
    CHECK(wait_until(^{ return (BOOL)([UIApplication sharedApplication].applicationIconBadgeNumber == 5); }, 3),
          "the badge the delegate asked to present is set");
    [self.presented removeAllObjects];
    CHECK(added(request_named(@"now", @"right away", nil)) == nil && wait_until(^{ return (BOOL)(self.presented.count > 0); }, 10),
          "a request with no trigger arrives right away");
    CHECK(pending().count == 0, "and nothing is left pending");
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"notifications.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self run];
        } @catch (NSException *exception) {
            charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
        }
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok",
                                                       charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"notifications.done"] atomically:YES
                    encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonNotificationsDelegate");
    }
}
