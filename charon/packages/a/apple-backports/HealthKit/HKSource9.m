// HKSource: the version of the process, which the source revision of everything it saves carries.
// The source itself is of iOS 8.0 and is in HKSource.m; the version out of the process's own plist is
// what iOS 9.0's HKSourceRevision needs, and this is a file of its own.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKSource (CharonIOS9)

// The CFBundleVersion of the process itself, out of its own Info.plist through the release's own
// NSBundle, and nil where the plist names none. The header says a source revision's version "is taken
// from the CFBundleVersion of the source" and "may be nil for older data", so nil is the answer the
// release itself gives where there is no version to take, and it stays nil rather than becoming an
// empty string.
+ (nullable NSString *)charon_processVersion
{
    static NSString *version;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSDictionary *info = [bundle localizedInfoDictionary] ?: [bundle infoDictionary];
        id given = [info objectForKey:@"CFBundleVersion"];
        version = [given isKindOfClass:[NSString class]] ? [given copy] : nil;
    });
    return version;
}

@end
