#import <UIKit/UIKit.h>

@interface DirectionalEdgesRecorder : NSObject
@property (nonatomic, readonly) NSMutableDictionary *records;
- (void)record:(NSString *)value named:(NSString *)name;
@end

typedef struct {
    NSString *prefix;
    const NSDirectionalEdgeInsets *zero;
    NSString *(*string)(NSDirectionalEdgeInsets);
    NSDirectionalEdgeInsets (*parse)(NSString *);
} DirectionalEdgesImplementation;

void directionaledges_run(DirectionalEdgesImplementation implementation, DirectionalEdgesRecorder *recorder);
