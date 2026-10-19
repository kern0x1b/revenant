#import <Foundation/Foundation.h>

typedef void (^UIKitAdditionsRecorder)(NSString *name, NSString *value);

void uikitadditions_run(UIKitAdditionsRecorder record);
