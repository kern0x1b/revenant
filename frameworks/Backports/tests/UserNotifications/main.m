#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

int main(void)
{
    @autoreleasepool {
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = @"Title";
        content.subtitle = @"Subtitle";
        content.body = @"Body";
        content.badge = @3;
        content.sound = [UNNotificationSound defaultSound];
        content.userInfo = @{@"key": @"value"};
        content.categoryIdentifier = @"category";
        content.threadIdentifier = @"thread";
        UNNotificationContent *copy = [content copy];
        printf("content %s|%s|%s|%d|%d|%lu|%s|%s\n", copy.title.UTF8String, copy.subtitle.UTF8String, copy.body.UTF8String,
               [copy.badge intValue], [copy.sound isEqual:[UNNotificationSound defaultSound]],
               (unsigned long)copy.userInfo.count, copy.categoryIdentifier.UTF8String, copy.threadIdentifier.UTF8String);
        printf("sound %d %d\n", [[UNNotificationSound soundNamed:@"ding.caf"] isEqual:[UNNotificationSound soundNamed:@"ding.caf"]],
               [[UNNotificationSound soundNamed:@"ding.caf"] isEqual:[UNNotificationSound defaultSound]]);

        UNTimeIntervalNotificationTrigger *interval = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:60 repeats:NO];
        printf("interval %g %d\n", interval.timeInterval, interval.repeats);

        NSDateComponents *wanted = [[NSDateComponents alloc] init];
        wanted.hour = 9;
        wanted.minute = 30;
        UNCalendarNotificationTrigger *calendar = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:wanted repeats:YES];
        printf("calendar %ld %ld %d\n", (long)calendar.dateComponents.hour, (long)calendar.dateComponents.minute, calendar.repeats);

        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"request" content:content trigger:interval];
        printf("request %s|%s|%g|%d\n", request.identifier.UTF8String, request.content.title.UTF8String,
               ((UNTimeIntervalNotificationTrigger *)request.trigger).timeInterval, request.trigger.repeats);

        UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"category" actions:@[]
                                                                        intentIdentifiers:@[] options:0];
        printf("category %s|%lu\n", category.identifier.UTF8String, (unsigned long)category.actions.count);
    }
    return 0;
}
