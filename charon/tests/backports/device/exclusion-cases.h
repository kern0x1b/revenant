#import <Foundation/Foundation.h>

typedef void (^ExclusionRecorder)(NSString *name, NSString *value);

void exclusion_run(ExclusionRecorder record);
