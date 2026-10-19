#import <Foundation/Foundation.h>
#import <os/log.h>
#import <os/signpost.h>

// The signpost family of iOS 12, over this port's own os_log, and the store the intervals land in.
//
// A signpost is a software mark: an application says "this interval began" and "it ended", with a name
// and a format, and the system shows the intervals in Instruments. Nothing about it is hardware, and
// the release's cache carries none of it - `_os_signpost_emit_with_name_impl`, `os_signpost_enabled`,
// `os_signpost_id_generate` and `os_signpost_id_make_with_pointer` are all absent from the armv7 6.1.3
// cache - while this package already carries the log they sit on (registry/Foundation/oslog.json,
// Foundation/OSLog9.m and OSLog10.m). So the family is here, over that log, and it *records* what it
// is told: the intervals an application marks are kept, and MetricKit's signpost metrics are read out
// of the same store (MXMetricManager.m, -_MXSignpostMetricsSnapshot). That is what makes the family
// worth carrying rather than a set of stubs: the mark an application makes is measurable afterwards.

// The port's own record of one signpost interval, keyed by the id that began it. `name` is the
// signpost's name, `subsystem` and `category` the log's, and `seconds` the interval's length - a
// monotonic difference taken between the two emits, which is the whole of what an interval is.
@interface CharonSignpostInterval : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *subsystem;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, assign) NSTimeInterval seconds;
@property (nonatomic, assign) NSUInteger count;
@end
@interface CharonSignpostInterval (CharonSynthesis)
@end

// Every interval the process has emitted, oldest first, and the store they are read from. This is the
// port's own API - a Charon-prefixed class and two functions - so the registry has nothing to describe
// and an application cannot mistake it for Apple's.
// The store of the intervals a process has marked. MetricKit's snapshot is its own object rather than
// one of this class's: a library of this package exports only the names the registry lists, so a class
// of ours defined here cannot be named from another of our libraries, and the snapshot - which
// _MXSignpostMetricsSnapshot returns and which therefore lives in the metric library - is the object
// that has to be built there.
// The name another of this package's libraries looks this class up by, which is how it reaches it: a
// library of this package exports only the names the registry lists, and the registry lists only
// names an SDK header declares, so nothing of ours is linkable from another of our libraries. The
// store is looked up once by this name and messaged, which is the port's own idiom for a class in
// another image (NSClassFromString in AVFoundation/AVCaptureDevice+Authorization.m, in
// CoreSpotlight/CSSearchableIndex.m, in CallKit/CharonCallAudio.m).

@interface CharonSignpostStore : NSObject
+ (NSArray<CharonSignpostInterval *> *)intervals;
// The public signpost:metrics pointer the mark carried, kept with the interval, so that the signpost the
// application marked and the snapshot MetricKit read the metrics from are the same fact.
+ (void)takePointer:(void *)pointer forInterval:(CharonSignpostInterval *)interval;
+ (void)recordBeginFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name;
+ (void)recordEndFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name;
+ (void)recordEventFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name;
+ (void)reset;
@end
