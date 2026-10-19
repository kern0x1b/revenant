#import <Foundation/Foundation.h>

typedef void (^CallKitRecorder)(NSString *name, NSString *value);

void callkit_run(CallKitRecorder record);
