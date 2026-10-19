#import <Foundation/Foundation.h>

typedef struct {
    NSString *prefix;
    Class transformer;
} Foundation11Implementation;

@interface Foundation11Recorder : NSObject
@property (nonatomic, readonly) NSMutableDictionary *records;
- (void)record:(NSString *)value named:(NSString *)name;
@end

void foundation11_run(Foundation11Implementation implementation, Foundation11Recorder *recorder);
