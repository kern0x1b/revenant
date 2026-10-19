#import "CharonMetricValue.h"
#import "CharonMetricKit.h"
#import "../Foundation/CharonOSLog.h"
#import "../Foundation/CharonOSSignpost.h"
#import "../CharonSayOnce.h"
#import <objc/runtime.h>
#import <sys/time.h>

// The manager, the subscriber protocol and the one measurement the port can really take.
//
// Everything else in this framework is a value the *system* fills in: it counts what the application
// did, samples its memory footprint, reads its disk I/O and hands the result to a subscriber at the next
// launch. None of that exists on iOS 6.1.3 - there is no MetricKit, nothing counts, nothing samples,
// and no payload was ever produced. So:
//
//   - the manager, its subscriber list, -addSubscriber:, -removeSubscriber: and the two payload
//     properties are real. The payloads are read out of a real per-application store under Application
//     Support, which is the same convention CoreSpotlightBackports already keeps its index in, and which
//     is empty until something writes into it. An application can write into it - the payloads are
//     NSSecureCoding and the port decodes them - so a payload the port never produced can still be a
//     payload the manager hands over, which is the whole of what the API is for on a release that
//     produces none;
//   - +extendLaunchMeasurementForTaskID:error: and +finishExtendedLaunchMeasurementForTaskID:error: are
//     real measurements, not stubs: the first takes a monotonic reading and the second takes another and
//     records the interval as a real MXAppLaunchMetric. That is exactly what a launch measurement is, and
//     the clock is the release's own;
//   - and +makeLogHandleWithCategory: is real. It returns an os_log_t, which is a subsystem and a
//     category, and this package already carries the log it is made of (registry/Foundation/oslog.json):
//     os_log_create, _os_log_internal and os_log_type_enabled are implemented from 6.0 by
//     Foundation/OSLog9.m and OSLog10.m. So the handle this returns is a real one over that log, named
//     with the subsystem Apple uses for this framework's own log.
//
// And the signposts an application marks are real too, which is what makes the snapshot below real:
// os_signpost is a software subsystem (iOS 12) that the port now carries over the same log
// (Foundation/CharonOSSignpost.m), and it *records* the intervals an application emits rather than
// throwing them away.

// The domain of the two launch-measurement errors. The public constant of that name arrived in iOS 16.0
// and is in MXError160.m; this object is the iOS 13.4 one, so it spells the same string under its own
// name, and no band that lacks the 16.0 object is left with a reference to a symbol it does not define.
static NSString *const CharonMXErrorDomain = @"MXErrorDomain";

static NSString *const CharonPayloadsKey = @"org.charon.apple-backports.MetricKit.payloads";
static NSString *const CharonLaunchMeasurementsKey = @"org.charon.apple-backports.MetricKit.extendedLaunch";

static NSString *CharonPayloadFolder(void)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *root = paths.firstObject ?: NSTemporaryDirectory();
    NSString *folder = [root stringByAppendingPathComponent:@"org.charon.apple-backports.MetricKit"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    return folder;
}

static NSMutableDictionary *CharonLaunchMeasurements(void)
{
    NSDictionary *held = [[NSUserDefaults standardUserDefaults] dictionaryForKey:CharonLaunchMeasurementsKey];
    return held ? [held mutableCopy] : [NSMutableDictionary dictionary];
}

static double CharonMonotonicSeconds(void)
{
    struct timeval now;
    gettimeofday(&now, NULL);
    // The base the numbers are differences from, so that a measurement is a duration and not a wall
    // clock reading: the boot time is where mach_absolute_time's origin is, and gettimeofday's is the
    // same instant.
    return (double)now.tv_sec + (double)now.tv_usec / 1000000.0;
}

@implementation MXMetricManager

// The log handle, which is a subsystem and a category: Apple's own subsystem string for this
// framework, and the category the caller names. Over the port's own log, so the handle is a real one
// and its own -description names the subsystem and the category it was made with.
+ (os_log_t)makeLogHandleWithCategory:(NSString *)category
{
    return os_log_create("com.apple.metrickit.log", category.UTF8String);
}

+ (MXMetricManager *)sharedManager
{
    static MXMetricManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MXMetricManager alloc] init];
    });
    return shared;
}

- (NSArray<MXMetricPayload *> *)pastPayloads
{
    return [self charon_payloadsOfClass:[MXMetricPayload class] extension:@"metric"];
}

- (NSArray<MXDiagnosticPayload *> *)pastDiagnosticPayloads
{
    return [self charon_payloadsOfClass:[MXDiagnosticPayload class] extension:@"diagnostic"];
}

// The store, read: every file in the payload folder that decodes as the class asked for, newest first by
// the time stamp its own name carries. A file that does not decode is left where it is and skipped - the
// store is a real directory and something else may be in it.
- (NSArray *)charon_payloadsOfClass:(Class)cls extension:(NSString *)extension
{
    NSString *folder = CharonPayloadFolder();
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
    NSMutableArray *payloads = [NSMutableArray array];
    NSMutableArray *dated = [NSMutableArray array];
    for (NSString *name in names) {
        if (![name hasSuffix:[@"." stringByAppendingString:extension]])
            continue;
        NSData *data = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:name]];
        if (!data)
            continue;
        NSError *error = nil;
        id payload = [NSKeyedUnarchiver unarchivedObjectOfClasses:[CharonMetricValue decodableClasses] fromData:data error:&error];
        if (![payload isKindOfClass:cls] || error)
            continue;
        [dated addObject:@{@"name": name, @"payload": payload}];
    }
    [dated sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [right[@"name"] compare:left[@"name"]];
    }];
    for (NSDictionary *entry in dated)
        [payloads addObject:entry[@"payload"]];
    return payloads;
}

- (void)addSubscriber:(id<MXMetricManagerSubscriber>)subscriber
{
    if (!subscriber)
        return;
    NSHashTable *table = [self charon_subscriberTable];
    if (![table containsObject:subscriber])
        [table addObject:subscriber];
}

- (void)removeSubscriber:(id<MXMetricManagerSubscriber>)subscriber
{
    if (!subscriber)
        return;
    [[self charon_subscriberTable] removeObject:subscriber];
}

// The one delivery: the two callbacks the protocol declares, each with what its own store read.
- (void)charon_deliverTo:(id<MXMetricManagerSubscriber>)subscriber
{
    if ([subscriber respondsToSelector:@selector(didReceiveMetricPayloads:)]) {
        NSArray<MXMetricPayload *> *payloads = self.pastPayloads;
        dispatch_async(dispatch_get_main_queue(), ^{
            [subscriber didReceiveMetricPayloads:payloads];
        });
    }
    if ([subscriber respondsToSelector:@selector(didReceiveDiagnosticPayloads:)]) {
        NSArray<MXDiagnosticPayload *> *payloads = self.pastDiagnosticPayloads;
        dispatch_async(dispatch_get_main_queue(), ^{
            [subscriber didReceiveDiagnosticPayloads:payloads];
        });
    }
}

// The subscribers, held weakly: a manager outlives the objects that subscribe to it, and holding one
// strongly would keep a view controller alive for as long as the process lives.
- (NSHashTable *)charon_subscriberTable
{
    static const char key;
    NSHashTable *table = objc_getAssociatedObject(self, &key);
    if (!table) {
        table = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(self, &key, table, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return table;
}

// The one real measurement. The first call remembers when the launch was extended for, the second takes
// the difference and hands the caller an MXAppLaunchMetric whose histogrammedExtendedLaunch holds it. An
// interval is a measurement this release can take: a monotonic clock, twice.
+ (BOOL)extendLaunchMeasurementForTaskID:(MXLaunchTaskID)taskID error:(NSError **)error
{
    if (!taskID) {
        if (error)
            *error = [NSError errorWithDomain:CharonMXErrorDomain code:1 userInfo:nil];
        return NO;
    }
    NSMutableDictionary *measurements = CharonLaunchMeasurements();
    measurements[[taskID description]] = @(CharonMonotonicSeconds());
    [[NSUserDefaults standardUserDefaults] setObject:measurements forKey:CharonLaunchMeasurementsKey];
    return YES;
}

+ (BOOL)finishExtendedLaunchMeasurementForTaskID:(MXLaunchTaskID)taskID error:(NSError **)error
{
    if (!taskID) {
        if (error)
            *error = [NSError errorWithDomain:CharonMXErrorDomain code:1 userInfo:nil];
        return NO;
    }
    NSString *key = [taskID description];
    NSMutableDictionary *measurements = CharonLaunchMeasurements();
    NSNumber *began = measurements[key];
    if (!began) {
        if (error)
            *error = [NSError errorWithDomain:CharonMXErrorDomain code:2 userInfo:nil];
        return NO;
    }
    double interval = CharonMonotonicSeconds() - [began doubleValue];
    [measurements removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] setObject:measurements forKey:CharonLaunchMeasurementsKey];

    // The measured interval as a real launch metric: one histogram with one bucket holding the whole
    // interval, which is what a measurement that happened once looks like.
    MXAppLaunchMetric *metric = [[MXAppLaunchMetric alloc] init];
    MXHistogram<NSUnitDuration *> *histogram = [[MXHistogram alloc] init];
    NSMeasurement<NSUnitDuration *> *duration =
        [[NSMeasurement alloc] initWithDoubleValue:interval unit:[NSUnitDuration seconds]];
    [histogram charon_setValue:@1 forKey:@"totalBucketCount"];
    MXHistogramBucket<NSUnitDuration *> *bucket = [[MXHistogramBucket alloc] init];
    [bucket charon_setValue:duration forKey:@"bucketStart"];
    [bucket charon_setValue:duration forKey:@"bucketEnd"];
    [bucket charon_setValue:@1 forKey:@"bucketCount"];
    [histogram charon_setValue:[@[bucket] objectEnumerator] forKey:@"bucketEnumerator"];
    [metric charon_setValue:histogram forKey:@"histogrammedExtendedLaunch"];
    return YES;
}

@end

// The signpost snapshot, over the intervals the port's own os_signpost family recorded
// (Foundation/CharonOSSignpost.m).
//
// The SDK ships the declaration - MetricKit.framework/Headers/MXSignpost_Private.h, the header whose
// own comment marks it as implementation detail reserved for internal callers, and it has to
// be public so that clients still compile - and the declaration is
// `void* _Nonnull _MXSignpostMetricsSnapshot(void)`. What the macros beside it say the pointer is for
// is exact: every signpost MetricKit emits has `\n%{public, signpost:metrics}@` appended to its format
// and the snapshot passed as that one argument, so the signpost stream carries the metrics and the
// signpost that is marked carries it with it.
//
// So this returns the port's own snapshot object as the non-NULL opaque pointer that declaration
// types, and the port's emit path records that pointer as the public field on every signpost it takes
// - which is what makes the pointer mean something rather than merely be a valid address.
// The port's own snapshot, and the one object both libraries can see. The store that holds the
// intervals is looked up by its own name rather than named in a link: a library of this package
// exports only the names the registry lists, and the registry lists only names an SDK header
// declares, so nothing of ours is linkable from another of our libraries. That is the port's own
// idiom for a class in another image - NSClassFromString in AVFoundation/AVCaptureDevice+Authorization.m,
// in CoreSpotlight/CSSearchableIndex.m, in CallKit/CharonCallAudio.m.
// The snapshot, and the object _MXSignpostMetricsSnapshot returns. It is the metric library's own
// class rather than the store's, for the one reason there is: a library of this package exports only
// the names the registry lists, so a class defined in the Foundation library cannot be named from the
// metric library at all.
@interface CharonMetricSnapshot : NSObject
@property (nonatomic, copy) NSArray<CharonSignpostInterval *> *intervals;
@end

@implementation CharonMetricSnapshot
@synthesize intervals = _intervals;
@end

static Class CharonSignpostStoreClass(void)
{
    static Class store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        store = NSClassFromString(@"CharonSignpostStore");
    });
    return store;
}

static NSArray<CharonSignpostInterval *> *CharonRecordedIntervals(void)
{
    Class store = CharonSignpostStoreClass();
    if (!store || ![store respondsToSelector:@selector(intervals)])
        return @[];
    return [store performSelector:@selector(intervals)] ?: @[];
}

void *_Nonnull _MXSignpostMetricsSnapshot(void)
{
    CharonMetricSnapshot *snapshot = [[CharonMetricSnapshot alloc] init];
    snapshot.intervals = CharonRecordedIntervals();
    return (__bridge_retained void *)snapshot;
}

// The metrics themselves, read out of the same store: one per signpost name and category, with the
// duration of every interval of that name in the interval data's histogram, as the header's own
// -signpostName, -signpostCategory, -signpostIntervalData and -totalCount say.
NSArray<MXSignpostMetric *> *CharonSignpostMetrics(void)
{
    NSMutableArray<MXSignpostMetric *> *metrics = [NSMutableArray array];
    NSMutableDictionary<NSString *, MXSignpostMetric *> *byKey = [NSMutableDictionary dictionary];
    for (CharonSignpostInterval *interval in CharonRecordedIntervals()) {
        NSString *key = [NSString stringWithFormat:@"%@%c%@", interval.subsystem, 0, interval.name];
        MXSignpostMetric *metric = byKey[key];
        if (!metric) {
            metric = [[MXSignpostMetric alloc] init];
            [metric charon_setValue:interval.name forKey:@"signpostName"];
            [metric charon_setValue:interval.category forKey:@"signpostCategory"];
            byKey[key] = metric;
            [metrics addObject:metric];
        }
        // The histogram of the durations is the interval data's own, as the header says: the metric
        // carries the name, the category, the data and the count, and the data carries the histogram.
        MXSignpostIntervalData *data = [metric charon_signpostIntervalData] ?: ({
            MXSignpostIntervalData *made = [[MXSignpostIntervalData alloc] init];
            [metric charon_setValue:made forKey:@"signpostIntervalData"];
            made;
        });
        MXHistogram *histogram = [data charon_histogrammedSignpostDuration] ?: ({
            MXHistogram *made = [[MXHistogram alloc] init];
            [data charon_setValue:made forKey:@"histogrammedSignpostDuration"];
            made;
        });
        NSMutableArray *buckets = objc_getAssociatedObject(histogram, @selector(bucketEnumerator));
        if (!buckets) {
            buckets = [NSMutableArray array];
            objc_setAssociatedObject(histogram, @selector(bucketEnumerator), buckets, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSMeasurement<NSUnitDuration *> *duration =
            [[NSMeasurement alloc] initWithDoubleValue:interval.seconds unit:[NSUnitDuration seconds]];
        MXHistogramBucket<NSUnitDuration *> *bucket = [[MXHistogramBucket alloc] init];
        [bucket charon_setValue:duration forKey:@"bucketStart"];
        [bucket charon_setValue:duration forKey:@"bucketEnd"];
        [bucket charon_setValue:@(interval.count) forKey:@"bucketCount"];
        [buckets addObject:bucket];
        [histogram charon_setValue:@(buckets.count) forKey:@"totalBucketCount"];
        [histogram charon_setValue:[buckets objectEnumerator] forKey:@"bucketEnumerator"];
        [metric charon_setValue:@((NSUInteger)[metric charon_totalCount] + interval.count) forKey:@"totalCount"];

        NSMeasurement<NSUnitDuration *> *cpu = [data charon_cumulativeCPUTime] ?: ({
            NSMeasurement *made = [[NSMeasurement alloc] initWithDoubleValue:0.0 unit:[NSUnitDuration seconds]];
            [data charon_setValue:made forKey:@"cumulativeCPUTime"];
            (NSMeasurement *)made;
        });
        [data charon_setValue:[[NSMeasurement alloc] initWithDoubleValue:[cpu doubleValue] + interval.seconds
                                                             unit:[NSUnitDuration seconds]]
                   forKey:@"cumulativeCPUTime"];
    }
    return metrics;
}
