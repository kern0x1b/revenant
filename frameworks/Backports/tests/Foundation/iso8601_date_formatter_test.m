#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    revenant_check(formatter != nil, "the formatter is created", @"nil");
    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    NSString *string = [formatter stringFromDate:date];
    revenant_check([string length] > 0, "the default format is not empty", [NSString stringWithFormat:@"%@", string]);
    NSDate *parsed = [formatter dateFromString:string];
    revenant_check(parsed != nil && [parsed timeIntervalSinceReferenceDate] == 0, "the default format parses back to the date", [NSString stringWithFormat:@"%@", parsed]);
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    string = [formatter stringFromDate:date];
    revenant_check([string hasPrefix:@"2001-01-01T00:00:00Z"], "the internet date time is extended with a UTC designator", [NSString stringWithFormat:@"%@", string]);
    formatter.formatOptions = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay;
    string = [formatter stringFromDate:date];
    revenant_check([string hasPrefix:(revenant_negative ? @"2001-01-01" : @"20010101")], "a date without the dash option is basic", [NSString stringWithFormat:@"%@", string]);
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    string = [formatter stringFromDate:date];
    revenant_check([string hasPrefix:@"20010101"], "a date with only date components keeps the basic form in UTC", [NSString stringWithFormat:@"%@", string]);
    formatter.formatOptions = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithTimeZone;
    string = [formatter stringFromDate:date];
    BOOL hasZ = [string hasSuffix:@"Z"];
    BOOL hasOffset = [string hasSuffix:@"+0000"] || [string hasSuffix:@"+00:00"];
    revenant_check(hasZ || hasOffset, "the time zone option adds a UTC offset", [NSString stringWithFormat:@"%@", string]);
    return revenant_finish();
}
