#import <Foundation/Foundation.h>

typedef void (^UIKitConstantsRecorder)(NSString *name, NSString *value);

void uikitconst_run(UIKitConstantsRecorder record);
void uikitrotor_run(UIKitConstantsRecorder record);
