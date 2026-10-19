#import "RevenantUserNotifications.h"
#import "../RevenantSayOnce.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const RevenantRequestKey = @"org.revenant.apple-backports.UNNotificationRequest";
static NSString *const RevenantAuthorizedKey = @"org.revenant.apple-backports.UIUserNotificationTypes";
static const BOOL RevenantReleaseShowsTitles = NO;

@implementation UNNotificationSettings {
@private
    UNAuthorizationStatus _authorizationStatus;
    UNNotificationSetting _soundSetting, _badgeSetting, _alertSetting, _notificationCenterSetting, _lockScreenSetting;
    UNAlertStyle _alertStyle;
    UNShowPreviewsSetting _showPreviewsSetting;
    UNNotificationSetting _criticalAlertSetting, _announcementSetting, _timeSensitiveSetting, _scheduledDeliverySetting, _directMessagesSetting;
    BOOL _providesAppNotificationSettings;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initRevenantWithOptions:(NSNumber *)options
{
    if ((self = [super init])) {
        _showPreviewsSetting = UNShowPreviewsSettingWhenAuthenticated;
        _criticalAlertSetting = UNNotificationSettingNotSupported;
        _providesAppNotificationSettings = NO;
        _announcementSetting = UNNotificationSettingNotSupported;
        _timeSensitiveSetting = UNNotificationSettingNotSupported;
        _scheduledDeliverySetting = UNNotificationSettingNotSupported;
        _directMessagesSetting = UNNotificationSettingNotSupported;
        if (!options) {
            _authorizationStatus = UNAuthorizationStatusNotDetermined;
            _notificationCenterSetting = UNNotificationSettingEnabled;
            _lockScreenSetting = UNNotificationSettingEnabled;
            _alertStyle = UNAlertStyleBanner;
            return self;
        }
        UNAuthorizationOptions granted = options.unsignedIntegerValue;
        _authorizationStatus = UNAuthorizationStatusAuthorized;
        _badgeSetting = granted & UNAuthorizationOptionBadge ? UNNotificationSettingEnabled : UNNotificationSettingDisabled;
        _soundSetting = granted & UNAuthorizationOptionSound ? UNNotificationSettingEnabled : UNNotificationSettingDisabled;
        _alertSetting = granted & UNAuthorizationOptionAlert ? UNNotificationSettingEnabled : UNNotificationSettingDisabled;
        _notificationCenterSetting = _alertSetting;
        _lockScreenSetting = _alertSetting;
        _alertStyle = granted & UNAuthorizationOptionAlert ? UNAlertStyleBanner : UNAlertStyleNone;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _authorizationStatus = [coder decodeIntegerForKey:@"authorizationStatus"];
        _soundSetting = [coder decodeIntegerForKey:@"soundSetting"];
        _badgeSetting = [coder decodeIntegerForKey:@"badgeSetting"];
        _alertSetting = [coder decodeIntegerForKey:@"alertSetting"];
        _notificationCenterSetting = [coder decodeIntegerForKey:@"notificationCenterSetting"];
        _lockScreenSetting = [coder decodeIntegerForKey:@"lockScreenSetting"];
        _alertStyle = [coder decodeIntegerForKey:@"alertStyle"];
        _showPreviewsSetting = [coder decodeIntegerForKey:@"showPreviewsSetting"];
        _criticalAlertSetting = [coder decodeIntegerForKey:@"criticalAlertSetting"];
        _providesAppNotificationSettings = [coder decodeBoolForKey:@"providesAppNotificationSettings"];
        _announcementSetting = [coder decodeIntegerForKey:@"announcementSetting"];
        _timeSensitiveSetting = [coder decodeIntegerForKey:@"timeSensitiveSetting"];
        _scheduledDeliverySetting = [coder decodeIntegerForKey:@"scheduledDeliverySetting"];
        _directMessagesSetting = [coder decodeIntegerForKey:@"directMessagesSetting"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_authorizationStatus forKey:@"authorizationStatus"];
    [coder encodeInteger:_soundSetting forKey:@"soundSetting"];
    [coder encodeInteger:_badgeSetting forKey:@"badgeSetting"];
    [coder encodeInteger:_alertSetting forKey:@"alertSetting"];
    [coder encodeInteger:_notificationCenterSetting forKey:@"notificationCenterSetting"];
    [coder encodeInteger:_lockScreenSetting forKey:@"lockScreenSetting"];
    [coder encodeInteger:_alertStyle forKey:@"alertStyle"];
    [coder encodeInteger:_showPreviewsSetting forKey:@"showPreviewsSetting"];
    [coder encodeInteger:_criticalAlertSetting forKey:@"criticalAlertSetting"];
    [coder encodeBool:_providesAppNotificationSettings forKey:@"providesAppNotificationSettings"];
    [coder encodeInteger:_announcementSetting forKey:@"announcementSetting"];
    [coder encodeInteger:_timeSensitiveSetting forKey:@"timeSensitiveSetting"];
    [coder encodeInteger:_scheduledDeliverySetting forKey:@"scheduledDeliverySetting"];
    [coder encodeInteger:_directMessagesSetting forKey:@"directMessagesSetting"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (UNAuthorizationStatus)authorizationStatus
{
    return _authorizationStatus;
}

- (UNNotificationSetting)soundSetting
{
    return _soundSetting;
}

- (UNNotificationSetting)badgeSetting
{
    return _badgeSetting;
}

- (UNNotificationSetting)alertSetting
{
    return _alertSetting;
}

- (UNNotificationSetting)notificationCenterSetting
{
    return _notificationCenterSetting;
}

- (UNNotificationSetting)lockScreenSetting
{
    return _lockScreenSetting;
}

- (UNNotificationSetting)carPlaySetting
{
    return UNNotificationSettingNotSupported;
}

- (UNAlertStyle)alertStyle
{
    return _alertStyle;
}

- (UNShowPreviewsSetting)showPreviewsSetting
{
    return _showPreviewsSetting;
}

- (UNNotificationSetting)criticalAlertSetting
{
    return _criticalAlertSetting;
}

- (BOOL)providesAppNotificationSettings
{
    return _providesAppNotificationSettings;
}

- (UNNotificationSetting)announcementSetting
{
    return _announcementSetting;
}

- (UNNotificationSetting)timeSensitiveSetting
{
    return _timeSensitiveSetting;
}

- (UNNotificationSetting)scheduledDeliverySetting
{
    return _scheduledDeliverySetting;
}

- (UNNotificationSetting)directMessagesSetting
{
    return _directMessagesSetting;
}

static NSString *revenant_setting_name(UNNotificationSetting setting)
{
    switch (setting) {
        case UNNotificationSettingNotSupported: return @"NotSupported";
        case UNNotificationSettingDisabled: return @"Disabled";
        case UNNotificationSettingEnabled: return @"Enabled";
    }
    return [NSString stringWithFormat:@"%ld", (long)setting];
}

- (NSString *)description
{
    NSArray *statuses = @[@"NotDetermined", @"Denied", @"Authorized"];
    NSArray *styles = @[@"None", @"Banner", @"Alert"];
    return [NSString stringWithFormat:@"<%@: %p; authorizationStatus: %@, notificationCenterSetting: %@, soundSetting: %@, "
                                      @"badgeSetting: %@, lockScreenSetting: %@, alertSetting: %@, carPlaySetting: %@, alertStyle: %@>",
                                      [self class], self, statuses[_authorizationStatus], revenant_setting_name(_notificationCenterSetting),
                                      revenant_setting_name(_soundSetting), revenant_setting_name(_badgeSetting),
                                      revenant_setting_name(_lockScreenSetting), revenant_setting_name(_alertSetting),
                                      revenant_setting_name(UNNotificationSettingNotSupported), styles[_alertStyle]];
}

@end

static dispatch_queue_t revenant_center_queue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("org.revenant.apple-backports.UNUserNotificationCenter", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

void revenant_on_main(void (^work)(void))
{
    if ([NSThread isMainThread])
        work();
    else
        dispatch_sync(dispatch_get_main_queue(), work);
}

static void revenant_say_once(NSString *key, NSString *text)
{
    revenant_say_once_for(key, text);
}

NSError *revenant_unsupported(NSString *reason)
{
    return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

static UNNotificationRequest *revenant_request_of(UILocalNotification *notification)
{
    NSData *archived = notification.userInfo[RevenantRequestKey];
    if (![archived isKindOfClass:[NSData class]])
        return nil;
    @try {
        id request = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
        return [request isKindOfClass:[UNNotificationRequest class]] ? request : nil;
    } @catch (NSException *exception) {
        return nil;
    }
}

static NSInteger revenant_highest_unit(NSDateComponents *components)
{
    if (components.era != NSUndefinedDateComponent || components.year != NSUndefinedDateComponent
        || components.yearForWeekOfYear != NSUndefinedDateComponent)
        return 6;
    if (components.month != NSUndefinedDateComponent)
        return 5;
    if (components.weekOfMonth != NSUndefinedDateComponent || components.weekOfYear != NSUndefinedDateComponent
        || components.weekdayOrdinal != NSUndefinedDateComponent)
        return 4;
    if (components.day != NSUndefinedDateComponent)
        return 3;
    if (components.weekday != NSUndefinedDateComponent)
        return 2;
    if (components.hour != NSUndefinedDateComponent)
        return 1;
    if (components.minute != NSUndefinedDateComponent)
        return 0;
    return components.second != NSUndefinedDateComponent ? -1 : -2;
}

static BOOL revenant_schedule_repeat(UILocalNotification *notification, UNNotificationTrigger *trigger, NSError **error)
{
    if ([trigger isKindOfClass:[UNTimeIntervalNotificationTrigger class]]) {
        NSTimeInterval interval = ((UNTimeIntervalNotificationTrigger *)trigger).timeInterval;
        notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:interval];
        if (!trigger.repeats)
            return YES;
        const struct { NSTimeInterval seconds; NSCalendarUnit unit; } units[] = {
            {60, NSMinuteCalendarUnit}, {3600, NSHourCalendarUnit}, {86400, NSDayCalendarUnit}, {604800, NSWeekCalendarUnit}};
        for (unsigned index = 0; index < sizeof(units) / sizeof(*units); index++)
            if (interval == units[index].seconds) {
                notification.repeatInterval = units[index].unit;
                notification.repeatCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
                notification.repeatCalendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
                return YES;
            }
        *error = revenant_unsupported([NSString stringWithFormat:@"iOS %@ repeats a local notification only every minute, hour, day or week, so a trigger repeating every %g seconds cannot be scheduled", [UIDevice currentDevice].systemVersion, interval]);
        return NO;
    }
    UNCalendarNotificationTrigger *calendarTrigger = (UNCalendarNotificationTrigger *)trigger;
    NSDateComponents *components = calendarTrigger.dateComponents;
    NSCalendar *calendar = [(components.calendar ?: [NSCalendar currentCalendar]) copy];
    if (components.timeZone)
        calendar.timeZone = components.timeZone;
    NSDate *next = calendarTrigger.nextTriggerDate;
    if (!next) {
        *error = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeNotificationInvalidNoDate userInfo:nil];
        return NO;
    }
    notification.fireDate = next;
    notification.timeZone = calendar.timeZone;
    if (!trigger.repeats)
        return YES;
    NSCalendarUnit unit = 0;
    switch (revenant_highest_unit(components)) {
        case -1: unit = NSMinuteCalendarUnit; break;
        case 0: unit = NSHourCalendarUnit; break;
        case 1: unit = NSDayCalendarUnit; break;
        case 2: unit = NSWeekCalendarUnit; break;
        case 3: unit = components.day <= 28 && components.weekday == NSUndefinedDateComponent ? NSMonthCalendarUnit : 0; break;
        case 5:
            unit = components.day != NSUndefinedDateComponent && components.weekday == NSUndefinedDateComponent
                && !(components.month == 2 && components.day == 29) ? NSYearCalendarUnit : 0;
            break;
        default: break;
    }
    if (!unit) {
        *error = revenant_unsupported([NSString stringWithFormat:@"iOS %@ repeats a local notification by one calendar unit from its first date, which does not follow the dates %@ matches when it repeats", [UIDevice currentDevice].systemVersion, components]);
        return NO;
    }
    notification.repeatInterval = unit;
    notification.repeatCalendar = calendar;
    return YES;
}

static UILocalNotification *revenant_local_notification(UNNotificationRequest *request)
{
    UNNotificationContent *content = request.content;
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = content.body;
    if (RevenantReleaseShowsTitles)
        [notification setValue:content.title forKey:@"alertTitle"];
    else if (content.title.length || content.subtitle.length)
        revenant_say_once(@"title", [NSString stringWithFormat:@"UNNotificationContent: iOS %@ shows no title or subtitle on a local notification, so they are kept with the request and not shown", [UIDevice currentDevice].systemVersion]);
    if (content.categoryIdentifier.length || content.threadIdentifier.length)
        revenant_say_once(@"category", [NSString stringWithFormat:@"UNNotificationContent: iOS %@ has no notification categories or threads, so categoryIdentifier and threadIdentifier are kept with the request and change nothing", [UIDevice currentDevice].systemVersion]);
    if (content.badge)
        notification.applicationIconBadgeNumber = content.badge.integerValue;
    if (content.sound) {
        NSString *name = [content.sound revenant_fileName];
        notification.soundName = name ?: UILocalNotificationDefaultSoundName;
    }
    if (content.launchImageName.length)
        notification.alertLaunchImage = content.launchImageName;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:content.userInfo ?: @{}];
    userInfo[RevenantRequestKey] = [NSKeyedArchiver archivedDataWithRootObject:request];
    notification.userInfo = userInfo;
    return notification;
}

@interface UNUserNotificationCenter ()
- (void)revenant_deliver:(UILocalNotification *)notification state:(UIApplicationState)state;
@end

static UNUserNotificationCenter *revenant_center;

static UNNotificationRequest *revenant_push_request(NSDictionary *userInfo)
{
    NSDictionary *aps = [userInfo[@"aps"] isKindOfClass:[NSDictionary class]] ? userInfo[@"aps"] : nil;
    NSString *alert = [aps[@"alert"] isKindOfClass:[NSString class]] ? aps[@"alert"] : nil;
    NSDictionary *fields = [aps[@"alert"] isKindOfClass:[NSDictionary class]] ? aps[@"alert"] : nil;
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = fields[@"title"];
    content.subtitle = fields[@"subtitle"];
    content.body = alert ?: fields[@"body"];
    content.badge = aps[@"badge"];
    content.categoryIdentifier = aps[@"category"];
    content.threadIdentifier = aps[@"thread-id"];
    content.userInfo = userInfo;
    NSString *sound = [aps[@"sound"] isKindOfClass:[NSString class]] ? aps[@"sound"] : nil;
    if (sound)
        content.sound = [sound isEqualToString:@"default"] ? [UNNotificationSound defaultSound] : [UNNotificationSound soundNamed:sound];
    return [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString] content:content
                                                trigger:[UNPushNotificationTrigger revenant_pushTrigger]];
}

static void revenant_hook_delegate(void)
{
    id delegate = [UIApplication sharedApplication].delegate;
    if (!delegate)
        return;
    Class cls = object_getClass(delegate);
    static char hooked;
    if ([objc_getAssociatedObject(cls, &hooked) boolValue])
        return;
    objc_setAssociatedObject(cls, &hooked, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SEL selector = @selector(application:didReceiveLocalNotification:);
    Method existing = class_getInstanceMethod(cls, selector);
    IMP original = existing ? method_getImplementation(existing) : NULL;
    IMP replacement = imp_implementationWithBlock(^(id self, UIApplication *application, UILocalNotification *notification) {
        if (revenant_center && revenant_request_of(notification)) {
            [revenant_center revenant_deliver:notification state:application.applicationState];
            return;
        }
        if (original)
            ((void (*)(id, SEL, UIApplication *, UILocalNotification *))original)(self, selector, application, notification);
    });
    if (!class_addMethod(cls, selector, replacement, "v@:@@"))
        method_setImplementation(existing, replacement);

    SEL pushed = @selector(application:didReceiveRemoteNotification:);
    Method existing_push = class_getInstanceMethod(cls, pushed);
    IMP original_push = existing_push ? method_getImplementation(existing_push) : NULL;
    IMP replacement_push = imp_implementationWithBlock(^(id self, UIApplication *application, NSDictionary *userInfo) {
        if ([userInfo isKindOfClass:[NSDictionary class]] && revenant_center)
            [revenant_center revenant_deliverRequest:revenant_push_request(userInfo) state:application.applicationState];
        if (original_push)
            ((void (*)(id, SEL, UIApplication *, NSDictionary *))original_push)(self, pushed, application, userInfo);
    });
    if (!class_addMethod(cls, pushed, replacement_push, "v@:@@"))
        method_setImplementation(existing_push, replacement_push);
}

@implementation UNUserNotificationCenter {
@private
    __weak id <UNUserNotificationCenterDelegate> _delegate;
}

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil
                                                  usingBlock:^(NSNotification *launched) {
        revenant_hook_delegate();
        UILocalNotification *notification = launched.userInfo[UIApplicationLaunchOptionsLocalNotificationKey];
        if (notification && revenant_request_of(notification))
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UNUserNotificationCenter currentNotificationCenter] revenant_deliver:notification state:UIApplicationStateInactive];
            });
    }];
}

+ (UNUserNotificationCenter *)currentNotificationCenter
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_center = [[self alloc] initRevenant];
    });
    return revenant_center;
}

- (instancetype)initRevenant
{
    return [super init];
}

- (UILocalNotification *)revenant_localNotificationForRequest:(UNNotificationRequest *)request
{
    return revenant_local_notification(request);
}

- (id <UNUserNotificationCenterDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id <UNUserNotificationCenterDelegate>)delegate
{
    _delegate = delegate;
    revenant_on_main(^{
        revenant_hook_delegate();
    });
}

- (BOOL)supportsContentExtensions
{
    return NO;
}

- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options
                      completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler
{
    UNAuthorizationOptions kept = options & (UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(kept) forKey:RevenantAuthorizedKey];
    [defaults synchronize];
    void (^done)(BOOL, NSError *) = [completionHandler copy];
    dispatch_async(revenant_center_queue(), ^{
        if (done)
            done(YES, nil);
    });
}

- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *settings))completionHandler
{
    UNNotificationSettings *settings =
        [[UNNotificationSettings alloc] initRevenantWithOptions:[[NSUserDefaults standardUserDefaults] objectForKey:RevenantAuthorizedKey]];
    void (^done)(UNNotificationSettings *) = [completionHandler copy];
    dispatch_async(revenant_center_queue(), ^{
        done(settings);
    });
}

- (void)addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(void (^)(NSError *error))completionHandler
{
    void (^done)(NSError *) = [completionHandler copy];
    __block NSError *failure = nil;
    if (!request.content) {
        failure = [NSError errorWithDomain:UNErrorDomain code:UNErrorCodeNotificationInvalidNoContent userInfo:nil];
    } else if ([request.trigger isKindOfClass:[UNLocationNotificationTrigger class]]) {
        failure = [[RevenantRegionMonitor revenant_sharedMonitor] revenant_monitorRequest:request];
    } else {
        UILocalNotification *notification = revenant_local_notification(request);
        BOOL keep = !request.trigger || revenant_schedule_repeat(notification, request.trigger, &failure);
        if (keep)
            revenant_on_main(^{
                UIApplication *application = [UIApplication sharedApplication];
                for (UILocalNotification *pending in application.scheduledLocalNotifications)
                    if ([revenant_request_of(pending).identifier isEqualToString:request.identifier])
                        [application cancelLocalNotification:pending];
                if (request.trigger)
                    [application scheduleLocalNotification:notification];
                else
                    [application presentLocalNotificationNow:notification];
            });
    }
    dispatch_async(revenant_center_queue(), ^{
        if (done)
            done(failure);
    });
}

- (void)setNotificationCategories:(NSSet<UNNotificationCategory *> *)categories
{
    NSData *archived = categories.count ? [NSKeyedArchiver archivedDataWithRootObject:categories] : nil;
    if (archived)
        revenant_say_once(@"categories", [NSString stringWithFormat:@"UNUserNotificationCenter: iOS %@ shows no actions on a notification, so the categories are kept and handed back and change nothing",
                                                                  [UIDevice currentDevice].systemVersion]);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (archived)
        [defaults setObject:archived forKey:@"space.kern0x1b.revenant.UNNotificationCategories"];
    else
        [defaults removeObjectForKey:@"space.kern0x1b.revenant.UNNotificationCategories"];
    [defaults synchronize];
}

- (void)getNotificationCategoriesWithCompletionHandler:(void (^)(NSSet<UNNotificationCategory *> *categories))completionHandler
{
    NSData *archived = [[NSUserDefaults standardUserDefaults] objectForKey:@"space.kern0x1b.revenant.UNNotificationCategories"];
    NSSet *categories = archived ? [NSKeyedUnarchiver unarchiveObjectWithData:archived] : nil;
    void (^done)(NSSet *) = [completionHandler copy];
    dispatch_async(revenant_center_queue(), ^{
        done(categories ?: [NSSet set]);
    });
}

- (void)getPendingNotificationRequestsWithCompletionHandler:(void (^)(NSArray<UNNotificationRequest *> *requests))completionHandler
{
    __block NSMutableArray *requests = [NSMutableArray array];
    revenant_on_main(^{
        for (UILocalNotification *pending in [UIApplication sharedApplication].scheduledLocalNotifications) {
            UNNotificationRequest *request = revenant_request_of(pending);
            if (request)
                [requests addObject:request];
        }
    });
    [requests addObjectsFromArray:[[RevenantRegionMonitor revenant_sharedMonitor] revenant_requests]];
    void (^done)(NSArray *) = [completionHandler copy];
    dispatch_async(revenant_center_queue(), ^{
        done([requests copy]);
    });
}

- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray *)identifiers
{
    NSSet *wanted = [NSSet setWithArray:identifiers ?: @[]];
    revenant_on_main(^{
        UIApplication *application = [UIApplication sharedApplication];
        for (UILocalNotification *pending in application.scheduledLocalNotifications) {
            UNNotificationRequest *request = revenant_request_of(pending);
            if (request && [wanted containsObject:request.identifier])
                [application cancelLocalNotification:pending];
        }
    });
    [[RevenantRegionMonitor revenant_sharedMonitor] revenant_removeRequestsWithIdentifiers:wanted];
}

- (void)removeAllPendingNotificationRequests
{
    revenant_on_main(^{
        UIApplication *application = [UIApplication sharedApplication];
        for (UILocalNotification *pending in application.scheduledLocalNotifications)
            if (revenant_request_of(pending))
                [application cancelLocalNotification:pending];
    });
    [[RevenantRegionMonitor revenant_sharedMonitor] revenant_removeRequestsWithIdentifiers:nil];
}

- (void)revenant_deliver:(UILocalNotification *)local state:(UIApplicationState)state
{
    [self revenant_deliverRequest:revenant_request_of(local) state:state];
}

- (void)revenant_deliverRequest:(UNNotificationRequest *)request state:(UIApplicationState)state
{
    if (!request)
        return;
    UNNotification *notification = [UNNotification notificationWithRequest:request date:[NSDate date]];
    id <UNUserNotificationCenterDelegate> delegate = _delegate;
    if (state == UIApplicationStateActive) {
        if (![delegate respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)])
            return;
        [delegate userNotificationCenter:self willPresentNotification:notification
                   withCompletionHandler:^(UNNotificationPresentationOptions options) {
            if ((options & UNNotificationPresentationOptionBadge) && request.content.badge)
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIApplication sharedApplication].applicationIconBadgeNumber = request.content.badge.integerValue;
                });
            if (options & ~UNNotificationPresentationOptionBadge)
                revenant_say_once(@"present", [NSString stringWithFormat:@"UNUserNotificationCenter: iOS %@ shows nothing and plays nothing for a notification that arrives while the application is in front, so only the badge of the presentation options is applied", [UIDevice currentDevice].systemVersion]);
        }];
        return;
    }
    if (![delegate respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)])
        return;
    UNNotificationResponse *response = [UNNotificationResponse responseWithNotification:notification
                                                                       actionIdentifier:UNNotificationDefaultActionIdentifier];
    [delegate userNotificationCenter:self didReceiveNotificationResponse:response withCompletionHandler:^{
    }];
}

@end
