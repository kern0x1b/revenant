#import <Foundation/Foundation.h>

int main(void) {
    @autoreleasepool {
        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        assert(formatter != nil);
        
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        NSString *string = [formatter stringFromDate:date];
        assert([string length] > 0);
        
        NSDate *parsed = [formatter dateFromString:string];
        assert(parsed != nil);
        assert([parsed timeIntervalSinceReferenceDate] == 0);
        
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        string = [formatter stringFromDate:date];
        assert([string hasPrefix:@"2001-01-01T00:00:00Z"]);
        
        formatter.formatOptions = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay;
        string = [formatter stringFromDate:date];
        assert([string hasPrefix:@"20010101"]);
        
        formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        string = [formatter stringFromDate:date];
        NSLog(@"ISO8601 string: %@", string);
        // With only date components, no timezone is included
        assert([string hasPrefix:@"20010101"]);
        
        // Test with timezone option
        formatter.formatOptions = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithTimeZone;
        string = [formatter stringFromDate:date];
        NSLog(@"ISO8601 string with TZ: %@", string);
        BOOL hasZ = [string hasSuffix:@"Z"];
        BOOL hasOffset = [string hasSuffix:@"+0000"] || [string hasSuffix:@"+00:00"];
        assert(hasZ || hasOffset);
        
        return 0;
    }
}