#import <Foundation/Foundation.h>

@interface KeyedArchive11Recorder : NSObject
@property (nonatomic, readonly) NSMutableDictionary *records;
- (void)record:(NSString *)value named:(NSString *)name;
@end

void keyedarchive11_run(NSString *prefix, KeyedArchive11Recorder *recorder);
