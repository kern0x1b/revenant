#import <Foundation/Foundation.h>

typedef struct {
    NSString *prefix;
    CFTypeRef (*autorelease)(CFTypeRef);
    NSString *rootObjectKey;
    NSArray *ubiquityKeys;
    NSArray *transformNames;
    NSArray *progressConstants;
    Class queryItemClass;
} Foundation2Implementation;

@interface Foundation2Recorder : NSObject
@property (nonatomic, readonly) NSMutableDictionary *records;
@property (nonatomic, readonly) NSMutableDictionary *tolerated;
- (void)record:(id)value named:(NSString *)name;
- (void)record:(id)value named:(NSString *)name tolerating:(NSString *)divergence;
@end

void foundation2_run(Foundation2Implementation implementation, Foundation2Recorder *recorder);
NSString *foundation2_digest(NSData *data);
id foundation2_portable(id value);
