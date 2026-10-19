#import <Foundation/Foundation.h>

typedef void (^InvalidationRecorder)(NSString *name, NSString *value);

void invalidation_run(InvalidationRecorder record);
