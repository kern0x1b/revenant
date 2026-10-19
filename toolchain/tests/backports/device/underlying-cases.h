#import <Foundation/Foundation.h>

typedef void (^UnderlyingRecorder)(NSString *name, NSString *value);

void underlying_run(NSOperationQueue *(^make)(void), UnderlyingRecorder record);
