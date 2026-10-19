#import <Foundation/Foundation.h>

typedef void (^UIKitNamesRecorder)(NSString *name, NSString *value);

void uikitnames_run(UIKitNamesRecorder record);
