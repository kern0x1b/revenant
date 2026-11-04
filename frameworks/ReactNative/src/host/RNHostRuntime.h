#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const RNHostErrorDomain;

@interface RNHostRuntime : NSObject

+ (NSString *)configuredBundlePath;
+ (NSString *)configuredValueForKey:(NSString *)key;
+ (BOOL)usesHermes;
+ (void)applyEnvironment;
+ (double)residentMegabytes;
+ (NSString *)evaluateBundleAtPath:(NSString *)path error:(NSError **)error;
+ (void)logClassProbes;
+ (void)logMemoryMap;
+ (void)logLayerCensus:(UIView *)root;
+ (void)logViewAudit:(UIView *)root;

@end
