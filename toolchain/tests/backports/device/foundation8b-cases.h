#import <Foundation/Foundation.h>

typedef void (^Foundation8bRecorder)(NSString *name, NSString *value);

void foundation8b_run(Foundation8bRecorder record);
