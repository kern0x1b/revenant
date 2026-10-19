#import "CharonMetricValue.h"
#import "CharonMetricKit.h"
#import "../Foundation/CharonOSLog.h"
#import "../Foundation/CharonOSSignpost.h"
#import "../CharonSayOnce.h"
#import <objc/runtime.h>
#import <sys/time.h>

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
    return (double)now.tv_sec + (double)now.tv_usec / 1000000.0;
}

@implementation MXMetricManager

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
