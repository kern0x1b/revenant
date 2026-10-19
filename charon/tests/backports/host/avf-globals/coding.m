#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>

static NSValue *CharonCMTimeValue(CMTime value)
{
    return [NSValue valueWithBytes:&value objCType:@encode(CMTime)];
}
#include <stdio.h>
#include <string.h>

@interface NSObject (CharonCodingProbeSetters)
- (void)charonProbeSetDate:(NSDate *)date;
- (void)charonProbeSetMediaTime:(CMTime)mediaTime;
- (void)charonProbeSetSessionID:(NSString *)sessionID;
- (void)charonProbeSetStableID:(NSString *)stableID;
- (void)charonProbeSetURL:(NSURL *)url;
- (void)charonProbeSetDidRecover:(BOOL)didRecover;
@end

@implementation NSObject (CharonCodingProbeSetters)
- (void)charonProbeSetDate:(NSDate *)date { [self setValue:date forKey:@"date"]; }
- (void)charonProbeSetMediaTime:(CMTime)mediaTime { [self setValue:CharonCMTimeValue(mediaTime) forKey:@"mediaTime"]; }
- (void)charonProbeSetSessionID:(NSString *)sessionID { [self setValue:sessionID forKey:@"sessionID"]; }
- (void)charonProbeSetStableID:(NSString *)stableID { [self setValue:stableID forKey:@"stableID"]; }
- (void)charonProbeSetURL:(NSURL *)url { [self setValue:url forKey:@"URL"]; }
- (void)charonProbeSetDidRecover:(BOOL)didRecover { [self setValue:@(didRecover) forKey:@"didRecover"]; }
@end

static id gPortEvent;
static id gPortRendition;

static void probe_coding_support(const char *name)
{
    char prefixed[512];
    snprintf(prefixed, sizeof prefixed, "charon_host_%s", name);
    Class cls = NSClassFromString([NSString stringWithUTF8String:prefixed]);
    printf("CONTROLSECTIONPORT\t%s\t%s\n", name,
           (cls != Nil && [cls respondsToSelector:@selector(supportsSecureCoding)] &&
            [cls supportsSecureCoding]) ? "YES" : "no");
}

static NSArray *round_trip(id object, NSString *label, NSArray<NSString *> *fields)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES
                                                        error:&error];
    if (data == nil) {
        printf("%s\tARCHIVE-FAILED\t%s\n", label.UTF8String, error ? error.description.UTF8String : "-");
        return nil;
    }
    id back = [NSKeyedUnarchiver unarchivedObjectOfClass:[object class] fromData:data error:&error];
    if (back == nil) {
        printf("%s\tUNARCHIVE-FAILED\t%s\n", label.UTF8String, error ? error.description.UTF8String : "-");
        return nil;
    }
    NSMutableArray *read = [NSMutableArray arrayWithCapacity:fields.count];
    for (NSString *field in fields) {
        [read addObject:[back valueForKey:field] ?: [NSNull null]];
    }
    printf("%s\tROUND-TRIP\tread back\tclass=%s\n", label.UTF8String, object_getClassName(back));
    return read;
}

static void check_event(void)
{
    id event = [[gPortEvent class] new];
    [event charonProbeSetDate:[NSDate dateWithTimeIntervalSince1970:1000000.0]];
    [event charonProbeSetMediaTime:CMTimeMake(1234, 600)];
    [event charonProbeSetSessionID:@"11111111-2222-3333-4444-555555555555"];
    NSArray *got = round_trip(event, @"AVMetricEvent", @[@"date", @"mediaTime", @"sessionID"]);
    NSDate *date = got[0] == [NSNull null] ? nil : got[0];
    CMTime mediaTime = kCMTimeZero;
    if (got.count > 1 && got[1] != [NSNull null]) {
        [(NSValue *)got[1] getValue:&mediaTime];
    }
    NSString *session = got.count > 2 && got[2] != [NSNull null] ? got[2] : nil;
    printf("AVMetricEvent.date\twant=978307200\thost-carried=%s\n",
           date && [date timeIntervalSince1970] == 1000000.0 ? "yes" : "NO");
    printf("AVMetricEvent.mediaTime\twant=1234/600 (206)\thost-carried=%s\n",
           CMTimeCompare(mediaTime, CMTimeMake(1234, 600)) == 0 ? "yes" : "NO");
    printf("AVMetricEvent.sessionID\twant=11111111-...\thost-carried=%s\n",
           [session isEqualToString:@"11111111-2222-3333-4444-555555555555"] ? "yes" : "NO");
    printf("AVMetricEvent.initDidNotRestamp\twant=no\theld=%s\n",
           (date && [date timeIntervalSince1970] != 1000000.0) ? "RESTAMPED" : "no");
    printf("AVMetricEvent.roundTripReadBack\twant=read back\theld=%s\n", got ? "read back" : "nil");
}

static void check_rendition(void)
{
    id rendition = [[gPortRendition class] new];
    [rendition charonProbeSetStableID:@"com.apple.quicktime.rendition.1"];
    [rendition charonProbeSetURL:[NSURL URLWithString:@"https://example.invalid/rendition.m3u8"]];
    NSArray *got = round_trip(rendition, @"AVMetricMediaRendition", @[@"stableID", @"URL"]);
    printf("AVMetricMediaRendition.stableID\twant=com.apple.quicktime.rendition.1\thost-carried=%s\n",
           [got[0] isEqualToString:@"com.apple.quicktime.rendition.1"] ? "yes" : "NO");
    printf("AVMetricMediaRendition.URL\twant=https://example.invalid/rendition.m3u8\thost-carried=%s\n",
           [got[1] isEqual:[NSURL URLWithString:@"https://example.invalid/rendition.m3u8"]] ? "yes" : "NO");
    printf("AVMetricMediaRendition.roundTripReadBack\twant=read back\theld=%s\n", got ? "read back" : "nil");
}

static void check_subclass(void)
{
    Class stall = NSClassFromString(@"charon_host_AVMetricPlayerItemStallEvent");
    Class errorEvent = NSClassFromString(@"charon_host_AVMetricErrorEvent");
    if (stall == Nil || errorEvent == Nil) {
        printf("AVMetricPlayerItemStallEvent\tABSENT\tthe subclass is not in the binary\n");
        return;
    }

    id inherited = [stall new];
    [inherited charonProbeSetDate:[NSDate dateWithTimeIntervalSince1970:2000000.0]];
    [inherited charonProbeSetMediaTime:CMTimeMake(77, 30)];
    NSArray *got = round_trip(inherited, @"AVMetricPlayerItemStallEvent", @[@"date", @"mediaTime"]);
    CMTime mediaTime = kCMTimeZero;
    if (got.count > 1 && got[1] != [NSNull null]) {
        [(NSValue *)got[1] getValue:&mediaTime];
    }
    printf("AVMetricPlayerItemStallEvent.date\twant=2000000\thost-carried=%s\n",
           (got[0] != [NSNull null] && [(NSDate *)got[0] timeIntervalSince1970] == 2000000.0) ? "yes" : "NO");
    printf("AVMetricPlayerItemStallEvent.mediaTime\twant=77/30\thost-carried=%s\n",
           CMTimeCompare(mediaTime, CMTimeMake(77, 30)) == 0 ? "yes" : "NO");
    printf("AVMetricPlayerItemStallEvent.inheritedMembers\twant=carried by the walk\theld=%s\n",
           (got.count == 2 && got[0] != [NSNull null] && got[1] != [NSNull null]) ? "carried" : "LOST");

    id own = [errorEvent new];
    [own charonProbeSetDate:[NSDate dateWithTimeIntervalSince1970:3000000.0]];
    [own charonProbeSetMediaTime:CMTimeMake(5, 1)];
    [own charonProbeSetDidRecover:YES];
    NSArray *own2 = round_trip(own, @"AVMetricErrorEvent", @[@"date", @"mediaTime", @"didRecover"]);
    printf("AVMetricErrorEvent.date\twant=3000000\thost-carried=%s\n",
           (own2[0] != [NSNull null] && [(NSDate *)own2[0] timeIntervalSince1970] == 3000000.0) ? "yes" : "NO");
    printf("AVMetricErrorEvent.didRecover\twant=1\thost-carried=%s\n",
           (own2[2] != [NSNull null] && [(NSNumber *)own2[2] boolValue]) ? "yes" : "NO");
}

int main(void)
{
    @autoreleasepool {
        probe_coding_support("AVMetricEvent");
        probe_coding_support("AVMetricMediaRendition");
        gPortEvent = NSClassFromString(@"charon_host_AVMetricEvent");
        gPortRendition = NSClassFromString(@"charon_host_AVMetricMediaRendition");
        if (gPortEvent == Nil || gPortRendition == Nil) {
            fprintf(stderr, "FAIL: the port's classes are not in this binary, so nothing below means anything\n");
            return 1;
        }
        @autoreleasepool {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{@"k": @"v"}
                                                    requiringSecureCoding:YES error:NULL];
            id back = data ? [NSKeyedUnarchiver unarchivedObjectOfClasses:
                              [NSSet setWithObjects:[NSDictionary class], [NSString class], nil]
                                                      fromData:data error:NULL] : nil;
            printf("ARCHIVE-CONTROL\t%s\n", [[back objectForKey:@"k"] isEqual:@"v"] ? "kept" : "LOST");
        }
        check_event();
        check_rendition();
        check_subclass();
    }
    return 0;
}
