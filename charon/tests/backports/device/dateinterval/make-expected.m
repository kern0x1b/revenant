#import <Foundation/Foundation.h>

static NSArray *kLocales(void)
{
    return @[@"en_US", @"en_GB", @"en_AU", @"en_CA", @"en_IN", @"de_DE", @"fr_FR", @"es_MX", @"it_IT",
              @"pt_BR", @"ja_JP", @"ko_KR", @"zh_CN", @"ru_RU", @"ar_EG"];
}

static NSArray *kZones(void)
{
    return @[@"UTC", @"America/New_York", @"Europe/Warsaw"];
}

static NSArray *kPairs(void)
{
    NSMutableArray *pairs = [NSMutableArray array];
    NSDate *start = [NSDate dateWithTimeIntervalSinceReferenceDate:600000000];
    [pairs addObject:@[start, [start dateByAddingTimeInterval:3600]]];
    [pairs addObject:@[start, [start dateByAddingTimeInterval:93600]]];
    [pairs addObject:@[start, [start dateByAddingTimeInterval:31622400]]];
    return pairs;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSArray *zones = kZones(), *pairs = kPairs();
        NSUInteger cases = 0;
        for (NSString *identifier in kLocales()) {
            NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
            for (NSInteger dateStyle = 0; dateStyle <= 4; dateStyle++) {
                for (NSInteger timeStyle = 0; timeStyle <= 4; timeStyle++) {
                    for (NSString *zone in zones) {
                        for (NSArray *pair in pairs) {
                            NSDateIntervalFormatter *formatter = [[NSDateIntervalFormatter alloc] init];
                            formatter.locale = locale;
                            formatter.dateStyle = (NSDateIntervalFormatterStyle)dateStyle;
                            formatter.timeStyle = (NSDateIntervalFormatterStyle)timeStyle;
                            formatter.timeZone = [NSTimeZone timeZoneWithName:zone];
                            if (dateStyle == 0 && timeStyle == 0) {
                                NSDateIntervalFormatter *fresh = [[NSDateIntervalFormatter alloc] init];
                                printf("defaults\t%ld\t%ld\t%s\n", (long)fresh.dateStyle, (long)fresh.timeStyle,
                                       fresh.dateTemplate.UTF8String);
                            }
                            NSString *answer = [formatter stringFromDate:pair[0] toDate:pair[1]];
                            NSString *safe = [[answer stringByReplacingOccurrencesOfString:@"\t" withString:@" "]
                                                 stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                            printf("%s\t%ld\t%ld\t%s\t%ld\t%ld\t%s\n", identifier.UTF8String, (long)dateStyle,
                                   (long)timeStyle, zone.UTF8String, (long)[pair[0] timeIntervalSinceReferenceDate],
                                   (long)[pair[1] timeIntervalSinceReferenceDate], safe.UTF8String);
                            cases++;
                        }
                    }
                }
            }
        }
        for (NSString *identifier in @[@"en_US", @"en_GB", @"de_DE", @"ja_JP", @"fr_FR"]) {
            for (NSString *template in @[@"jm", @"MMMd", @"yMdjm", @"yMMMMd", @"jmv", @"MMMdjmss", @"Hm"]) {
                for (NSArray *pair in pairs) {
                    NSDateIntervalFormatter *formatter = [[NSDateIntervalFormatter alloc] init];
                    formatter.locale = [NSLocale localeWithLocaleIdentifier:identifier];
                    formatter.dateStyle = formatter.timeStyle = NSDateIntervalFormatterNoStyle;
                    formatter.dateTemplate = template;
                    formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                    printf("template\t%s\t%s\t%ld\t%s\n", identifier.UTF8String, template.UTF8String,
                                           (long)[pair[0] timeIntervalSinceReferenceDate],
                                           [formatter stringFromDate:pair[0] toDate:pair[1]].UTF8String);
                    cases++;
                }
            }
        }
        fprintf(stderr, "%lu cases\n", (unsigned long)cases);
    }
    return 0;
}
