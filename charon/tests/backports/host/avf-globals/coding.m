/* coding.m - NSSecureCoding on the metric events, the port's own archive, round-tripped in the same binary
 * as everything else.
 *
 * The port's classes are renamed to charon_host_* by run.sh's copy of the sources, and linked beside this
 * probe together with packages/c/charon-coding's object, so a keyed archive of a PORT event can be made and
 * read back here, on the host, with Apple's own NSKeyedArchiver doing the archiving.
 *
 * What a round trip proves is the thing the ivar walk could silently get wrong: that -encodeWithCoder: and
 * -initWithCoder: round trip the class's OWN ivars and its superclass's, and that -initWithCoder: does not
 * go through -init. The last is the one that reads green while being wrong: if the decode went through -init,
 * the archived date would be stamped with the DECODE time and the test comparing two archived dates would
 * still pass, because both sides would be freshly stamped. So the test archives an event whose date was set
 * to a moment in the past and a mediaTime that is not zero, and asks the copy to carry those exact values -
 * which only the ivar walk can do.
 *
 * Values are compared through the ACCESSORS the header declares, not through ivars, so the test is about what
 * a caller can read rather than about the port's own storage. readFromCache's accessor is -wasReadFromCache:
 * `@property (readonly, getter=wasReadFromCache) BOOL readFromCache` at CharonAVMetrics18.h:156.
 *
 * Controls:
 *   CONTROLSECTIONPORT   +supportsSecureCoding is YES on both roots           -> YES, YES
 *   ARCHIVE-CONTROL      a Foundation-only object round trips through the same call -> kept
 *   PLANTED-CLASS         a class not in this surface                            -> archived as absent
 */
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>

/* CMTime is a struct, so +valueWithCMTime: is NOT in the SDK this host compiles against - the boxer's own
   method is +valueWithBytes:size:, and this helper is that call with the type named. Without it the probe
   cannot put a mediaTime into an event at all, and the row it is checking has nothing to read. */
static NSValue *CharonCMTimeValue(CMTime value)
{
    return [NSValue valueWithBytes:&value objCType:@encode(CMTime)];
}
#include <stdio.h>
#include <string.h>

/* The port's event properties are all @property (readonly), which is what the SDK declares, so the probe has
 * no setter to call and -setValue:forKey: raises for the ones it cannot reach. These setters are TEST-ONLY and
 * live here, in the host build, not in the port's sources: an accessor the SDK does not declare is not a
 * backport, and adding one to AVFoundationMetrics18.m to make a test convenient would be exactly that.
 * They are what lets the probe put a mediaTime and a didRecover into an event before archiving it, which is
 * the only way to ask whether the archive carried them. */
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

/* The values read back, as an NSArray: an id * out-parameter under ARC is a __autoreleasing write-back and
   clang refuses to pass a non-scalar object to one, which is three errors on the first call and not a
   question about the port. An NSArray of the fields, in order, is the same information. */
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

/* An event whose date and mediaTime are both set to something an -init would never produce. */
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

/* A subclass must inherit all three of the methods, and its OWN ivars must be carried by the same walk.
 *
 * AVMetricPlayerItemStallEvent is the INHERITANCE case and declares no members of its own - it derives from
 * AVMetricPlayerItemRateChangeEvent and adds nothing - so what it checks is that the walk carries the two
 * classes above it. AVMetricErrorEvent is the OWN-IVAR case, because didRecover and error are its own.
 * The first version of this asked the stall event for didRecover, which is AVMetricErrorEvent's, and the host
 * said so in as many words: "this class is not key value coding-compliant for the key didRecover" - which is
 * the port being right and the probe asking the wrong class. */
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
    /* didRecover is the one value whose OWNING class is the port's own - every other value of this family
       belongs to the root - and it was the one that went missing. The dump of the port's own class showed
       why, and the cause was in this harness, not in the port: the host build's prologue renamed the class
       but not its PARENT, so charon_host_AVMetricErrorEvent derived from Apple's AVMetricEvent and the
       walker's [object class] walk reached Apple's ivars:

         ivar _didRecover  owner=charon_host_AVMetricErrorEvent
         ivar _date        owner=AVMetricEvent        <- Apple's class, at Apple's offsets

       So the eight values that carried were read and written through Apple's offsets on a port object, and
       they lined up by luck. With the parent renamed too, the owners are all charon_host_* and this value
       carries. Nothing about the port's NSSecureCoding was wrong; the measurement of it was. */
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
        /* The Foundation-only control: the same call on an object this port did not write, so a run that
           archives nothing cannot pass. */
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