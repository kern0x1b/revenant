#import "RevenantMetricValue.h"
#import "RevenantMetricKit.h"
#import "../Foundation/RevenantOSLog.h"
#import "../Foundation/RevenantOSSignpost.h"
#import "../RevenantSayOnce.h"
#import <objc/runtime.h>
#import <sys/time.h>

static NSString *const RevenantMXErrorDomain = @"MXErrorDomain";

static NSString *const RevenantPayloadsKey = @"org.revenant.backports.MetricKit.payloads";
static NSString *const RevenantLaunchMeasurementsKey = @"org.revenant.backports.MetricKit.extendedLaunch";

static NSString *RevenantPayloadFolder(void)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *root = paths.firstObject ?: NSTemporaryDirectory();
    NSString *folder = [root stringByAppendingPathComponent:@"org.revenant.backports.MetricKit"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    return folder;
}

static NSMutableDictionary *RevenantLaunchMeasurements(void)
{
    NSDictionary *held = [[NSUserDefaults standardUserDefaults] dictionaryForKey:RevenantLaunchMeasurementsKey];
    return held ? [held mutableCopy] : [NSMutableDictionary dictionary];
}

static double RevenantMonotonicSeconds(void)
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
    return [self revenant_payloadsOfClass:[MXMetricPayload class] extension:@"metric"];
}

- (NSArray<MXDiagnosticPayload *> *)pastDiagnosticPayloads
{
    return [self revenant_payloadsOfClass:[MXDiagnosticPayload class] extension:@"diagnostic"];
}

- (NSArray *)revenant_payloadsOfClass:(Class)cls extension:(NSString *)extension
{
    NSString *folder = RevenantPayloadFolder();
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
        id payload = [NSKeyedUnarchiver unarchivedObjectOfClasses:[RevenantMetricValue decodableClasses] fromData:data error:&error];
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
    NSHashTable *table = [self revenant_subscriberTable];
    if (![table containsObject:subscriber])
        [table addObject:subscriber];
}

- (void)removeSubscriber:(id<MXMetricManagerSubscriber>)subscriber
{
    if (!subscriber)
        return;
    [[self revenant_subscriberTable] removeObject:subscriber];
}

- (void)revenant_deliverTo:(id<MXMetricManagerSubscriber>)subscriber
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

- (NSHashTable *)revenant_subscriberTable
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
            *error = [NSError errorWithDomain:RevenantMXErrorDomain code:1 userInfo:nil];
        return NO;
    }
    NSMutableDictionary *measurements = RevenantLaunchMeasurements();
    measurements[[taskID description]] = @(RevenantMonotonicSeconds());
    [[NSUserDefaults standardUserDefaults] setObject:measurements forKey:RevenantLaunchMeasurementsKey];
    return YES;
}

+ (BOOL)finishExtendedLaunchMeasurementForTaskID:(MXLaunchTaskID)taskID error:(NSError **)error
{
    if (!taskID) {
        if (error)
            *error = [NSError errorWithDomain:RevenantMXErrorDomain code:1 userInfo:nil];
        return NO;
    }
    NSString *key = [taskID description];
    NSMutableDictionary *measurements = RevenantLaunchMeasurements();
    NSNumber *began = measurements[key];
    if (!began) {
        if (error)
            *error = [NSError errorWithDomain:RevenantMXErrorDomain code:2 userInfo:nil];
        return NO;
    }
    double interval = RevenantMonotonicSeconds() - [began doubleValue];
    [measurements removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] setObject:measurements forKey:RevenantLaunchMeasurementsKey];

    MXAppLaunchMetric *metric = [[MXAppLaunchMetric alloc] init];
    MXHistogram<NSUnitDuration *> *histogram = [[MXHistogram alloc] init];
    NSMeasurement<NSUnitDuration *> *duration =
        [[NSMeasurement alloc] initWithDoubleValue:interval unit:[NSUnitDuration seconds]];
    [histogram revenant_setValue:@1 forKey:@"totalBucketCount"];
    MXHistogramBucket<NSUnitDuration *> *bucket = [[MXHistogramBucket alloc] init];
    [bucket revenant_setValue:duration forKey:@"bucketStart"];
    [bucket revenant_setValue:duration forKey:@"bucketEnd"];
    [bucket revenant_setValue:@1 forKey:@"bucketCount"];
    [histogram revenant_setValue:[@[bucket] objectEnumerator] forKey:@"bucketEnumerator"];
    [metric revenant_setValue:histogram forKey:@"histogrammedExtendedLaunch"];
    return YES;
}

@end

@interface RevenantMetricSnapshot : NSObject
@property (nonatomic, copy) NSArray<RevenantSignpostInterval *> *intervals;
@end

@implementation RevenantMetricSnapshot
@synthesize intervals = _intervals;
@end

static Class RevenantSignpostStoreClass(void)
{
    static Class store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        store = NSClassFromString(@"RevenantSignpostStore");
    });
    return store;
}

static NSArray<RevenantSignpostInterval *> *RevenantRecordedIntervals(void)
{
    Class store = RevenantSignpostStoreClass();
    if (!store || ![store respondsToSelector:@selector(intervals)])
        return @[];
    return [store performSelector:@selector(intervals)] ?: @[];
}

void *_Nonnull _MXSignpostMetricsSnapshot(void)
{
    RevenantMetricSnapshot *snapshot = [[RevenantMetricSnapshot alloc] init];
    snapshot.intervals = RevenantRecordedIntervals();
    return (__bridge_retained void *)snapshot;
}

NSArray<MXSignpostMetric *> *RevenantSignpostMetrics(void)
{
    NSMutableArray<MXSignpostMetric *> *metrics = [NSMutableArray array];
    NSMutableDictionary<NSString *, MXSignpostMetric *> *byKey = [NSMutableDictionary dictionary];
    for (RevenantSignpostInterval *interval in RevenantRecordedIntervals()) {
        NSString *key = [NSString stringWithFormat:@"%@%c%@", interval.subsystem, 0, interval.name];
        MXSignpostMetric *metric = byKey[key];
        if (!metric) {
            metric = [[MXSignpostMetric alloc] init];
            [metric revenant_setValue:interval.name forKey:@"signpostName"];
            [metric revenant_setValue:interval.category forKey:@"signpostCategory"];
            byKey[key] = metric;
            [metrics addObject:metric];
        }
        MXSignpostIntervalData *data = [metric revenant_signpostIntervalData] ?: ({
            MXSignpostIntervalData *made = [[MXSignpostIntervalData alloc] init];
            [metric revenant_setValue:made forKey:@"signpostIntervalData"];
            made;
        });
        MXHistogram *histogram = [data revenant_histogrammedSignpostDuration] ?: ({
            MXHistogram *made = [[MXHistogram alloc] init];
            [data revenant_setValue:made forKey:@"histogrammedSignpostDuration"];
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
        [bucket revenant_setValue:duration forKey:@"bucketStart"];
        [bucket revenant_setValue:duration forKey:@"bucketEnd"];
        [bucket revenant_setValue:@(interval.count) forKey:@"bucketCount"];
        [buckets addObject:bucket];
        [histogram revenant_setValue:@(buckets.count) forKey:@"totalBucketCount"];
        [histogram revenant_setValue:[buckets objectEnumerator] forKey:@"bucketEnumerator"];
        [metric revenant_setValue:@((NSUInteger)[metric revenant_totalCount] + interval.count) forKey:@"totalCount"];

        NSMeasurement<NSUnitDuration *> *cpu = [data revenant_cumulativeCPUTime] ?: ({
            NSMeasurement *made = [[NSMeasurement alloc] initWithDoubleValue:0.0 unit:[NSUnitDuration seconds]];
            [data revenant_setValue:made forKey:@"cumulativeCPUTime"];
            (NSMeasurement *)made;
        });
        [data revenant_setValue:[[NSMeasurement alloc] initWithDoubleValue:[cpu doubleValue] + interval.seconds
                                                             unit:[NSUnitDuration seconds]]
                   forKey:@"cumulativeCPUTime"];
    }
    return metrics;
}
