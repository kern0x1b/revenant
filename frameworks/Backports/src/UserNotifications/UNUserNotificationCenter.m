#import "RevenantUserNotificationCenter.h"
#import "../RevenantSayOnce.h"
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const RevenantRequestKey = @"org.revenant.backports.UNNotificationRequest";
static NSString *const RevenantAuthorizedKey = @"org.revenant.backports.UIUserNotificationTypes";
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
        _authorizationStatus = granted ? UNAuthorizationStatusAuthorized : UNAuthorizationStatusDenied;
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
        queue = dispatch_queue_create("org.revenant.backports.UNUserNotificationCenter", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static void revenant_say_once(NSString *key, NSString *text)
{
    revenant_say_once_for(key, text);
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

static UNAuthorizationOptions revenant_authorization_of(UIRemoteNotificationType types)
{
    UNAuthorizationOptions granted = 0;
    if (types & UIRemoteNotificationTypeAlert)
        granted |= UNAuthorizationOptionAlert;
    if (types & UIRemoteNotificationTypeBadge)
        granted |= UNAuthorizationOptionBadge;
    if (types & UIRemoteNotificationTypeSound)
        granted |= UNAuthorizationOptionSound;
    return granted;
}

static UIRemoteNotificationType revenant_remote_types(UNAuthorizationOptions granted)
{
    UIRemoteNotificationType types = UIRemoteNotificationTypeNone;
    if (granted & UNAuthorizationOptionAlert)
        types |= UIRemoteNotificationTypeAlert;
    if (granted & UNAuthorizationOptionBadge)
        types |= UIRemoteNotificationTypeBadge;
    if (granted & UNAuthorizationOptionSound)
        types |= UIRemoteNotificationTypeSound;
    return types;
}

static NSNumber *revenant_authorization_options(void)
{
    UNAuthorizationOptions granted = revenant_authorization_of([UIApplication sharedApplication].enabledRemoteNotificationTypes);
    if (granted)
        return @(granted);
    return [[NSUserDefaults standardUserDefaults] objectForKey:RevenantAuthorizedKey] ? @0 : nil;
}

static void revenant_report_authorization(void (^done)(BOOL granted, NSError *error))
{
    BOOL granted = [UIApplication sharedApplication].enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
    if (done)
        done(granted, nil);
}

static void revenant_await_prompt(void (^finish)(void))
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    __block BOOL shown = NO;
    __block BOOL finished = NO;
    __block id resigned = nil;
    __block id active = nil;
    void (^end)(void) = ^{
        if (finished)
            return;
        finished = YES;
        [center removeObserver:resigned];
        [center removeObserver:active];
        finish();
    };
    resigned = [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue]
                               usingBlock:^(NSNotification *note) {
        shown = YES;
    }];
    active = [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue]
                             usingBlock:^(NSNotification *note) {
        if (shown)
            end();
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!shown)
            end();
    });
}

static NSURL *revenant_sound_file(NSString *name)
{
    if (name.length)
        return [[NSBundle mainBundle] URLForResource:name.stringByDeletingPathExtension withExtension:name.pathExtension];
    NSString *system = @"/System/Library/Audio/UISounds/sms-received1.caf";
    return [[NSFileManager defaultManager] fileExistsAtPath:system] ? [NSURL fileURLWithPath:system] : nil;
}

static void revenant_play_sound(NSString *name)
{
    static NSMutableDictionary *sounds;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sounds = [[NSMutableDictionary alloc] init];
    });
    NSURL *file = revenant_sound_file(name);
    SystemSoundID sound = 0;
    if (file) {
        NSNumber *cached = sounds[file.absoluteString];
        if (cached)
            sound = (SystemSoundID)cached.unsignedIntValue;
        else if (AudioServicesCreateSystemSoundID((__bridge CFURLRef)file, &sound) == kAudioServicesNoError)
            sounds[file.absoluteString] = @(sound);
        else
            sound = 0;
    }
    if (sound)
        AudioServicesPlaySystemSound(sound);
    else
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

static void revenant_present(UNNotificationRequest *request, UNNotificationPresentationOptions options)
{
    UNNotificationContent *content = request.content;
    if ((options & UNNotificationPresentationOptionBadge) && content.badge)
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].applicationIconBadgeNumber = content.badge.integerValue;
        });
    if ((options & UNNotificationPresentationOptionSound) && content.sound) {
        NSString *name = [content.sound revenant_fileName];
        dispatch_async(dispatch_get_main_queue(), ^{
            revenant_play_sound(name);
        });
    }
    if (options & UNNotificationPresentationOptionAlert)
        revenant_say_once(@"alert", [NSString stringWithFormat:@"UNUserNotificationCenter: iOS %@ draws no banner for a notification that arrives while the application is in front, so the alert option is accepted and nothing is drawn", [UIDevice currentDevice].systemVersion]);
}

@interface RevenantUserNotificationDefaultDelegate : NSObject <UNUserNotificationCenterDelegate>
+ (instancetype)revenant_shared;
@end

@implementation RevenantUserNotificationDefaultDelegate

+ (instancetype)revenant_shared
{
    static RevenantUserNotificationDefaultDelegate *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    completionHandler(0);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    completionHandler();
}

@end

static id <UNUserNotificationCenterDelegate> revenant_responder(id <UNUserNotificationCenterDelegate> delegate, SEL selector)
{
    return [delegate respondsToSelector:selector] ? delegate : [RevenantUserNotificationDefaultDelegate revenant_shared];
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
    void (^done)(BOOL, NSError *) = [completionHandler copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIRemoteNotificationType types = revenant_remote_types(kept);
        if (types == UIRemoteNotificationTypeNone) {
            revenant_report_authorization(done);
            return;
        }
        BOOL undecided = revenant_authorization_options() == nil;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:@(kept) forKey:RevenantAuthorizedKey];
        [defaults synchronize];
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:types];
        if (undecided)
            revenant_await_prompt(^{
                revenant_report_authorization(done);
            });
        else
            revenant_report_authorization(done);
    });
}

- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *settings))completionHandler
{
    void (^done)(UNNotificationSettings *) = [completionHandler copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        done([[UNNotificationSettings alloc] initRevenantWithOptions:revenant_authorization_options()]);
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

- (void)getDeliveredNotificationsWithCompletionHandler:(void (^)(NSArray<UNNotification *> *notifications))completionHandler
{
    void (^done)(NSArray *) = [completionHandler copy];
    dispatch_async(revenant_center_queue(), ^{
        done(@[]);
    });
}

- (void)removeDeliveredNotificationsWithIdentifiers:(NSArray<NSString *> *)identifiers
{
}

- (void)removeAllDeliveredNotifications
{
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
    if (state == UIApplicationStateActive) {
        id <UNUserNotificationCenterDelegate> responder =
            revenant_responder(_delegate, @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:));
        [responder userNotificationCenter:self willPresentNotification:notification
                    withCompletionHandler:^(UNNotificationPresentationOptions options) {
            revenant_present(request, options);
        }];
        return;
    }
    id <UNUserNotificationCenterDelegate> responder =
        revenant_responder(_delegate, @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    UNNotificationResponse *response = [UNNotificationResponse responseWithNotification:notification
                                                                       actionIdentifier:UNNotificationDefaultActionIdentifier];
    [responder userNotificationCenter:self didReceiveNotificationResponse:response withCompletionHandler:^{
    }];
}

@end
